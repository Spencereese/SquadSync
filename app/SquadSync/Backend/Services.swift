import Foundation

enum BackendMode: String {
    case mock
    case live
}

enum BackendFeature: String, Equatable {
    case profile = "Profiles"
    case squad = "Squads"
    case messages = "Chat"
    case readState = "Read markers"
}

enum BackendFailure: Error, Equatable {
    case notConfigured
    case notSignedIn
    case notSetUp(BackendFeature)
    case rejected(String)
}

struct BackendConfig: Equatable {
    var urlText: String
    var anonKey: String

    var url: URL? {
        let text = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains("$(") else { return nil }
        return URL(string: text)
    }

    var missingKeys: [String] {
        var keys: [String] = []
        if url == nil { keys.append("SupabaseURL") }
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.isEmpty || key == "paste-anon-key-here" || key.contains("$(") {
            keys.append("SupabaseAnonKey")
        }
        return keys
    }

    var isConfigured: Bool { missingKeys.isEmpty }

    var configurationError: String? {
        let keys = missingKeys
        guard !keys.isEmpty else { return nil }
        return "Supabase is not configured. Empty: \(keys.joined(separator: ", "))."
    }

    static func parse(_ info: [String: Any]) -> BackendConfig {
        BackendConfig(
            urlText: info["SupabaseURL"] as? String ?? "",
            anonKey: info["SupabaseAnonKey"] as? String ?? ""
        )
    }

    static func fromBundle(_ bundle: Bundle = .main) -> BackendConfig {
        parse(bundle.infoDictionary ?? [:])
    }
}

struct AuthSession: Equatable, Codable {
    var accessToken: String
    var refreshToken: String
    var userId: UUID
    var email: String
}

struct UserProfile: Equatable, Identifiable, Codable {
    let id: UUID
    var displayName: String
    var defaultGame: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case defaultGame = "default_game"
    }
}

struct SquadMemberRecord: Equatable, Identifiable {
    let id: UUID
    var displayName: String
    var defaultGame: String
    var isOwner: Bool
}

struct SquadRecord: Equatable, Identifiable {
    let id: UUID
    let ownerId: UUID
    var members: [SquadMemberRecord]
}

struct RemoteMessage: Equatable, Identifiable, Codable {
    let id: UUID
    let squadId: UUID
    let senderId: UUID
    var body: String
    var sentAt: Date

    func entry() -> ChatEntry {
        ChatEntry(id: id, senderId: senderId, body: body, sentAt: sentAt, delivery: .sent)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case senderId = "sender_id"
        case body
        case sentAt = "sent_at"
    }
}

protocol SessionStoring: AnyObject {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear() throws
}

protocol AuthService: AnyObject {
    func sendCode(to email: String) async throws
    func verify(email: String, code: String) async throws -> AuthSession
    func restore() throws -> AuthSession?
    func signOut() async throws
}

protocol ProfileService: AnyObject {
    func loadOrCreate(userId: UUID, email: String) async throws -> UserProfile
    func save(_ profile: UserProfile) async throws
}

protocol SquadService: AnyObject {
    func currentSquad(userId: UUID) async throws -> SquadRecord?
    func createSquad(ownerId: UUID) async throws -> SquadRecord
}

protocol ChatService: AnyObject {
    func history(squadId: UUID) async throws -> [RemoteMessage]
    func send(_ message: RemoteMessage) async throws
    func newer(squadId: UUID, after: Date) async throws -> [RemoteMessage]
    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws
}
