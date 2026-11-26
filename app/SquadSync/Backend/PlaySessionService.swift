import Foundation

/// What the app asks of the server for play sessions. Live: `sq8_sessions` and
/// `sq8_session_rsvps` (0016) through PostgREST. Mock: in memory.
protocol PlaySessionServing: AnyObject {
    /// The squad's sessions that start after `since`, soonest first, each with its RSVPs.
    func sessions(squadId: UUID, since: Date) async throws -> [PlaySession]
    func schedule(_ request: PlaySessionRequest) async throws -> PlaySession
    /// Your own answer. Insert or change, in one request.
    func respond(sessionId: UUID, userId: UUID, response: PlaySessionResponse) async throws
    func cancel(sessionId: UUID) async throws -> PlaySession
}

struct PlaySessionRequest: Equatable, Encodable {
    let squadId: UUID
    let creatorId: UUID
    let game: String
    let startsAt: Date
    let note: String?

    enum CodingKeys: String, CodingKey {
        case squadId = "squad_id"
        case creatorId = "creator_id"
        case game
        case startsAt = "starts_at"
        case note
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(squadId, forKey: .squadId)
        try container.encode(creatorId, forKey: .creatorId)
        try container.encode(game, forKey: .game)
        try container.encode(startsAt, forKey: .startsAt)
        try container.encodeIfPresent(note, forKey: .note)
    }
}

/// A row of `sq8_sessions` with its RSVPs embedded (PostgREST resource embedding).
struct PlaySessionRow: Decodable {
    let id: UUID
    let squadId: UUID
    let creatorId: UUID
    let game: String
    let startsAt: Date
    let durationMinutes: Int?
    let note: String?
    let cancelledAt: Date?
    let createdAt: Date
    let rsvps: [RSVPRow]?

    struct RSVPRow: Decodable {
        let userId: UUID
        let response: String
        let updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case response
            case updatedAt = "updated_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case creatorId = "creator_id"
        case game
        case startsAt = "starts_at"
        case durationMinutes = "duration_minutes"
        case note
        case cancelledAt = "cancelled_at"
        case createdAt = "created_at"
        case rsvps = "sq8_session_rsvps"
    }

    /// An answer the app doesn't know is dropped rather than guessed.
    var session: PlaySession {
        PlaySession(
            id: id,
            squadId: squadId,
            creatorId: creatorId,
            game: game,
            startsAt: startsAt,
            durationMinutes: durationMinutes,
            note: note,
            cancelledAt: cancelledAt,
            createdAt: createdAt,
            rsvps: (rsvps ?? []).compactMap { row in
                PlaySessionResponse(rawValue: row.response).map {
                    PlaySessionRSVP(userId: row.userId, response: $0, updatedAt: row.updatedAt)
                }
            }
        )
    }
}

final class SupabasePlaySessionService: PlaySessionServing {
    static let sessionColumns = "id,squad_id,creator_id,game,starts_at,duration_minutes,note,cancelled_at,created_at"
    static let select = sessionColumns + ",sq8_session_rsvps(user_id,response,updated_at)"

    private let http: SupabaseHTTP
    private let clock: () -> Date

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
        self.clock = clock
    }

    func sessions(squadId: UUID, since: Date) async throws -> [PlaySession] {
        let data = try await http.send(
            path: "rest/v1/sq8_sessions",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "starts_at", value: "gte.\(BackendJSON.parseStamp(since) ?? "")"),
                URLQueryItem(name: "select", value: Self.select),
                URLQueryItem(name: "order", value: "starts_at.asc,id.asc"),
                URLQueryItem(name: "limit", value: "\(PlaySessionRules.readLimit)")
            ],
            feature: .sessions
        )
        do {
            return try BackendJSON.decoder.decode([PlaySessionRow].self, from: data).map(\.session)
        } catch {
            throw PlaySessionProblem.failed
        }
    }

    func schedule(_ request: PlaySessionRequest) async throws -> PlaySession {
        let body = try BackendJSON.encoder.encode(request)
        let data = try await http.send(
            path: "rest/v1/sq8_sessions",
            method: "POST",
            query: [URLQueryItem(name: "select", value: Self.select)],
            body: body,
            prefer: "return=representation",
            feature: .sessions
        )
        return try firstRow(data)
    }

    func respond(sessionId: UUID, userId: UUID, response: PlaySessionResponse) async throws {
        // updated_at is sent so a server without 0025 still orders answers; 0025 stamps its own.
        let body = try BackendJSON.encoder.encode(RSVPBody(sessionId: sessionId, userId: userId, response: response.rawValue, updatedAt: clock()))
        _ = try await http.send(
            path: "rest/v1/sq8_session_rsvps",
            method: "POST",
            query: [URLQueryItem(name: "on_conflict", value: "session_id,user_id")],
            body: body,
            prefer: "resolution=merge-duplicates,return=minimal",
            feature: .sessions
        )
    }

    func cancel(sessionId: UUID) async throws -> PlaySession {
        let body = try BackendJSON.encoder.encode(CancelBody(cancelledAt: clock()))
        let data = try await http.send(
            path: "rest/v1/sq8_sessions",
            method: "PATCH",
            query: [
                URLQueryItem(name: "id", value: "eq.\(sessionId.uuidString)"),
                URLQueryItem(name: "select", value: Self.select)
            ],
            body: body,
            prefer: "return=representation",
            feature: .sessions
        )
        return try firstRow(data)
    }

    /// RLS answers a write it refuses with no rows: say so instead of pretending.
    private func firstRow(_ data: Data) throws -> PlaySession {
        let rows: [PlaySessionRow]
        do {
            rows = try BackendJSON.decoder.decode([PlaySessionRow].self, from: data)
        } catch {
            throw PlaySessionProblem.failed
        }
        guard let row = rows.first else { throw PlaySessionProblem.notAllowed }
        return row.session
    }

    private struct RSVPBody: Encodable {
        let sessionId: UUID
        let userId: UUID
        let response: String
        let updatedAt: Date

        enum CodingKeys: String, CodingKey {
            case sessionId = "session_id"
            case userId = "user_id"
            case response
            case updatedAt = "updated_at"
        }
    }

    private struct CancelBody: Encodable {
        let cancelledAt: Date

        enum CodingKeys: String, CodingKey {
            case cancelledAt = "cancelled_at"
        }
    }
}

/// In memory, with the same rules the server has (0016 plus 0025's guards), so
/// the mock UI and the tests hit the same refusals live would.
final class MockPlaySessionService: PlaySessionServing {
    private(set) var stored: [PlaySession]
    /// The squad's members, for the "still in the squad" rule. Nil skips it.
    var memberIds: Set<UUID>?
    /// No session tables on this server (0016 missing).
    var serverMissing: Bool
    /// Reads fail until `recover()`; Retry calls it through the model.
    var readsDown: Bool
    /// Every write fails as if offline.
    var writesDown: Bool
    var readDelay: TimeInterval
    private(set) var reads = 0
    private let now: () -> Date

    init(
        sessions: [PlaySession] = [],
        memberIds: Set<UUID>? = nil,
        serverMissing: Bool = false,
        readsDown: Bool = false,
        writesDown: Bool = false,
        readDelay: TimeInterval = 0,
        now: @escaping () -> Date = { Date() }
    ) {
        self.stored = sessions
        self.memberIds = memberIds
        self.serverMissing = serverMissing
        self.readsDown = readsDown
        self.writesDown = writesDown
        self.readDelay = readDelay
        self.now = now
    }

    func recover() { readsDown = false }

    func sessions(squadId: UUID, since: Date) async throws -> [PlaySession] {
        reads += 1
        if readDelay > 0 { try await Task.sleep(nanoseconds: UInt64(readDelay * 1_000_000_000)) }
        if serverMissing { throw BackendFailure.notSetUp(.sessions) }
        if readsDown { throw BackendFailure.rejected("The server didn't answer.") }
        return stored
            .filter { $0.squadId == squadId && $0.startsAt >= since }
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    func schedule(_ request: PlaySessionRequest) async throws -> PlaySession {
        try checkWrite()
        let game = request.game.trimmingCharacters(in: .whitespacesAndNewlines)
        if game.isEmpty { throw BackendFailure.rejected("new row for relation \"sq8_sessions\" violates check constraint \"sq8_sessions_game_not_blank\"") }
        if game.count > PlaySessionRules.maxGameLength { throw BackendFailure.rejected("session_game_long") }
        let at = now()
        if request.startsAt < at.addingTimeInterval(-PlaySessionRules.pastGrace) { throw BackendFailure.rejected("session_time_past") }
        if request.startsAt > at.addingTimeInterval(PlaySessionRules.horizon) { throw BackendFailure.rejected("session_time_far") }
        if let memberIds, !memberIds.contains(request.creatorId) {
            throw BackendFailure.rejected("new row violates row-level security policy for table \"sq8_sessions\"")
        }
        let session = PlaySession(
            id: UUID(),
            squadId: request.squadId,
            creatorId: request.creatorId,
            game: game,
            startsAt: request.startsAt,
            durationMinutes: nil,
            note: request.note,
            cancelledAt: nil,
            createdAt: at,
            rsvps: []
        )
        stored.append(session)
        return session
    }

    func respond(sessionId: UUID, userId: UUID, response: PlaySessionResponse) async throws {
        try checkWrite()
        guard let index = stored.firstIndex(where: { $0.id == sessionId }) else {
            throw BackendFailure.rejected("new row violates row-level security policy for table \"sq8_session_rsvps\"")
        }
        let session = stored[index]
        let at = now()
        if session.cancelledAt != nil { throw BackendFailure.rejected("session_cancelled") }
        if at >= PlaySessionRules.endsAt(session) { throw BackendFailure.rejected("session_over") }
        if let memberIds, !memberIds.contains(userId) { throw BackendFailure.rejected("not_in_squad") }
        if response == .going, session.response(of: userId) != .going,
           session.rsvps.filter({ $0.response == .going && $0.userId != userId }).count >= 8 {
            throw BackendFailure.rejected("session_full")
        }
        stored[index] = PlaySessionRules.setting(response, for: userId, in: session, at: at)
    }

    func cancel(sessionId: UUID) async throws -> PlaySession {
        try checkWrite()
        guard let index = stored.firstIndex(where: { $0.id == sessionId }) else { throw PlaySessionProblem.notAllowed }
        if stored[index].cancelledAt != nil { throw BackendFailure.rejected("session_cancelled") }
        stored[index].cancelledAt = now()
        return stored[index]
    }

    /// Test and UI-test seeding: another member answers.
    func seedResponse(sessionId: UUID, userId: UUID, response: PlaySessionResponse) {
        guard let index = stored.firstIndex(where: { $0.id == sessionId }) else { return }
        stored[index] = PlaySessionRules.setting(response, for: userId, in: stored[index], at: now())
    }

    private func checkWrite() throws {
        if serverMissing { throw BackendFailure.notSetUp(.sessions) }
        if writesDown { throw BackendFailure.reconnecting }
    }
}

/// Seeded sessions for the mock launches and the UI tests.
enum PlaySessionSeed {
    static let tonightId = UUID(uuidString: "00000000-0000-0000-0000-000000000501")!
    static let cancelledId = UUID(uuidString: "00000000-0000-0000-0000-000000000502")!
    static let pastId = UUID(uuidString: "00000000-0000-0000-0000-000000000503")!
    static let laterId = UUID(uuidString: "00000000-0000-0000-0000-000000000504")!

    /// Alex scheduled tonight (two in, one out, you haven't answered), plus a
    /// later one, a cancelled one and one that's over.
    static func squad(viewerId: UUID, squadId: UUID, alex: UUID, jordan: UUID, sam: UUID, now: Date, calendar: Calendar = .autoupdatingCurrent) -> [PlaySession] {
        let tonight = PlaySessionTime.suggestedStart(now: now, calendar: calendar).addingTimeInterval(60 * 60)
        let later = calendar.date(byAdding: .day, value: 2, to: tonight) ?? tonight.addingTimeInterval(2 * 86_400)
        return [
            PlaySession(
                id: pastId, squadId: squadId, creatorId: jordan, game: "Apex Legends",
                startsAt: now.addingTimeInterval(-3 * 60 * 60), durationMinutes: nil, note: nil,
                cancelledAt: nil, createdAt: now.addingTimeInterval(-4 * 60 * 60),
                rsvps: [PlaySessionRSVP(userId: jordan, response: .going, updatedAt: nil)]
            ),
            PlaySession(
                id: cancelledId, squadId: squadId, creatorId: sam, game: "Valorant",
                startsAt: tonight, durationMinutes: nil, note: nil,
                cancelledAt: now.addingTimeInterval(-30 * 60), createdAt: now.addingTimeInterval(-40 * 60),
                rsvps: [PlaySessionRSVP(userId: sam, response: .going, updatedAt: nil)]
            ),
            PlaySession(
                id: tonightId, squadId: squadId, creatorId: alex, game: "Warzone",
                startsAt: tonight, durationMinutes: nil, note: "Bring mics. Quads.",
                cancelledAt: nil, createdAt: now.addingTimeInterval(-25 * 60),
                rsvps: [
                    PlaySessionRSVP(userId: alex, response: .going, updatedAt: nil),
                    PlaySessionRSVP(userId: jordan, response: .going, updatedAt: nil),
                    PlaySessionRSVP(userId: sam, response: .out, updatedAt: nil)
                ]
            ),
            PlaySession(
                id: laterId, squadId: squadId, creatorId: viewerId, game: "Halo Infinite",
                startsAt: later, durationMinutes: nil, note: nil,
                cancelledAt: nil, createdAt: now.addingTimeInterval(-10 * 60),
                rsvps: [PlaySessionRSVP(userId: viewerId, response: .going, updatedAt: nil)]
            )
        ]
    }
}
