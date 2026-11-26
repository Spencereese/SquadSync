import XCTest
@testable import SquadSync

/// The side-thread list and the new-thread form: rows, previews, the draft, and
/// the requests the live service sends. Foundation only, so it runs on Linux too.
final class SideThreadListTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private let otherSquad = UUID(uuidString: "00000000-0000-0000-0000-000000000020")!
    private let me = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let riley = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    private let jordan = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!
    private let ranked = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    private let dmRiley = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!
    private let quiet = UUID(uuidString: "00000000-0000-0000-0000-00000000B003")!
    private let foreign = UUID(uuidString: "00000000-0000-0000-0000-00000000B004")!

    private var names: [UUID: String] { [me: "Spencer", riley: "Riley", sam: "Sam", jordan: "Jordan"] }

    private func info(_ id: UUID, kind: String = "side_group", title: String? = "Ranked", squad: UUID? = nil, made: TimeInterval? = nil) -> SideThreadInfo {
        SideThreadInfo(id: id, squadId: squad ?? self.squad, kind: kind, title: title, createdAt: made.map { Date(timeIntervalSince1970: $0) })
    }

    private func message(_ thread: UUID, from sender: UUID, _ body: String, at seconds: TimeInterval) -> SideThreadMessage {
        SideThreadMessage(id: UUID(), threadId: thread, squadId: squad, senderId: sender, body: body, sentAt: Date(timeIntervalSince1970: seconds))
    }

    func testRowsAreNewestActivityFirstAndOnlyThisSquad() {
        let threads = [
            info(ranked, made: 100),
            info(dmRiley, kind: "dm", title: nil, made: 200),
            info(quiet, title: "Quiet", made: 300),
            info(foreign, squad: otherSquad, made: 999)
        ]
        let memberships = [
            SideThreadMembership(threadId: ranked, userId: me), SideThreadMembership(threadId: ranked, userId: riley),
            SideThreadMembership(threadId: ranked, userId: riley),
            SideThreadMembership(threadId: dmRiley, userId: me), SideThreadMembership(threadId: dmRiley, userId: riley)
        ]
        let last = [
            ranked: message(ranked, from: riley, "on in 5", at: 1000),
            dmRiley: message(dmRiley, from: me, "ok", at: 500)
        ]
        let rows = SideThreadList.rows(threads: threads, memberships: memberships, last: last, squadId: squad)
        XCTAssertEqual(rows.map(\.id), [ranked, dmRiley, quiet], "Reply time first, then a quiet thread by when it was made; other squads dropped")
        XCTAssertEqual(rows[0].memberIds, [me, riley], "A repeated membership row counts once")
        XCTAssertEqual(rows[2].memberIds, [])
        XCTAssertNil(rows[2].last)
    }

    func testAThreadWithNoDateSortsLastAndTiesAreStable() {
        let a = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
        let b = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
        let rows = SideThreadList.rows(
            threads: [info(b, made: nil), info(a, made: nil), info(ranked, made: 5)],
            memberships: [],
            last: [:],
            squadId: squad
        )
        XCTAssertEqual(rows.map(\.id), [ranked, a, b])
        XCTAssertEqual(SideThreadList.rows(threads: [], memberships: [], last: [:], squadId: squad), [])
    }

    func testTheExistingDMBetweenTwoPeopleIsFoundNotTheGroup() {
        let rows = SideThreadList.rows(
            threads: [info(ranked), info(dmRiley, kind: "dm", title: nil)],
            memberships: [
                SideThreadMembership(threadId: ranked, userId: me), SideThreadMembership(threadId: ranked, userId: riley),
                SideThreadMembership(threadId: dmRiley, userId: riley), SideThreadMembership(threadId: dmRiley, userId: me)
            ],
            last: [:],
            squadId: squad
        )
        XCTAssertEqual(SideThreadList.directThread(in: rows, between: me, and: riley)?.id, dmRiley)
        XCTAssertNil(SideThreadList.directThread(in: rows, between: me, and: sam))
    }

    func testPreviewSaysWhoSpokeAndFoldsWhitespace() {
        let group = SideThreadRow(info: info(ranked), memberIds: [me, riley], last: message(ranked, from: riley, "  on in 5,\n bring the\tmic ", at: 10))
        XCTAssertEqual(SideThreadCopy.preview(group, viewerId: me, names: names), "Riley: on in 5, bring the mic")
        let mine = SideThreadRow(info: info(ranked), memberIds: [me, riley], last: message(ranked, from: me, "omw", at: 10))
        XCTAssertEqual(SideThreadCopy.preview(mine, viewerId: me, names: names), "You: omw")
        let dm = SideThreadRow(info: info(dmRiley, kind: "dm", title: nil), memberIds: [me, riley], last: message(dmRiley, from: riley, "u on?", at: 10))
        XCTAssertEqual(SideThreadCopy.preview(dm, viewerId: me, names: names), "u on?", "A DM's title is already their name")
        let stranger = SideThreadRow(info: info(ranked), memberIds: [me], last: message(ranked, from: jordan, "hi", at: 10))
        XCTAssertEqual(SideThreadCopy.preview(stranger, viewerId: me, names: [:]), "Player: hi")
        let none = SideThreadRow(info: info(ranked), memberIds: [me], last: nil)
        XCTAssertEqual(SideThreadCopy.preview(none, viewerId: me, names: names), "No messages yet")
    }

    func testTheTimeIsClockTodayWeekdayThisWeekAndDateAfter() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let locale = Locale(identifier: "en_US_POSIX")
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 26, hour: 15, minute: 0))!
        func at(_ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
        }
        // Newer ICU writes a narrow no-break space before "AM"; it's still the same time text.
        let clock = SideThreadCopy.when(at(26, 9, 2), now: now, calendar: calendar, locale: locale)
            .replacingOccurrences(of: "\u{202F}", with: " ")
        XCTAssertEqual(clock, "9:02 AM")
        XCTAssertEqual(SideThreadCopy.when(at(24, 23), now: now, calendar: calendar, locale: locale), "Tue")
        XCTAssertEqual(SideThreadCopy.when(at(25, 1), now: now, calendar: calendar, locale: locale), "Wed", "Yesterday is a weekday name")
        XCTAssertEqual(SideThreadCopy.when(at(14, 8), now: now, calendar: calendar, locale: locale), "Nov 14")
    }

    func testTheSpokenRowReadsTitlePreviewAndTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let row = SideThreadRow(info: info(ranked), memberIds: [me, riley], last: message(ranked, from: riley, "on in 5", at: 1_700_000_000 - 60))
        let spoken = SideThreadCopy.spoken(row, title: "Ranked", viewerId: me, names: names, now: now)
        XCTAssertTrue(spoken.hasPrefix("Side group Ranked. Riley: on in 5. "), spoken)
        let dm = SideThreadRow(info: info(dmRiley, kind: "dm", title: nil), memberIds: [me, riley], last: nil)
        XCTAssertEqual(SideThreadCopy.spoken(dm, title: "Riley", viewerId: me, names: names, now: now), "Direct message with Riley. No messages yet")
    }

    func testOnePersonMakesADMAndTwoMakeAGroup() {
        var draft = SideThreadDraft()
        XCTAssertFalse(draft.canCreate, "Nobody picked")
        draft.toggle(riley)
        XCTAssertTrue(draft.isDirect)
        XCTAssertFalse(draft.isGroup)
        XCTAssertTrue(draft.canCreate)
        let dm = draft.newThread(squadId: squad, creator: me, names: names)
        XCTAssertEqual(dm?.kind, "dm")
        XCTAssertNil(dm?.title, "A DM has no title, even if one was typed")
        XCTAssertEqual(dm?.memberIds, [riley])
        draft.title = "ignored"
        XCTAssertNil(draft.newThread(squadId: squad, creator: me, names: names)?.title)
        draft.toggle(sam)
        XCTAssertTrue(draft.isGroup)
        let group = draft.newThread(squadId: squad, creator: me, names: names)
        XCTAssertEqual(group?.kind, "side_group")
        XCTAssertEqual(group?.title, "ignored")
        XCTAssertEqual(group?.memberIds, [riley, sam], "Picked order")
        draft.toggle(riley)
        XCTAssertTrue(draft.isDirect, "Unpicking goes back to a DM")
        draft.toggle(sam)
        XCTAssertFalse(draft.canCreate)
    }

    func testAGroupWithoutANameIsCalledByItsMembers() {
        var draft = SideThreadDraft()
        draft.toggle(sam)
        draft.toggle(riley)
        draft.title = "   "
        XCTAssertEqual(draft.resolvedTitle(names: names), "Sam, Riley")
        XCTAssertEqual(draft.resolvedTitle(names: [:]), "Player, Player")
        draft.title = "  Ranked tonight "
        XCTAssertEqual(draft.resolvedTitle(names: names), "Ranked tonight")
        draft.title = ""
        let long = ["Alexandria", "Bartholomew", "Cornelius", "Dominique"].map { n -> (UUID, String) in (UUID(), n) }
        var big = SideThreadDraft()
        for (id, _) in long { big.toggle(id) }
        let title = big.resolvedTitle(names: Dictionary(uniqueKeysWithValues: long))!
        XCTAssertEqual(title.count, SideThreadDraft.titleLimit)
        XCTAssertTrue(title.hasSuffix("…"))
    }

    func testATooLongGroupNameBlocksCreateButADMDoesNot() {
        var draft = SideThreadDraft()
        draft.toggle(riley)
        draft.title = String(repeating: "x", count: SideThreadDraft.titleLimit + 1)
        XCTAssertTrue(draft.canCreate, "A DM ignores the name")
        draft.toggle(sam)
        XCTAssertTrue(draft.titleTooLong)
        XCTAssertFalse(draft.canCreate)
        draft.title = String(repeating: "x", count: SideThreadDraft.titleLimit)
        XCTAssertTrue(draft.canCreate)
        draft.creating = true
        XCTAssertFalse(draft.canCreate, "Not twice at once")
    }

    func testTheDraftKeepsItsThreadIdForARetry() {
        let id = UUID()
        var draft = SideThreadDraft(threadId: id)
        draft.toggle(riley)
        draft.error = SideThreadCopy.createFailed
        draft.toggle(sam)
        XCTAssertEqual(draft.error, "", "Changing who's in clears the old error")
        XCTAssertEqual(draft.newThread(squadId: squad, creator: me, names: names)?.id, id)
    }

    func testYouAreNeverPutInTwice() {
        var draft = SideThreadDraft()
        draft.toggle(me)
        draft.toggle(riley)
        XCTAssertEqual(draft.newThread(squadId: squad, creator: me, names: names)?.memberIds, [riley])
    }

    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")

    private func query(_ request: URLRequest) -> [URLQueryItem] {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    func testTheServiceListsThreadsForTheSquadNewestFirst() async throws {
        let body = "[{\"id\":\"\(ranked.uuidString.lowercased())\",\"squad_id\":\"\(squad.uuidString.lowercased())\",\"kind\":\"side_group\",\"title\":\"Ranked\",\"created_at\":\"2026-11-26T09:00:00.5+00:00\"},{\"id\":\"\(dmRiley.uuidString.lowercased())\",\"squad_id\":\"\(squad.uuidString.lowercased())\",\"kind\":\"dm\",\"title\":null,\"created_at\":\"2026-11-25T09:00:00+00:00\"}]"
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let threads = try await service.threads(squadId: squad)
        XCTAssertEqual(threads.map(\.id), [ranked, dmRiley])
        XCTAssertEqual(threads[1].isDirect, true)
        XCTAssertNotNil(threads[0].createdAt)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/rest/v1/sq8_threads")
        XCTAssertTrue(query(request).contains(URLQueryItem(name: "squad_id", value: "eq.\(squad.uuidString)")))
        XCTAssertTrue(query(request).contains(URLQueryItem(name: "order", value: "created_at.desc")))
    }

    func testTheServiceReadsMembershipsForTheseThreadsOnly() async throws {
        let body = "[{\"thread_id\":\"\(ranked.uuidString.lowercased())\",\"user_id\":\"\(me.uuidString.lowercased())\"}]"
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let none = try await service.memberships(threadIds: [])
        XCTAssertEqual(none, [])
        XCTAssertTrue(transport.requests.isEmpty, "No threads, no request")
        let rows = try await service.memberships(threadIds: [ranked, dmRiley])
        XCTAssertEqual(rows, [SideThreadMembership(threadId: ranked, userId: me)])
        let filter = query(try XCTUnwrap(transport.requests.first)).first { $0.name == "thread_id" }?.value
        XCTAssertEqual(filter, "in.(\(ranked.uuidString.lowercased()),\(dmRiley.uuidString.lowercased()))")
    }

    func testTheServiceTakesTheNewestMessagePerThread() async throws {
        func row(_ thread: UUID, _ body: String, _ at: String) -> String {
            "{\"id\":\"\(UUID().uuidString.lowercased())\",\"thread_id\":\"\(thread.uuidString.lowercased())\",\"squad_id\":\"\(squad.uuidString.lowercased())\",\"sender_id\":\"\(riley.uuidString.lowercased())\",\"body\":\"\(body)\",\"sent_at\":\"\(at)\"}"
        }
        let batch = "[\(row(ranked, "newest", "2026-11-26T09:02:00+00:00")),\(row(dmRiley, "dm", "2026-11-26T09:01:00+00:00")),\(row(ranked, "older", "2026-11-26T09:00:00+00:00"))]"
        let transport = ScriptedTransport(responses: [(200, Data(batch.utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let last = try await service.lastMessages(threadIds: [ranked, dmRiley, quiet])
        XCTAssertEqual(last[ranked]?.body, "newest")
        XCTAssertEqual(last[dmRiley]?.body, "dm")
        XCTAssertNil(last[quiet], "A short batch means nothing was crowded out, so no extra reads")
        XCTAssertEqual(transport.requests.count, 1)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.url?.path, "/rest/v1/sq8_thread_messages")
        XCTAssertTrue(query(request).contains(URLQueryItem(name: "order", value: "sent_at.desc,id.desc")))
    }

    func testCreateMakesTheThreadThenSeatsEveryoneInOneStatement() async throws {
        let transport = ScriptedTransport(responses: [(201, Data()), (201, Data())])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let id = UUID(uuidString: "00000000-0000-0000-0000-00000000B0AA")!
        try await service.create(NewSideThread(id: id, squadId: squad, createdBy: me, memberIds: [riley, sam], title: "Ranked"))
        XCTAssertEqual(transport.requests.map { $0.url?.path ?? "" }, ["/rest/v1/sq8_threads", "/rest/v1/sq8_thread_members"])
        XCTAssertEqual(transport.requests.map(\.httpMethod), ["POST", "POST"])
        for request in transport.requests {
            XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=minimal,resolution=ignore-duplicates", "No read-back (the creator can't read it yet), and a repeat is harmless")
        }
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(thread["kind"] as? String, "side_group")
        XCTAssertEqual(thread["title"] as? String, "Ranked")
        XCTAssertEqual((thread["created_by"] as? String)?.lowercased(), me.uuidString.lowercased())
        XCTAssertEqual((thread["squad_id"] as? String)?.lowercased(), squad.uuidString.lowercased())
        XCTAssertEqual((thread["id"] as? String)?.lowercased(), id.uuidString.lowercased())
        let seats = try XCTUnwrap(JSONSerialization.jsonObject(with: transport.requests[1].httpBody ?? Data()) as? [[String: Any]])
        XCTAssertEqual(seats.compactMap { ($0["user_id"] as? String)?.lowercased() }, [me, riley, sam].map { $0.uuidString.lowercased() }, "You first, then the others")
        XCTAssertTrue(seats.allSatisfy { ($0["added_by"] as? String)?.lowercased() == me.uuidString.lowercased() })
        XCTAssertTrue(seats.allSatisfy { ($0["thread_id"] as? String)?.lowercased() == id.uuidString.lowercased() })
    }

    func testACreatedDMHasNoTitleKey() async throws {
        let transport = ScriptedTransport(responses: [(201, Data()), (201, Data())])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        try await service.create(NewSideThread(id: UUID(), squadId: squad, createdBy: me, memberIds: [riley], title: "should not be sent"))
        let thread = try XCTUnwrap(JSONSerialization.jsonObject(with: transport.requests[0].httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(thread["kind"] as? String, "dm")
        XCTAssertNil(thread["title"], "0017 requires a title only for a side group")
        let seats = try XCTUnwrap(JSONSerialization.jsonObject(with: transport.requests[1].httpBody ?? Data()) as? [[String: Any]])
        XCTAssertEqual(seats.count, 2)
    }

    func testARefusedThreadInsertStopsBeforeSeatingAnyone() async {
        let transport = ScriptedTransport(responses: [(403, Data("{\"code\":\"42501\",\"message\":\"new row violates row-level security policy\"}".utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        do {
            try await service.create(NewSideThread(id: UUID(), squadId: squad, createdBy: me, memberIds: [riley], title: nil))
            XCTFail("A refused insert should throw")
        } catch {
        }
        XCTAssertEqual(transport.requests.count, 1)
    }
}

/// The session model with the list and the form (@MainActor, so Mac only).
@MainActor
final class SideThreadListModelTests: XCTestCase {
    private let squad = ChatSeed.squadId
    private let riley = ChatSeed.otherId
    private let ranked = MockSideThreadService.threadId

    private func model() -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .invite
        )
    }

    private func reset() {
        PushCoordinator.shared.resetForTests()
    }

    func testTheListLoadsTheSeededThreadWithItsLastReply() async {
        reset()
        defer { reset() }
        let model = model()
        model.openSideThreadList()
        XCTAssertTrue(model.sideThreadsOpen)
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadList.load, .ready)
        let row = model.sideThreadList.rows.first
        XCTAssertEqual(row?.id, ranked)
        XCTAssertEqual(row?.last?.body, "On in 5, bring the mic")
        XCTAssertEqual(row?.memberIds.count, 2)
        model.closeSideThreadList()
        XCTAssertFalse(model.sideThreadsOpen)
    }

    func testAnEmptyServerIsEmptyNotFailed() async {
        reset()
        defer { reset() }
        let model = model()
        model.mockSideThreadServer?.removeAll()
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadList.load, .ready)
        XCTAssertTrue(model.sideThreadList.isEmpty)
    }

    func testADownServerIsAFailureThatRetryClears() async {
        reset()
        defer { reset() }
        let model = model()
        model.mockSideThreadServer?.failsReads = true
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadList.load, .failed)
        model.mockSideThreadServer?.failsReads = false
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadList.load, .ready)
        XCTAssertEqual(model.sideThreadList.rows.count, 1)
    }

    func testAFailedRefreshKeepsTheRowsOnScreen() async {
        reset()
        defer { reset() }
        let model = model()
        await model.loadSideThreads()
        model.mockSideThreadServer?.failsReads = true
        await model.loadSideThreads(showLoading: false)
        XCTAssertEqual(model.sideThreadList.load, .ready)
        XCTAssertEqual(model.sideThreadList.rows.count, 1)
    }

    func testStartingADMCreatesItOpensItAndTheListThenHasIt() async {
        reset()
        defer { reset() }
        let model = model()
        model.openSideThreadList()
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadCandidates.map(\.id), [riley], "The squad except you")
        model.beginNewSideThread()
        XCTAssertNotNil(model.sideThreadDraft)
        model.toggleSideThreadMember(riley)
        await model.createSideThread()
        XCTAssertNil(model.sideThreadDraft)
        let made = model.mockSideThreadCreates
        XCTAssertEqual(made.count, 1)
        XCTAssertEqual(made.first?.kind, "dm")
        XCTAssertEqual(made.first?.memberIds, [riley])
        XCTAssertEqual(made.first?.squadId, squad)
        XCTAssertEqual(made.first?.createdBy, model.viewerId)
        XCTAssertEqual(model.sideThread?.threadId, made.first?.id, "The new thread opens")
        await model.loadSideThread()
        XCTAssertEqual(model.sideThread?.load, .ready)
        XCTAssertEqual(model.sideThread?.info?.isDirect, true)
        model.sideThread?.draft = "hi"
        await model.sendSideThreadReply()
        model.closeSideThread()
        XCTAssertNil(model.sideThread)
        XCTAssertTrue(model.sideThreadsOpen, "Back to the list")
        await model.loadSideThreads()
        XCTAssertEqual(model.sideThreadList.rows.count, 2)
        XCTAssertEqual(model.sideThreadList.rows.first?.id, made.first?.id, "Newest activity first")
        XCTAssertEqual(model.sideThreadList.rows.first?.last?.body, "hi")
    }

    func testStartingTheSameDMAgainOpensTheOneYouHave() async {
        reset()
        defer { reset() }
        let model = model()
        await model.loadSideThreads()
        for _ in 0..<2 {
            model.beginNewSideThread()
            model.toggleSideThreadMember(riley)
            await model.createSideThread()
            model.closeSideThread()
            await model.loadSideThreads()
        }
        XCTAssertEqual(model.mockSideThreadCreates.count, 1, "The second start found the DM and made nothing")
        XCTAssertEqual(model.sideThreadList.rows.count, 2)
    }

    func testAFailedCreateKeepsTheFormAndRetriesWithTheSameId() async {
        reset()
        defer { reset() }
        let model = model()
        await model.loadSideThreads()
        model.mockSideThreadServer?.failsCreate = true
        model.beginNewSideThread()
        model.toggleSideThreadMember(riley)
        let id = model.sideThreadDraft?.threadId
        await model.createSideThread()
        XCTAssertEqual(model.sideThreadDraft?.error, SideThreadCopy.createFailed)
        XCTAssertEqual(model.sideThreadDraft?.creating, false)
        XCTAssertNil(model.sideThread)
        model.mockSideThreadServer?.failsCreate = false
        await model.createSideThread()
        XCTAssertNil(model.sideThreadDraft)
        XCTAssertEqual(model.mockSideThreadCreates.first?.id, id)
    }

    func testAThreadOpenedFromTheListClosesBackToTheList() async {
        reset()
        defer { reset() }
        let model = model()
        model.openSideThreadList()
        await model.loadSideThreads()
        model.openThreadFromList(ranked)
        XCTAssertEqual(model.sideThread?.threadId, ranked)
        XCTAssertNil(model.sideThread?.focus, "No reply to scroll to: it lands on the newest")
        model.closeSideThread()
        XCTAssertTrue(model.sideThreadsOpen)
    }

    func testSignOutClosesTheListAndTheForm() async {
        reset()
        defer { reset() }
        let model = model()
        model.openSideThreadList()
        model.beginNewSideThread()
        await model.signOut()
        XCTAssertFalse(model.sideThreadsOpen)
        XCTAssertNil(model.sideThreadDraft)
        XCTAssertEqual(model.sideThreadList, SideThreadListState())
    }
}
