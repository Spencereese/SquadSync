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
        XCTAssertEqual(SquadPresence.moreLabel(3), "3 more in Who's in")
    }
}

final class SpotHistoryServerTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
    private let ended = UUID(uuidString: "00000000-0000-0000-0000-0000000000D1")!
    private let cancelled = UUID(uuidString: "00000000-0000-0000-0000-0000000000D2")!
    private let caller = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
    private let member = UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")!

    private func probes() -> [(Int, Data)] {
        let rows = Data("[]".utf8)
        return [(200, rows), (200, rows)]
    }

    private func stamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    func testHistoryReadsFinishedCallsWithTwoReadOnlyGets() async throws {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let calls = Data("""
        [{"id":"\(cancelled.uuidString)","squad_id":"\(squad.uuidString)","caller_id":"\(caller.uuidString)","game":"Valorant","called_at":"\(stamp(base))","join_until":"\(stamp(base.addingTimeInterval(300)))","locked_at":null,"closed_at":"\(stamp(base.addingTimeInterval(60)))","status":"cancelled","seat_target":8},
         {"id":"\(ended.uuidString)","squad_id":"\(squad.uuidString)","caller_id":"\(caller.uuidString)","game":"Apex","called_at":"\(stamp(base.addingTimeInterval(-3600)))","join_until":"\(stamp(base.addingTimeInterval(-3300)))","locked_at":"\(stamp(base.addingTimeInterval(-3400)))","closed_at":"\(stamp(base.addingTimeInterval(-1800)))","status":"ended","seat_target":8}]
        """.utf8)
        let seats = Data("""
        [{"call_id":"\(ended.uuidString.lowercased())","user_id":"\(caller.uuidString)","response":"in","starter":true},
         {"call_id":"\(ended.uuidString.lowercased())","user_id":"\(member.uuidString)","response":"in","starter":false},
         {"call_id":"\(cancelled.uuidString.lowercased())","user_id":"\(caller.uuidString)","response":"in","starter":false}]
        """.utf8)
        let transport = ScriptedTransport(responses: probes() + [(200, calls), (200, seats)])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        let history = try await spots.history(squadId: squad, limit: 5)
        XCTAssertEqual(history.map(\.game), ["Valorant", "Apex"])
        XCTAssertEqual(history.map(\.filled), [1, 2])
        XCTAssertEqual(history.map(\.status), [.cancelled, .ended])
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" && $0.httpBody == nil }, "History must not write")
        let callRead = try XCTUnwrap(transport.requests.dropLast().last)
        let callQuery = callRead.url?.query?.removingPercentEncoding ?? ""
        XCTAssertTrue(callRead.url?.path.hasSuffix("sq8_spot_calls") == true)
        XCTAssertTrue(callQuery.contains("status=in.(ended,cancelled,expired)"), callQuery)
        XCTAssertTrue(callQuery.contains("order=called_at.desc"))
        XCTAssertTrue(callQuery.contains("limit=5"))
        let seatQuery = transport.requests.last?.url?.query?.removingPercentEncoding ?? ""
        XCTAssertTrue(seatQuery.contains("call_id=in.("), seatQuery)
        let outcomes = history.map { SpotThread.outcome($0, viewerId: member, now: base) }
        XCTAssertEqual(outcomes, [.cancelled, .ended])
    }

    func testHistoryWithNoFinishedCallsMakesOneRead() async throws {
        let transport = ScriptedTransport(responses: probes() + [(200, Data("[]".utf8))])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        let history = try await spots.history(squadId: squad, limit: 5)
        XCTAssertTrue(history.isEmpty)
        XCTAssertEqual(transport.requests.count, 3)
    }

    func testCallingOnAServerWithoutTheRpcIsUnavailable() async throws {
        let missing = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function public.sq8_call_spot in the schema cache\"}".utf8)
        let transport = ScriptedTransport(responses: [(404, missing)])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        do {
            _ = try await spots.call(squadId: squad, game: "Apex", startsAt: Date())
            XCTFail("A missing call RPC should not succeed")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .unavailable)
            XCTAssertEqual(problem.message, "Spot calls aren't set up on this server yet.")
        }
    }
}

@MainActor
final class SpotThreadModelTests: XCTestCase {
    private func model(_ scenario: LaunchScenario) -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: scenario
        )
    }

    private let session = AuthSession(
        accessToken: "mock-access",
        refreshToken: "mock-refresh",
        userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        email: "spencer@squadsync.app"
    )

    func testSlashSpotsWithAGameCallsInsteadOfSending() async {
        let model = model(.spotHistory)
        let before = model.log.ordered.count
        model.draft = "/spots Halo"
        await model.send()
        XCTAssertEqual(model.spot?.game, "Halo")
        XCTAssertEqual(model.log.ordered.count, before, "The command was sent as a message")
        XCTAssertEqual(model.draft, "")
        let phase = model.spot.map { SpotThread.phase($0, viewerId: model.viewerId, now: Date()) }
        XCTAssertEqual(phase, .active)
    }

    func testBareSlashSpotsOpensTheSheetWithTheDefaultGame() async {
        let model = model(.spotHistory)
        model.spotGame = ""
        model.draft = "/spots"
        await model.send()
        XCTAssertTrue(model.spotSheetOpen)
        XCTAssertEqual(model.spotGame, model.defaultGame)
        XCTAssertNil(model.spot)
    }

    func testPlusMenuWithAnActiveCallSaysOneIsOpen() {
        let model = model(.spotCall)
        model.openSpotCall()
        XCTAssertFalse(model.spotSheetOpen)
        XCTAssertEqual(model.spotNote, SpotProblem.alreadyOpen.message)
    }

    func testSheetClosesOnSuccess() async {
        let model = model(.spotHistory)
        model.openSpotCall()
        XCTAssertTrue(model.spotSheetOpen)
        await model.callSpotsFromSheet()
        XCTAssertFalse(model.spotSheetOpen)
        XCTAssertEqual(model.spotSheet, .editing)
        XCTAssertNotNil(model.spot)
    }

    func testSheetStaysOpenAndSaysWhyWhenTheRpcIsMissing() async {
        let model = model(.spotServerMissing)
        model.openSpotCall()
        await model.callSpotsFromSheet()
        XCTAssertTrue(model.spotSheetOpen)
        XCTAssertEqual(model.spotSheet, .failed(SpotProblem.unavailable.message))
        XCTAssertNil(model.spot)
    }

    func testHistoryReadFailureSaysSoWithoutFailingTheCard() async {
        let model = model(.spotServerMissing)
        await model.loadSpot(session)
        XCTAssertEqual(model.spotHistoryNote, SpotThread.historyUnavailable)
        XCTAssertEqual(model.spotLoad, .loaded)
    }

    func testCancelledCallTurnsIntoHistoryThenMovesIntoTheThread() async {
        let model = model(.spotCallMine)
        let first = model.spot?.id
        await model.cancelSpot()
        let cancelled = model.spot.map { SpotThread.phase($0, viewerId: model.viewerId, now: Date()) }
        XCTAssertEqual(cancelled, .history(.cancelled))
        XCTAssertTrue(SpotThread.canCallNow(model.spot, now: Date()))
        model.spotGame = "Apex"
        let called = await model.callSpots()
        XCTAssertTrue(called)
        XCTAssertEqual(model.spot?.game, "Apex")
        XCTAssertTrue(model.spotHistory.contains { $0.id == first }, "The cancelled call did not move into the thread history")
        let thread = SpotThread.history(past: model.spotHistory, excluding: model.spot?.id, viewerId: model.viewerId, now: Date())
        XCTAssertEqual(thread.map(\.id), [first].compactMap { $0 })
    }

    func testHistoryCardWrapsTheWholeGameNameAtAccessibilitySizes() {
        let large = SpotHistoryCard.Layout(accessibilitySize: true)
        XCTAssertTrue(large.stacksTime, "At AX sizes the time should sit under the game, not beside it")
        XCTAssertNil(large.gameLineLimit, "At AX sizes the game name must wrap fully")
        let regular = SpotHistoryCard.Layout(accessibilitySize: false)
        XCTAssertFalse(regular.stacksTime)
        XCTAssertEqual(regular.gameLineLimit, 2)
    }
}
