import XCTest
@testable import SquadSync

/// Game on: seats, full, close, idle expiry, the cap of two, the form's
/// defaults, the copy, the chat lines, planned sessions turning into cards,
/// and both services (the mock and the live one against scripted HTTP).
/// Foundation only; runs in the Linux harness.
final class GameOnTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private let viewer = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let alex = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let jordan = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
    private let gone = UUID(uuidString: "00000000-0000-0000-0000-0000000000A9")!
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon")
    private let now = Date(timeIntervalSince1970: 1_795_000_000)
    private var members: Set<UUID> { [viewer, alex, jordan, sam] }
    private var names: [UUID: String] { [viewer: "Spencer", alex: "Alex", jordan: "Jordan", sam: "Sam"] }

    private func call(
        _ id: Int = 1,
        caller: UUID? = nil,
        need: Int = 1,
        seats: [GameOnSeat]? = nil,
        calledAgo: TimeInterval = 600,
        idleIn: TimeInterval = 3 * 3600 - 600,
        status: GameOnStatus = .open,
        closed: Date? = nil
    ) -> GameOn {
        let starter = caller ?? alex
        return GameOn(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            squadId: squad,
            callerId: starter,
            game: "Warzone",
            calledAt: now.addingTimeInterval(-calledAgo),
            idleUntil: now.addingTimeInterval(idleIn),
            seatTarget: need + 1,
            status: status,
            closedAt: closed,
            seats: seats ?? [seat(starter, starter: true, at: -calledAgo)]
        )
    }

    private func seat(_ user: UUID, isIn: Bool = true, starter: Bool = false, ready: Bool = false, at offset: TimeInterval = -60) -> GameOnSeat {
        GameOnSeat(userId: user, isIn: isIn, starter: starter, ready: ready, updatedAt: now.addingTimeInterval(offset))
    }

    // MARK: Rules

    func testNeedCountsOnlySeatsThatAreInAndStillInTheGroup() {
        let card = call(need: 3, seats: [
            seat(alex, starter: true, at: -600),
            seat(jordan, at: -300),
            seat(sam, isIn: false, at: -200),
            seat(gone, at: -100)
        ])
        XCTAssertEqual(GameOnRules.need(card, memberIds: members), 2, "Out seats and people who left the group don't fill seats")
        XCTAssertEqual(GameOnRules.players(card, memberIds: members).map(\.userId), [alex, jordan], "Starter first, then in join order")
        XCTAssertEqual(GameOnRules.need(card), 1, "Without a member list every in seat counts")
    }

    func testFullWhenTheSeatsAreTakenAndJoiningIsOffForOthers() {
        let card = call(need: 1, seats: [seat(alex, starter: true), seat(jordan)])
        XCTAssertTrue(GameOnRules.isFull(card, memberIds: members))
        XCTAssertEqual(GameOnRules.viewerState(card, viewerId: viewer, memberIds: members), .full)
        XCTAssertEqual(GameOnRules.viewerState(card, viewerId: jordan, memberIds: members), .joined(ready: false, starter: false))
        XCTAssertEqual(GameOnRules.viewerState(card, viewerId: alex, memberIds: members), .joined(ready: false, starter: true))
    }

    func testJoiningStaysOpenLongAfterFiveMinutes() {
        let card = call(need: 2, calledAgo: 2 * 3600, idleIn: 3600)
        XCTAssertTrue(GameOnRules.isLive(card, now: now, memberIds: members))
        XCTAssertEqual(GameOnRules.viewerState(card, viewerId: viewer, memberIds: members), .canJoin)
    }

    func testIdleClosedAndEmptyCardsAreNotLive() {
        XCTAssertFalse(GameOnRules.isLive(call(idleIn: -1), now: now), "Past the idle deadline")
        XCTAssertFalse(GameOnRules.isLive(call(idleIn: 0), now: now), "At the deadline exactly, like the server's now() >= join_until")
        XCTAssertFalse(GameOnRules.isLive(call(status: .ended, closed: now), now: now))
        XCTAssertFalse(GameOnRules.isLive(call(status: .expired), now: now), "An expired status never shows as open")
        XCTAssertFalse(GameOnRules.isLive(call(seats: [seat(alex, isIn: false, starter: true)]), now: now), "Everyone left")
        XCTAssertFalse(GameOnRules.isLive(call(seats: [seat(gone, starter: true)]), now: now, memberIds: members), "Only someone who left the group is in")
        XCTAssertTrue(GameOnRules.isLive(call(), now: now))
    }

    func testLiveShowsAtMostTwoOldestFirst() {
        let cards = [call(3, calledAgo: 60), call(1, calledAgo: 900), call(2, calledAgo: 300), call(4, idleIn: -5)]
        let live = GameOnRules.live(cards, now: now)
        XCTAssertEqual(live.map(\.id), [cards[1].id, cards[2].id])
        XCTAssertFalse(GameOnRules.canStart(live: live))
        XCTAssertTrue(GameOnRules.canStart(live: Array(live.prefix(1))))
        XCTAssertTrue(GameOnRules.canStart(live: []))
    }

    func testOnlyTheStarterCanClose() {
        let card = call(caller: alex)
        XCTAssertTrue(GameOnRules.canClose(card, viewerId: alex))
        XCTAssertFalse(GameOnRules.canClose(card, viewerId: viewer), "Owners don't get a special close")
        XCTAssertFalse(GameOnRules.canClose(card, viewerId: nil))
    }

    func testActivityPushesTheIdleDeadlineOut() {
        let card = GameOnRules.bumped(call(idleIn: 60), now: now)
        XCTAssertEqual(card.idleUntil, now.addingTimeInterval(3 * 3600))
    }

    // MARK: Form

    func testFormStartsOnYourDefaultGameWithYourGamesListed() {
        let draft = GameOnDraft.initial(defaultGame: " Warzone ", games: ["Apex", "warzone", "", "Halo"])
        XCTAssertEqual(draft.game, "Warzone")
        XCTAssertEqual(draft.games, ["Warzone", "Apex", "Halo"], "Default first, blanks and repeats dropped")
        XCTAssertEqual(draft.need, 1)
        XCTAssertTrue(draft.canSubmit)
    }

    func testFormRefusesBlankLongAndOutOfRange() {
        var draft = GameOnDraft.initial(defaultGame: "", games: [])
        XCTAssertEqual(draft.validationError, GameOnProblem.gameBlank.message)
        draft.game = String(repeating: "x", count: 61)
        XCTAssertEqual(draft.validationError, GameOnProblem.gameLong.message)
        draft.game = "Apex"
        draft.need = 0
        XCTAssertEqual(draft.validationError, GameOnProblem.needRange.message)
        draft.need = 8
        XCTAssertEqual(draft.validationError, GameOnProblem.needRange.message)
        draft.need = 7
        XCTAssertNil(draft.validationError)
    }

    // MARK: Errors

    func testServerCodesMapToPlainReasons() {
        let cases: [(String, GameOnProblem)] = [
            ("game_on_cap", .cap), ("game_on_full", .full), ("game_on_closed", .closed),
            ("game_on_missing", .closed), ("game_on_not_starter", .notStarter), ("game_on_not_in", .notIn),
            ("game_on_game_blank", .gameBlank), ("game_on_game_long", .gameLong),
            ("game_on_need_range", .needRange), ("game_on_not_member", .notMember),
            ("column sq8_spot_calls.kind does not exist", .notSetUp), ("boom", .failed)
        ]
        for (text, expected) in cases {
            XCTAssertEqual(GameOnProblem.from(BackendFailure.rejected(text)), expected, text)
        }
        XCTAssertEqual(GameOnProblem.from(BackendFailure.notSetUp(.gameOn)), .notSetUp)
        XCTAssertEqual(GameOnProblem.from(BackendFailure.reconnecting), .offline)
        XCTAssertEqual(GameOnProblem.cap.message, "Two games are already on. Join one, or wait for one to end.")
    }

    // MARK: Copy

    func testTitleLineAndNeedReadNaturally() {
        let card = call(caller: alex, need: 1)
        XCTAssertEqual(GameOnCopy.title(card, names: names, viewerId: viewer), "Alex's on Warzone")
        XCTAssertEqual(GameOnCopy.line(card, names: names, viewerId: viewer), "Alex's on Warzone, need 1", "Same words as the push")
        let mine = call(caller: viewer, need: 2)
        XCTAssertEqual(GameOnCopy.title(mine, names: names, viewerId: viewer), "You're on Warzone")
        XCTAssertEqual(GameOnCopy.line(mine, names: names, viewerId: viewer), "You're on Warzone, need 2")
        XCTAssertEqual(GameOnCopy.needLabel(2), "Need 2")
        XCTAssertEqual(GameOnCopy.needLabel(0), "Full")
        XCTAssertEqual(GameOnCopy.title(call(caller: gone), names: names, viewerId: viewer), "Someone's on Warzone")
    }

    func testSpokenCardSaysWhoAndHowManyMore() {
        let card = call(need: 2, seats: [seat(alex, starter: true, ready: true), seat(viewer)])
        XCTAssertEqual(
            GameOnCopy.spoken(card, names: names, viewerId: viewer, memberIds: members),
            "Alex's on Warzone. Needs 1 more. In: Alex and You. 1 ready"
        )
        let full = call(need: 1, seats: [seat(alex, starter: true), seat(jordan)])
        XCTAssertTrue(GameOnCopy.spoken(full, names: names, viewerId: viewer).contains("Full"))
    }

    // MARK: Chat lines

    func testLinesSitWhereEachGameOnStarted() {
        let first = ChatEntry(id: UUID(), senderId: alex, body: "hey", sentAt: now.addingTimeInterval(-900), delivery: .sent)
        let second = ChatEntry(id: UUID(), senderId: jordan, body: "sup", sentAt: now.addingTimeInterval(-60), delivery: .sent)
        let card = call(calledAgo: 300)
        let old = call(2, calledAgo: 5000)
        let items = GameOnThread.items([.message(first), .message(second)], calls: [card, old], earliest: first.sentAt)
        XCTAssertEqual(items.map(\.id), ["message-\(first.id.uuidString)", "gameon-\(card.id.uuidString)", "message-\(second.id.uuidString)"],
                       "A line older than the loaded history waits for older pages")
        let rows = ChatThread.rows(items: items, context: ChatThread.Context(
            viewerId: viewer, names: names, reads: [], unreadAnchor: nil, clock: ChatClock(calendar: Calendar(identifier: .gregorian), locale: Locale(identifier: "en_US")), now: now
        ))
        XCTAssertTrue(rows.contains { $0.identity == "gameon-\(card.id.uuidString)" })
    }

    // MARK: Planned sessions

    func testPlannedSessionShowsAsACardFromItsStartForAnHour() {
        func session(_ id: Int, starts: TimeInterval, cancelled: Bool = false, minutes: Int? = nil) -> PlaySession {
            PlaySession(
                id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
                squadId: squad, creatorId: alex, game: "Apex", startsAt: now.addingTimeInterval(starts),
                durationMinutes: minutes, note: nil, cancelledAt: cancelled ? now : nil,
                createdAt: now.addingTimeInterval(-86_400), rsvps: []
            )
        }
        let sessions = [
            session(1, starts: -60),
            session(2, starts: 60),
            session(3, starts: -3601),
            session(4, starts: -30, cancelled: true),
            session(5, starts: -1200, minutes: 15)
        ]
        XCTAssertEqual(PlannedGameOn.starting(sessions, now: now).map(\.id), [sessions[0].id])
        XCTAssertEqual(PlannedGameOn.title(sessions[0], names: names, viewerId: viewer), "Alex's Apex session is starting")
    }

    // MARK: Prompts

    func testPromptsShowWhenTheyHelpAndNotAfter() {
        XCTAssertTrue(HomePrompts.showsInvite(memberCount: 1, dismissed: false))
        XCTAssertTrue(HomePrompts.showsInvite(memberCount: 3, dismissed: false))
        XCTAssertFalse(HomePrompts.showsInvite(memberCount: 4, dismissed: false))
        XCTAssertFalse(HomePrompts.showsInvite(memberCount: 2, dismissed: true))
        XCTAssertTrue(HomePrompts.showsWelcome(justJoined: true, liveCount: 0))
        XCTAssertFalse(HomePrompts.showsWelcome(justJoined: true, liveCount: 1), "A card's already there to join")
        XCTAssertFalse(HomePrompts.showsWelcome(justJoined: false, liveCount: 0))
        XCTAssertTrue(HomePrompts.showsPhoto(hasPhoto: false, dismissed: false, storageReady: true))
        XCTAssertFalse(HomePrompts.showsPhoto(hasPhoto: false, dismissed: false, storageReady: false), "No bucket, no prompt")
        XCTAssertFalse(HomePrompts.showsPhoto(hasPhoto: true, dismissed: false, storageReady: true))
    }

    // MARK: Mock service

    private func mock(_ viewerId: UUID? = nil, calls: [GameOn] = [], clock: Date? = nil) -> MockGameOnService {
        let at = clock ?? now
        return MockGameOnService(viewerId: viewerId ?? viewer, memberIds: members, calls: calls, now: { at })
    }

    func testMockStartPutsYouInTheFirstSeat() async throws {
        let service = mock()
        let id = try await service.start(squadId: squad, game: " Halo ", need: 2)
        let read = try await service.recent(squadId: squad, since: now.addingTimeInterval(-60))
        XCTAssertEqual(read.first?.id, id)
        XCTAssertEqual(read.first?.game, "Halo")
        XCTAssertEqual(read.first?.seatTarget, 3)
        XCTAssertEqual(read.first?.idleUntil, now.addingTimeInterval(3 * 3600))
        XCTAssertEqual(read.first.map { GameOnRules.players($0).map(\.userId) }, [viewer])
    }

    func testMockCapsAtTwoOpen() async throws {
        let service = mock(calls: [call(1), call(2, caller: jordan)])
        do {
            _ = try await service.start(squadId: squad, game: "Apex", need: 1)
            XCTFail("A third Game on started")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .cap)
        }
    }

    func testMockIdleOnesDontCountTowardTheCapAndExpire() async throws {
        let service = mock(calls: [call(1, idleIn: -10), call(2, caller: jordan)])
        _ = try await service.start(squadId: squad, game: "Apex", need: 1)
        let read = try await service.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first { $0.id == call(1).id }?.status, .expired)
    }

    func testMockJoinUntilFullThenRefuses() async throws {
        let card = call(need: 1)
        let me = mock(calls: [card])
        try await me.join(callId: card.id)
        try await me.join(callId: card.id)
        let read = try await me.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first.map { GameOnRules.players($0).count }, 2, "Joining twice is one seat")
        XCTAssertEqual(read.first?.idleUntil, now.addingTimeInterval(3 * 3600), "Joining bumps the idle deadline")
        let sam = MockGameOnService(viewerId: self.sam, memberIds: members, calls: read, now: { self.now })
        do {
            try await sam.join(callId: card.id)
            XCTFail("Joined a full Game on")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .full)
        }
    }

    func testMockLeavingOpensTheSeatAndTheLastOneOutEndsIt() async throws {
        let card = call(caller: alex, need: 1, seats: [seat(alex, starter: true), seat(viewer)])
        let me = mock(calls: [card])
        try await me.leave(callId: card.id)
        var read = try await me.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first.map { GameOnRules.need($0) }, 1)
        XCTAssertNil(read.first?.closedAt)
        let starter = MockGameOnService(viewerId: alex, memberIds: members, calls: read, now: { self.now })
        try await starter.leave(callId: card.id)
        read = try await starter.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first?.status, .ended)
        XCTAssertNotNil(read.first?.closedAt)
    }

    func testMockCloseIsStarterOnlyAndIdempotent() async throws {
        let card = call(caller: alex)
        let me = mock(calls: [card])
        do {
            try await me.close(callId: card.id)
            XCTFail("Someone else closed it")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .notStarter)
        }
        let starter = mock(alex, calls: [card])
        try await starter.close(callId: card.id)
        try await starter.close(callId: card.id)
        let read = try await starter.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first?.status, .ended)
        do {
            try await starter.join(callId: card.id)
            XCTFail("Joined a closed one")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .closed)
        }
    }

    func testMockReadyNeedsASeat() async throws {
        let card = call()
        let me = mock(calls: [card])
        do {
            try await me.setReady(callId: card.id, ready: true)
            XCTFail("Ready without a seat")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .notIn)
        }
        try await me.join(callId: card.id)
        try await me.setReady(callId: card.id, ready: true)
        let read = try await me.recent(squadId: squad, since: .distantPast)
        XCTAssertEqual(read.first.map { GameOnRules.viewerState($0, viewerId: viewer) }, .joined(ready: true, starter: false))
    }

    func testMockWithoutTheServerSaysSoOnReadAndWrite() async {
        let service = MockGameOnService(viewerId: viewer, memberIds: members, serverMissing: true)
        do {
            _ = try await service.recent(squadId: squad, since: now)
            XCTFail("Read worked without 0028")
        } catch {
            XCTAssertEqual(GameOnProblem.from(error), .notSetUp)
        }
        do {
            _ = try await service.start(squadId: squad, game: "Apex", need: 1)
            XCTFail("Start worked without 0028")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .notSetUp)
        }
    }

    // MARK: Live service

    private func query(_ request: URLRequest?) -> [String: String] {
        guard let url = request?.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    func testLiveReadAsksForGameOnRowsWithSeats() async throws {
        let body = """
        [{"id":"00000000-0000-0000-0000-000000000001","squad_id":"00000000-0000-0000-0000-0000000000aa",
          "caller_id":"00000000-0000-0000-0000-0000000000a1","game":"Warzone","called_at":"2026-11-26T15:00:00Z",
          "join_until":"2026-11-26T18:00:00Z","seat_target":2,"status":"open","closed_at":null,
          "sq8_spot_rsvps":[{"user_id":"00000000-0000-0000-0000-0000000000a1","response":"in","starter":true,"ready":false,"updated_at":"2026-11-26T15:00:00Z"},
                            {"user_id":"00000000-0000-0000-0000-000000000001","response":"out","starter":false,"ready":false,"updated_at":null}]},
         {"id":"00000000-0000-0000-0000-000000000002","squad_id":"00000000-0000-0000-0000-0000000000aa",
          "caller_id":"00000000-0000-0000-0000-0000000000a1","game":"Apex","called_at":"2026-11-26T14:00:00Z",
          "join_until":"2026-11-26T17:00:00Z","seat_target":3,"status":"brand_new","closed_at":null,"sq8_spot_rsvps":[]}]
        """
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabaseGameOnService(config: config, accessToken: "token", transport: transport)
        let read = try await service.recent(squadId: squad, since: now)
        XCTAssertEqual(read.count, 2)
        XCTAssertEqual(read[0].seatTarget, 2)
        XCTAssertEqual(read[0].seats.filter(\.isIn).map(\.userId), [alex])
        XCTAssertEqual(read[1].status, .ended, "A status the app doesn't know never shows as open")
        let request = transport.requests.first
        XCTAssertEqual(request?.url?.path, "/rest/v1/sq8_spot_calls")
        let items = query(request)
        XCTAssertEqual(items["kind"], "eq.game_on")
        XCTAssertEqual(items["squad_id"], "eq.\(squad.uuidString)")
        XCTAssertEqual(items["select"], SupabaseGameOnService.select)
        XCTAssertEqual(items["order"], "called_at.desc,id.desc")
    }

    func testLiveReadWithoutTheKindColumnIsNotSetUp() async {
        let missing = Data("{\"code\":\"42703\",\"message\":\"column sq8_spot_calls.kind does not exist\"}".utf8)
        let transport = ScriptedTransport(responses: [(400, missing)])
        let service = SupabaseGameOnService(config: config, accessToken: "token", transport: transport)
        do {
            _ = try await service.recent(squadId: squad, since: now)
            XCTFail("Read worked without 0028")
        } catch {
            XCTAssertEqual(error as? BackendFailure, .notSetUp(.gameOn))
        }
    }

    func testLiveWritesCallTheRpcsWithTheirArguments() async throws {
        let id = "00000000-0000-0000-0000-000000000077"
        let transport = ScriptedTransport(responses: [(200, Data("\"\(id)\"".utf8)), (204, Data()), (204, Data()), (204, Data()), (204, Data())])
        let service = SupabaseGameOnService(config: config, accessToken: "token", transport: transport)
        let started = try await service.start(squadId: squad, game: "Warzone", need: 1)
        XCTAssertEqual(started.uuidString.lowercased(), id)
        let callId = UUID(uuidString: id)!
        try await service.join(callId: callId)
        try await service.setReady(callId: callId, ready: true)
        try await service.leave(callId: callId)
        try await service.close(callId: callId)
        let paths = transport.requests.map { $0.url?.path ?? "" }
        XCTAssertEqual(paths, [
            "/rest/v1/rpc/sq8_start_game_on", "/rest/v1/rpc/sq8_join_game_on", "/rest/v1/rpc/sq8_set_game_on_ready",
            "/rest/v1/rpc/sq8_leave_game_on", "/rest/v1/rpc/sq8_close_game_on"
        ])
        let start = try JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(start?["game"] as? String, "Warzone")
        XCTAssertEqual(start?["need"] as? Int, 1)
        XCTAssertEqual((start?["squad"] as? String)?.lowercased(), squad.uuidString.lowercased())
        let ready = try JSONSerialization.jsonObject(with: transport.requests[2].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(ready?["ready"] as? Bool, true)
        XCTAssertEqual((ready?["call_id"] as? String)?.lowercased(), id)
    }

    func testLiveRefusalsKeepTheirReason() async {
        let full = Data("{\"code\":\"P0001\",\"message\":\"game_on_full\"}".utf8)
        let missing = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function public.sq8_join_game_on(call_id) in the schema cache\"}".utf8)
        let transport = ScriptedTransport(responses: [(400, full), (404, missing)])
        let service = SupabaseGameOnService(config: config, accessToken: "token", transport: transport)
        let callId = UUID()
        do {
            try await service.join(callId: callId)
            XCTFail("Joined a full one")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .full)
        }
        do {
            try await service.join(callId: callId)
            XCTFail("Joined without the RPC")
        } catch {
            XCTAssertEqual(error as? GameOnProblem, .notSetUp)
        }
    }
}
