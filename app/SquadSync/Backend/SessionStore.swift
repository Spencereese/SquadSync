import Foundation
import Security

enum SessionStoreError: Error, Equatable {
    case keychain(OSStatus)
    case unreadable

    var message: String {
        switch self {
        case .keychain(let status):
            "Session restore failed. Keychain status \(status)."
        case .unreadable:
            "Session restore failed. The saved session could not be read."
        }
    }
}

enum SessionStoreChoice: Equatable {
    case keychain
    case insecureFallback
    case failure(OSStatus)
}

enum KeychainFallbackPolicy {
    /// errSecMissingEntitlement. The unsigned simulator returns this.
    static let missingEntitlement: OSStatus = -34018

    static var allowsInsecureFallback: Bool {
        #if DEBUG
        return true
        #elseif targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static func choose(status: OSStatus, allowsFallback: Bool = allowsInsecureFallback) -> SessionStoreChoice {
        if status == errSecSuccess || status == errSecItemNotFound {
            return .keychain
        }
        if status == missingEntitlement && allowsFallback {
            return .insecureFallback
        }
        return .failure(status)
    }
}

final class MemorySessionStore: SessionStoring {
    private var session: AuthSession?

    func load() throws -> AuthSession? { session }

    func save(_ session: AuthSession) throws { self.session = session }

    func clear() throws { session = nil }
}

final class KeychainSessionStore: SessionStoring {
    private let service = "com.spencereese.squadsync.session"
    private let account = "sq8"
    private let defaults: UserDefaults
    private let defaultsKey = "sq8.session.fallback"
    private var usingFallback = false
    private static var didLogFallback = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> AuthSession? {
        if usingFallback { return try readFallback() }
        let found = copyMatching()
        switch KeychainFallbackPolicy.choose(status: found.status) {
        case .keychain:
            guard found.status == errSecSuccess, let data = found.data else { return nil }
            return try decode(data)
        case .insecureFallback:
            noteFallback()
            usingFallback = true
            return try readFallback()
        case .failure(let status):
            throw SessionStoreError.keychain(status)
        }
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(session)
        if usingFallback {
            defaults.set(data, forKey: defaultsKey)
            return
        }
        let status = write(data)
        switch KeychainFallbackPolicy.choose(status: status) {
        case .keychain:
            guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
        case .insecureFallback:
            noteFallback()
            usingFallback = true
            defaults.set(data, forKey: defaultsKey)
        case .failure(let code):
            throw SessionStoreError.keychain(code)
        }
    }

    func clear() throws {
        if usingFallback {
            defaults.removeObject(forKey: defaultsKey)
            return
        }
        let status = delete()
        switch KeychainFallbackPolicy.choose(status: status) {
        case .keychain:
            if status != errSecSuccess && status != errSecItemNotFound {
                throw SessionStoreError.keychain(status)
            }
        case .insecureFallback:
            noteFallback()
            usingFallback = true
            defaults.removeObject(forKey: defaultsKey)
        case .failure(let code):
            throw SessionStoreError.keychain(code)
        }
    }

    private func noteFallback() {
        guard !Self.didLogFallback else { return }
        Self.didLogFallback = true
        print("SquadSync: Keychain status -34018 (missing entitlement). This DEBUG or simulator build is storing the session in UserDefaults.")
    }

    private func copyMatching() -> (data: Data?, status: OSStatus) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        return (item as? Data, status)
    }

    private func write(_ data: Data) -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        return SecItemAdd(add as CFDictionary, nil)
    }

    private func delete() -> OSStatus {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        return SecItemDelete(query as CFDictionary)
    }

    private func readFallback() throws -> AuthSession? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        return try decode(data)
    }

    private func decode(_ data: Data) throws -> AuthSession {
        guard let session = try? JSONDecoder().decode(AuthSession.self, from: data) else {
            throw SessionStoreError.unreadable
        }
        return session
    }
}
