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
    var name: String
    var members: [SquadMemberRecord]
}

enum SquadSelect {
    static let columns = "id,owner_id,name"
}

struct SquadDetails: Decodable, Equatable {
    let id: UUID
    let ownerId: UUID
    var name: String

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerId = try container.decode(UUID.self, forKey: .ownerId)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

enum SignInCode {
    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValid(_ raw: String) -> Bool {
        let code = normalized(raw)
        return (6...10).contains(code.count) && code.allSatisfy(\.isNumber)
    }
}

enum SquadTitle {
    static func line(name: String, memberCount: Int, cap: Int = 8) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Your squad" : trimmed
        return "\(title) · \(memberCount) of \(cap)"
    }
}

enum SquadName {
    static let maxLength = 40

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func validationError(_ raw: String) -> String? {
        let name = normalized(raw)
        if name.isEmpty { return "Enter a squad name." }
        if name.count > maxLength { return "Use 40 characters or fewer." }
        return nil
    }
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
    func createSquad(ownerId: UUID, name: String) async throws -> SquadRecord
}

protocol ChatService: AnyObject {
    func history(squadId: UUID) async throws -> [RemoteMessage]
    func send(_ message: RemoteMessage) async throws
    func newer(squadId: UUID, after: Date) async throws -> [RemoteMessage]
    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws
}
