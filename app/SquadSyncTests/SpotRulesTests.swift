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
