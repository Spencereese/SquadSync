import Foundation

enum SpotRules {
    static let squadCap = 8
    static let joinWindow: TimeInterval = 5 * 60

    static func filled(_ party: Party) -> Int {
        party.seats.filter { $0.status != .out }.count
    }

    static func readyCount(_ party: Party) -> Int {
        party.seats.filter { $0.status == .ready }.count
    }

    static func isStarterExempt(_ person: Person) -> Bool {
        person.isStarter && person.inGame
    }

    static func joinDeadline(_ party: Party) -> Date {
        party.calledAt.addingTimeInterval(joinWindow)
    }

    /// Never longer than the five-minute window, even if the clock is behind the call.
    static func remaining(_ party: Party, now: Date) -> TimeInterval {
        let raw = joinDeadline(party).timeIntervalSince(now)
        return min(joinWindow, max(0, raw))
    }

    static func countdownText(_ party: Party, now: Date) -> String {
        let left = Int(remaining(party, now: now))
        return String(format: "%d:%02d", left / 60, left % 60)
    }

    /// In-game starters skip the five-minute drop. Everyone else is closed
    /// once the window ends, the card locks, or the seats hit the cap of 8.
    static func canJoin(party: Party, person: Person, now: Date) -> Bool {
        if party.locked { return false }
        if party.seat(for: person.id) != nil { return false }
        if filled(party) >= squadCap { return false }
        if filled(party) >= party.targetSize { return false }
        if isStarterExempt(person) { return true }
        return now < joinDeadline(party)
    }

    static func markReady(party: inout Party, personId: String) -> Bool {
        guard !party.locked else { return false }
        guard let index = party.seats.firstIndex(where: { $0.userId == personId }) else {
            return false
        }
        guard party.seats[index].status == .in else { return false }
        party.seats[index].status = .ready
        return true
    }

    /// The caller or the owner can lock once enough people are Ready,
    /// and never above the squad cap.
    static func canLock(party: Party, actor: Person) -> Bool {
        if party.locked { return false }
        let allowed = actor.role == .owner || actor.id == party.callerId
        guard allowed else { return false }
        let ready = readyCount(party)
        return ready >= party.targetSize && ready <= squadCap && filled(party) <= squadCap
    }

    static func lock(party: inout Party, actor: Person) -> Bool {
        guard canLock(party: party, actor: actor) else { return false }
        party.locked = true
        return true
    }

    static func canAddToSquad(memberCount: Int, role: Role) -> Bool {
        if role == .guest { return true }
        return memberCount < squadCap
    }

    /// Guests only see the side groups and DMs they were added to.
    static func visibleConversations(viewer: Person, conversations: [Conversation]) -> [Conversation] {
        if viewer.role != .guest { return conversations }
        return conversations.filter { conversation in
            conversation.guestIds.contains(viewer.id)
                || (conversation.kind == .dm && conversation.participantIds.contains(viewer.id))
        }
    }

    static func onCount(_ people: [Person]) -> Int {
        people.filter { $0.countsTowardCap && $0.isOnline }.count
    }
}

enum SpotCallStatus: String, Equatable {
    case open
    case locked
    case ended
    case cancelled
    case expired
}

struct SpotRsvp: Equatable, Identifiable {
    let userId: UUID
    var name: String
    var response: String
    var starter: Bool
    /// Ready is a phone value until 0020's column and RPC are both present.
    var ready: Bool

    var id: UUID { userId }
    var isIn: Bool { response == "in" }
}

struct SpotCall: Equatable, Identifiable {
    let id: UUID
    let squadId: UUID
    let callerId: UUID
    var game: String
    var calledAt: Date
    var joinUntil: Date
    var lockedAt: Date?
    var closedAt: Date?
    var status: SpotCallStatus
    var rsvps: [SpotRsvp]
    /// Stored by 0020. Nil when that column is not on the server yet.
    var seatTarget: Int? = nil
    /// True when `sq8_lock_spot_when_ready` is present. Lock then waits for Ready.
    var serverOwnsLock: Bool = false
    /// True when `sq8_read_open_spot` is present. Expiry then comes from `status`.
    var serverOwnsExpiry: Bool = false

    var filled: Int { rsvps.filter(\.isIn).count }
    var seatTotal: Int { seatTarget ?? SpotCallRules.cap }

    func seat(for userId: UUID) -> SpotRsvp? {
        rsvps.first { $0.userId == userId }
    }
}

struct SpotActionGate: Equatable {
    private(set) var busy = false

    mutating func begin() -> Bool {
        if busy { return false }
        busy = true
        return true
    }

    mutating func finish() { busy = false }
}

enum SpotClock {
    /// A timeline paused in the background can sit before `join_until`. The resume instant still counts.
    static func now(timeline: Date, resumedAt: Date) -> Date {
        max(timeline, resumedAt)
    }
}

enum SpotCallRules {
    static let cap = 8
    static let window: TimeInterval = 5 * 60

    static func remaining(joinUntil: Date, now: Date) -> TimeInterval {
        min(window, max(0, joinUntil.timeIntervalSince(now)))
    }

    static func countdown(joinUntil: Date, now: Date) -> String {
        let left = Int(remaining(joinUntil: joinUntil, now: now))
        return String(format: "%d:%02d", left / 60, left % 60)
    }

    /// Without 0020, the row stays `open` after join_until and this phone decides.
    /// With the read RPC, `status == expired` is the server clock and wins even if this phone is behind.
    static func showsExpired(_ call: SpotCall, now: Date) -> Bool {
        if call.status == .expired { return true }
        if call.serverOwnsExpiry { return false }
        return call.status == .open && call.closedAt == nil && now >= call.joinUntil
    }

    static func canJoin(_ call: SpotCall, userId: UUID, now: Date) -> Bool {
        guard call.closedAt == nil, call.lockedAt == nil else { return false }
        guard call.status == .open || call.status == .expired else { return false }
        if call.seat(for: userId)?.isIn == true { return false }
        if call.filled >= cap { return false }
        if call.seat(for: userId)?.starter == true { return true }
        if call.status == .expired { return false }
        return now < call.joinUntil
    }

    /// 0013 lets the caller or the owner lock an open call. It does not look at Ready.
    /// Once `join_until` has passed the row stays `open`, but the client does not offer Lock.
    /// When 0020's lock RPC is present, every in-joiner must also be Ready.
    static func canLock(_ call: SpotCall, actorId: UUID, ownerId: UUID, now: Date) -> Bool {
        guard call.status == .open, call.closedAt == nil, call.lockedAt == nil else { return false }
        if now >= call.joinUntil { return false }
        guard actorId == call.callerId || actorId == ownerId else { return false }
        if call.serverOwnsLock { return SpotLockRule.allows(call) }
        return true
    }

    static func canCancel(_ call: SpotCall, actorId: UUID, now: Date) -> Bool {
        guard call.status == .open, call.lockedAt == nil, call.closedAt == nil else { return false }
        if now >= call.joinUntil { return false }
        return actorId == call.callerId
    }

    /// No card, a server `expired` row, or an unlocked card past `join_until`, can take a new call.
    /// A lock still blocks it. 0013 ends the old unlocked row when the next call starts.
    static func showsCallForm(_ call: SpotCall?, now: Date) -> Bool {
        guard let call else { return true }
        if call.lockedAt != nil || call.status == .locked { return false }
        if call.status == .expired { return true }
        return now >= call.joinUntil
    }

    /// The pinned bar is only for a call people can still act on.
    static func showsPinnedBar(_ call: SpotCall, now: Date) -> Bool {
        call.status == .open && call.closedAt == nil && !showsExpired(call, now: now)
    }

    /// One action for the pinned bar. Expired calls have none, except a starter who can still join.
    static func barAction(_ call: SpotCall, viewerId: UUID, ownerId: UUID, now: Date) -> SpotBarAction? {
        if showsExpired(call, now: now), canJoin(call, userId: viewerId, now: now) { return .join }
        guard showsPinnedBar(call, now: now) else { return nil }
        if viewerId == call.callerId {
            if canLock(call, actorId: viewerId, ownerId: ownerId, now: now) { return .lock }
            if canCancel(call, actorId: viewerId, now: now) { return .cancel }
            return nil
        }
        if let seat = call.seat(for: viewerId), seat.isIn {
            if now >= call.joinUntil || call.status == .expired { return nil }
            return seat.ready ? .leave : .ready
        }
        if canJoin(call, userId: viewerId, now: now) { return .join }
        return nil
    }

    /// What a full Ready lock would require. 0020 does not use this. `SpotLockRule` is the lock gate.
    static func everyoneReady(_ call: SpotCall) -> Bool {
        let seated = call.rsvps.filter(\.isIn)
        return seated.count >= cap && seated.allSatisfy(\.ready)
    }
}

/// 0020 lock gate. Every in-joiner is Ready, and at least one person is in.
/// A full table is not required. The seat target is not read here.
enum SpotExpiryRead {
    /// The phone asks the server to stamp expiry just after its own window ends.
    static let margin: TimeInterval = 2

    /// Nil once that moment has passed. The read already on screen is the one that stamps.
    static func delay(joinUntil: Date, now: Date) -> TimeInterval? {
        let delay = joinUntil.addingTimeInterval(margin).timeIntervalSince(now)
        if delay <= 0 { return nil }
        return delay
    }
}

enum SpotLockRule {
    static func allows(_ call: SpotCall) -> Bool {
        let seated = call.rsvps.filter(\.isIn)
        return !seated.isEmpty && seated.allSatisfy(\.ready)
    }
}

struct SpotServerCapabilities: Equatable {
    var ready: Bool
    var gatedLock: Bool
    var expiry: Bool
    var seatTarget: Bool

    static let unavailable = SpotServerCapabilities(ready: false, gatedLock: false, expiry: false, seatTarget: false)
}

enum SpotProbe {
    /// Only a missing function is absent. A GET runs read-only and fails on FOR UPDATE; that failure means it is there.
    static func functionPresent(status: Int, body: String) -> Bool {
        if status == 404 { return false }
        let text = body.lowercased()
        if text.contains("pgrst202") || text.contains("could not find the function") { return false }
        return true
    }

    /// A missing column is 42703 or PGRST204. Any other error is not treated as present.
    static func columnPresent(status: Int, body: String) -> Bool {
        let text = body.lowercased()
        if text.contains("42703") || text.contains("pgrst204") { return false }
        if text.contains("could not find the") && text.contains("column") { return false }
        if text.contains("column") && text.contains("does not exist") { return false }
        return (200..<300).contains(status)
    }
}

enum SpotBarAction: Equatable {
    case join
    case leave
    case ready
    case lock
    case cancel

    var identifier: String {
        switch self {
        case .join: "active-call-join"
        case .leave: "active-call-leave"
        case .ready: "active-call-ready"
        case .lock: "active-call-lock"
        case .cancel: "active-call-cancel"
        }
    }

    var title: String {
        switch self {
        case .join: "Join"
        case .leave: "Leave"
        case .ready: "Ready"
        case .lock: "Lock"
        case .cancel: "Cancel"
        }
    }
}

enum SpotProblem: Error, Equatable {
    case signedOut
    case notMember
    case gameBlank
    case alreadyOpen
    case missing
    case closed
    case locked
    case joinClosed
    case full
    case notCaller
    case notLocked
    case notReady
    case notIn
    case expired
    case badResponse
    case other(String)

    var message: String {
        switch self {
        case .signedOut: "Sign in again before calling spots."
        case .notMember: "You are not in this squad."
        case .gameBlank: "Enter a game name."
        case .alreadyOpen: "This squad already has a spot call."
        case .missing: "That spot call is gone."
        case .closed: "That spot call is closed."
        case .locked: "That spot call is locked."
        case .joinClosed: "The 5 minute window has ended. Check-in starters can still join."
        case .full: "That spot call is full (8)."
        case .notCaller: "Only the caller or the owner can do that."
        case .notLocked: "Lock the call before ending it."
        case .notReady: "Everyone who is in has to be Ready before this locks."
        case .notIn: "Join before you mark Ready."
        case .expired: "The 5 minute window has ended."
        case .badResponse: "Join or leave. Those are the only answers this server stores."
        case .other(let text): text
        }
    }

    static func from(serverMessage: String) -> SpotProblem {
        let text = serverMessage.lowercased()
        if text.contains("spot_signed_out") { return .signedOut }
        if text.contains("spot_not_member") { return .notMember }
        if text.contains("spot_game_blank") { return .gameBlank }
        if text.contains("spot_already_open") { return .alreadyOpen }
        if text.contains("spot_missing") { return .missing }
        if text.contains("spot_join_closed") { return .joinClosed }
        if text.contains("spot_full") { return .full }
        if text.contains("spot_not_caller") { return .notCaller }
        if text.contains("spot_not_locked") { return .notLocked }
        if text.contains("spot_not_ready") { return .notReady }
        if text.contains("spot_not_in") { return .notIn }
        if text.contains("spot_expired") { return .expired }
        if text.contains("spot_locked") { return .locked }
        if text.contains("spot_closed") { return .closed }
        if text.contains("spot_response") { return .badResponse }
        return .other(serverMessage)
    }
}

enum SpotSeed {
    static let callId = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    static let alex = UUID(uuidString: "00000000-0000-0000-0000-00000000B011")!
    static let jordan = UUID(uuidString: "00000000-0000-0000-0000-00000000B012")!
    static let sam = UUID(uuidString: "00000000-0000-0000-0000-00000000B013")!
    static let casey = UUID(uuidString: "00000000-0000-0000-0000-00000000B014")!

    static func halfFilled(ownerId: UUID, squadId: UUID, now: Date) -> SpotCall {
        SpotCall(
            id: callId,
            squadId: squadId,
            callerId: alex,
            game: "Warzone",
            calledAt: now.addingTimeInterval(-60),
            joinUntil: now.addingTimeInterval(4 * 60),
            lockedAt: nil,
            closedAt: nil,
            status: .open,
            rsvps: [
                SpotRsvp(userId: alex, name: "Alex", response: "in", starter: true, ready: true),
                SpotRsvp(userId: jordan, name: "Jordan", response: "in", starter: false, ready: true),
                SpotRsvp(userId: sam, name: "Sam", response: "in", starter: false, ready: false),
                SpotRsvp(userId: casey, name: "Casey", response: "in", starter: false, ready: false)
            ]
        )
    }

    /// The signed-in person called it, so Cancel and Lock are theirs.
    static func calledByViewer(ownerId: UUID, squadId: UUID, now: Date) -> SpotCall {
        var card = halfFilled(ownerId: ownerId, squadId: squadId, now: now)
        card = SpotCall(
            id: card.id,
            squadId: card.squadId,
            callerId: ownerId,
            game: card.game,
            calledAt: card.calledAt,
            joinUntil: card.joinUntil,
            lockedAt: nil,
            closedAt: nil,
            status: .open,
            rsvps: [SpotRsvp(userId: ownerId, name: "You", response: "in", starter: false, ready: false)] + card.rsvps
        )
        return card
    }

    /// Seven people are in. One seat is open. They are not all Ready, so the 0020 lock rule says no.
    static func nearlyFull(ownerId: UUID, squadId: UUID, now: Date) -> SpotCall {
        let seated: [(UUID, String, Bool)] = [
            (alex, "Alex", true),
            (jordan, "Jordan", true),
            (sam, "Sam", true),
            (casey, "Casey", true),
            (morgan, "Morgan", true),
            (quinn, "Quinn", false),
            (avery, "Avery", false)
        ]
        return SpotCall(
            id: callId,
            squadId: squadId,
            callerId: alex,
            game: "Warzone",
            calledAt: now.addingTimeInterval(-60),
            joinUntil: now.addingTimeInterval(4 * 60),
            lockedAt: nil,
            closedAt: nil,
            status: .open,
            rsvps: seated.map { userId, name, ready in
                SpotRsvp(userId: userId, name: name, response: "in", starter: userId == alex, ready: ready)
            },
            seatTarget: 8,
            serverOwnsLock: true,
            serverOwnsExpiry: false
        )
    }

    /// Still `open` on the server, unlocked, and days past `join_until`. The next call replaces it.
    static func staleExpired(ownerId: UUID, squadId: UUID, now: Date) -> SpotCall {
        SpotCall(
            id: callId,
            squadId: squadId,
            callerId: alex,
            game: "Warzone",
            calledAt: now.addingTimeInterval(-4 * 24 * 60 * 60),
            joinUntil: now.addingTimeInterval(-4 * 24 * 60 * 60 + 5 * 60),
            lockedAt: nil,
            closedAt: nil,
            status: .open,
            rsvps: [
                SpotRsvp(userId: alex, name: "Alex", response: "in", starter: true, ready: false)
            ]
        )
    }

    static let morgan = UUID(uuidString: "00000000-0000-0000-0000-00000000B015")!
    static let quinn = UUID(uuidString: "00000000-0000-0000-0000-00000000B016")!
    static let avery = UUID(uuidString: "00000000-0000-0000-0000-00000000B017")!
}

enum PartyLauncher {
    struct Destination: Equatable, Identifiable {
        let title: String
        let scheme: URL
        let web: URL
        var id: String { title }
        var note: String { "Launcher only. This does not show who is already there." }
    }

    static let destinations: [Destination] = [
        Destination(
            title: "Discord",
            scheme: URL(string: "discord://")!,
            web: URL(string: "https://discord.com/app")!
        ),
        Destination(
            title: "Xbox",
            scheme: URL(string: "xbox://")!,
            web: URL(string: "https://www.xbox.com/")!
        ),
        Destination(
            title: "PlayStation",
            scheme: URL(string: "psapp://")!,
            web: URL(string: "https://www.playstation.com/")!
        )
    ]
}
