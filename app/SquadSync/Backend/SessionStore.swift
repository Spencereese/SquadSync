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

struct SessionEnvelope: Codable, Equatable {
    var session: AuthSession
    var savedAt: Date

    static func newer(_ first: SessionEnvelope?, _ second: SessionEnvelope?) -> SessionEnvelope? {
        switch (first, second) {
        case (nil, nil):
            return nil
        case (let only?, nil), (nil, let only?):
            return only
        case (let primary?, let backup?):
            return primary.savedAt >= backup.savedAt ? primary : backup
        }
    }

    static func decode(_ data: Data) -> SessionEnvelope? {
        if let envelope = try? JSONDecoder().decode(SessionEnvelope.self, from: data) {
            return envelope
        }
        if let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            return SessionEnvelope(session: session, savedAt: .distantPast)
        }
        return nil
    }
}

final class KeychainSessionStore: SessionStoring {
    private let service: String
    private let account: String
    private let defaults: UserDefaults
    private let defaultsKey: String
    private let clearedAtKey: String
    private var usingFallback = false
    private static var didLogFallback = false

    init(
        defaults: UserDefaults = .standard,
        service: String = "com.spencereese.squadsync.session",
        account: String = "sq8"
    ) {
        self.defaults = defaults
        self.service = service
        self.account = account
        if service == "com.spencereese.squadsync.session" && account == "sq8" {
            self.defaultsKey = "sq8.session.fallback"
            self.clearedAtKey = "sq8.session.cleared-at"
        } else {
            self.defaultsKey = "sq8.session.fallback.\(service).\(account)"
            self.clearedAtKey = "sq8.session.cleared-at.\(service).\(account)"
        }
    }

    func load() throws -> AuthSession? {
        let backup = visible(try readFallback())
        if usingFallback { return backup?.session }
        let found = copyMatching()
        switch KeychainFallbackPolicy.choose(status: found.status) {
        case .keychain:
            guard found.status == errSecSuccess, let data = found.data, let primary = visible(SessionEnvelope.decode(data)) else {
                return backup?.session
            }
            return SessionEnvelope.newer(primary, backup)?.session
        case .insecureFallback:
            noteFallback()
            usingFallback = true
            return backup?.session
        case .failure(let status):
            throw SessionStoreError.keychain(status)
        }
    }

    func save(_ session: AuthSession) throws {
        let data = try JSONEncoder().encode(SessionEnvelope(session: session, savedAt: Date()))
        if usingFallback {
            defaults.set(data, forKey: defaultsKey)
            return
        }
        let status = write(data)
        switch KeychainFallbackPolicy.choose(status: status) {
        case .keychain:
            guard status == errSecSuccess else { throw SessionStoreError.keychain(status) }
            defaults.set(data, forKey: defaultsKey)
        case .insecureFallback:
            noteFallback()
            usingFallback = true
            defaults.set(data, forKey: defaultsKey)
        case .failure(let code):
            throw SessionStoreError.keychain(code)
        }
    }

    func clear() throws {
        defaults.removeObject(forKey: defaultsKey)
        defaults.set(Date(), forKey: clearedAtKey)
        if usingFallback { return }
        let status = delete()
        switch KeychainFallbackPolicy.choose(status: status) {
        case .keychain:
            if status != errSecSuccess && status != errSecItemNotFound {
                throw SessionStoreError.keychain(status)
            }
            defaults.removeObject(forKey: clearedAtKey)
        case .insecureFallback:
            noteFallback()
            usingFallback = true
        case .failure(let code):
            throw SessionStoreError.keychain(code)
        }
    }

    private func visible(_ envelope: SessionEnvelope?) -> SessionEnvelope? {
        guard let envelope else { return nil }
        if let clearedAt = defaults.object(forKey: clearedAtKey) as? Date, envelope.savedAt <= clearedAt {
            return nil
        }
        return envelope
    }

    private func noteFallback() {
        guard !Self.didLogFallback else { return }
        Self.didLogFallback = true
        SquadLog.http.notice("auth keychain status -34018, session store is UserDefaults")
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

    private func readFallback() throws -> SessionEnvelope? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }
        guard let envelope = SessionEnvelope.decode(data) else {
            throw SessionStoreError.unreadable
        }
        return envelope
    }
}
