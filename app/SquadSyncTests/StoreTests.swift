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

    func testTypingStaysOnItsThread() {
        let store = MockStore.seeded()
        XCTAssertEqual(store.typingNames(in: "general"), ["Jordan"])
        XCTAssertTrue(store.typingNames(in: "warzone").isEmpty)
        XCTAssertTrue(store.typingNames(in: "friday").isEmpty)
    }

    func testPartyCardStaysOnItsThread() {
        let store = MockStore.seeded()
        let general = store.conversations.first { $0.id == "general" }!
        let warzone = store.conversations.first { $0.id == "warzone" }!
        let friday = store.conversations.first { $0.id == "friday" }!
        XCTAssertTrue(store.showsParty(in: general))
        XCTAssertFalse(store.showsParty(in: warzone))
        XCTAssertFalse(store.showsParty(in: friday))
        XCTAssertFalse(store.canOfferCall(in: warzone))
        store.party = nil
        XCTAssertTrue(store.canOfferCall(in: warzone))
        XCTAssertFalse(store.canOfferCall(in: friday))
    }

    func testReadyBecomesUnreadyWhenTheViewerIsAlreadyReady() {
        let store = MockStore.seeded()
        XCTAssertEqual(store.readyButtonTitle, "Unready")
        XCTAssertTrue(store.canPressReady)
        XCTAssertFalse(store.markReady(personId: "spencer"))
        XCTAssertTrue(store.toggleReady(personId: "spencer"))
        XCTAssertEqual(store.party?.seat(for: "spencer")?.status, .in)
        XCTAssertEqual(store.readyButtonTitle, "Ready")
        XCTAssertTrue(store.markReady(personId: "spencer"))
    }

    func testCallSpotDoesNotReplaceAFormingCard() {
        let store = MockStore.seeded()
        XCTAssertFalse(store.callSpot(game: "Halo", size: 3, in: "warzone"))
        XCTAssertEqual(store.party?.id, "party-warzone")
        XCTAssertEqual(store.party?.game, "Warzone")
        XCTAssertEqual(store.party?.conversationId, "general")
    }

    func testUnseatedViewerCanJoin() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let store = MockStore.seeded(now: now, scenario: .unseated)
        XCTAssertNil(store.party?.seat(for: "spencer"))
        XCTAssertFalse(store.canPressReady)
        XCTAssertTrue(store.joinParty(personId: "spencer", now: now))
        XCTAssertEqual(store.party?.seat(for: "spencer")?.status, .in)
        XCTAssertTrue(store.canPressReady)
        XCTAssertFalse(store.lockParty())
    }

    func testFourReadySeatsEnableLock() {
        let store = MockStore.seeded(scenario: .ready4)
        XCTAssertEqual(SpotRules.readyCount(store.party!), 4)
        XCTAssertTrue(SpotRules.canLock(party: store.party!, actor: store.viewer))
        XCTAssertTrue(store.lockParty())
        XCTAssertEqual(store.party?.locked, true)
        XCTAssertFalse(store.canPressReady)
    }

    func testLaunchArgumentsPickTheScreenAndScenario() {
        let options = LaunchOptions.current([
            "SquadSync", "-screen", "voice-pill", "-scenario", "ready4", "-uitest-largeText"
        ])
        XCTAssertEqual(options.screen, .voicePill)
        XCTAssertEqual(options.scenario, .ready4)
        XCTAssertTrue(options.largeText)
        XCTAssertEqual(options.path, [])
        let mockSquad = LaunchOptions.current(["-backend", "mock", "-scenario", "noSquad"])
        XCTAssertEqual(mockSquad.backend, .mock)
        XCTAssertEqual(mockSquad.scenario, .noSquad)
        XCTAssertEqual(LaunchOptions.current(["-screen", "thread-warzone"]).path, ["warzone"])
        XCTAssertEqual(LaunchOptions.current(["-screen", "party"]).path, ["general"])
    }
}
