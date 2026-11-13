import XCTest
@testable import SquadSync

final class SpotRulesTests: XCTestCase {
    private func person(
        id: String = "p",
        role: Role = .member,
        inGame: Bool = false,
        starter: Bool = false
    ) -> Person {
        Person(
            id: id,
            name: id,
            role: role,
            availability: .upToPlay,
            game: inGame ? "Warzone" : nil,
            inVoice: false,
            isSpeaking: false,
            isStarter: starter
        )
    }

    private func party(calledAt: Date, seats: [Seat] = [], locked: Bool = false, size: Int = 4) -> Party {
        Party(
            id: "party",
            game: "Warzone",
            targetSize: size,
            callerId: "caller",
            calledAt: calledAt,
            seats: seats,
            locked: locked
        )
    }

    func testCountdownNeverExceedsFiveMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let skewed = party(calledAt: now.addingTimeInterval(207))
        XCTAssertEqual(SpotRules.remaining(skewed, now: now), SpotRules.joinWindow)
        XCTAssertEqual(SpotRules.countdownText(skewed, now: now), "5:00")
        let fresh = party(calledAt: now)
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now), "5:00")
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now.addingTimeInterval(90)), "3:30")
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now.addingTimeInterval(301)), "0:00")
    }

    func testWindowClosesForEveryoneExceptInGameStarters() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let open = party(calledAt: start)
        let later = start.addingTimeInterval(SpotRules.joinWindow + 1)
        let regular = person(id: "regular")
        let starter = person(id: "starter", inGame: true, starter: true)
        XCTAssertTrue(SpotRules.canJoin(party: open, person: regular, now: start.addingTimeInterval(10)))
        XCTAssertFalse(SpotRules.canJoin(party: open, person: regular, now: later))
        XCTAssertTrue(SpotRules.canJoin(party: open, person: starter, now: later))
        XCTAssertTrue(SpotRules.isStarterExempt(starter))
        XCTAssertFalse(SpotRules.isStarterExempt(person(id: "online-starter", starter: true)))
    }

    func testReadyThenLockRequiresTheCallerOrOwnerAndTheTarget() {
        var card = party(calledAt: Date(), seats: [
            Seat(userId: "a", status: .ready),
            Seat(userId: "b", status: .in)
        ], size: 2)
        let caller = person(id: "caller", role: .member)
        let owner = person(id: "owner", role: .owner)
        let member = person(id: "member")
        XCTAssertFalse(SpotRules.canLock(party: card, actor: caller))
        XCTAssertTrue(SpotRules.markReady(party: &card, personId: "b"))
        XCTAssertFalse(SpotRules.markReady(party: &card, personId: "missing"))
        XCTAssertFalse(SpotRules.canLock(party: card, actor: member))
        XCTAssertTrue(SpotRules.canLock(party: card, actor: caller))
        XCTAssertTrue(SpotRules.lock(party: &card, actor: owner))
        XCTAssertTrue(card.locked)
        XCTAssertFalse(SpotRules.canJoin(party: card, person: member, now: Date()))
    }

    func testCapOfEightBlocksANinthMemberButNotAGuest() {
        XCTAssertFalse(SpotRules.canAddToSquad(memberCount: 8, role: .member))
        XCTAssertTrue(SpotRules.canAddToSquad(memberCount: 7, role: .member))
        XCTAssertTrue(SpotRules.canAddToSquad(memberCount: 8, role: .guest))
        var full = party(
            calledAt: Date(),
            seats: (0..<8).map { Seat(userId: "s\($0)", status: .in) },
            size: 8
        )
        XCTAssertFalse(SpotRules.canJoin(party: full, person: person(id: "ninth"), now: Date()))
        XCTAssertEqual(SpotRules.filled(full), 8)
        _ = SpotRules.lock(party: &full, actor: person(id: "caller", role: .owner))
    }

    func testGuestsOnlySeeGroupsTheyWereAddedTo() {
        let guest = person(id: "riley", role: .guest)
        let member = person(id: "spencer", role: .owner)
        let threads = [
            Conversation(id: "space", title: "The Eight", kind: .squadSpace, parentId: nil, participantIds: ["spencer"], guestIds: [], unread: 0, folded: true),
            Conversation(id: "general", title: "#general", kind: .channel, parentId: "space", participantIds: ["spencer"], guestIds: [], unread: 0, folded: true),
            Conversation(id: "friday", title: "Friday crew", kind: .sideGroup, parentId: nil, participantIds: ["spencer", "riley"], guestIds: ["riley"], unread: 0, folded: false),
            Conversation(id: "dm", title: "Riley", kind: .dm, parentId: nil, participantIds: ["spencer", "riley"], guestIds: ["riley"], unread: 0, folded: false)
        ]
        let seen = SpotRules.visibleConversations(viewer: guest, conversations: threads).map(\.id)
        XCTAssertEqual(seen, ["friday", "dm"])
        XCTAssertEqual(SpotRules.visibleConversations(viewer: member, conversations: threads).count, 4)
    }
}

final class SpotCallRulesTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let caller = UUID(uuidString: "00000000-0000-0000-0000-00000000B011")!
    private let starter = UUID(uuidString: "00000000-0000-0000-0000-00000000B012")!
    private let member = UUID(uuidString: "00000000-0000-0000-0000-00000000B013")!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(status: SpotCallStatus = .open, joinUntil: Date? = nil, rsvps: [SpotRsvp]? = nil) -> SpotCall {
        SpotCall(
            id: SpotSeed.callId,
            squadId: ChatSeed.squadId,
            callerId: caller,
            game: "Warzone",
            calledAt: start,
            joinUntil: joinUntil ?? start.addingTimeInterval(SpotCallRules.window),
            lockedAt: status == .locked ? start : nil,
            closedAt: status == .ended || status == .cancelled ? start : nil,
            status: status,
            rsvps: rsvps ?? [
                SpotRsvp(userId: caller, name: "Alex", response: "in", starter: false, ready: false)
            ]
        )
    }

    func testCountdownUsesTheServerDeadlineAndClampsAtFiveMinutes() {
        let fresh = start.addingTimeInterval(SpotCallRules.window)
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start), "5:00")
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start.addingTimeInterval(90)), "3:30")
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start.addingTimeInterval(301)), "0:00")
        let skewed = start.addingTimeInterval(8 * 60)
        XCTAssertEqual(SpotCallRules.remaining(joinUntil: skewed, now: start), SpotCallRules.window)
    }

    func testStartersCanJoinAfterTheWindowAndOthersCannot() {
        let open = call()
        let later = start.addingTimeInterval(SpotCallRules.window + 1)
        var expired = open
        expired.joinUntil = start
        XCTAssertTrue(SpotCallRules.canJoin(open, userId: member, now: start.addingTimeInterval(10)))
        XCTAssertFalse(SpotCallRules.canJoin(expired, userId: member, now: later))
        var seated = expired
        seated.rsvps.append(SpotRsvp(userId: member, name: "Sam", response: "out", starter: true, ready: false))
        XCTAssertTrue(SpotCallRules.canJoin(seated, userId: member, now: later))
        XCTAssertTrue(SpotCallRules.showsExpired(expired, now: later))
        XCTAssertEqual(expired.status, .open)
    }

    func testLockIsCallerOrOwnerAndDoesNotRequireReady() {
        let open = call()
        XCTAssertTrue(SpotCallRules.canLock(open, actorId: caller, ownerId: owner))
        XCTAssertTrue(SpotCallRules.canLock(open, actorId: owner, ownerId: owner))
        XCTAssertFalse(SpotCallRules.canLock(open, actorId: member, ownerId: owner))
        XCTAssertFalse(SpotCallRules.canLock(call(status: .cancelled), actorId: caller, ownerId: owner))
        XCTAssertFalse(SpotCallRules.everyoneReady(open))
        var full = open
        full.rsvps = (0..<8).map { index in
            SpotRsvp(
                userId: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
                name: "P\(index)",
                response: "in",
                starter: false,
                ready: true
            )
        }
        XCTAssertTrue(SpotCallRules.everyoneReady(full))
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_full").message, "That spot call is full (8).")
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_join_closed"), .joinClosed)
    }
}
