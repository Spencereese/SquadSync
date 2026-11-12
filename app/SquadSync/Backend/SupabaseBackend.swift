import Foundation

final class SupabaseAuthService: AuthService {
    private let config: BackendConfig
    private let store: SessionStoring

    init(config: BackendConfig, store: SessionStoring) {
        self.config = config
        self.store = store
    }

    func sendCode(to email: String) async throws {
        let body = try BackendJSON.encoder.encode(EmailBody(email: email, createUser: true))
        _ = try await http().send(
            path: "auth/v1/otp",
            method: "POST",
            body: body,
            feature: .profile
        )
    }

    func verify(email: String, code: String) async throws -> AuthSession {
        let body = try BackendJSON.encoder.encode(VerifyBody(email: email, token: code, type: "email"))
        let data = try await http().send(
            path: "auth/v1/verify",
            method: "POST",
            body: body,
            feature: .profile
        )
        let decoded = try BackendJSON.decoder.decode(VerifyResponse.self, from: data)
        let session = AuthSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            userId: decoded.user.id,
            email: decoded.user.email ?? email
        )
        try store.save(session)
        return session
    }

    func restore() throws -> AuthSession? { try store.load() }

    func signOut() async throws {
        if let token = try store.load()?.accessToken {
            var client = http()
            client.accessToken = token
            _ = try? await client.send(path: "auth/v1/logout", method: "POST", feature: .profile)
        }
        try store.clear()
    }

    private func http() -> SupabaseHTTP { SupabaseHTTP(config: config, accessToken: nil) }

    private struct EmailBody: Encodable {
        let email: String
        let createUser: Bool
        enum CodingKeys: String, CodingKey {
            case email
            case createUser = "create_user"
        }
    }

    private struct VerifyBody: Encodable {
        let email: String
        let token: String
        let type: String
    }

    private struct VerifyResponse: Decodable {
        let accessToken: String
        let refreshToken: String
        let user: User
        struct User: Decodable {
            let id: UUID
            let email: String?
        }
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case user
        }
    }
}

final class SupabaseProfileService: ProfileService {
    private let http: SupabaseHTTP

    init(config: BackendConfig, accessToken: String) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken)
    }

    func loadOrCreate(userId: UUID, email: String) async throws -> UserProfile {
        let rows = try await http.send(
            path: "rest/v1/sq8_profiles",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(userId.uuidString)"),
                URLQueryItem(name: "select", value: "id,display_name,default_game")
            ],
            feature: .profile
        )
        let found = try BackendJSON.decoder.decode([UserProfile].self, from: rows)
        if let existing = found.first { return existing }
        let name = email.split(separator: "@").first.map(String.init) ?? "Player"
        let created = UserProfile(id: userId, displayName: name, defaultGame: "Call of Duty")
        let body = try BackendJSON.encoder.encode(created)
        _ = try await http.send(
            path: "rest/v1/sq8_profiles",
            method: "POST",
            body: body,
            prefer: "return=minimal",
            feature: .profile
        )
        return created
    }

    func save(_ profile: UserProfile) async throws {
        let body = try BackendJSON.encoder.encode(ProfilePatch(displayName: profile.displayName, defaultGame: profile.defaultGame))
        _ = try await http.send(
            path: "rest/v1/sq8_profiles",
            method: "PATCH",
            query: [URLQueryItem(name: "id", value: "eq.\(profile.id.uuidString)")],
            body: body,
            prefer: "return=minimal",
            feature: .profile
        )
    }

    private struct ProfilePatch: Encodable {
        let displayName: String
        let defaultGame: String
        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case defaultGame = "default_game"
        }
    }
}

final class SupabaseSquadService: SquadService {
    private let http: SupabaseHTTP

    init(config: BackendConfig, accessToken: String) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken)
    }

    func currentSquad(userId: UUID) async throws -> SquadRecord? {
        let mine = try await http.send(
            path: "rest/v1/sq8_squad_members",
            method: "GET",
            query: [
                URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)"),
                URLQueryItem(name: "select", value: "squad_id")
            ],
            feature: .squad
        )
        let seats = try BackendJSON.decoder.decode([Seat].self, from: mine)
        guard let squadId = seats.first?.squadId else { return nil }
        return try await load(squadId: squadId)
    }

    func createSquad(ownerId: UUID) async throws -> SquadRecord {
        let body = try BackendJSON.encoder.encode(NewSquad(ownerId: ownerId))
        let data = try await http.send(
            path: "rest/v1/sq8_squads",
            method: "POST",
            body: body,
            prefer: "return=representation",
            feature: .squad
        )
        let created = try BackendJSON.decoder.decode([SquadRow].self, from: data)
        guard let row = created.first else { throw BackendFailure.rejected("Squad was not returned.") }
        return try await load(squadId: row.id)
    }

    private func load(squadId: UUID) async throws -> SquadRecord {
        let squadData = try await http.send(
            path: "rest/v1/sq8_squads",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: "id,owner_id")
            ],
            feature: .squad
        )
        let squads = try BackendJSON.decoder.decode([SquadRow].self, from: squadData)
        guard let squad = squads.first else { throw BackendFailure.rejected("Squad was not found.") }
        let memberData = try await http.send(
            path: "rest/v1/sq8_squad_members",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: "user_id")
            ],
            feature: .squad
        )
        let memberIDs = try BackendJSON.decoder.decode([MemberRow].self, from: memberData).map(\.userId)
        let profiles = try await profiles(for: memberIDs)
        let members = memberIDs.map { id in
            let profile = profiles.first { $0.id == id }
            return SquadMemberRecord(
                id: id,
                displayName: profile?.displayName ?? "Player",
                defaultGame: profile?.defaultGame ?? "",
                isOwner: id == squad.ownerId
            )
        }
        return SquadRecord(id: squad.id, ownerId: squad.ownerId, members: members)
    }

    private func profiles(for ids: [UUID]) async throws -> [UserProfile] {
        guard !ids.isEmpty else { return [] }
        let list = ids.map(\.uuidString).joined(separator: ",")
        let data = try await http.send(
            path: "rest/v1/sq8_profiles",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "in.(\(list))"),
                URLQueryItem(name: "select", value: "id,display_name,default_game")
            ],
            feature: .profile
        )
        return try BackendJSON.decoder.decode([UserProfile].self, from: data)
    }

    private struct Seat: Decodable {
        let squadId: UUID
        enum CodingKeys: String, CodingKey { case squadId = "squad_id" }
    }

    private struct SquadRow: Decodable {
        let id: UUID
        let ownerId: UUID
        enum CodingKeys: String, CodingKey {
            case id
            case ownerId = "owner_id"
        }
    }

    private struct MemberRow: Decodable {
        let userId: UUID
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    private struct NewSquad: Encodable {
        let ownerId: UUID
        enum CodingKeys: String, CodingKey { case ownerId = "owner_id" }
    }
}

final class SupabaseChatService: ChatService {
    private let http: SupabaseHTTP

    init(config: BackendConfig, accessToken: String) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken)
    }

    func history(squadId: UUID) async throws -> [RemoteMessage] {
        try await fetch(squadId: squadId, after: nil)
    }

    func send(_ message: RemoteMessage) async throws {
        let body = try BackendJSON.encoder.encode(message)
        _ = try await http.send(
            path: "rest/v1/sq8_messages",
            method: "POST",
            body: body,
            prefer: "return=minimal,resolution=ignore-duplicates",
            feature: .messages
        )
    }

    func newer(squadId: UUID, after: Date) async throws -> [RemoteMessage] {
        try await fetch(squadId: squadId, after: after)
    }

    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws {
        let body = try BackendJSON.encoder.encode(ReadWrite(userId: userId, squadId: squadId, lastReadAt: at, lastReadId: messageId))
        _ = try await http.send(
            path: "rest/v1/sq8_chat_read_state",
            method: "POST",
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal",
            feature: .readState
        )
    }

    private func fetch(squadId: UUID, after: Date?) async throws -> [RemoteMessage] {
        var query = [
            URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
            URLQueryItem(name: "select", value: "id,squad_id,sender_id,body,sent_at"),
            URLQueryItem(name: "order", value: "sent_at.asc,id.asc"),
            URLQueryItem(name: "limit", value: "200")
        ]
        if let after, let text = BackendJSON.parseStamp(after) {
            query.append(URLQueryItem(name: "sent_at", value: "gt.\(text)"))
        }
        let data = try await http.send(
            path: "rest/v1/sq8_messages",
            method: "GET",
            query: query,
            feature: .messages
        )
        return try BackendJSON.decoder.decode([RemoteMessage].self, from: data)
    }

    private struct ReadWrite: Encodable {
        let userId: UUID
        let squadId: UUID
        let lastReadAt: Date
        let lastReadId: UUID?
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case squadId = "squad_id"
            case lastReadAt = "last_read_at"
            case lastReadId = "last_read_id"
        }
    }
}
