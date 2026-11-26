import Foundation

/// What the app asks of the server for Game on. Live: `sq8_spot_calls` rows with
/// `kind = 'game_on'` plus their `sq8_spot_rsvps`, read through PostgREST, and the
/// 0028 RPCs for every write. Mock: in memory with the same rules.
protocol GameOnServing: AnyObject {
    /// The group's Game ons started after `since`, newest first, each with its seats.
    func recent(squadId: UUID, since: Date) async throws -> [GameOn]
    /// Starts one, with you in the first seat. Returns its id.
    func start(squadId: UUID, game: String, need: Int) async throws -> UUID
    func join(callId: UUID) async throws
    func leave(callId: UUID) async throws
    func setReady(callId: UUID, ready: Bool) async throws
    /// Starter only.
    func close(callId: UUID) async throws
}

/// A row of `sq8_spot_calls` with its seats embedded.
struct GameOnRow: Decodable {
    let id: UUID
    let squadId: UUID
    let callerId: UUID
    let game: String
    let calledAt: Date
    let joinUntil: Date
    let seatTarget: Int?
    let status: String
    let closedAt: Date?
    let rsvps: [Seat]?

    struct Seat: Decodable {
        let userId: UUID
        let response: String
        let starter: Bool?
        let ready: Bool?
        let updatedAt: Date?

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case response, starter, ready
            case updatedAt = "updated_at"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case callerId = "caller_id"
        case game
        case calledAt = "called_at"
        case joinUntil = "join_until"
        case seatTarget = "seat_target"
        case status
        case closedAt = "closed_at"
        case rsvps = "sq8_spot_rsvps"
    }

    /// A status the app doesn't know reads as ended, so it never shows as open.
    var gameOn: GameOn {
        GameOn(
            id: id,
            squadId: squadId,
            callerId: callerId,
            game: game,
            calledAt: calledAt,
            idleUntil: joinUntil,
            seatTarget: seatTarget ?? SpotRules.squadCap,
            status: GameOnStatus(rawValue: status) ?? .ended,
            closedAt: closedAt,
            seats: (rsvps ?? []).map { seat in
                GameOnSeat(
                    userId: seat.userId,
                    isIn: seat.response == "in",
                    starter: seat.starter ?? false,
                    ready: seat.ready ?? false,
                    updatedAt: seat.updatedAt
                )
            }
        )
    }
}

final class SupabaseGameOnService: GameOnServing {
    static let columns = "id,squad_id,caller_id,game,called_at,join_until,seat_target,status,closed_at"
    static let select = columns + ",sq8_spot_rsvps(user_id,response,starter,ready,updated_at)"

    private let http: SupabaseHTTP

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
    }

    /// Without 0028 there's no `kind` column, and PostgREST refuses the filter:
    /// that reads as "not set up", never as an empty list.
    func recent(squadId: UUID, since: Date) async throws -> [GameOn] {
        let data: Data
        do {
            data = try await http.send(
                path: "rest/v1/sq8_spot_calls",
                method: "GET",
                query: [
                    URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                    URLQueryItem(name: "kind", value: "eq.game_on"),
                    URLQueryItem(name: "called_at", value: "gte.\(BackendJSON.parseStamp(since) ?? "")"),
                    URLQueryItem(name: "select", value: Self.select),
                    URLQueryItem(name: "order", value: "called_at.desc,id.desc"),
                    URLQueryItem(name: "limit", value: "\(GameOnRules.readLimit)")
                ],
                feature: .gameOn,
                probe: true
            )
        } catch let failure as BackendFailure where MissingColumn.matches(failure) {
            throw BackendFailure.notSetUp(.gameOn)
        }
        do {
            return try BackendJSON.decoder.decode([GameOnRow].self, from: data).map(\.gameOn)
        } catch {
            throw GameOnProblem.failed
        }
    }

    func start(squadId: UUID, game: String, need: Int) async throws -> UUID {
        let body = try BackendJSON.encoder.encode(StartBody(squad: squadId, game: game, need: need))
        let data = try await rpc("sq8_start_game_on", body: body)
        if let id = try? JSONDecoder().decode(UUID.self, from: data) { return id }
        if let text = String(data: data, encoding: .utf8),
           let id = UUID(uuidString: text.trimmingCharacters(in: CharacterSet(charactersIn: "\" \n"))) {
            return id
        }
        throw GameOnProblem.failed
    }

    func join(callId: UUID) async throws {
        _ = try await rpc("sq8_join_game_on", body: try BackendJSON.encoder.encode(CallBody(callId: callId)))
    }

    func leave(callId: UUID) async throws {
        _ = try await rpc("sq8_leave_game_on", body: try BackendJSON.encoder.encode(CallBody(callId: callId)))
    }

    func setReady(callId: UUID, ready: Bool) async throws {
        _ = try await rpc("sq8_set_game_on_ready", body: try BackendJSON.encoder.encode(ReadyBody(callId: callId, ready: ready)))
    }

    func close(callId: UUID) async throws {
        _ = try await rpc("sq8_close_game_on", body: try BackendJSON.encoder.encode(CallBody(callId: callId)))
    }

    /// A missing function is "not set up"; a refusal keeps its server code for GameOnProblem.
    private func rpc(_ name: String, body: Data) async throws -> Data {
        do {
            return try await http.send(path: "rest/v1/rpc/\(name)", method: "POST", body: body, feature: .gameOn)
        } catch let failure as BackendFailure {
            throw GameOnProblem.from(failure)
        }
    }

    private struct StartBody: Encodable {
        let squad: UUID
        let game: String
        let need: Int
    }

    private struct CallBody: Encodable {
        let callId: UUID
        enum CodingKeys: String, CodingKey { case callId = "call_id" }
    }

    private struct ReadyBody: Encodable {
        let callId: UUID
        let ready: Bool
        enum CodingKeys: String, CodingKey {
            case callId = "call_id"
            case ready
        }
    }
}

/// In memory, with the server's rules (0028): cap of two, seats until full,
/// starter-only close, ended when the last one leaves, idle after three hours.
final class MockGameOnService: GameOnServing {
    private(set) var stored: [GameOn]
    var viewerId: UUID
    /// The group's members. Seats of anyone else don't count.
    var memberIds: Set<UUID>
    /// No 0028 on this server.
    var serverMissing: Bool
    /// Reads fail until `recover()`.
    var readsDown: Bool
    /// Every write fails as if offline.
    var writesDown: Bool
    var readDelay: TimeInterval
    private(set) var reads = 0
    private let now: () -> Date

    init(
        viewerId: UUID,
        memberIds: Set<UUID>,
        calls: [GameOn] = [],
        serverMissing: Bool = false,
        readsDown: Bool = false,
        writesDown: Bool = false,
        readDelay: TimeInterval = 0,
        now: @escaping () -> Date = { Date() }
    ) {
        self.viewerId = viewerId
        self.memberIds = memberIds
        self.stored = calls
        self.serverMissing = serverMissing
        self.readsDown = readsDown
        self.writesDown = writesDown
        self.readDelay = readDelay
        self.now = now
    }

    func recover() { readsDown = false }

    func recent(squadId: UUID, since: Date) async throws -> [GameOn] {
        reads += 1
        if readDelay > 0 { try await Task.sleep(nanoseconds: UInt64(readDelay * 1_000_000_000)) }
        if serverMissing { throw BackendFailure.notSetUp(.gameOn) }
        if readsDown { throw BackendFailure.rejected("The server didn't answer.") }
        return stored
            .filter { $0.squadId == squadId && $0.calledAt >= since }
            .sorted { lhs, rhs in
                if lhs.calledAt != rhs.calledAt { return lhs.calledAt > rhs.calledAt }
                return lhs.id.uuidString > rhs.id.uuidString
            }
    }

    func start(squadId: UUID, game: String, need: Int) async throws -> UUID {
        try checkWrite()
        let name = game.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { throw GameOnProblem.gameBlank }
        if name.count > GameOnRules.maxGameLength { throw GameOnProblem.gameLong }
        if !GameOnRules.needRange.contains(need) { throw GameOnProblem.needRange }
        guard memberIds.contains(viewerId) else { throw GameOnProblem.notMember }
        sweep(squadId: squadId)
        let open = stored.filter { $0.squadId == squadId && $0.closedAt == nil }
        if open.count >= GameOnRules.maxOpen { throw GameOnProblem.cap }
        let at = now()
        let call = GameOn(
            id: UUID(),
            squadId: squadId,
            callerId: viewerId,
            game: name,
            calledAt: at,
            idleUntil: at.addingTimeInterval(GameOnRules.idleWindow),
            seatTarget: need + 1,
            status: .open,
            closedAt: nil,
            seats: [GameOnSeat(userId: viewerId, isIn: true, starter: true, ready: false, updatedAt: at)]
        )
        stored.append(call)
        return call.id
    }

    func join(callId: UUID) async throws {
        try checkWrite()
        var call = try openCall(callId)
        if call.seats.contains(where: { $0.userId == viewerId && $0.isIn }) { return }
        if GameOnRules.isFull(call, memberIds: memberIds) { throw GameOnProblem.full }
        let at = now()
        if let index = call.seats.firstIndex(where: { $0.userId == viewerId }) {
            call.seats[index].isIn = true
            call.seats[index].ready = false
            call.seats[index].updatedAt = at
        } else {
            call.seats.append(GameOnSeat(userId: viewerId, isIn: true, starter: false, ready: false, updatedAt: at))
        }
        save(GameOnRules.bumped(call, now: at))
    }

    func leave(callId: UUID) async throws {
        try checkWrite()
        guard let found = stored.first(where: { $0.id == callId }) else { throw GameOnProblem.closed }
        if found.closedAt != nil { return }
        var call = found
        let at = now()
        if let index = call.seats.firstIndex(where: { $0.userId == viewerId }) {
            call.seats[index].isIn = false
            call.seats[index].ready = false
            call.seats[index].updatedAt = at
        }
        if GameOnRules.players(call, memberIds: memberIds).isEmpty {
            call.status = .ended
            call.closedAt = at
            save(call)
        } else {
            save(GameOnRules.bumped(call, now: at))
        }
    }

    func setReady(callId: UUID, ready: Bool) async throws {
        try checkWrite()
        var call = try openCall(callId)
        guard let index = call.seats.firstIndex(where: { $0.userId == viewerId && $0.isIn }) else {
            throw GameOnProblem.notIn
        }
        call.seats[index].ready = ready
        save(GameOnRules.bumped(call, now: now()))
    }

    func close(callId: UUID) async throws {
        try checkWrite()
        guard var call = stored.first(where: { $0.id == callId }) else { throw GameOnProblem.closed }
        guard call.callerId == viewerId else { throw GameOnProblem.notStarter }
        if call.closedAt != nil { return }
        call.status = .ended
        call.closedAt = now()
        save(call)
    }

    /// Seeds someone else's seat (tests and launch scenarios).
    func seat(_ userId: UUID, in callId: UUID, ready: Bool = false) {
        guard var call = stored.first(where: { $0.id == callId }) else { return }
        call.seats.removeAll { $0.userId == userId }
        call.seats.append(GameOnSeat(userId: userId, isIn: true, starter: false, ready: ready, updatedAt: now()))
        save(call)
    }

    private func checkWrite() throws {
        if serverMissing { throw GameOnProblem.notSetUp }
        if writesDown { throw GameOnProblem.offline }
    }

    private func openCall(_ callId: UUID) throws -> GameOn {
        guard let found = stored.first(where: { $0.id == callId }) else { throw GameOnProblem.closed }
        sweep(squadId: found.squadId)
        guard let call = stored.first(where: { $0.id == callId }), call.closedAt == nil else {
            throw GameOnProblem.closed
        }
        guard memberIds.contains(viewerId) else { throw GameOnProblem.notMember }
        return call
    }

    /// Like `sq8.sweep_game_ons`: idle ones expire, empty ones end.
    private func sweep(squadId: UUID) {
        let at = now()
        stored = stored.map { call in
            guard call.squadId == squadId, call.closedAt == nil else { return call }
            var copy = call
            if at >= call.idleUntil {
                copy.status = .expired
                copy.closedAt = at
            } else if GameOnRules.players(call, memberIds: memberIds).isEmpty {
                copy.status = .ended
                copy.closedAt = at
            }
            return copy
        }
    }

    private func save(_ call: GameOn) {
        stored = stored.map { $0.id == call.id ? call : $0 }
    }
}
