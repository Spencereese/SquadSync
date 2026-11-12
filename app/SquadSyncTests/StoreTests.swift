import XCTest
@testable import SquadSync

@MainActor
final class StoreTests: XCTestCase {
    func testStoreUsesTheJoinExemptionAndTheCap() {
        let store = MockStore.seeded(now: Date(timeIntervalSince1970: 1_700_000_000))
        let expired = Date(timeIntervalSince1970: 1_700_000_000 + 400)
        XCTAssertFalse(store.joinParty(personId: "jordan", now: expired))
        XCTAssertTrue(store.joinParty(personId: "alex", now: expired) == false)
        store.people[1].game = "Warzone"
        store.people[1].isStarter = true
        if var party = store.party, party.seat(for: "alex") != nil {
            party.seats.removeAll { $0.userId == "alex" }
            store.party = party
        }
        XCTAssertTrue(store.joinParty(personId: "alex", now: expired))
        store.party?.seats = []
        if var party = store.party {
            party.seats = (0..<8).map { Seat(userId: "seat-\($0)", status: .in) }
            store.party = party
        }
        XCTAssertFalse(store.joinParty(personId: "jordan", now: Date()))
    }

    func testGuestInboxHidesTheSquadChannels() {
        let store = MockStore.seeded()
        store.viewerId = "riley"
        let titles = store.visibleConversations().map(\.title)
        XCTAssertTrue(titles.contains("Friday crew"))
        XCTAssertTrue(titles.contains("Riley"))
        XCTAssertFalse(titles.contains("#general"))
        XCTAssertFalse(titles.contains("The Eight"))
    }

    func testReadyAndLockFromTheViewer() {
        let store = MockStore.seeded()
        XCTAssertTrue(store.markReady(personId: "alex"))
        XCTAssertFalse(store.lockParty())
        if var party = store.party {
            party.targetSize = 2
            store.party = party
        }
        XCTAssertTrue(store.lockParty())
        XCTAssertEqual(store.party?.locked, true)
    }
}
