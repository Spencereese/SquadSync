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
}

struct SpotRsvp: Equatable, Identifiable {
    let userId: UUID
    var name: String
    var response: String
    var starter: Bool
    /// Ready is not a column in 0013. The mock keeps it on the phone.
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

    var filled: Int { rsvps.filter(\.isIn).count }

    func seat(for userId: UUID) -> SpotRsvp? {
        rsvps.first { $0.userId == userId }
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

    /// The row stays `open` after join_until. The server only closes it when the next call starts.
    static func showsExpired(_ call: SpotCall, now: Date) -> Bool {
        call.status == .open && call.closedAt == nil && now >= call.joinUntil
    }

    static func canJoin(_ call: SpotCall, userId: UUID, now: Date) -> Bool {
        guard call.status == .open, call.closedAt == nil, call.lockedAt == nil else { return false }
        if call.seat(for: userId)?.isIn == true { return false }
        if call.filled >= cap { return false }
        if call.seat(for: userId)?.starter == true { return true }
        return now < call.joinUntil
    }

    /// 0013 lets the caller or the owner lock an open call. It does not look at Ready.
    /// Once `join_until` has passed the row stays `open`, but the client does not offer Lock.
    static func canLock(_ call: SpotCall, actorId: UUID, ownerId: UUID, now: Date) -> Bool {
        guard call.status == .open, call.closedAt == nil, call.lockedAt == nil else { return false }
        if now >= call.joinUntil { return false }
        return actorId == call.callerId || actorId == ownerId
    }

    static func canCancel(_ call: SpotCall, actorId: UUID, now: Date) -> Bool {
        guard call.status == .open, call.lockedAt == nil, call.closedAt == nil else { return false }
        if now >= call.joinUntil { return false }
        return actorId == call.callerId
    }

    /// The pinned bar is only for a call people can still act on.
    static func showsPinnedBar(_ call: SpotCall, now: Date) -> Bool {
        call.status == .open && call.closedAt == nil && !showsExpired(call, now: now)
    }

    /// One action for the pinned bar. Expired calls have none, including Cancel.
    static func barAction(_ call: SpotCall, viewerId: UUID, ownerId: UUID, now: Date) -> SpotBarAction? {
        guard showsPinnedBar(call, now: now) else { return nil }
        if viewerId == call.callerId {
            if canLock(call, actorId: viewerId, ownerId: ownerId, now: now) { return .lock }
            if canCancel(call, actorId: viewerId, now: now) { return .cancel }
            return nil
        }
        if let seat = call.seat(for: viewerId), seat.isIn {
            return seat.ready ? .leave : .ready
        }
        if canJoin(call, userId: viewerId, now: now) { return .join }
        return nil
    }

    /// What a full Ready lock would require. The server does not enforce this.
    static func everyoneReady(_ call: SpotCall) -> Bool {
        let seated = call.rsvps.filter(\.isIn)
        return seated.count >= cap && seated.allSatisfy(\.ready)
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
