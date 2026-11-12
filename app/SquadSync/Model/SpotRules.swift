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
