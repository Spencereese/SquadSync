import Foundation

private final class RefreshFlight: @unchecked Sendable {
    let task: Task<AuthSession, Error>
    init(_ task: Task<AuthSession, Error>) { self.task = task }
}

final class SupabaseAuthService: AuthService, TokenRefreshing {
    private let config: BackendConfig
    private let store: SessionStoring
    private let transport: HTTPTransport
    private var refreshTask: RefreshFlight?
    private let refreshLock = NSLock()

    init(config: BackendConfig, store: SessionStoring, transport: HTTPTransport = URLSessionTransport.shared) {
        self.config = config
        self.store = store
        self.transport = transport
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

    func prepareSession(now: Date) async throws -> AuthSession? {
        guard let session = try store.load() else { return nil }
        #if DEBUG
        if let exp = AccessTokenClock.expiry(of: session.accessToken) {
            let seconds = Int(exp.timeIntervalSince(now))
            let refresh = AccessTokenClock.needsRefresh(session.accessToken, now: now)
            SquadLog.http.notice("auth access token expires in \(seconds, privacy: .public)s refresh=\(refresh, privacy: .public)")
        } else {
            SquadLog.http.notice("auth access token has no readable exp, refresh=true")
        }
        #endif
        if !AccessTokenClock.needsRefresh(session.accessToken, now: now) { return session }
        return try await refreshSharingWork()
    }

    func refreshAfterRejection() async -> TokenRefreshResult {
        do {
            let session = try await refreshSharingWork()
            return .refreshed(session.accessToken)
        } catch let failure as BackendFailure {
            if case .sessionEnded = failure { return .rejected }
            if case .notSignedIn = failure { return .rejected }
            return .unreachable
        } catch {
            return .unreachable
        }
    }

    func signOut() async throws {
        if let token = try store.load()?.accessToken {
            var client = http()
            client.accessToken = token
            _ = try? await client.send(path: "auth/v1/logout", method: "POST", feature: .profile)
        }
        try store.clear()
    }

    private func http() -> SupabaseHTTP { SupabaseHTTP(config: config, accessToken: nil, transport: transport) }

    /// One refresh at a time. A cancelled waiter does not drop the in-flight task,
    /// or the next caller would send the same refresh token again.
    private func refreshSharingWork() async throws -> AuthSession {
        let flight: RefreshFlight = refreshLock.withLock {
            if let refreshTask { return refreshTask }
            let created = RefreshFlight(Task { try await self.performRefresh() })
            refreshTask = created
            return created
        }
        let result = await flight.task.result
        refreshLock.withLock {
            if refreshTask === flight { refreshTask = nil }
        }
        return try result.get()
    }

    private func performRefresh() async throws -> AuthSession {
        guard let session = try store.load() else { throw BackendFailure.sessionEnded }
        let sentRefreshToken = session.refreshToken
        guard config.isConfigured, let base = config.url else { throw BackendFailure.notConfigured }
        var url = base
        url.appendPathComponent("auth")
        url.appendPathComponent("v1")
        url.appendPathComponent("token")
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendFailure.rejected("Bad request URL.")
        }
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        guard let endpoint = components.url else { throw BackendFailure.rejected("Bad request URL.") }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(RefreshBody(refreshToken: sentRefreshToken))
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            if RequestNoise.isCancellation(error) { throw error }
            throw BackendFailure.reconnecting
        }
        guard let http = response as? HTTPURLResponse else {
            throw BackendFailure.reconnecting
        }
        if http.statusCode >= 400 {
            HTTPFailureLog.record(
                method: "POST",
                path: "/auth/v1/token",
                status: http.statusCode,
                body: data
            )
        }
        if RefreshRejection.clearsSession(status: http.statusCode, body: data) {
            if let kept = try? store.load(), kept.refreshToken != sentRefreshToken {
                return kept
            }
            try store.clear()
            throw BackendFailure.sessionEnded
        }
        guard http.statusCode >= 200 && http.statusCode < 300 else {
            throw BackendFailure.reconnecting
        }
        let decoded = try BackendJSON.decoder.decode(VerifyResponse.self, from: data)
        let updated = AuthSession(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            userId: decoded.user.id,
            email: decoded.user.email ?? session.email
        )
        try store.save(updated)
        return updated
    }

    private struct RefreshBody: Encodable {
        let refreshToken: String
        enum CodingKeys: String, CodingKey {
            case refreshToken = "refresh_token"
        }
    }

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

    init(config: BackendConfig, accessToken: String, refresher: TokenRefreshing? = nil) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, refresher: refresher)
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

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
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
        return try await load(squadId: row.id)
    }

    func removeMember(squadId: UUID, userId: UUID) async throws {
        let data: Data
        do {
            data = try await http.send(
                path: "rest/v1/sq8_squad_members",
                method: "DELETE",
                query: [
                    URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                    URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)")
                ],
                prefer: "return=representation",
                feature: .squad
            )
        } catch let failure as BackendFailure {
            if case .rejected(let message) = failure, message.lowercased().contains("sq8_owner_protected") {
                throw InviteProblem.other("The owner stays in the squad.")
            }
            throw failure
        }
        let rows = try BackendJSON.decoder.decode([MemberRow].self, from: data)
        guard rows.contains(where: { $0.userId == userId }) else {
            throw InviteProblem.other("You can't remove that person.")
        }
    }

    func renameAvailable() async -> Bool {
        do {
            // GET names both arguments so PostgREST resolves sq8_rename_squad(uuid, text).
            // It runs in a read-only transaction and fails on the lock. Only a missing
            // function (404 or PGRST202) means rename is unavailable.
            _ = try await http.send(
                path: "rest/v1/rpc/sq8_rename_squad",
                method: "GET",
                query: [
                    URLQueryItem(name: "squad", value: "00000000-0000-0000-0000-000000000000"),
                    URLQueryItem(name: "new_name", value: "null")
                ],
                feature: .squad
            )
            return true
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { return false }
            if case .rejected(let message) = failure {
                return LeaveProbe.available(status: 400, body: message)
            }
            return false
        } catch {
            return false
        }
    }

    func renameSquad(squadId: UUID, name: String?) async throws {
        let body = try JSONEncoder().encode(RenameBody(squad: squadId, newName: name))
        let data = try await http.send(
            path: "rest/v1/rpc/sq8_rename_squad",
            method: "POST",
            body: body,
            feature: .squad
        )
        let payload = try JSONDecoder().decode(RenamePayload.self, from: data)
        guard payload.ok else {
            throw BackendFailure.rejected(RenameFailure.message(payload.error ?? "missing"))
        }
    }

    func leaveAvailable() async -> Bool {
        do {
            // GET names new_owner so PostgREST resolves sq8_leave_squad(uuid).
            // The function is volatile, so GET is refused and does not run it.
            _ = try await http.send(
                path: "rest/v1/rpc/sq8_leave_squad",
                method: "GET",
                query: [URLQueryItem(name: "new_owner", value: "null")],
                feature: .squad
            )
            return true
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { return false }
            if case .rejected(let message) = failure {
                return LeaveProbe.available(status: 400, body: message)
            }
            return false
        } catch {
            return false
        }
    }

    func leaveSquad(newOwner: UUID?) async throws {
        let body = try JSONEncoder().encode(LeaveBody(newOwner: newOwner))
        let data = try await http.send(
            path: "rest/v1/rpc/sq8_leave_squad",
            method: "POST",
            body: body,
            feature: .squad
        )
        let payload = try JSONDecoder().decode(LeavePayload.self, from: data)
        guard payload.ok else {
            throw InviteProblem.from(serverCode: payload.error ?? "already_left")
        }
    }

    private struct LeaveBody: Encodable {
        let newOwner: UUID?
        enum CodingKeys: String, CodingKey { case newOwner = "new_owner" }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let newOwner {
                try container.encode(newOwner, forKey: .newOwner)
            } else {
                try container.encodeNil(forKey: .newOwner)
            }
        }
    }

    private struct LeavePayload: Decodable {
        let ok: Bool
        let error: String?
    }

    private func load(squadId: UUID) async throws -> SquadRecord {
        let squad = try await fetchSquad(squadId: squadId)
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

    private func fetchSquad(squadId: UUID) async throws -> SquadDetails {
        let squadData = try await http.send(
            path: "rest/v1/sq8_squads",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: SquadSelect.columns)
            ],
            feature: .squad
        )
        let squads = try BackendJSON.decoder.decode([SquadDetails].self, from: squadData)
        guard let squad = squads.first else { throw BackendFailure.rejected("Squad was not found.") }
        return squad
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

    private struct RenameBody: Encodable {
        let squad: UUID
        let newName: String?
        enum CodingKeys: String, CodingKey {
            case squad
            case newName = "new_name"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(squad, forKey: .squad)
            if let newName {
                try container.encode(newName, forKey: .newName)
            } else {
                try container.encodeNil(forKey: .newName)
            }
        }
    }

    private struct RenamePayload: Decodable {
        let ok: Bool
        let error: String?
    }
}

enum RenameFailure {
    static func message(_ code: String) -> String {
        switch code {
        case "signed_out": "Sign in again before renaming."
        case "not_owner": "Only the owner can rename the squad."
        case "name_length": "Use 40 characters or fewer."
        case "missing": "That squad is gone."
        default: code
        }
    }
}

final class SupabaseChatService: ChatService {
    private let http: SupabaseHTTP

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
    }

    func history(squadId: UUID) async throws -> [RemoteMessage] {
        try await fetch(squadId: squadId, after: nil)
    }

    func send(_ message: RemoteMessage) async throws -> SendReceipt {
        let body = try BackendJSON.encoder.encode(message)
        let data = try await http.send(
            path: "rest/v1/sq8_messages",
            method: "POST",
            body: body,
            prefer: "return=representation,resolution=ignore-duplicates",
            feature: .messages
        )
        let rows = (try? BackendJSON.decoder.decode([RemoteMessage].self, from: data)) ?? []
        if Self.matches(message, in: rows) { return .stored }
        let found = try await http.send(
            path: "rest/v1/sq8_messages",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(message.id.uuidString)"),
                URLQueryItem(name: "squad_id", value: "eq.\(message.squadId.uuidString)"),
                URLQueryItem(name: "select", value: "id,squad_id,sender_id,body,sent_at")
            ],
            feature: .messages
        )
        let stored = (try? BackendJSON.decoder.decode([RemoteMessage].self, from: found)) ?? []
        return Self.matches(message, in: stored) ? .stored : .missing
    }

    private static func matches(_ message: RemoteMessage, in rows: [RemoteMessage]) -> Bool {
        rows.contains { row in
            row.id == message.id
                && row.squadId == message.squadId
                && row.senderId == message.senderId
                && row.body == message.body
        }
    }

    func newer(squadId: UUID, after: Date) async throws -> [RemoteMessage] {
        try await fetch(squadId: squadId, after: after)
    }

    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws {
        let body = try BackendJSON.encoder.encode(ReadWrite(userId: userId, squadId: squadId, lastReadAt: at, lastReadId: messageId))
        let conflict = [URLQueryItem(name: "on_conflict", value: "user_id,squad_id")]
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_chat_read_state",
                method: "POST",
                query: conflict,
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
                query: conflict,
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
        // sq8_message_reads is the live cursor. sq8_chat_read_state is the older
        // table and its GET is not part of this read.
        try await readStamp(path: "rest/v1/sq8_message_reads", squadId: squadId, userId: userId)
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

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
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

final class SupabaseSpotService: SpotServing {
    private let http: SupabaseHTTP
    private var cachedCapabilities: SpotServerCapabilities?
    /// A nil id. GET names the real arguments. PostgREST runs it read-only, so FOR UPDATE fails and nothing commits.
    private static let probeId = "00000000-0000-0000-0000-000000000000"

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
    }

    func current(squadId: UUID) async throws -> SpotCall? {
        let caps = await serverCapabilities()
        if caps.expiry {
            do {
                return try await readOpen(squadId: squadId, capabilities: caps)
            } catch let failure as BackendFailure where isFunctionMissing(failure) {
                cachedCapabilities?.expiry = false
            }
        }
        let fresh = cachedCapabilities ?? caps
        return try await readTable(squadId: squadId, capabilities: fresh)
    }

    func call(squadId: UUID, game: String, startsAt: Date) async throws -> UUID {
        let body = try BackendJSON.encoder.encode(CallBody(squad: squadId, game: game, startsAt: startsAt))
        let data = try await perform(path: "rest/v1/rpc/sq8_call_spot", body: body)
        return try JSONDecoder().decode(UUID.self, from: data)
    }

    func rsvp(callId: UUID, response: String) async throws {
        let body = try BackendJSON.encoder.encode(RsvpBody(callId: callId, response: response))
        _ = try await perform(path: "rest/v1/rpc/sq8_rsvp_spot", body: body)
    }

    func lock(callId: UUID) async throws {
        // 0020 redefines sq8_lock_spot with the Ready gate. The merged app calls
        // this name, so this client does too. The when_ready probe only tells
        // the UI whether that gate is on the server yet.
        _ = await serverCapabilities()
        let body = try BackendJSON.encoder.encode(CallIdBody(callId: callId))
        _ = try await perform(path: "rest/v1/rpc/sq8_lock_spot", body: body)
    }

    func cancel(callId: UUID) async throws {
        _ = try await perform(path: "rest/v1/rpc/sq8_cancel_spot", body: try BackendJSON.encoder.encode(CallIdBody(callId: callId)))
    }

    func end(callId: UUID) async throws {
        _ = try await perform(path: "rest/v1/rpc/sq8_end_spot", body: try BackendJSON.encoder.encode(CallIdBody(callId: callId)))
    }

    func setReady(callId: UUID, userId _: UUID, ready: Bool) async throws {
        let caps = await serverCapabilities()
        guard caps.ready else { throw SpotProblem.badResponse }
        let body = try BackendJSON.encoder.encode(ReadyBody(callId: callId, ready: ready))
        do {
            _ = try await perform(path: "rest/v1/rpc/sq8_set_spot_ready", body: body)
            return
        } catch let failure as BackendFailure where isFunctionMissing(failure) {
            cachedCapabilities?.ready = false
            throw SpotProblem.badResponse
        }
    }

    func serverCapabilities() async -> SpotServerCapabilities {
        if let cachedCapabilities { return cachedCapabilities }
        let readyFunction = await functionExists(
            path: "rest/v1/rpc/sq8_set_spot_ready",
            query: [
                URLQueryItem(name: "call_id", value: Self.probeId),
                URLQueryItem(name: "ready", value: "false")
            ]
        )
        let lockFunction = await functionExists(
            path: "rest/v1/rpc/sq8_lock_spot_when_ready",
            query: [URLQueryItem(name: "call_id", value: Self.probeId)]
        )
        let expiryFunction = await functionExists(
            path: "rest/v1/rpc/sq8_read_open_spot",
            query: [URLQueryItem(name: "squad", value: Self.probeId)]
        )
        let seatColumn = await columnExists(path: "rest/v1/sq8_spot_calls", column: "seat_target")
        let readyColumn = await columnExists(path: "rest/v1/sq8_spot_rsvps", column: "ready")
        let found = SpotServerCapabilities(
            ready: readyFunction && readyColumn,
            gatedLock: lockFunction,
            expiry: expiryFunction,
            seatTarget: seatColumn
        )
        cachedCapabilities = found
        return found
    }

    private func readOpen(squadId: UUID, capabilities: SpotServerCapabilities) async throws -> SpotCall? {
        let body = try BackendJSON.encoder.encode(SquadReadBody(squad: squadId))
        let data = try await perform(path: "rest/v1/rpc/sq8_read_open_spot", body: body)
        let payload = try BackendJSON.decoder.decode(OpenSpotPayload.self, from: data)
        guard let row = payload.call else { return nil }
        let seats = payload.rsvps.map {
            SpotRsvp(userId: $0.userId, name: "Player", response: $0.response, starter: $0.starter, ready: $0.ready ?? false)
        }
        var reading = capabilities
        if row.seatTarget != nil { reading.seatTarget = true }
        return row.call(rsvps: seats, capabilities: reading)
    }

    private func readTable(squadId: UUID, capabilities: SpotServerCapabilities) async throws -> SpotCall? {
        let callSelect = capabilities.seatTarget
            ? "id,squad_id,caller_id,game,called_at,join_until,locked_at,closed_at,status,seat_target"
            : "id,squad_id,caller_id,game,called_at,join_until,locked_at,closed_at,status"
        let data = try await http.send(
            path: "rest/v1/sq8_spot_calls",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "closed_at", value: "is.null"),
                URLQueryItem(name: "select", value: callSelect),
                URLQueryItem(name: "order", value: "called_at.desc"),
                URLQueryItem(name: "limit", value: "1")
            ],
            feature: .squad
        )
        let rows = try BackendJSON.decoder.decode([CallRow].self, from: data)
        guard let row = rows.first else { return nil }
        let seats = try await rsvps(callId: row.id, includeReady: capabilities.ready)
        return row.call(rsvps: seats, capabilities: capabilities)
    }

    private func rsvps(callId: UUID, includeReady: Bool) async throws -> [SpotRsvp] {
        let select = includeReady ? "user_id,response,starter,ready" : "user_id,response,starter"
        let data = try await http.send(
            path: "rest/v1/sq8_spot_rsvps",
            method: "GET",
            query: [
                URLQueryItem(name: "call_id", value: "eq.\(callId.uuidString)"),
                URLQueryItem(name: "select", value: select)
            ],
            feature: .squad
        )
        return try BackendJSON.decoder.decode([RsvpRow].self, from: data).map {
            SpotRsvp(userId: $0.userId, name: "Player", response: $0.response, starter: $0.starter, ready: $0.ready ?? false)
        }
    }

    private func functionExists(path: String, query: [URLQueryItem]) async -> Bool {
        do {
            _ = try await http.send(path: path, method: "GET", query: query, feature: .squad)
            return true
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { return false }
            if case .rejected(let message) = failure {
                return SpotProbe.functionPresent(status: 400, body: message)
            }
            return false
        } catch {
            return false
        }
    }

    private func columnExists(path: String, column: String) async -> Bool {
        do {
            _ = try await http.send(
                path: path,
                method: "GET",
                query: [
                    URLQueryItem(name: "select", value: column),
                    URLQueryItem(name: "limit", value: "1")
                ],
                feature: .squad
            )
            return true
        } catch let failure as BackendFailure {
            if case .rejected(let message) = failure {
                return SpotProbe.columnPresent(status: 400, body: message)
            }
            return false
        } catch {
            return false
        }
    }

    private func isFunctionMissing(_ failure: BackendFailure) -> Bool {
        if case .notSetUp = failure { return true }
        if case .rejected(let message) = failure {
            return !SpotProbe.functionPresent(status: 400, body: message)
        }
        return false
    }

    private func perform(path: String, body: Data) async throws -> Data {
        do {
            return try await http.send(path: path, method: "POST", body: body, feature: .squad)
        } catch let failure as BackendFailure {
            if case .rejected(let message) = failure { throw SpotProblem.from(serverMessage: message) }
            throw failure
        }
    }

    private struct CallRow: Decodable {
        let id: UUID
        let squadId: UUID
        let callerId: UUID
        let game: String
        let calledAt: Date
        let joinUntil: Date
        let lockedAt: Date?
        let closedAt: Date?
        let status: String
        let seatTarget: Int?

        enum CodingKeys: String, CodingKey {
            case id, game, status
            case squadId = "squad_id"
            case callerId = "caller_id"
            case calledAt = "called_at"
            case joinUntil = "join_until"
            case lockedAt = "locked_at"
            case closedAt = "closed_at"
            case seatTarget = "seat_target"
        }

        func call(rsvps: [SpotRsvp], capabilities: SpotServerCapabilities) -> SpotCall {
            SpotCall(
                id: id,
                squadId: squadId,
                callerId: callerId,
                game: game,
                calledAt: calledAt,
                joinUntil: joinUntil,
                lockedAt: lockedAt,
                closedAt: closedAt,
                status: SpotCallStatus(rawValue: status) ?? .open,
                rsvps: rsvps,
                seatTarget: capabilities.seatTarget ? seatTarget : nil,
                serverOwnsLock: capabilities.gatedLock,
                serverOwnsExpiry: capabilities.expiry
            )
        }
    }

    private struct RsvpRow: Decodable {
        let userId: UUID
        let response: String
        let starter: Bool
        let ready: Bool?
        enum CodingKeys: String, CodingKey {
            case response, starter, ready
            case userId = "user_id"
        }
    }

    private struct OpenSpotPayload: Decodable {
        let call: CallRow?
        let rsvps: [RsvpRow]
    }

    private struct SquadReadBody: Encodable {
        let squad: UUID
    }

    private struct ReadyBody: Encodable {
        let callId: UUID
        let ready: Bool
        enum CodingKeys: String, CodingKey {
            case ready
            case callId = "call_id"
        }
    }

    private struct CallBody: Encodable {
        let squad: UUID
        let game: String
        let startsAt: Date
        enum CodingKeys: String, CodingKey {
            case squad, game
            case startsAt = "starts_at"
        }
    }

    private struct RsvpBody: Encodable {
        let callId: UUID
        let response: String
        enum CodingKeys: String, CodingKey {
            case response
            case callId = "call_id"
        }
    }

    private struct CallIdBody: Encodable {
        let callId: UUID
        enum CodingKeys: String, CodingKey { case callId = "call_id" }
    }
}
