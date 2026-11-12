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
    var url: URL
    var anonKey: String

    var isConfigured: Bool {
        let key = anonKey.trimmingCharacters(in: .whitespacesAndNewlines)
        return !key.isEmpty && key != "paste-anon-key-here"
    }

    static func fromBundle(_ bundle: Bundle = .main) -> BackendConfig {
        let rawURL = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String ?? ""
        let key = (bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = URL(string: rawURL) ?? URL(string: "https://sfckxrnoiwetmzdycqaa.supabase.co")!
        return BackendConfig(url: url, anonKey: key)
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
    func load() -> AuthSession?
    func save(_ session: AuthSession)
    func clear()
}

protocol AuthService: AnyObject {
    func sendCode(to email: String) async throws
    func verify(email: String, code: String) async throws -> AuthSession
    func restore() -> AuthSession?
    func signOut() async
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
