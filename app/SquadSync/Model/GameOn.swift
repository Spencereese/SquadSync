import Foundation

/// Game on (0028): someone says what they're playing and how many more they need.
/// It's a row of `sq8_spot_calls` with `kind = 'game_on'`; seats are `sq8_spot_rsvps`.
/// There's no join window and no lock: anyone in the group joins until the seats
/// are full. The card ends when the starter closes it, when everyone leaves, or
/// after about three hours with nothing happening (`join_until`, bumped on activity).
enum GameOnStatus: String, Equatable {
    case open
    case locked
    case ended
    case cancelled
    case expired
}

struct GameOnSeat: Equatable, Identifiable, Hashable {
    let userId: UUID
    var isIn: Bool
    var starter: Bool
    var ready: Bool
    var updatedAt: Date?

    var id: UUID { userId }
}

struct GameOn: Equatable, Identifiable {
    let id: UUID
    let squadId: UUID
    let callerId: UUID
    var game: String
    let calledAt: Date
    /// `join_until`: the idle deadline. Each join, leave or Ready pushes it out again.
    var idleUntil: Date
    /// The starter plus however many they asked for.
    var seatTarget: Int
    var status: GameOnStatus
    var closedAt: Date?
    var seats: [GameOnSeat]

    /// How many the starter asked for when they started it.
    var askedFor: Int { max(0, seatTarget - 1) }
}

enum GameOnRules {
    /// At most two open at once (the server says `game_on_cap`).
    static let maxOpen = 2
    /// Idle for about this long and the card ends.
    static let idleWindow: TimeInterval = 3 * 60 * 60
    /// "How many more?" One to seven: the group tops out at eight.
    static let needRange = 1...7
    static let maxGameLength = 60
    /// Chat lines for Game ons from the last two weeks.
    static let readWindow: TimeInterval = 14 * 24 * 60 * 60
    static let readLimit = 30

    /// Who's in, starter first, then in the order they joined. Seats of people who
    /// left the group don't count (the server's `game_on_full` doesn't count them either).
    static func players(_ call: GameOn, memberIds: Set<UUID>? = nil) -> [GameOnSeat] {
        call.seats
            .filter { $0.isIn && (memberIds?.contains($0.userId) ?? true) }
            .sorted { lhs, rhs in
                if lhs.starter != rhs.starter { return lhs.starter }
                let left = lhs.updatedAt ?? .distantPast
                let right = rhs.updatedAt ?? .distantPast
                if left != right { return left < right }
                return lhs.userId.uuidString < rhs.userId.uuidString
            }
    }

    static func need(_ call: GameOn, memberIds: Set<UUID>? = nil) -> Int {
        max(0, call.seatTarget - players(call, memberIds: memberIds).count)
    }

    static func isFull(_ call: GameOn, memberIds: Set<UUID>? = nil) -> Bool {
        need(call, memberIds: memberIds) == 0
    }

    /// Still on the top of the chat: not closed, not idle past its deadline, and
    /// somebody's still in. The server sweeps idle and empty rows on its next write;
    /// until then the app hides them on its own.
    static func isLive(_ call: GameOn, now: Date, memberIds: Set<UUID>? = nil) -> Bool {
        guard call.closedAt == nil else { return false }
        guard call.status == .open || call.status == .locked else { return false }
        guard now < call.idleUntil else { return false }
        return !players(call, memberIds: memberIds).isEmpty
    }

    /// The open cards, oldest first, never more than two.
    static func live(_ calls: [GameOn], now: Date, memberIds: Set<UUID>? = nil) -> [GameOn] {
        Array(
            calls
                .filter { isLive($0, now: now, memberIds: memberIds) }
                .sorted { lhs, rhs in
                    if lhs.calledAt != rhs.calledAt { return lhs.calledAt < rhs.calledAt }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                .prefix(maxOpen)
        )
    }

    static func canStart(live: [GameOn]) -> Bool {
        live.count < maxOpen
    }

    enum ViewerState: Equatable {
        case canJoin
        case full
        case joined(ready: Bool, starter: Bool)
    }

    static func viewerState(_ call: GameOn, viewerId: UUID?, memberIds: Set<UUID>? = nil) -> ViewerState {
        if let viewerId, let seat = players(call, memberIds: memberIds).first(where: { $0.userId == viewerId }) {
            return .joined(ready: seat.ready, starter: seat.starter || call.callerId == viewerId)
        }
        return isFull(call, memberIds: memberIds) ? .full : .canJoin
    }

    /// Only the one who started it closes it. Owners don't get a special button.
    static func canClose(_ call: GameOn, viewerId: UUID?) -> Bool {
        viewerId != nil && call.callerId == viewerId
    }

    /// Joining, leaving and Ready each push the idle deadline out, like the server.
    static func bumped(_ call: GameOn, now: Date) -> GameOn {
        var copy = call
        copy.idleUntil = now.addingTimeInterval(idleWindow)
        return copy
    }

    /// Replaces a card by id (or adds it), keeping the newest first.
    static func replacing(_ call: GameOn, in calls: [GameOn]) -> [GameOn] {
        var result = calls.filter { $0.id != call.id }
        result.append(call)
        return result.sorted { lhs, rhs in
            if lhs.calledAt != rhs.calledAt { return lhs.calledAt > rhs.calledAt }
            return lhs.id.uuidString > rhs.id.uuidString
        }
    }
}

/// What the "Game on" form starts with: your default game, picked from your games.
struct GameOnDraft: Equatable {
    var game: String
    var need: Int
    /// Your games, default first, no blanks or repeats.
    var games: [String]

    static let other = "Other"

    static func initial(defaultGame: String, games: [String]) -> GameOnDraft {
        let list = choices(defaultGame: defaultGame, games: games)
        return GameOnDraft(game: list.first ?? "", need: 1, games: list)
    }

    static func choices(defaultGame: String, games: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in [defaultGame] + games {
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(name)
        }
        return result
    }

    var trimmedGame: String { game.trimmingCharacters(in: .whitespacesAndNewlines) }

    var validationError: String? {
        if trimmedGame.isEmpty { return GameOnProblem.gameBlank.message }
        if trimmedGame.count > GameOnRules.maxGameLength { return GameOnProblem.gameLong.message }
        if !GameOnRules.needRange.contains(need) { return GameOnProblem.needRange.message }
        return nil
    }

    var canSubmit: Bool { validationError == nil }
}

enum GameOnProblem: Error, Equatable {
    case notSetUp
    case cap
    case full
    case closed
    case notStarter
    case notIn
    case gameBlank
    case gameLong
    case needRange
    case notMember
    case offline
    case failed

    var message: String {
        switch self {
        case .notSetUp: "Game on needs a server update before it works here."
        case .cap: "Two games are already on. Join one, or wait for one to end."
        case .full: "That game's full."
        case .closed: "That game already ended."
        case .notStarter: "Only the person who started it can end it."
        case .notIn: "Join first, then you can say you're ready."
        case .gameBlank: "Pick a game."
        case .gameLong: "Keep the game name to 60 characters."
        case .needRange: "Pick from 1 to 7 more."
        case .notMember: "You're not in this group anymore."
        case .offline: "You're offline. Try again when you're back."
        case .failed: "That didn't go through. Try again."
        }
    }

    static func from(_ error: Error) -> GameOnProblem {
        if let problem = error as? GameOnProblem { return problem }
        guard let failure = error as? BackendFailure else { return .failed }
        switch failure {
        case .notSetUp: return .notSetUp
        case .reconnecting: return .offline
        case .rejected(let text):
            let lower = text.lowercased()
            if lower.contains("game_on_cap") { return .cap }
            if lower.contains("game_on_full") { return .full }
            if lower.contains("game_on_closed") || lower.contains("game_on_missing") { return .closed }
            if lower.contains("game_on_not_starter") { return .notStarter }
            if lower.contains("game_on_not_in") { return .notIn }
            if lower.contains("game_on_game_blank") { return .gameBlank }
            if lower.contains("game_on_game_long") { return .gameLong }
            if lower.contains("game_on_need_range") { return .needRange }
            if lower.contains("game_on_not_member") { return .notMember }
            if MissingColumn.matches(text) { return .notSetUp }
            return .failed
        case .notConfigured, .notSignedIn, .sessionEnded:
            return .failed
        }
    }
}

enum GameOnLoad: Equatable {
    case idle
    case loading
    case loaded
    /// The read failed. Cards that loaded before stay up.
    case failed(String)
    /// This server doesn't have 0028 yet.
    case unavailable
}

enum GameOnCopy {
    static let button = "Game on"
    static let buttonHint = "Say what you're playing and how many more you need."
    static let sheetTitle = "Game on"
    static let gamePrompt = "What are you playing?"
    static let otherGame = "Game name"
    static let needPrompt = "How many more?"
    static let start = "Start"
    static let join = "Join"
    static let leave = "Leave"
    static let ready = "Ready"
    static let notReady = "Not ready"
    static let end = "End"
    static let full = "Full"
    static let loading = "Checking who's on…"
    static let loadFailed = "Couldn't check who's on."
    static let unavailable = GameOnProblem.notSetUp.message
    static let capReached = GameOnProblem.cap.message
    static let openSeat = "Open seat"

    static func name(_ id: UUID, names: [UUID: String], viewerId: UUID?) -> String {
        if id == viewerId { return "You" }
        let raw = names[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Someone" : raw
    }

    /// "Riley's on Warzone" / "You're on Warzone".
    static func title(_ call: GameOn, names: [UUID: String], viewerId: UUID?) -> String {
        if call.callerId == viewerId { return "You're on \(call.game)" }
        return "\(name(call.callerId, names: names, viewerId: viewerId))'s on \(call.game)"
    }

    /// "Need 1" or "Full".
    static func needLabel(_ need: Int) -> String {
        need <= 0 ? full : "Need \(need)"
    }

    /// The push and the chat line: "Riley's on Warzone, need 1". Matches the server's banner.
    static func line(_ call: GameOn, names: [UUID: String], viewerId: UUID?) -> String {
        let who = call.callerId == viewerId ? "You're" : "\(name(call.callerId, names: names, viewerId: nil))'s"
        let tail = call.askedFor > 0 ? "need \(call.askedFor)" : "full"
        return "\(who) on \(call.game), \(tail)"
    }

    static func players(_ call: GameOn, names: [UUID: String], viewerId: UUID?, memberIds: Set<UUID>? = nil) -> String {
        let list = GameOnRules.players(call, memberIds: memberIds).map { name($0.userId, names: names, viewerId: viewerId) }
        return PlaySessionRoster.list(list)
    }

    /// One VoiceOver label for the whole card.
    static func spoken(_ call: GameOn, names: [UUID: String], viewerId: UUID?, memberIds: Set<UUID>? = nil) -> String {
        let seats = GameOnRules.players(call, memberIds: memberIds)
        let need = GameOnRules.need(call, memberIds: memberIds)
        let ready = seats.filter(\.ready).count
        var parts = [title(call, names: names, viewerId: viewerId)]
        parts.append(need == 0 ? "Full" : (need == 1 ? "Needs 1 more" : "Needs \(need) more"))
        parts.append("In: \(players(call, names: names, viewerId: viewerId, memberIds: memberIds))")
        if ready > 0 { parts.append("\(ready) ready") }
        return parts.joined(separator: ". ")
    }

    /// "Ended" lines are left out on purpose: the chat line is when it started.
    static func spokenLine(_ call: GameOn, names: [UUID: String], viewerId: UUID?) -> String {
        "Game on. " + line(call, names: names, viewerId: viewerId)
    }
}

/// Chat lines for Game ons: one where each started, between messages. Built on
/// the phone from the Game on rows, so nothing extra is written to the chat
/// (and the chat's own push doesn't fire twice).
enum GameOnThread {
    static func items(_ base: [SpotThreadItem], calls: [GameOn], earliest: Date?) -> [SpotThreadItem] {
        let lines = calls
            .filter { call in earliest.map { call.calledAt >= $0 } ?? true }
            .sorted { lhs, rhs in
                if lhs.calledAt != rhs.calledAt { return lhs.calledAt < rhs.calledAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        guard !lines.isEmpty else { return base }
        var result: [SpotThreadItem] = []
        var pending = lines[...]
        for item in base {
            let at = PlaySessionThread.date(of: item)
            while let next = pending.first, next.calledAt <= at {
                result.append(.gameOn(next))
                pending = pending.dropFirst()
            }
            result.append(item)
        }
        result.append(contentsOf: pending.map { .gameOn($0) })
        return result
    }
}

/// A planned session (PR #44) shows as a Game on card once its start time
/// arrives, until it's over, cancelled, or an hour has gone by.
enum PlannedGameOn {
    static let showFor: TimeInterval = 60 * 60

    static func starting(_ sessions: [PlaySession], now: Date) -> [PlaySession] {
        sessions
            .filter { session in
                session.cancelledAt == nil
                    && session.startsAt <= now
                    && now < min(PlaySessionRules.endsAt(session), session.startsAt.addingTimeInterval(showFor))
            }
            .sorted { lhs, rhs in
                if lhs.startsAt != rhs.startsAt { return lhs.startsAt < rhs.startsAt }
                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    static func title(_ session: PlaySession, names: [UUID: String], viewerId: UUID?) -> String {
        if session.creatorId == viewerId { return "Your \(session.game) session is starting" }
        return "\(GameOnCopy.name(session.creatorId, names: names, viewerId: viewerId))'s \(session.game) session is starting"
    }
}

/// The "nothing happening yet" nudges on the home chat.
enum HomePrompts {
    /// Under this many people, the empty seats come with an invite nudge.
    static let smallGroup = 4

    static func showsInvite(memberCount: Int, dismissed: Bool) -> Bool {
        !dismissed && memberCount < smallGroup && memberCount < SpotRules.squadCap
    }

    /// Right after you join a group: "I'm on" or Game on, once.
    static func showsWelcome(justJoined: Bool, liveCount: Int) -> Bool {
        justJoined && liveCount == 0
    }

    /// The photo nudge shows early: until you add one or say not now.
    static func showsPhoto(hasPhoto: Bool, dismissed: Bool, storageReady: Bool) -> Bool {
        storageReady && !hasPhoto && !dismissed
    }

    static let imOnMessage = "I'm on"
    static let welcomeTitle = "You're in."
    static let welcomeBody = "Let everyone know you're around."
    static let invitePrompt = "It's quiet in here. Invite a friend."
    static let photoPrompt = "Add a photo so people know it's you."
    static let addPhoto = "Add photo"
    static let notNow = "Not now"
}

/// Mock Game ons for the launch scenarios and UI tests.
enum GameOnSeed {
    static let alexCall = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    static let jordanCall = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
    static let mineCall = UUID(uuidString: "00000000-0000-0000-0000-00000000C003")!

    /// Alex is on Warzone and needs one more. `full` adds Jordan; `idle` has sat
    /// untouched past the three hours.
    static func alexWarzone(squadId: UUID, now: Date, full: Bool = false, idle: Bool = false) -> GameOn {
        let calledAt = now.addingTimeInterval(idle ? -4 * 3600 : -4 * 60)
        var seats = [GameOnSeat(userId: SpotSeed.alex, isIn: true, starter: true, ready: false, updatedAt: calledAt)]
        if full {
            seats.append(GameOnSeat(userId: SpotSeed.jordan, isIn: true, starter: false, ready: true, updatedAt: calledAt.addingTimeInterval(60)))
        }
        return GameOn(
            id: alexCall,
            squadId: squadId,
            callerId: SpotSeed.alex,
            game: "Warzone",
            calledAt: calledAt,
            idleUntil: calledAt.addingTimeInterval(GameOnRules.idleWindow),
            seatTarget: 2,
            status: .open,
            closedAt: nil,
            seats: seats
        )
    }

    static func jordanApex(squadId: UUID, now: Date) -> GameOn {
        let calledAt = now.addingTimeInterval(-2 * 60)
        return GameOn(
            id: jordanCall,
            squadId: squadId,
            callerId: SpotSeed.jordan,
            game: "Apex Legends",
            calledAt: calledAt,
            idleUntil: calledAt.addingTimeInterval(GameOnRules.idleWindow),
            seatTarget: 3,
            status: .open,
            closedAt: nil,
            seats: [GameOnSeat(userId: SpotSeed.jordan, isIn: true, starter: true, ready: false, updatedAt: calledAt)]
        )
    }

    static func mine(viewerId: UUID, squadId: UUID, now: Date) -> GameOn {
        let calledAt = now.addingTimeInterval(-3 * 60)
        return GameOn(
            id: mineCall,
            squadId: squadId,
            callerId: viewerId,
            game: "Call of Duty",
            calledAt: calledAt,
            idleUntil: calledAt.addingTimeInterval(GameOnRules.idleWindow),
            seatTarget: 4,
            status: .open,
            closedAt: nil,
            seats: [
                GameOnSeat(userId: viewerId, isIn: true, starter: true, ready: false, updatedAt: calledAt),
                GameOnSeat(userId: SpotSeed.sam, isIn: true, starter: false, ready: false, updatedAt: calledAt.addingTimeInterval(30))
            ]
        )
    }
}
