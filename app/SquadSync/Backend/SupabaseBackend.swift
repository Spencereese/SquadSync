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

    func createSquad(ownerId: UUID, name: String) async throws -> SquadRecord {
        let trimmed = SquadName.normalized(name)
        if let error = SquadName.validationError(trimmed) {
            throw BackendFailure.rejected(error)
        }
        let body = try BackendJSON.encoder.encode(NewSquad(ownerId: ownerId, name: trimmed))
        let data = try await http.send(
            path: "rest/v1/sq8_squads",
            method: "POST",
            body: body,
            prefer: "return=representation",
            feature: .squad
        )
        let created = try BackendJSON.decoder.decode([SquadDetails].self, from: data)
        guard let row = created.first else { throw BackendFailure.rejected("Squad was not returned.") }
        var record = try await load(squadId: row.id)
        if record.name.isEmpty { record.name = trimmed }
        return record
    }

    private func load(squadId: UUID) async throws -> SquadRecord {
        let squad = try await squadDetails(squadId: squadId)
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
        return SquadRecord(id: squad.id, ownerId: squad.ownerId, name: squad.name, members: members)
    }

    private func squadDetails(squadId: UUID) async throws -> SquadDetails {
        do {
            return try await fetchSquad(squadId: squadId, select: SquadSelect.columns)
        } catch let failure as BackendFailure {
            guard Self.missingNameColumn(failure) else { throw failure }
            return try await fetchSquad(squadId: squadId, select: "id,owner_id")
        }
    }

    private func fetchSquad(squadId: UUID, select: String) async throws -> SquadDetails {
        let squadData = try await http.send(
            path: "rest/v1/sq8_squads",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: select)
            ],
            feature: .squad
        )
        let squads = try BackendJSON.decoder.decode([SquadDetails].self, from: squadData)
        guard let squad = squads.first else { throw BackendFailure.rejected("Squad was not found.") }
        return squad
    }

    private static func missingNameColumn(_ failure: BackendFailure) -> Bool {
        guard case .rejected(let message) = failure else { return false }
        let text = message.lowercased()
        return text.contains("name") && text.contains("column")
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

    private struct MemberRow: Decodable {
        let userId: UUID
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    private struct NewSquad: Encodable {
        let ownerId: UUID
        let name: String
        enum CodingKeys: String, CodingKey {
            case ownerId = "owner_id"
            case name
        }
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
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_chat_read_state",
                method: "POST",
                body: body,
                prefer: "resolution=merge-duplicates,return=minimal",
                feature: .readState
            )
        } catch let failure as BackendFailure where isMissing(failure) {
        }
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_message_reads",
                method: "POST",
                body: body,
                prefer: "resolution=merge-duplicates,return=minimal",
                feature: .readState
            )
        } catch let failure as BackendFailure where isMissing(failure) {
        }
    }

    func reactions(squadId: UUID) async throws -> [ReactionMark] {
        let data = try await http.send(
            path: "rest/v1/sq8_message_reactions",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: "message_id,user_id,emoji")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([ReactionRow].self, from: data).map {
            ReactionMark(messageId: $0.messageId, userId: $0.userId, emoji: $0.emoji)
        }
    }

    func setReaction(squadId: UUID, messageId: UUID, userId: UUID, emoji: String, active: Bool) async throws {
        if !active {
            _ = try await http.send(
                path: "rest/v1/sq8_message_reactions",
                method: "DELETE",
                query: [
                    URLQueryItem(name: "message_id", value: "eq.\(messageId.uuidString)"),
                    URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "emoji", value: "eq.\(emoji)")
                ],
                feature: .messages
            )
            return
        }
        let body = try BackendJSON.encoder.encode(ReactionWrite(messageId: messageId, squadId: squadId, userId: userId, emoji: emoji))
        _ = try await http.send(
            path: "rest/v1/sq8_message_reactions",
            method: "POST",
            body: body,
            prefer: "return=minimal,resolution=ignore-duplicates",
            feature: .messages
        )
    }

    func reads(squadId: UUID) async throws -> [MemberRead] {
        let data = try await http.send(
            path: "rest/v1/sq8_message_reads",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: "user_id,last_read_at")
            ],
            feature: .readState
        )
        return try BackendJSON.decoder.decode([ReadRow].self, from: data).map {
            MemberRead(userId: $0.userId, lastReadAt: $0.lastReadAt)
        }
    }

    func ownReadAt(squadId: UUID, userId: UUID) async throws -> Date? {
        let shared = try await readStamp(path: "rest/v1/sq8_message_reads", squadId: squadId, userId: userId)
        let own = try await readStamp(path: "rest/v1/sq8_chat_read_state", squadId: squadId, userId: userId)
        return [shared, own].compactMap { $0 }.max()
    }

    private func readStamp(path: String, squadId: UUID, userId: UUID) async throws -> Date? {
        do {
            let data = try await http.send(
                path: path,
                method: "GET",
                query: [
                    URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                    URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "select", value: "last_read_at")
                ],
                feature: .readState
            )
            return try BackendJSON.decoder.decode([StampRow].self, from: data).map(\.lastReadAt).max()
        } catch let failure as BackendFailure where isMissing(failure) {
            return nil
        }
    }

    private func isMissing(_ failure: BackendFailure) -> Bool {
        if case .notSetUp = failure { return true }
        return false
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

    private struct ReactionRow: Decodable {
        let messageId: UUID
        let userId: UUID
        let emoji: String
        enum CodingKeys: String, CodingKey {
            case messageId = "message_id"
            case userId = "user_id"
            case emoji
        }
    }

    private struct ReactionWrite: Encodable {
        let messageId: UUID
        let squadId: UUID
        let userId: UUID
        let emoji: String
        enum CodingKeys: String, CodingKey {
            case messageId = "message_id"
            case squadId = "squad_id"
            case userId = "user_id"
            case emoji
        }
    }

    private struct ReadRow: Decodable {
        let userId: UUID
        let lastReadAt: Date
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case lastReadAt = "last_read_at"
        }
    }

    private struct StampRow: Decodable {
        let lastReadAt: Date
        enum CodingKeys: String, CodingKey { case lastReadAt = "last_read_at" }
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

final class SupabaseInviteService: InviteServing {
    private let http: SupabaseHTTP

    init(config: BackendConfig, accessToken: String) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken)
    }

    func createInvite() async throws -> InviteTicket {
        let data = try await http.send(
            path: "rest/v1/rpc/sq8_create_invite",
            method: "POST",
            body: Data("{}".utf8),
            feature: .squad
        )
        let payload = try JSONDecoder().decode(InvitePayload.self, from: data)
        guard payload.ok, let code = payload.code, let squadId = payload.squadId else {
            throw InviteProblem.from(serverCode: payload.error ?? "not_owner")
        }
        return InviteTicket(code: code, squadId: squadId)
    }

    func join(code: String) async throws -> UUID {
        let body = try JSONEncoder().encode(JoinBody(code: code))
        let data = try await http.send(
            path: "rest/v1/rpc/sq8_join_with_code",
            method: "POST",
            body: body,
            feature: .squad
        )
        let payload = try JSONDecoder().decode(InvitePayload.self, from: data)
        guard payload.ok, let squadId = payload.squadId else {
            throw InviteProblem.from(serverCode: payload.error ?? "invalid")
        }
        return squadId
    }

    private struct JoinBody: Encodable {
        let code: String
    }

    private struct InvitePayload: Decodable {
        let ok: Bool
        let error: String?
        let code: String?
        let squadId: UUID?
        enum CodingKeys: String, CodingKey {
            case ok, error, code
            case squadId = "squad_id"
        }
    }
}
