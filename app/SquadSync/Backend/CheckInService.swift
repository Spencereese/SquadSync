import Foundation

// Check-ins and Steam presence for the who's-in sheet (redesign S4).
// Reads and writes only `sq8_check_ins` (0006, live) under its own row level
// security, plus one optional call to the sq8-steam-presence function, which
// is not deployed today. Nothing here runs SQL or changes the schema.

enum CheckInProblem: Error, Equatable {
    /// `sq8_check_ins` isn't on the server.
    case unavailable
    /// The server refused the write; the text is already plain words.
    case rejected(String)

    var message: String {
        switch self {
        case .unavailable: return WhosIn.untrackedNote
        case .rejected(let text): return text
        }
    }
}

protocol CheckInServing: AnyObject {
    /// Read-only probes. Throws only when the server can't be reached, so a
    /// network blip never reads as "not set up".
    func capabilities() async throws -> CheckInCapabilities
    func checkIns(squadId: UUID) async throws -> [CheckInRecord]
    /// Upserts the caller's own row and returns what the server stored.
    func save(_ write: CheckInWrite) async throws -> CheckInRecord?
    /// Deletes the caller's own row.
    func clear(userId: UUID, squadId: UUID) async throws
    /// Never throws: not deployed is `.notSetUp`, anything else `.failed`.
    func steam() async -> SteamRead
}

enum CheckInSelect {
    static let base = "user_id,squad_id,kind,checked_at,until_at"
    static let withDetails = base + ",game,platform"

    static func columns(details: Bool) -> String { details ? withDetails : base }
}

enum SteamFunction {
    static let path = "functions/v1/sq8-steam-presence"

    /// An undeployed function answers 404 "Requested function was not found".
    static func isMissing(_ failure: BackendFailure) -> Bool {
        switch failure {
        case .notSetUp: return true
        case .rejected(let text):
            let lower = text.lowercased()
            return lower.contains("function was not found") || lower.contains("not_found")
        default: return false
        }
    }
}

final class SupabaseCheckInService: CheckInServing {
    private let http: SupabaseHTTP
    private var details: Bool?

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared,
        knownDetails: Bool? = nil
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
        self.details = knownDetails
    }

    func capabilities() async throws -> CheckInCapabilities {
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_check_ins",
                method: "GET",
                query: [
                    URLQueryItem(name: "select", value: "user_id"),
                    URLQueryItem(name: "limit", value: "1")
                ],
                feature: .checkIns
            )
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { return .unknown }
            throw failure
        }
        let found = await detailColumnsExist()
        details = found
        return CheckInCapabilities(table: true, details: found)
    }

    private func detailColumnsExist() async -> Bool {
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_check_ins",
                method: "GET",
                query: [
                    URLQueryItem(name: "select", value: "game,platform"),
                    URLQueryItem(name: "limit", value: "1")
                ],
                feature: .checkIns
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

    func checkIns(squadId: UUID) async throws -> [CheckInRecord] {
        do {
            let data = try await http.send(
                path: "rest/v1/sq8_check_ins",
                method: "GET",
                query: [
                    URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                    URLQueryItem(name: "select", value: CheckInSelect.columns(details: details == true))
                ],
                feature: .checkIns
            )
            return try CheckInRows.decode(data, decoder: BackendJSON.decoder)
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { throw CheckInProblem.unavailable }
            throw failure
        }
    }

    func save(_ write: CheckInWrite) async throws -> CheckInRecord? {
        let body = try BackendJSON.encoder.encode(write)
        do {
            let data = try await http.send(
                path: "rest/v1/sq8_check_ins",
                method: "POST",
                query: [
                    URLQueryItem(name: "on_conflict", value: "user_id"),
                    URLQueryItem(name: "select", value: CheckInSelect.columns(details: write.includesDetails))
                ],
                body: body,
                prefer: "resolution=merge-duplicates,return=representation",
                feature: .checkIns
            )
            return try CheckInRows.decode(data, decoder: BackendJSON.decoder).first
        } catch let failure as BackendFailure {
            switch failure {
            case .notSetUp: throw CheckInProblem.unavailable
            case .rejected(let text) where !AuthFailure.mentionsJWT(text):
                throw CheckInProblem.rejected(CheckInRules.message(for: text))
            default: throw failure
            }
        }
    }

    func clear(userId: UUID, squadId: UUID) async throws {
        do {
            _ = try await http.send(
                path: "rest/v1/sq8_check_ins",
                method: "DELETE",
                query: [
                    URLQueryItem(name: "user_id", value: "eq.\(userId.uuidString)"),
                    URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)")
                ],
                prefer: "return=minimal",
                feature: .checkIns
            )
        } catch let failure as BackendFailure {
            if case .notSetUp = failure { throw CheckInProblem.unavailable }
            throw failure
        }
    }

    func steam() async -> SteamRead {
        do {
            let data = try await http.send(
                path: SteamFunction.path,
                method: "POST",
                body: Data(#"{"op":"presence"}"#.utf8),
                feature: .checkIns
            )
            return SteamRead.parse(data)
        } catch let failure as BackendFailure {
            return SteamFunction.isMissing(failure) ? .notSetUp : .failed
        } catch {
            return .failed
        }
    }
}

/// The mock server for the who's-in scenarios.
@MainActor
final class MockCheckInService: CheckInServing {
    var caps: CheckInCapabilities
    var rows: [UUID: CheckInRecord]
    var steamRead: SteamRead
    /// Reads fail until `recover()`; Retry in the sheet calls it through the model.
    var readsDown: Bool
    var readDelay: TimeInterval
    /// The launch read doesn't happen, so the sheet's own (slow) read is the first one
    /// and its loading row shows, like opening Who's in before the first read is back.
    var waitsForSheet: Bool
    /// Every write is refused with this text.
    var refuseWrites: String?
    private(set) var writes: [CheckInWrite] = []
    var clock: () -> Date = Date.init

    init(
        caps: CheckInCapabilities = CheckInCapabilities(table: true, details: false),
        rows: [CheckInRecord] = [],
        steam: SteamRead = .notSetUp,
        readsDown: Bool = false,
        readDelay: TimeInterval = 0,
        waitsForSheet: Bool = false,
        refuseWrites: String? = nil
    ) {
        self.caps = caps
        self.rows = Dictionary(rows.map { ($0.userId, $0) }, uniquingKeysWith: { _, last in last })
        self.steamRead = steam
        self.readsDown = readsDown
        self.readDelay = readDelay
        self.waitsForSheet = waitsForSheet
        self.refuseWrites = refuseWrites
    }

    func capabilities() async throws -> CheckInCapabilities { caps }

    func recover() { readsDown = false }

    func checkIns(squadId: UUID) async throws -> [CheckInRecord] {
        if readDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(readDelay * 1_000_000_000))
        }
        if readsDown { throw BackendFailure.rejected("The server didn't answer.") }
        guard caps.table else { throw CheckInProblem.unavailable }
        return rows.values.filter { $0.squadId == squadId }.sorted { $0.userId.uuidString < $1.userId.uuidString }
    }

    /// Mirrors the 0006 trigger: the server stamps the time and the 60-minute window.
    func save(_ write: CheckInWrite) async throws -> CheckInRecord? {
        guard caps.table else { throw CheckInProblem.unavailable }
        if let refuseWrites { throw CheckInProblem.rejected(refuseWrites) }
        let now = clock()
        let until: Date?
        switch write.kind {
        case .availableNow: until = now.addingTimeInterval(CheckInRules.nowWindow)
        case .unavailable: until = nil
        case .availableLater:
            guard let at = write.untilAt, CheckInRules.acceptsLater(at, now: now) else {
                throw CheckInProblem.rejected(CheckInRules.message(for: "sq8_check_in_later_invalid"))
            }
            until = at
        }
        writes.append(write)
        let keep = caps.details && write.includesDetails && write.kind != .unavailable
        let record = CheckInRecord(
            userId: write.userId,
            squadId: write.squadId,
            kind: write.kind,
            checkedAt: now,
            untilAt: until,
            game: keep ? write.game : nil,
            platform: keep ? write.platform : nil
        )
        rows[write.userId] = record
        return record
    }

    func clear(userId: UUID, squadId: UUID) async throws {
        guard caps.table else { throw CheckInProblem.unavailable }
        if rows[userId]?.squadId == squadId { rows[userId] = nil }
    }

    func steam() async -> SteamRead { steamRead }
}

/// Seeded check-ins for the mock squad (`seedSpotSquad`).
enum WhosInSeed {
    static func rows(viewerId: UUID, squadId: UUID, now: Date, details: Bool) -> [CheckInRecord] {
        [
            CheckInRecord(
                userId: SpotSeed.alex, squadId: squadId, kind: .availableNow,
                checkedAt: now.addingTimeInterval(-10 * 60), untilAt: now.addingTimeInterval(50 * 60),
                game: details ? "Halo Infinite" : nil, platform: details ? .xbox : nil
            ),
            CheckInRecord(
                userId: SpotSeed.jordan, squadId: squadId, kind: .availableNow,
                checkedAt: now.addingTimeInterval(-5 * 60), untilAt: now.addingTimeInterval(55 * 60),
                game: nil, platform: nil
            ),
            CheckInRecord(
                userId: SpotSeed.sam, squadId: squadId, kind: .availableLater,
                checkedAt: now.addingTimeInterval(-60 * 60), untilAt: now.addingTimeInterval(2 * 60 * 60),
                game: details ? "Rocket League" : nil, platform: details ? .playstation : nil
            ),
            CheckInRecord(
                userId: SpotSeed.casey, squadId: squadId, kind: .unavailable,
                checkedAt: now.addingTimeInterval(-30 * 60), untilAt: nil, game: nil, platform: nil
            )
        ]
    }

    /// Jordan plays on Steam; Casey's profile is private; Alex never linked.
    static let steam = SteamRead.members([
        SpotSeed.jordan: .playing("Counter-Strike 2"),
        SpotSeed.casey: .privateProfile,
        SpotSeed.alex: .notLinked
    ])
}
