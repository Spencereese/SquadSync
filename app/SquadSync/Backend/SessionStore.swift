import Foundation
import Security

final class MemorySessionStore: SessionStoring {
    private var session: AuthSession?

    func load() -> AuthSession? { session }

    func save(_ session: AuthSession) { self.session = session }

    func clear() { session = nil }
}

final class KeychainSessionStore: SessionStoring {
    private let service = "com.spencereese.squadsync.session"
    private let account = "sq8"
    private var memory: AuthSession?

    func load() -> AuthSession? {
        if let memory { return memory }
        guard let data = read() else { return nil }
        let session = try? JSONDecoder().decode(AuthSession.self, from: data)
        memory = session
        return session
    }

    func save(_ session: AuthSession) {
        memory = session
        guard let data = try? JSONEncoder().encode(session) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    func clear() {
        memory = nil
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func read() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }
}
