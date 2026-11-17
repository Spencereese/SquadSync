import XCTest
@testable import SquadSync

final class SpotThreadTests: XCTestCase {
    private let owner = UUID()
    private let squad = ChatSeed.squadId
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOpenCallIsActiveAndTurnsIntoHistoryWhenCancelled() {
        var card = SpotSeed.calledByViewer(ownerId: owner, squadId: squad, now: now)
        XCTAssertEqual(SpotThread.phase(card, viewerId: owner, now: now), .active)
        card.status = .cancelled
        card.closedAt = now
        XCTAssertEqual(SpotThread.phase(card, viewerId: owner, now: now), .history(.cancelled))
        XCTAssertTrue(SpotThread.canCallNow(card, now: now))
    }

    func testPastTheWindowIsExpiredUnlessAStarterCanStillJoin() {
        let card = SpotSeed.halfFilled(ownerId: owner, squadId: squad, now: now)
        let later = card.joinUntil.addingTimeInterval(5)
        XCTAssertEqual(SpotThread.phase(card, viewerId: owner, now: later), .history(.expired))
        XCTAssertTrue(SpotThread.showsLocalExpiryNote(card, outcome: .expired))
    }

    func testLockedCallStaysPinnedUntilItEnds() {
        var card = SpotSeed.calledByViewer(ownerId: owner, squadId: squad, now: now)
        card.status = .locked
        card.lockedAt = now
        XCTAssertEqual(SpotThread.phase(card, viewerId: owner, now: now), .active)
        XCTAssertFalse(SpotThread.canCallNow(card, now: now))
        card.status = .ended
        card.closedAt = now.addingTimeInterval(60)
        XCTAssertEqual(SpotThread.phase(card, viewerId: owner, now: now), .history(.ended))
    }

    func testHistoryCardsInterleaveWithMessagesByWhenTheyEnded() {
        let past = SpotSeed.history(ownerId: owner, squadId: squad, now: now)
        let early = ChatEntry(id: UUID(), senderId: owner, body: "early", sentAt: now.addingTimeInterval(-55 * 60), delivery: .sent)
        let middle = ChatEntry(id: UUID(), senderId: owner, body: "middle", sentAt: now.addingTimeInterval(-20 * 60), delivery: .sent)
        let late = ChatEntry(id: UUID(), senderId: owner, body: "late", sentAt: now.addingTimeInterval(-5 * 60), delivery: .sent)
        let history = SpotThread.history(past: past, excluding: nil, viewerId: owner, now: now)
        let ids = SpotThread.items(entries: [early, middle, late], history: history).map(\.id)
        XCTAssertEqual(ids, [
            "message-\(early.id.uuidString)",
            "spot-\(SpotSeed.historyEnded.uuidString)",
            "message-\(middle.id.uuidString)",
            "spot-\(SpotSeed.historyCancelled.uuidString)",
            "message-\(late.id.uuidString)"
        ])
        let withoutCurrent = SpotThread.history(past: past, excluding: SpotSeed.historyCancelled, viewerId: owner, now: now)
        XCTAssertEqual(withoutCurrent.map(\.id), [SpotSeed.historyEnded])
    }

    func testSpotsCommandParsing() {
        XCTAssertEqual(SpotCommand.parse("/spots"), .call(game: nil))
        XCTAssertEqual(SpotCommand.parse("  /SPOTS  Apex Legends "), .call(game: "Apex Legends"))
        XCTAssertEqual(SpotCommand.parse("/spot Halo"), .call(game: "Halo"))
        XCTAssertNil(SpotCommand.parse("/spotsx"))
        XCTAssertNil(SpotCommand.parse("spots tonight?"))
    }

    func testLoadStateOnlyShowsLoadingBeforeACardAndSaysWhenItFails() {
        XCTAssertEqual(SpotLoadState.beginning(.idle, hasCard: false), .loading)
        XCTAssertEqual(SpotLoadState.beginning(.loaded, hasCard: true), .loaded)
        XCTAssertEqual(SpotLoadState.finished(failure: SpotThread.loadFailed).failure, SpotThread.loadFailed)
        XCTAssertEqual(SpotLoadState.finished(failure: nil), .loaded)
    }

    func testMissingFunctionBecomesUnavailable() {
        let missing = SpotProblem.other("Could not find the function public.sq8_call_spot in the schema cache")
        XCTAssertEqual(SpotProblem.unavailableIfMissing(missing), .unavailable)
        XCTAssertEqual(SpotProblem.unavailableIfMissing(.notReady), .notReady)
    }

    func testRosterLimitsAlwaysEndWithZeroRows() {
        XCTAssertEqual(SquadPresence.rosterLimits(count: 5), [5, 4, 2, 1, 0])
        XCTAssertEqual(SquadPresence.rosterLimits(count: 1), [1, 1, 1, 1, 0])
        XCTAssertEqual(SquadPresence.moreLabel(3), "3 more in the squad panel")
    }
}
