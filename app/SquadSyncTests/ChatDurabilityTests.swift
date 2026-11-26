import XCTest
@testable import SquadSync

/// Chat durability: older-history paging, unsent messages on disk, and opening a
/// pushed message that isn't loaded yet. Foundation only, so these run in the
/// Linux harness too.
final class ChatDurabilityTests: XCTestCase {
    private let me = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let squad = ChatSeed.squadId
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    private func remote(_ index: Int, at seconds: TimeInterval) -> RemoteMessage {
        RemoteMessage(id: ChatLongSeed.id(index), squadId: squad, senderId: ChatSeed.otherId, body: "m\(index)", sentAt: base.addingTimeInterval(seconds))
    }

    private func tempOutbox() -> ChatOutbox {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return ChatOutbox(directory: dir)
    }

    /// The mock service is main-actor; these tests aren't, so they hop to it.
    private func longMock() async -> MockChatService {
        let messages = ChatLongSeed.messages(viewerId: me, squadId: squad, now: base)
        return await MainActor.run {
            let chat = MockChatService()
            for message in messages { chat.seed(message) }
            return chat
        }
    }

    private func olderReads(_ chat: MockChatService) async -> Int {
        await MainActor.run { chat.olderReads }
    }

    private func setOlderDown(_ chat: MockChatService, _ down: Bool) async {
        await MainActor.run { chat.olderDown = down }
    }

    // MARK: Paging

    func testOlderPagesComeBackOldestFirstAndMergeInOrderWithoutDuplicates() async throws {
        let chat = await longMock()
        let first = try await chat.history(squadId: squad)
        XCTAssertEqual(first.count, SupabaseChatService.historyLimit)
        XCTAssertEqual(first.first?.id, ChatLongSeed.id(60))
        var log = ChatLog()
        log.adopt(replacingSquad: true, history: first.map { $0.entry() })

        let cursor = try XCTUnwrap(ChatOlderPaging.cursor(log))
        XCTAssertEqual(cursor.id, ChatLongSeed.id(60))
        let page = try await chat.older(squadId: squad, before: cursor, limit: ChatOlderPaging.pageSize)
        XCTAssertEqual(page.map(\.id), (10..<60).map(ChatLongSeed.id), "One page is the 50 just before the cursor, oldest first")

        // The same page twice (a retry after a lost response) adds nothing.
        log.ingest(page.map { $0.entry() })
        log.ingest(page.map { $0.entry() })
        XCTAssertEqual(log.entries.count, 250)
        XCTAssertEqual(Set(log.entries.map(\.id)).count, 250)
        XCTAssertEqual(log.ordered.map(\.id), (10..<260).map(ChatLongSeed.id))
    }

    func testCursorBreaksSentAtTiesOnId() {
        let cursor = ChatPageCursor(sentAt: base, id: ChatLongSeed.id(5))
        XCTAssertTrue(cursor.precedes(sentAt: base.addingTimeInterval(-1), id: ChatLongSeed.id(9)))
        XCTAssertTrue(cursor.precedes(sentAt: base, id: ChatLongSeed.id(4)), "Same second, lower id comes first")
        XCTAssertFalse(cursor.precedes(sentAt: base, id: ChatLongSeed.id(5)), "The cursor row itself isn't older")
        XCTAssertFalse(cursor.precedes(sentAt: base, id: ChatLongSeed.id(6)))
        XCTAssertFalse(cursor.precedes(sentAt: base.addingTimeInterval(1), id: ChatLongSeed.id(0)))
    }

    func testPagingAcrossTiedTimestampsSkipsAndRepeatsNothing() async throws {
        // Every page boundary in the long seed falls inside a pair sharing a second.
        let chat = await longMock()
        var log = ChatLog()
        log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        var paging = ChatOlderPaging()
        paging.settleFirstRead(rowCount: log.entries.count, limit: SupabaseChatService.historyLimit)
        var pages = 0
        while paging.state == .idle, let cursor = ChatOlderPaging.cursor(log) {
            XCTAssertTrue(paging.begin())
            let page = try await chat.older(squadId: squad, before: cursor, limit: 7)
            log.ingest(page.map { $0.entry() })
            paging.finish(rowCount: page.count, pageSize: 7)
            pages += 1
            XCTAssertLessThan(pages, 20)
        }
        XCTAssertEqual(paging.state, .reachedStart)
        XCTAssertEqual(log.ordered.map(\.id), (0..<260).map(ChatLongSeed.id))
    }

    func testCursorSkipsUnsentLocalRows() {
        var log = ChatLog()
        log.ingest([remote(1, at: 10).entry(), remote(2, at: 20).entry()])
        log.beginSend(id: UUID(), senderId: me, body: "pending", now: base)
        let cursor = ChatOlderPaging.cursor(log)
        XCTAssertEqual(cursor?.id, ChatLongSeed.id(1), "A local row's clock isn't a server cursor")
        XCTAssertNil(ChatOlderPaging.cursor(ChatLog()))
    }

    func testFirstReadDecidesWhetherThereIsAnythingOlder() {
        var paging = ChatOlderPaging()
        paging.settleFirstRead(rowCount: 12, limit: 200)
        XCTAssertEqual(paging.state, .reachedStart)
        XCTAssertFalse(paging.begin(), "No page past the start of the chat")
        paging.settleFirstRead(rowCount: 200, limit: 200)
        XCTAssertEqual(paging.state, .idle)
    }

    func testEndOfHistoryAfterAShortPage() {
        var paging = ChatOlderPaging()
        XCTAssertTrue(paging.begin())
        paging.finish(rowCount: 50)
        XCTAssertEqual(paging.state, .idle, "A full page may have more behind it")
        XCTAssertTrue(paging.begin())
        paging.finish(rowCount: 10)
        XCTAssertEqual(paging.state, .reachedStart)
        XCTAssertEqual(ChatOlderPaging.startText, "Start of chat")
    }

    func testErrorThenRetry() {
        var paging = ChatOlderPaging()
        XCTAssertTrue(paging.begin())
        XCTAssertFalse(paging.begin(), "A second page doesn't start while one runs")
        paging.fail()
        XCTAssertEqual(paging.state, .failed(ChatOlderPaging.failedText))
        XCTAssertFalse(ChatOlderTrigger.isDue(metrics: atTop, oldestRowY: 40, userHasScrolled: true, settlingPrepend: false, paging: paging, hasMessages: true), "Failed waits for Retry, no auto loop")
        XCTAssertTrue(paging.begin(), "Retry starts the page again")
        paging.finish(rowCount: 50)
        XCTAssertEqual(paging.state, .idle)
    }

    func testMockOlderReadFailsUntilBroughtBack() async throws {
        let chat = await longMock()
        await setOlderDown(chat, true)
        let cursor = ChatPageCursor(sentAt: base, id: ChatLongSeed.id(259))
        do {
            _ = try await chat.older(squadId: squad, before: cursor, limit: 50)
            XCTFail("The older read should fail while down")
        } catch {}
        await setOlderDown(chat, false)
        let page = try await chat.older(squadId: squad, before: cursor, limit: 50)
        XCTAssertEqual(page.count, 50)
        let reads = await olderReads(chat)
        XCTAssertEqual(reads, 2)
    }

    func testSupabaseOlderQueryPagesBeforeTheCursorWithAnIdTieBreak() async throws {
        let rows = [remote(2, at: 20), remote(1, at: 10)] // newest first, as the server sends
        let transport = ScriptedTransport(responses: [(200, try BackendJSON.encoder.encode(rows))])
        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let cursorId = ChatLongSeed.id(3)
        let page = try await chat.older(squadId: squad, before: ChatPageCursor(sentAt: base.addingTimeInterval(30), id: cursorId), limit: 50)
        XCTAssertEqual(page.map(\.id), [ChatLongSeed.id(1), ChatLongSeed.id(2)], "Flipped to oldest first")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        let url = try XCTUnwrap(request.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        XCTAssertTrue(url.path.hasSuffix("rest/v1/sq8_messages"))
        XCTAssertEqual(value("squad_id"), "eq.\(squad.uuidString)")
        XCTAssertEqual(value("order"), "sent_at.desc,id.desc")
        XCTAssertEqual(value("limit"), "50")
        let filter = try XCTUnwrap(value("or"))
        let stamp = try XCTUnwrap(BackendJSON.parseStamp(base.addingTimeInterval(30)))
        XCTAssertEqual(filter, "(sent_at.lt.\"\(stamp)\",and(sent_at.eq.\"\(stamp)\",id.lt.\(cursorId.uuidString.lowercased())))")
    }

    func testSupabaseMessageLookup() async throws {
        let found = remote(4, at: 40)
        let transport = ScriptedTransport(responses: [(200, try BackendJSON.encoder.encode([found])), (200, Data("[]".utf8))])
        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let hit = try await chat.message(squadId: squad, id: found.id)
        XCTAssertEqual(hit?.id, found.id)
        let miss = try await chat.message(squadId: squad, id: UUID())
        XCTAssertNil(miss)
        let query = transport.requests.first?.url?.query ?? ""
        XCTAssertTrue(query.contains("id=eq.\(found.id.uuidString)"), query)
        XCTAssertTrue(query.contains("squad_id=eq.\(squad.uuidString)"), query)
    }

    // MARK: Scroll geometry: when to page (decided from geometry, not onAppear)

    /// A 600pt list over 8000pt of content.
    private func metrics(offset: Double, content: Double = 8000, viewport: Double = 600) -> ChatScrollMetrics {
        ChatScrollMetrics(offset: offset, topInset: 0, bottomInset: 0, contentHeight: content, viewportHeight: viewport)
    }

    private var atTop: ChatScrollMetrics { metrics(offset: 0) }

    func testPageIsDueWhenTheOldestMessageComesIntoView() {
        let paging = ChatOlderPaging()
        func due(_ m: ChatScrollMetrics, _ y: Double?) -> Bool {
            ChatOlderTrigger.isDue(metrics: m, oldestRowY: y, userHasScrolled: true, settlingPrepend: false, paging: paging, hasMessages: true)
        }
        XCTAssertFalse(due(metrics(offset: 4000), 900), "Oldest message still below the screen")
        XCTAssertTrue(due(metrics(offset: 4000), 590), "Its top came up past the bottom edge")
        XCTAssertTrue(due(metrics(offset: 4000), -300), "Flung past it")
        XCTAssertTrue(due(metrics(offset: 100), nil), "Near the top with no row geometry yet")
        XCTAssertFalse(due(metrics(offset: 400), nil), "Not near the top")
    }

    func testFirstRenderAtTheTopDoesNotPage() {
        // The list draws its top before jumping to the newest message.
        let due = ChatOlderTrigger.isDue(metrics: atTop, oldestRowY: 40, userHasScrolled: false, settlingPrepend: false, paging: ChatOlderPaging(), hasMessages: true)
        XCTAssertFalse(due)
    }

    func testNoPageWhileTheLastOneIsStillGoingIn() {
        var paging = ChatOlderPaging()
        let base = { (settling: Bool, paging: ChatOlderPaging) in
            ChatOlderTrigger.isDue(metrics: self.atTop, oldestRowY: 40, userHasScrolled: true, settlingPrepend: settling, paging: paging, hasMessages: true)
        }
        XCTAssertTrue(paging.begin())
        XCTAssertFalse(base(false, paging), "Loading")
        paging.finish(rowCount: 50)
        XCTAssertFalse(base(true, paging), "Rows handed over but not laid out: geometry is stale")
        XCTAssertTrue(base(false, paging), "Laid out and still at the top: the next page is due")
        paging.finish(rowCount: 3)
        XCTAssertFalse(base(false, paging), "Start of chat")
        XCTAssertFalse(ChatOlderTrigger.isDue(metrics: atTop, oldestRowY: 40, userHasScrolled: true, settlingPrepend: false, paging: ChatOlderPaging(), hasMessages: false))
    }

    func testReaderParkedAtTheTopPagesToTheStartWithoutScrolling() async throws {
        // The Mac-pass stall: after a page the reader is still at the top and
        // doesn't move. Every paging-state change re-reads the geometry, so the
        // next page is asked for until the start, with no scroll events at all.
        let chat = await longMock()
        var log = ChatLog()
        log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        var paging = ChatOlderPaging()
        paging.settleFirstRead(rowCount: log.entries.count, limit: SupabaseChatService.historyLimit)
        var pages = 0
        while ChatOlderTrigger.isDue(metrics: atTop, oldestRowY: 40, userHasScrolled: true, settlingPrepend: false, paging: paging, hasMessages: true) {
            XCTAssertTrue(paging.begin())
            let cursor = try XCTUnwrap(ChatOlderPaging.cursor(log))
            let page = try await chat.older(squadId: squad, before: cursor, limit: ChatOlderPaging.pageSize)
            log.ingest(page.map { $0.entry() })
            paging.finish(rowCount: page.count)
            pages += 1
            if pages > 10 { XCTFail("Paging never ended"); break }
        }
        XCTAssertEqual(paging.state, .reachedStart)
        XCTAssertEqual(pages, 2)
        XCTAssertEqual(log.ordered.map(\.id), (0..<260).map(ChatLongSeed.id))
    }

    // MARK: Scroll geometry: holding the place

    func testInsertMovesTheOffsetByExactlyTheGrowth() {
        // Fling stopped at offset 0 with message 60 at y 450 on screen.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 0, contentHeightBefore: 8000, anchorYBefore: 450)
        XCTAssertNil(hold.offsetForInsert(metrics(offset: 0, content: 8000)), "No growth yet: not the insert")
        let target = hold.offsetForInsert(metrics(offset: 0, content: 11_200))
        XCTAssertEqual(target, 3200, "Same rows on screen: offset moves by the 3200pt added above")
        XCTAssertTrue(hold.insertApplied)
        XCTAssertNil(hold.offsetForInsert(metrics(offset: 3200, content: 11_300)), "Later growth (rows below measuring) isn't the insert")
    }

    func testAnchorDriftIsCorrectedExactlyThenSettles() {
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 0, contentHeightBefore: 8000, anchorYBefore: 450)
        XCTAssertNil(hold.offsetForAnchor(y: 300, metrics: metrics(offset: 0, content: 8000)), "Nothing before the insert")
        _ = hold.offsetForInsert(metrics(offset: 0, content: 11_200))
        // Estimated heights for the new rows were 40pt short in total: the anchor
        // shows up at 490 instead of 450.
        XCTAssertEqual(hold.offsetForAnchor(y: 490, metrics: metrics(offset: 3200, content: 11_240)), 3240)
        XCTAssertFalse(hold.settled)
        XCTAssertNil(hold.offsetForAnchor(y: 450.2, metrics: metrics(offset: 3240, content: 11_240)), "Within the tolerance")
        XCTAssertFalse(hold.settled, "Checked again after the next layouts")
        XCTAssertNil(hold.offsetForAnchor(y: 450.1, metrics: metrics(offset: 3240, content: 11_240)))
        XCTAssertFalse(hold.settled)
        XCTAssertNil(hold.offsetForAnchor(y: 450.1, metrics: metrics(offset: 3240, content: 11_240)))
        XCTAssertTrue(hold.settled)
        XCTAssertNil(hold.offsetForAnchor(y: 200, metrics: metrics(offset: 3240, content: 11_240)), "A settled hold doesn't move the list again")
    }

    func testHoldIsClampedToTheContent() {
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 0, contentHeightBefore: 500, anchorYBefore: nil)
        // Short content: 500pt list, page adds 200pt; the most it can scroll is 100.
        let target = hold.offsetForInsert(metrics(offset: 0, content: 700, viewport: 600))
        XCTAssertEqual(target, 100)
        XCTAssertTrue(hold.settled, "No anchor geometry: the insert step is the whole hold")
    }

    func testReplayedFlingKeepsMessage60OnScreen() {
        // Simulates the list: rows of varying height, offset at the top after a
        // fling, 50 rows inserted above with estimated heights, then real heights.
        let viewport = 600.0
        var heights = (60..<260).map { 40.0 + Double($0 % 3) * 20 }
        func contentHeight() -> Double { heights.reduce(0, +) }
        func y(ofRow index: Int, offset: Double) -> Double { heights.prefix(index).reduce(0, +) - offset }
        var offset = 0.0
        let anchorBefore = y(ofRow: 0, offset: offset)
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: offset, contentHeightBefore: contentHeight(), anchorYBefore: anchorBefore)
        heights.insert(contentsOf: Array(repeating: 50.0, count: 50), at: 0)
        if let next = hold.offsetForInsert(ChatScrollMetrics(offset: offset, topInset: 0, bottomInset: 0, contentHeight: contentHeight(), viewportHeight: viewport)) {
            offset = next
        }
        // The lazy stack measures the new rows: real heights differ from the estimate.
        for index in 0..<50 { heights[index] = 40.0 + Double(index % 4) * 15 }
        for _ in 0..<4 {
            let metrics = ChatScrollMetrics(offset: offset, topInset: 0, bottomInset: 0, contentHeight: contentHeight(), viewportHeight: viewport)
            if let next = hold.offsetForAnchor(y: y(ofRow: 50, offset: offset), metrics: metrics) { offset = next }
        }
        let anchorAfter = y(ofRow: 50, offset: offset)
        XCTAssertEqual(anchorAfter, anchorBefore, accuracy: 0.5, "Message 60 is where it was")
        XCTAssertTrue((0..<viewport).contains(anchorAfter), "and on screen")
        XCTAssertTrue(hold.settled)
    }

    func testKeyboardKeepsAReaderAtTheBottomThere() {
        let pinned = metrics(offset: 7400, content: 8000, viewport: 600)
        var shorter = pinned
        shorter.viewportHeight = 300
        XCTAssertEqual(ChatViewportStick.offset(before: pinned, after: shorter), 7700, "Last message stays above the keyboard")
        let reading = metrics(offset: 3000, content: 8000, viewport: 600)
        var readingShorter = reading
        readingShorter.viewportHeight = 300
        XCTAssertNil(ChatViewportStick.offset(before: reading, after: readingShorter), "Scrolled up: nothing moves")
        XCTAssertNil(ChatViewportStick.offset(before: pinned, after: pinned), "No size change")
    }

    // MARK: Microsecond cursor

    private let microStamp = "2026-11-17T18:00:00.123456+00:00"

    private func microRowJSON(id: UUID, stamp: String) -> Data {
        Data("""
        [{"id":"\(id.uuidString.lowercased())","squad_id":"\(squad.uuidString.lowercased())","sender_id":"\(ChatSeed.otherId.uuidString.lowercased())","body":"edge","sent_at":"\(stamp)","reply_to_id":null}]
        """.utf8)
    }

    func testServerSentAtTextIsKeptForTheCursor() throws {
        let id = ChatLongSeed.id(7)
        let rows = try BackendJSON.decoder.decode([RemoteMessage].self, from: microRowJSON(id: id, stamp: microStamp))
        let row = try XCTUnwrap(rows.first)
        XCTAssertEqual(row.sentAtStamp, microStamp)
        var log = ChatLog()
        log.ingest(rows.map { $0.entry() })
        let cursor = try XCTUnwrap(ChatOlderPaging.cursor(log))
        XCTAssertEqual(cursor.stamp, microStamp)
        XCTAssertEqual(cursor.filterStamp, microStamp, "The cursor keeps the microseconds")
        let rebuilt = BackendJSON.parseStamp(row.sentAt) ?? ""
        XCTAssertNotEqual(rebuilt, microStamp, "A Date round trip would have lost them")
        // Never sent back to the server, and not part of what makes rows equal.
        let encoded = String(data: try BackendJSON.encoder.encode(row), encoding: .utf8) ?? ""
        XCTAssertFalse(encoded.contains("123456"), encoded)
        var plain = row
        plain.sentAtStamp = nil
        XCTAssertEqual(plain, row)
    }

    func testMicrosecondBoundaryGoesToTheServerIntact() async throws {
        let id = ChatLongSeed.id(7)
        let rows = try BackendJSON.decoder.decode([RemoteMessage].self, from: microRowJSON(id: id, stamp: microStamp))
        var log = ChatLog()
        log.ingest(rows.map { $0.entry() })
        let cursor = try XCTUnwrap(ChatOlderPaging.cursor(log))
        let transport = ScriptedTransport(responses: [(200, Data("[]".utf8))])
        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        _ = try await chat.older(squadId: squad, before: cursor, limit: 50)
        let url = try XCTUnwrap(transport.requests.first?.url)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let filter = try XCTUnwrap(items.first { $0.name == "or" }?.value)
        // A row at .123456 is the boundary: rows at .123000-.123455 are older and
        // must stay in the next page, which a ".123" cursor would have dropped.
        XCTAssertEqual(filter, "(sent_at.lt.\"\(microStamp)\",and(sent_at.eq.\"\(microStamp)\",id.lt.\(id.uuidString.lowercased())))")
        let raw = url.absoluteString
        XCTAssertTrue(raw.contains("%2B00:00"), "The offset's + must be encoded, or it reads as a space: \(raw)")
        XCTAssertFalse(raw.contains("+00:00"), raw)
    }

    func testEchoOfALocalSendPicksUpTheServerStamp() throws {
        let id = ChatLongSeed.id(7)
        var log = ChatLog()
        log.beginSend(id: id, senderId: me, body: "edge", now: base)
        XCTAssertNil(log.entries.first?.serverStamp)
        let rows = try BackendJSON.decoder.decode([RemoteMessage].self, from: microRowJSON(id: id, stamp: microStamp))
        log.ingest(rows.map { $0.entry() })
        XCTAssertEqual(log.entries.first?.serverStamp, microStamp)
        XCTAssertEqual(ChatOlderPaging.cursor(log)?.stamp, microStamp)
    }

    func testCursorWithoutAServerStampFallsBackToItsDate() {
        let cursor = ChatPageCursor(sentAt: base, id: ChatLongSeed.id(1))
        XCTAssertEqual(cursor.filterStamp, BackendJSON.parseStamp(base))
        let odd = ChatPageCursor(sentAt: base, id: ChatLongSeed.id(1), stamp: "x\",y")
        XCTAssertEqual(odd.filterStamp, BackendJSON.parseStamp(base), "Text that could break the filter isn't used")
    }

    // MARK: Unsent messages on disk

    func testOutboxRoundTrip() {
        let outbox = tempOutbox()
        let reply = UUID()
        let item = OutboxItem(id: UUID(), squadId: squad, senderId: me, body: "on my way", createdAt: base, replyToId: reply)
        outbox.add(item)
        XCTAssertEqual(outbox.load(squadId: squad, userId: me), [item])
        XCTAssertEqual(item.message.id, item.id)
        XCTAssertEqual(item.message.replyToId, reply)
        XCTAssertEqual(OutboxItem(item.message), item)
        XCTAssertTrue(outbox.load(squadId: UUID(), userId: me).isEmpty, "Per squad")
        XCTAssertTrue(outbox.load(squadId: squad, userId: UUID()).isEmpty, "Per user")
        outbox.remove(id: item.id, squadId: squad, userId: me)
        XCTAssertTrue(outbox.load(squadId: squad, userId: me).isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: outbox.fileURL(squadId: squad, userId: me).path), "An empty outbox leaves no file")
    }

    func testOutboxSurvivesARelaunch() {
        let first = tempOutbox()
        let a = OutboxItem(id: UUID(), squadId: squad, senderId: me, body: "first", createdAt: base)
        let b = OutboxItem(id: UUID(), squadId: squad, senderId: me, body: "second", createdAt: base.addingTimeInterval(5))
        first.add(a)
        first.add(b)
        // A new instance on the same directory is what the next launch sees.
        let relaunched = ChatOutbox(directory: first.directory)
        XCTAssertEqual(relaunched.load(squadId: squad, userId: me), [a, b])
    }

    func testRestoredMessagesComeBackFailedWithTheirIds() {
        let pending = OutboxItem(id: UUID(), squadId: squad, senderId: me, body: "was sending", createdAt: base.addingTimeInterval(15))
        let delivered = OutboxItem(id: ChatLongSeed.id(1), squadId: squad, senderId: me, body: "m1", createdAt: base.addingTimeInterval(10))
        var log = ChatLog()
        log.ingest([remote(1, at: 10).entry(), remote(2, at: 20).entry()])
        let already = OutboxRestore.apply([pending, delivered], to: &log)
        XCTAssertEqual(already, [delivered.id], "The server already has it, so it leaves the outbox")
        let restored = log.entries.first { $0.id == pending.id }
        XCTAssertEqual(restored?.delivery, .failed)
        XCTAssertEqual(restored?.body, "was sending")
        XCTAssertEqual(log.ordered.map(\.id), [ChatLongSeed.id(1), pending.id, ChatLongSeed.id(2)], "Back in its place in time")
        XCTAssertEqual(log.entries.count, 3)
        // Applying again (a second history load) doesn't double it.
        OutboxRestore.apply([pending], to: &log)
        XCTAssertEqual(log.entries.count, 3)
    }

    func testRetryAfterRelaunchUsesTheSameId() async throws {
        let outbox = tempOutbox()
        let id = UUID()
        outbox.add(OutboxItem(id: id, squadId: squad, senderId: me, body: "retry me", createdAt: base))
        let relaunched = ChatOutbox(directory: outbox.directory)
        var log = ChatLog()
        OutboxRestore.apply(relaunched.load(squadId: squad, userId: me), to: &log)
        log.retry(id: id)
        relaunched.add(OutboxItem(id: id, squadId: squad, senderId: me, body: "retry me", createdAt: base))
        XCTAssertEqual(relaunched.load(squadId: squad, userId: me).count, 1, "Re-adding the same id replaces it")

        // The insert carries the client id with ignore-duplicates, so a row the
        // server took before the kill isn't stored twice.
        let message = try XCTUnwrap(relaunched.load(squadId: squad, userId: me).first).message
        let echoed = try BackendJSON.encoder.encode([message])
        let transport = ScriptedTransport(responses: [(201, echoed)])
        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let receipt = try await chat.send(message)
        XCTAssertEqual(receipt, .stored)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=representation,resolution=ignore-duplicates")
        let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.lowercased().contains(id.uuidString.lowercased()), "The retry sends the original id")
        log.markSent(id: id)
        relaunched.remove(id: id, squadId: squad, userId: me)
        XCTAssertEqual(log.entries.first?.delivery, .sent)
        XCTAssertTrue(relaunched.load(squadId: squad, userId: me).isEmpty)
    }

    func testSignOutClearsOnlyThatPersonsOutbox() {
        let outbox = tempOutbox()
        let other = UUID()
        let otherSquad = UUID()
        outbox.add(OutboxItem(id: UUID(), squadId: squad, senderId: me, body: "a", createdAt: base))
        outbox.add(OutboxItem(id: UUID(), squadId: otherSquad, senderId: me, body: "b", createdAt: base))
        outbox.add(OutboxItem(id: UUID(), squadId: squad, senderId: other, body: "c", createdAt: base))
        outbox.clear(userId: me)
        XCTAssertTrue(outbox.load(squadId: squad, userId: me).isEmpty)
        XCTAssertTrue(outbox.load(squadId: otherSquad, userId: me).isEmpty, "Every squad for that person")
        XCTAssertEqual(outbox.load(squadId: squad, userId: other).count, 1)
        outbox.clearAll()
        XCTAssertTrue(outbox.load(squadId: squad, userId: other).isEmpty)
    }

    // MARK: Opening a pushed message

    func testRevealPagesBackUntilTheMessageIsLoaded() async throws {
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let target = ChatLongSeed.id(3)
        let squadId = squad
        let outcome = await ChatReveal.run(
            loaded: { box.log.entries.contains { $0.id == target } },
            exists: { try await chat.message(squadId: squadId, id: target) != nil },
            loadOlderPage: {
                guard let cursor = ChatOlderPaging.cursor(box.log) else { return false }
                let page = try await chat.older(squadId: squadId, before: cursor, limit: ChatOlderPaging.pageSize)
                box.log.ingest(page.map { $0.entry() })
                return page.count == ChatOlderPaging.pageSize
            }
        )
        XCTAssertEqual(outcome, .found)
        let reads = await olderReads(chat)
        XCTAssertEqual(reads, 2, "Two pages reach message 3")
        XCTAssertEqual(box.log.ordered.map(\.id), (0..<260).map(ChatLongSeed.id), "The window stays contiguous")
    }

    func testRevealAlreadyLoadedNeedsNoRead() async {
        var reads = 0
        let outcome = await ChatReveal.run(loaded: { true }, exists: { reads += 1; return true }, loadOlderPage: { reads += 1; return true })
        XCTAssertEqual(outcome, .found)
        XCTAssertEqual(reads, 0)
    }

    func testRevealSaysWhenTheMessageIsGone() async {
        var pages = 0
        let outcome = await ChatReveal.run(loaded: { false }, exists: { false }, loadOlderPage: { pages += 1; return true })
        XCTAssertEqual(outcome, .notInChat)
        XCTAssertEqual(pages, 0, "No paging for a message the server doesn't have")
        XCTAssertEqual(ChatReveal.text(outcome), "That message isn't in this chat anymore.")
    }

    func testRevealStopsAtTheCap() async {
        var pages = 0
        let outcome = await ChatReveal.run(loaded: { false }, exists: { true }, loadOlderPage: { pages += 1; return true }, maxPages: 3)
        XCTAssertEqual(outcome, .tooFarBack)
        XCTAssertEqual(pages, 3)
        XCTAssertEqual(ChatReveal.text(outcome), ChatReveal.tooFarBackText)
    }

    func testRevealReachingTheStartWithoutItIsHonest() async {
        let outcome = await ChatReveal.run(loaded: { false }, exists: { true }, loadOlderPage: { false })
        XCTAssertEqual(outcome, .notInChat)
    }

    func testRevealFailureSaysSo() async {
        let outcome = await ChatReveal.run(loaded: { false }, exists: { throw BackendFailure.reconnecting }, loadOlderPage: { true })
        XCTAssertEqual(outcome, .failed)
        XCTAssertEqual(ChatReveal.text(outcome), "Couldn't open that message. Try again.")
        let midway = await ChatReveal.run(loaded: { false }, exists: { true }, loadOlderPage: { throw BackendFailure.reconnecting })
        XCTAssertEqual(midway, .failed)
    }

    // MARK: Opening a pushed message that is newer than the loaded chat

    func testPlacementPutsAPushedMessageAgainstTheLoadedWindow() {
        let oldest = base
        let newest = base.addingTimeInterval(600)
        XCTAssertEqual(ChatReveal.placement(sentAt: nil, oldestLoaded: oldest, newestLoaded: newest), .missing)
        XCTAssertEqual(ChatReveal.placement(sentAt: newest.addingTimeInterval(1), oldestLoaded: oldest, newestLoaded: newest), .newer)
        XCTAssertEqual(ChatReveal.placement(sentAt: newest, oldestLoaded: oldest, newestLoaded: newest), .gap)
        XCTAssertEqual(ChatReveal.placement(sentAt: base.addingTimeInterval(300), oldestLoaded: oldest, newestLoaded: newest), .gap)
        XCTAssertEqual(ChatReveal.placement(sentAt: oldest, oldestLoaded: oldest, newestLoaded: newest), .gap)
        XCTAssertEqual(ChatReveal.placement(sentAt: oldest.addingTimeInterval(-1), oldestLoaded: oldest, newestLoaded: newest), .older)
        XCTAssertEqual(ChatReveal.placement(sentAt: base, oldestLoaded: nil, newestLoaded: nil), .gap, "An empty chat takes the one row")
    }

    /// The app's wiring of `ChatReveal.run`, against the mock server and a log box.
    private func revealLikeTheApp(
        _ target: UUID,
        chat: MockChatService,
        box: LogBox,
        catchUpFails: Bool = false,
        catchUpReturnsNothing: Bool = false
    ) async -> (ChatReveal.Outcome, newerReads: Int, inserts: Int) {
        let squadId = squad
        var newerReads = 0
        var inserts = 0
        var located: RemoteMessage?
        let outcome = await ChatReveal.run(
            loaded: { box.log.entries.contains { $0.id == target } },
            locate: {
                located = try await chat.message(squadId: squadId, id: target)
                let onServer = box.log.ordered.filter { $0.delivery == .sent }
                return ChatReveal.placement(sentAt: located?.sentAt, oldestLoaded: onServer.first?.sentAt, newestLoaded: onServer.last?.sentAt)
            },
            catchUpNewer: {
                newerReads += 1
                if catchUpFails { throw BackendFailure.reconnecting }
                if catchUpReturnsNothing { return }
                let newest = box.log.ordered.last { $0.delivery == .sent }?.sentAt ?? .distantPast
                box.log.ingest(try await chat.newer(squadId: squadId, after: newest).map { $0.entry() })
            },
            insert: {
                inserts += 1
                if let located { box.log.ingest([located.entry()]) }
            },
            loadOlderPage: {
                guard let cursor = ChatOlderPaging.cursor(box.log) else { return false }
                let page = try await chat.older(squadId: squadId, before: cursor, limit: ChatOlderPaging.pageSize)
                box.log.ingest(page.map { $0.entry() })
                return page.count == ChatOlderPaging.pageSize
            }
        )
        return (outcome, newerReads, inserts)
    }

    func testAWarmTapOnAMessageTheSocketHasNotDeliveredCatchesUpInsteadOfPagingBack() async throws {
        // The chat is loaded; then two messages land on the server before the
        // socket brings them. The push is for the second one.
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let before = box.log.entries.count
        let first = RemoteMessage(id: UUID(), squadId: squad, senderId: ChatSeed.otherId, body: "first new", sentAt: base.addingTimeInterval(10))
        let pushed = RemoteMessage(id: UUID(), squadId: squad, senderId: ChatSeed.otherId, body: "pushed", sentAt: base.addingTimeInterval(20))
        await MainActor.run {
            chat.seed(first)
            chat.seed(pushed)
        }
        let result = await revealLikeTheApp(pushed.id, chat: chat, box: box)
        XCTAssertEqual(result.0, .found, "The pushed message opens")
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 0, "A newer message never pages back through older history")
        XCTAssertEqual(result.newerReads, 1)
        XCTAssertEqual(result.inserts, 0, "The catch-up brought it")
        XCTAssertEqual(box.log.entries.count, before + 2, "The message before it came too, so there's no gap")
        XCTAssertEqual(box.log.ordered.suffix(2).map(\.id), [first.id, pushed.id])
    }

    func testAWarmTapStillOpensWhenTheCatchUpMissesTheMessage() async throws {
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let pushed = RemoteMessage(id: UUID(), squadId: squad, senderId: ChatSeed.otherId, body: "pushed", sentAt: base.addingTimeInterval(20))
        await MainActor.run { chat.seed(pushed) }
        let result = await revealLikeTheApp(pushed.id, chat: chat, box: box, catchUpReturnsNothing: true)
        XCTAssertEqual(result.0, .found)
        XCTAssertEqual(result.inserts, 1, "The located row goes in on its own")
        XCTAssertEqual(box.log.ordered.last?.id, pushed.id)
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 0)
    }

    func testAFailedCatchUpSaysSoAndDoesNotPageBack() async throws {
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let pushed = RemoteMessage(id: UUID(), squadId: squad, senderId: ChatSeed.otherId, body: "pushed", sentAt: base.addingTimeInterval(20))
        await MainActor.run { chat.seed(pushed) }
        let result = await revealLikeTheApp(pushed.id, chat: chat, box: box, catchUpFails: true)
        XCTAssertEqual(result.0, .failed)
        XCTAssertEqual(ChatReveal.text(result.0), ChatReveal.failedText)
        XCTAssertFalse(box.log.entries.contains { $0.id == pushed.id })
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 0)
    }

    func testAMissingRowInsideTheLoadedWindowIsInsertedInPlace() async throws {
        let chat = await longMock()
        let box = LogBox()
        let history = try await chat.history(squadId: squad)
        // The window is loaded except message 250, which the socket dropped.
        let dropped = ChatLongSeed.id(250)
        box.log.adopt(replacingSquad: true, history: history.filter { $0.id != dropped }.map { $0.entry() })
        let result = await revealLikeTheApp(dropped, chat: chat, box: box)
        XCTAssertEqual(result.0, .found)
        XCTAssertEqual(result.newerReads, 0)
        XCTAssertEqual(result.inserts, 1)
        XCTAssertEqual(box.log.ordered.map(\.id), history.map(\.id), "It sits in order")
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 0)
    }

    func testAnOlderPushedMessageStillPagesBackOnTheNewPath() async throws {
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let result = await revealLikeTheApp(ChatLongSeed.id(3), chat: chat, box: box)
        XCTAssertEqual(result.0, .found)
        XCTAssertEqual(result.newerReads, 0)
        XCTAssertEqual(result.inserts, 0)
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 2, "Two pages reach message 3")
        XCTAssertEqual(box.log.ordered.map(\.id), (0..<260).map(ChatLongSeed.id), "The window stays contiguous")
    }

    func testAPushedMessageTheServerDoesNotHaveSaysSoWithoutReading() async throws {
        let chat = await longMock()
        let box = LogBox()
        box.log.adopt(replacingSquad: true, history: try await chat.history(squadId: squad).map { $0.entry() })
        let result = await revealLikeTheApp(UUID(), chat: chat, box: box)
        XCTAssertEqual(result.0, .notInChat)
        XCTAssertEqual(result.newerReads, 0)
        XCTAssertEqual(result.inserts, 0)
        let pages = await olderReads(chat)
        XCTAssertEqual(pages, 0)
    }

    func testALocateFailureSaysSo() async {
        let outcome = await ChatReveal.run(
            loaded: { false },
            locate: { throw BackendFailure.reconnecting },
            catchUpNewer: {},
            insert: {},
            loadOlderPage: { true }
        )
        XCTAssertEqual(outcome, .failed)
    }

    // MARK: Staying at the bottom

    private func pinnedAtBottom() -> (ChatBottomPin, ChatScrollMetrics) {
        var pin = ChatBottomPin()
        let m = metrics(offset: 7700, content: 8000, viewport: 300)
        _ = pin.observe(m, change: .offset)
        return (pin, m)
    }

    func testFailedLastMessageKeepsAReaderAtTheBottom() {
        // AX5 with the keyboard up: the reader is at the bottom, their message fails
        // and grows by "Not delivered" + Retry. The end changed, so the list follows.
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        m.contentHeight += 27
        XCTAssertEqual(pin.observe(m, change: .content), 7727, "Back to the bottom after the failed row lays out")
        m.offset = 7727
        m.contentHeight += 20
        XCTAssertEqual(pin.observe(m, change: .content), 7747, "Every pass of that layout, until it settles")
        pin.endSettled()
        m.offset = 7747
        m.contentHeight += 50
        XCTAssertNil(pin.observe(m, change: .content), "Later growth isn't the end changing")
    }

    func testNewRowAtTheEndIsFollowed() {
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        m.contentHeight += 60
        XCTAssertEqual(pin.observe(m, change: .content), 7760)
    }

    func testRowExpandingInPlaceDoesNotMoveThePinnedList() {
        // The reaction menu grows a row to 382pt; nothing at the end changed.
        var (pin, m) = pinnedAtBottom()
        m.contentHeight += 330
        XCTAssertNil(pin.observe(m, change: .content), "A middle row growing leaves the offset alone")
        XCTAssertTrue(pin.pinned)
        pin.expanded()
        XCTAssertFalse(pin.pinned, "The tap that opened it is the person's own move")
        m.viewportHeight = 250
        XCTAssertNil(pin.observe(m, change: .viewport), "And the keyboard doesn't pull it down after")
    }

    func testLockingTheSpotCardKeepsEndOnScreen() {
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        pin.expanded()
        XCTAssertFalse(pin.endPending, "An expansion cancels following a pending end change")
        m.contentHeight += 140
        XCTAssertNil(pin.observe(m, change: .content), "The card grows; the list stays where End was tapped")
    }

    func testHeaderAndComposerChangingOnSendStayPinned() {
        // On Send the header comes back (top inset +55, offset +55 in the same pass)
        // and the field shrinks (bottom inset -27). Layout, not the person.
        var (pin, m) = pinnedAtBottom()
        m.topInset += 55
        m.offset += 55
        XCTAssertEqual(pin.observe(m, change: .offset), 7700, "Insets moved: back to the bottom")
        XCTAssertTrue(pin.pinned)
        m.offset = 7700
        m.bottomInset -= 27
        XCTAssertEqual(pin.observe(m, change: .offset), m.maxOffset)
        XCTAssertTrue(pin.pinned)
        m.offset = m.maxOffset
        m.viewportHeight = 159
        XCTAssertEqual(pin.observe(m, change: .viewport), m.maxOffset, "The keyboard: back to the bottom")
    }

    func testAnOffsetChangeThatIsNotThePersonsIsLeftAlone() {
        // The framework scrolling something into view: no fight, no loop.
        var (pin, m) = pinnedAtBottom()
        m.offset = 7000
        XCTAssertNil(pin.observe(m, change: .offset))
        XCTAssertTrue(pin.pinned)
    }

    func testCorrectionsAreBoundedPerTurn() {
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        var moves = 0
        for step in 1...10 {
            m.contentHeight = 8000 + Double(step) * 10
            if let target = pin.observe(m, change: .content) { moves += 1; XCTAssertEqual(target, m.maxOffset) }
        }
        XCTAssertEqual(moves, ChatBottomPin.budget, "A layout that keeps changing can't keep the main thread busy")
        pin.turnEnded()
        m.contentHeight += 10
        XCTAssertNotNil(pin.observe(m, change: .content), "Next turn: follows again")
        var settled = pinnedAtBottom().0
        settled.endChanged()
        XCTAssertNil(settled.observe(metrics(offset: 7700.3, content: 8000, viewport: 300), change: .content), "Within half a point: no move")
    }

    func testReaderWhoScrolledUpIsNotPulledDown() {
        var (pin, m) = pinnedAtBottom()
        m.offset = 7600
        XCTAssertNil(pin.observe(m, change: .offset, interacting: true))
        XCTAssertFalse(pin.pinned, "100pt up unpins")
        pin.endChanged()
        m.contentHeight += 40
        XCTAssertNil(pin.observe(m, change: .content), "A new or failed row doesn't move someone reading up")
        m.viewportHeight = 250
        XCTAssertNil(pin.observe(m, change: .viewport))
        m.offset = m.maxOffset - 20
        XCTAssertNil(pin.observe(m, change: .offset, interacting: true))
        XCTAssertTrue(pin.pinned, "Within \(ChatBottomPin.slack)pt of the bottom pins again")
    }

    func testPushOpenJumpUnpinsAndIsNotPulledBack() {
        var (pin, m) = pinnedAtBottom()
        pin.jumped(toBottom: false)
        m.offset = 0
        XCTAssertNil(pin.observe(m, change: .offset))
        pin.endChanged()
        m.contentHeight += 60
        XCTAssertNil(pin.observe(m, change: .content), "A new row doesn't pull an opened message down")
        m.viewportHeight = 250
        XCTAssertNil(pin.observe(m, change: .viewport))
        XCTAssertFalse(pin.pinned)
    }

    func testJumpToLatestPins() {
        var pin = ChatBottomPin()
        var m = metrics(offset: 3000, content: 8000, viewport: 300)
        _ = pin.observe(m, change: .offset, interacting: true)
        XCTAssertFalse(pin.pinned)
        pin.jumped(toBottom: true)
        m.viewportHeight = 250
        XCTAssertEqual(pin.observe(m, change: .viewport), 7750)
        m.offset = 7750
        pin.endChanged()
        m.contentHeight += 27
        XCTAssertEqual(pin.observe(m, change: .content), 7777, "Your send after it is followed")
    }

    func testPinWaitsOutDragsAndOlderPages() {
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        m.contentHeight += 30
        XCTAssertNil(pin.observe(m, change: .content, interacting: true), "Never fights a finger or a fling")
        XCTAssertTrue(pin.pinned, "30pt is within the slack")
        m.contentHeight += 2000
        XCTAssertNil(pin.observe(m, change: .content, holding: true), "An older page being held in place wins")
        pin.reset()
        XCTAssertTrue(pin.pinned, "A new squad opens at the newest message")
    }

    // MARK: Holding the place: only fresh positions, until it's still

    func testVisibleAnchorIsTheTopmostFullyVisibleRow() {
        // Gated paging run: message 60 is 300pt above the screen (and may be dropped
        // by the lazy stack), 68 is cut off at the top, 69 is the first whole row.
        let frames: [UUID: ChatRowFrame] = [
            ChatLongSeed.id(60): ChatRowFrame(minY: 1000, height: 50),
            ChatLongSeed.id(68): ChatRowFrame(minY: 1288, height: 50),
            ChatLongSeed.id(69): ChatRowFrame(minY: 1330, height: 60),
            ChatLongSeed.id(70): ChatRowFrame(minY: 1390, height: 50),
            ChatLongSeed.id(80): ChatRowFrame(minY: 1880, height: 50)  // past the bottom edge
        ]
        let restore = ChatPrependHold.visibleAnchor(frames: frames, offset: 1300, viewportHeight: 600)
        XCTAssertEqual(restore?.id, ChatLongSeed.id(69))
        XCTAssertEqual(restore?.y, 30)
        XCTAssertEqual(restore?.unitY ?? -1, 30.0 / 540.0, accuracy: 0.0001, "Scrolling to (0.5, unitY) puts its top back at 30")
        XCTAssertNil(ChatPrependHold.visibleAnchor(frames: [ChatLongSeed.id(60): ChatRowFrame(minY: 1000, height: 50)], offset: 1300, viewportHeight: 600),
                     "Nothing whole on screen: fall back")
        let tall = ChatPrependHold.visibleAnchor(frames: [ChatLongSeed.id(5): ChatRowFrame(minY: 1300, height: 600)], offset: 1300, viewportHeight: 600)
        XCTAssertEqual(tall?.unitY, 0, "A row exactly the list's height scrolls to its top")
    }

    func testVisibleAnchorHoldIgnoresTheEstimatedGrowth() {
        // The page adds 2500pt of estimates (and re-estimates rows below the screen);
        // moving the offset by that would throw row 69 out of the laid-out range.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(69), offsetBefore: 1300, contentHeightBefore: 12_000,
                                   anchorYBefore: 30, generation: 1, insertMovesOffset: false)
        XCTAssertNil(hold.offsetForInsert(metrics(offset: 1300, content: 14_500)), "No move on content growth")
        XCTAssertTrue(hold.insertApplied)
        XCTAssertFalse(hold.settled)
        // After the scroll back to row 69 it reports 3pt low; corrected exactly, then still three times.
        XCTAssertEqual(hold.offsetForAnchor(y: 33, measuredIn: 1, metrics: metrics(offset: 3780, content: 14_500)), 3783)
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3783, content: 14_500)))
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3783, content: 14_500)))
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3783, content: 14_500)))
        XCTAssertTrue(hold.settled)
    }

    func testThreadOrderIsKeptAcrossChanges() {
        var log = ChatLog()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let a = UUID(), b = UUID(), c = UUID()
        log.ingest([ChatEntry(id: b, senderId: UUID(), body: "b", sentAt: base.addingTimeInterval(20), delivery: .sent),
                    ChatEntry(id: a, senderId: UUID(), body: "a", sentAt: base.addingTimeInterval(10), delivery: .sent)])
        XCTAssertEqual(log.ordered.map(\.id), [a, b])
        log.beginSend(id: c, senderId: UUID(), body: "c", now: base.addingTimeInterval(5))
        XCTAssertEqual(log.ordered.map(\.id), [c, a, b], "A send in the past sorts in")
        log.ingest([ChatEntry(id: c, senderId: UUID(), body: "c", sentAt: base.addingTimeInterval(30), delivery: .sent)])
        XCTAssertEqual(log.ordered.map(\.id), [a, b, c], "The server's time moves it")
        XCTAssertEqual(log.ordered.last?.delivery, .sent)
        log.markFailed(id: a)
        XCTAssertEqual(log.ordered.first?.delivery, .failed, "In-place changes show in the ordered thread")
        log.remove(id: b)
        XCTAssertEqual(log.ordered.map(\.id), [a, c])
        XCTAssertEqual(log.ordered, ChatLog.sorted(log.entries))
    }

    func testHoldKeepsCorrectingUntilTheAnchorIsStill() {
        // Message 60 at y 40 (the reader sees 68-71 below it). Rows above realize in
        // two passes, each moving it; the hold follows both and ends only after two
        // in-place readings.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 0, contentHeightBefore: 8000, anchorYBefore: 40, generation: 1)
        XCTAssertEqual(hold.offsetForInsert(metrics(offset: 0, content: 10_500)), 2500)
        XCTAssertEqual(hold.offsetForAnchor(y: 75, measuredIn: 1, metrics: metrics(offset: 2500, content: 10_535)), 2535, "First realization pass: 35pt")
        XCTAssertNil(hold.offsetForAnchor(y: 40, measuredIn: 1, metrics: metrics(offset: 2535, content: 10_535)))
        XCTAssertFalse(hold.settled, "One in-place reading isn't stable yet")
        XCTAssertEqual(hold.offsetForAnchor(y: -20, measuredIn: 1, metrics: metrics(offset: 2535, content: 10_475)), 2475, "Second pass moved it the other way")
        XCTAssertNil(hold.offsetForAnchor(y: 40, measuredIn: 1, metrics: metrics(offset: 2475, content: 10_475)))
        XCTAssertNil(hold.offsetForAnchor(y: 40.2, measuredIn: 1, metrics: metrics(offset: 2475, content: 10_475)))
        XCTAssertNil(hold.offsetForAnchor(y: 40.1, measuredIn: 1, metrics: metrics(offset: 2475, content: 10_475)))
        XCTAssertTrue(hold.settled, "Three in-place readings in a row")
    }

    func testHoldCorrectionsAreBounded() {
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 0, contentHeightBefore: 8000, anchorYBefore: 40, generation: 1)
        _ = hold.offsetForInsert(metrics(offset: 0, content: 10_000))
        var moves = 0
        for step in 0..<40 where !hold.settled {
            let y = step % 2 == 0 ? 60.0 : 20.0
            if hold.offsetForAnchor(y: y, measuredIn: 1, metrics: metrics(offset: 2000, content: 10_000)) != nil { moves += 1 }
        }
        XCTAssertEqual(moves, ChatPrependHold.maxCorrections, "A layout that never settles can't keep moving the list")
        XCTAssertTrue(hold.settled)
    }

    func testHoldWithoutTheAnchorLaidOutIsTheInsertStepAlone() {
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(60), offsetBefore: 9000, contentHeightBefore: 12_000, anchorYBefore: nil, generation: 1)
        XCTAssertEqual(hold.offsetForInsert(metrics(offset: 9000, content: 14_500)), 11_500)
        XCTAssertTrue(hold.settled, "Reader far below the insert: nothing they see moves with the new rows")
    }

    func testOlderCursorMatchesTheOrderedThread() {
        var log = ChatLog()
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        var generator = SystemRandomNumberGenerator()
        var entries: [ChatEntry] = []
        for index in 0..<300 {
            let tie = index % 7 == 0 ? 0 : Double(Int.random(in: 0..<500, using: &generator))
            entries.append(ChatEntry(id: UUID(), senderId: UUID(), body: "m\(index)", sentAt: base.addingTimeInterval(tie),
                                     delivery: index % 11 == 0 ? .sending : .sent))
        }
        log.ingest(entries)
        let expected = log.ordered.first(where: { $0.delivery == .sent })
        XCTAssertEqual(ChatOlderPaging.cursor(log)?.id, expected?.id, "Same row as the sorted thread, ties by id")
        XCTAssertNil(ChatOlderPaging.cursor(ChatLog()))
    }

    func testStalePositionIsNeverCorrectedFor() {
        // Reader near the bottom, message 237 at y 30. The page lands; a report from
        // before the insert's layout (generation 0) would claim a 3200pt drift.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(237), offsetBefore: 7400, contentHeightBefore: 8000, anchorYBefore: 30, generation: 1)
        XCTAssertEqual(hold.offsetForInsert(metrics(offset: 7400, content: 11_200)), 10_600)
        XCTAssertNil(hold.offsetForAnchor(y: 3230, measuredIn: 0, metrics: metrics(offset: 10_600, content: 11_200)), "Stale: ignored")
        XCTAssertFalse(hold.settled)
        XCTAssertEqual(hold.offsetForAnchor(y: 59, measuredIn: 1, metrics: metrics(offset: 10_600, content: 11_229)), 10_629, "Fresh: corrected exactly")
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 10_629, content: 11_229)))
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 10_629, content: 11_229)))
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 10_629, content: 11_229)))
        XCTAssertTrue(hold.settled)
    }

    func testResidualKickIsUndoneBeforeTheHoldEnds() {
        // The scroll to the visible anchor lands, but a pass later the rows sit
        // 1.2pt higher. Same-pass readings that look in place don't end the hold;
        // the residual is corrected exactly and only confirming readings settle it.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(69), offsetBefore: 1300, contentHeightBefore: 12_000,
                                   anchorYBefore: 30, generation: 1, insertMovesOffset: false)
        _ = hold.offsetForInsert(metrics(offset: 1300, content: 14_500))
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3780, content: 14_500), confirming: false))
        XCTAssertNil(hold.offsetForAnchor(y: 30.1, measuredIn: 1, metrics: metrics(offset: 3780, content: 14_500), confirming: false))
        XCTAssertEqual(hold.inPlaceReads, 0, "Same-pass readings never count as in place")
        XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3780, content: 14_500)))
        XCTAssertFalse(hold.settled)
        // The landing finishes: every row 1.2pt up.
        let corrected = hold.offsetForAnchor(y: 28.8, measuredIn: 1, metrics: metrics(offset: 3780, content: 14_500))
        XCTAssertEqual(corrected ?? 0, 3778.8, accuracy: 0.0001, "Undone exactly")
        XCTAssertEqual(hold.inPlaceReads, 0)
        for _ in 0..<ChatPrependHold.stableReads {
            XCTAssertFalse(hold.settled)
            XCTAssertNil(hold.offsetForAnchor(y: 30, measuredIn: 1, metrics: metrics(offset: 3778.8, content: 14_500)))
        }
        XCTAssertTrue(hold.settled)
    }

    func testSettledHoldIsAlwaysWithinHalfAPoint() {
        // Drifts from 0.3 to 1.7pt (what a device pass saw) are all corrected; a
        // reading inside the tolerance is under half a point by construction.
        XCTAssertLessThan(ChatPrependHold.tolerance, 0.5)
        for drift in [0.3, -0.3, 0.6, -1.0, 1.7, -1.7] {
            var hold = ChatPrependHold(anchor: ChatLongSeed.id(69), offsetBefore: 0, contentHeightBefore: 8000,
                                       anchorYBefore: 100, generation: 1, insertMovesOffset: false)
            _ = hold.offsetForInsert(metrics(offset: 0, content: 9000))
            let target = hold.offsetForAnchor(y: 100 + drift, measuredIn: 1, metrics: metrics(offset: 500, content: 9000))
            XCTAssertEqual(target ?? 500, 500 + drift, accuracy: 0.0001, "drift \(drift)")
        }
    }

    func testFailedRowStickingOutBelowMovesTheListByExactlyThat() {
        // AX5, keyboard up: the list is 371pt tall, the failed row (ND + Retry at
        // its bottom) ends 28pt below it after the composer settled.
        let m = ChatScrollMetrics(offset: 1000, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 371)
        XCTAssertEqual(ChatRowFit.offset(rowTop: 250, rowBottom: 395, metrics: m), 1028)
        XCTAssertNil(ChatRowFit.offset(rowTop: 222, rowBottom: 366, metrics: m), "Inside the list: nothing to do")
        XCTAssertNil(ChatRowFit.offset(rowTop: 222, rowBottom: 367.3, metrics: m), "Within half a point")
    }

    func testFailedRowFitIsClampedToTheContent() {
        let m = ChatScrollMetrics(offset: 1125, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 371)
        XCTAssertEqual(m.maxOffset, 1133)
        XCTAssertEqual(ChatRowFit.offset(rowTop: 250, rowBottom: 420, metrics: m), 1133, "Never past the end")
        let atEnd = ChatScrollMetrics(offset: 1133, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 371)
        XCTAssertNil(ChatRowFit.offset(rowTop: 250, rowBottom: 420, metrics: atEnd), "Can't move further: no change")
    }

    func testFailedRowTopIsBroughtInOnlyWhenTheWholeRowFits() {
        let m = ChatScrollMetrics(offset: 1000, topInset: 20, bottomInset: 4, contentHeight: 1500, viewportHeight: 371)
        XCTAssertEqual(ChatRowFit.offset(rowTop: 10, rowBottom: 200, metrics: m), 990, "Top under the inset: down by 10")
        XCTAssertNil(ChatRowFit.offset(rowTop: 19.7, rowBottom: 200, metrics: m), "Within half a point")
        XCTAssertNil(ChatRowFit.offset(rowTop: -100, rowBottom: 360, metrics: m), "Taller than the list: bottom lines win")
    }

    // MARK: Cycles across run-loop turns, tracked rows, failed-row fit

    func testPinStopsFollowingAContentCycleThatSpansTurns() {
        // Each turn: a correction, the lazy stack re-estimates, the content size
        // moves, the next turn corrects again. The per-turn budget refills every
        // turn, so on its own it never ends that.
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        var moves = 0
        var now = 10.0
        for turn in 1...20 {
            m.contentHeight = 8000 + Double(turn % 2 == 0 ? 40 : -40)
            if let target = pin.observe(m, change: .content, now: now) {
                moves += 1
                m.offset = target
            }
            pin.turnEnded()
            now += 0.004
        }
        XCTAssertEqual(moves, ChatBottomPin.cycleLimit, "Cut after the limit, not after 20 turns")
        XCTAssertTrue(pin.suspended)
        XCTAssertTrue(pin.pinned, "Still pinned: only the automatic following stopped")
        m.viewportHeight -= 50
        XCTAssertNil(pin.observe(m, change: .viewport, now: now + 0.2), "Nothing is followed mid-cycle, whatever moved")
        XCTAssertEqual(pin.observe(m, change: .viewport, now: now + 1.3), m.maxOffset, "A second of quiet ends it")
        XCTAssertFalse(pin.suspended)
    }

    func testTheSameCycleThroughTheInsetsIsCutToo() {
        // contentMargins or the keyboard rewriting the insets on each layout pass:
        // the inset change re-pins, the move lays out, the insets move back.
        var (pin, m) = pinnedAtBottom()
        var moves = 0
        var now = 3.0
        for turn in 1...40 {
            m.bottomInset = turn % 2 == 0 ? 40 : 12
            let change: ChatBottomPin.Change = turn % 3 == 0 ? .offset : .insets
            if let target = pin.observe(m, change: change, now: now) {
                moves += 1
                m.offset = target
            }
            pin.turnEnded()
            now += 0.002
        }
        XCTAssertLessThanOrEqual(moves, ChatBottomPin.cycleLimit)
        XCTAssertTrue(pin.suspended)
    }

    func testTheKeyboardOpeningAndClosingNeverLooksLikeACycle() {
        var (pin, m) = pinnedAtBottom()
        var now = 0.0
        for _ in 1...30 {
            m.viewportHeight = m.viewportHeight == 600 ? 300 : 600
            if let target = pin.observe(m, change: .viewport, now: now) { m.offset = target }
            XCTAssertEqual(m.offset, m.maxOffset, "Every open and close is followed")
            pin.turnEnded()
            now += 0.6
        }
        XCTAssertFalse(pin.suspended)
    }

    func testDiscreteEventsResumeFollowing() {
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        for turn in 1...ChatBottomPin.cycleLimit + 1 {
            m.contentHeight = 8000 + Double(turn) * 10
            if let target = pin.observe(m, change: .content) { m.offset = target }
            pin.turnEnded()
        }
        XCTAssertTrue(pin.suspended)
        pin.endChanged()
        XCTAssertFalse(pin.suspended, "A new row at the end is a new event")
        m.contentHeight += 30
        XCTAssertEqual(pin.observe(m, change: .content), m.maxOffset)
        for turn in 1...ChatBottomPin.cycleLimit {
            m.contentHeight += Double(turn)
            if let target = pin.observe(m, change: .content) { m.offset = target }
            pin.turnEnded()
        }
        XCTAssertTrue(pin.suspended)
        pin.jumped(toBottom: true)
        XCTAssertFalse(pin.suspended, "Jump to latest resumes")
        _ = pin.observe(m, change: .offset, interacting: true)
        XCTAssertFalse(pin.suspended, "So does the person's own scroll")
    }

    func testASendThatFailsAtAX5StaysUnderTheCycleLimit() {
        // The real sequence: new row, failed (both end changes), then header and
        // composer settling: a few content and inset-driven corrections.
        var (pin, m) = pinnedAtBottom()
        pin.endChanged()
        m.contentHeight += 60
        XCTAssertNotNil(pin.observe(m, change: .content))
        m.offset = m.maxOffset
        pin.endChanged()
        for _ in 0..<2 {
            m.contentHeight += 27
            XCTAssertNotNil(pin.observe(m, change: .content))
            m.offset = m.maxOffset
        }
        pin.turnEnded()
        m.topInset += 55
        m.offset += 55
        XCTAssertNotNil(pin.observe(m, change: .offset), "Next turn: the header coming back")
        XCTAssertFalse(pin.suspended)
    }

    func testTrackedRowsAreStampedWithTheGenerationWhenTheyReport() {
        var rows = ChatTrackedRows()
        let a = ChatLongSeed.id(68), b = ChatLongSeed.id(69)
        rows.moved(a, frame: ChatRowFrame(minY: 1000, height: 40))
        rows.moved(b, frame: ChatRowFrame(minY: 1042, height: 40))
        XCTAssertEqual(rows.framesMeasured(since: 0).count, 2)
        // Page 1 is handed to the list: what was measured before is generation 0.
        rows.begin(generation: 1)
        XCTAssertTrue(rows.framesMeasured(since: 1).isEmpty, "Nothing measured in the new layout yet")
        rows.moved(b, frame: ChatRowFrame(minY: 3542, height: 40))
        XCTAssertEqual(rows.measured(b)?.generation, 1, "A report after the page went in is from a layout that has it")
        XCTAssertEqual(rows.measured(a)?.generation, 0)
        XCTAssertEqual(Set(rows.framesMeasured(since: 1).keys), [b])
    }

    func testHoldAnchorSurvivesATransientDisappear() {
        var rows = ChatTrackedRows()
        let anchor = ChatLongSeed.id(69), other = ChatLongSeed.id(70)
        rows.moved(anchor, frame: ChatRowFrame(minY: 1042, height: 40))
        rows.moved(other, frame: ChatRowFrame(minY: 1084, height: 40))
        XCTAssertFalse(rows.gone(anchor, holdAnchor: anchor), "The lazy stack re-creating it mid-insert keeps its reading")
        XCTAssertNotNil(rows.frames[anchor])
        XCTAssertTrue(rows.gone(other, holdAnchor: anchor))
        XCTAssertNil(rows.frames[other], "Any other row that leaves can't claim it's on screen")
        XCTAssertTrue(rows.gone(anchor, holdAnchor: nil), "Without a hold it leaves like any row")
        XCTAssertNil(rows.frames[anchor])
    }

    func testVisibleAnchorHoldMarksTheInsertWithoutMovingSoStepTwoCanRun() {
        // The controller has to store the hold after offsetForInsert even when it
        // returns nil: until 1c7fe9f it dropped that copy, insertApplied never
        // stuck, step 2 never ran, and the scroll to the anchor's unit point left
        // -0.3 to -1.7pt of drift on every visible row.
        var hold = ChatPrependHold(anchor: ChatLongSeed.id(69), offsetBefore: 1300, contentHeightBefore: 8000,
                                   anchorYBefore: 250.33, generation: 1, insertMovesOffset: false)
        XCTAssertNil(hold.offsetForInsert(metrics(offset: 1300, content: 10500)), "No move on estimated growth")
        XCTAssertTrue(hold.insertApplied)
        let landed = metrics(offset: 3800, content: 10500)
        XCTAssertEqual(hold.offsetForAnchor(y: 249.33, measuredIn: 1, metrics: landed, confirming: false) ?? 0, 3799, accuracy: 0.0001,
                       "The 1pt the scroll left is corrected exactly")
        XCTAssertNil(hold.offsetForAnchor(y: 250.33, measuredIn: 1, metrics: metrics(offset: 3799, content: 10500)))
        XCTAssertFalse(hold.settled, "One still reading isn't enough")
    }

    func testFailedFitWithoutAFrameGoesToTheBottom() {
        // AX5, keyboard up, the 279 landing: the list stopped 28pt short of the end
        // and the row's frame never came in.
        let short = ChatScrollMetrics(offset: 1105, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 159)
        let decision = ChatFailedFit.decide(contentTop: nil, height: nil, metrics: short)
        XCTAssertEqual(decision.reason, .bottom)
        XCTAssertEqual(decision.offset, short.maxOffset)
        XCTAssertEqual(short.maxOffset, 1345, "Content end with the bottom inset applied")
        let there = ChatScrollMetrics(offset: 1345, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 159)
        XCTAssertNil(ChatFailedFit.decide(contentTop: nil, height: nil, metrics: there).offset)
        XCTAssertEqual(ChatFailedFit.decide(contentTop: nil, height: nil, metrics: there).reason, .atBottom)
        XCTAssertEqual(ChatFailedFit.decide(contentTop: 1400, height: 0, metrics: short).reason, .bottom, "A zero first report isn't a frame")
    }

    func testFailedFitFromAFrameMovesRetryInside() {
        // Row measured in content coordinates: "Not delivered" + Retry end 11pt
        // below the list (Retry 382 vs 371 in screen terms, list 159pt tall).
        let m = ChatScrollMetrics(offset: 1200, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 159)
        let decision = ChatFailedFit.decide(contentTop: 1200 + 67, height: 103, metrics: m)
        XCTAssertEqual(decision.reason, .fitFromFrame)
        XCTAssertEqual(decision.offset ?? 0, 1200 + (67 + 103 - 155), accuracy: 0.0001, "Up by exactly what sticks out")
        let inside = ChatFailedFit.decide(contentTop: 1200 + 40, height: 103, metrics: m)
        XCTAssertNil(inside.offset)
        XCTAssertEqual(inside.reason, .fits)
    }

    func testFailedFitSaysWhenTheContentEndsTooSoon() {
        // At the end already and the row still sticks out: the content size is
        // behind the row (logged as clamped, not silently skipped).
        let m = ChatScrollMetrics(offset: 1345, topInset: 0, bottomInset: 4, contentHeight: 1500, viewportHeight: 159)
        let decision = ChatFailedFit.decide(contentTop: 1345 + 80, height: 103, metrics: m)
        XCTAssertNil(decision.offset)
        XCTAssertEqual(decision.reason, .clamped)
    }

    // MARK: Prepend landing and settling (6f41b07 paging residual)

    func testScrollToTheVisibleAnchorLandsItBackExactlyWithABottomMargin() {
        // 6f41b07 paging, msg 70: top at 48.57, unitY 0.10, 16 pt content margin.
        // Against the whole viewport the framework landed it 1.67 pt up; against the
        // visible part it lands where it was.
        let id = UUID()
        let frames = [id: ChatRowFrame(minY: 6248.57, height: 60)]
        let viewport = 520.0
        let whole = ChatPrependHold.visibleAnchor(frames: frames, offset: 6200, viewportHeight: viewport)!
        let wholeLanding = ChatPrependHold.landing(unitY: whole.unitY, height: 60, viewportHeight: viewport, bottomInset: 16)
        XCTAssertEqual(wholeLanding - whole.y, -whole.unitY * 16, accuracy: 0.001, "The old residual: unitY times the margin")
        XCTAssertGreaterThan(abs(wholeLanding - whole.y), 1)

        let visible = ChatPrependHold.visibleAnchor(frames: frames, offset: 6200, viewportHeight: viewport, bottomInset: 16)!
        XCTAssertEqual(visible.id, id)
        XCTAssertEqual(visible.y, 48.57, accuracy: 0.001)
        XCTAssertEqual(ChatPrependHold.landing(unitY: visible.unitY, height: 60, viewportHeight: viewport, bottomInset: 16), visible.y, accuracy: 0.001)
    }

    func testVisibleAnchorLandsExactlyWithTopAndBottomInsets() {
        let a = UUID(), b = UUID()
        let frames = [a: ChatRowFrame(minY: 1005, height: 80), b: ChatRowFrame(minY: 1030, height: 50)]
        // a's top is under the 20 pt top inset, so b is the topmost whole row.
        let restore = ChatPrependHold.visibleAnchor(frames: frames, offset: 990, viewportHeight: 400, topInset: 20, bottomInset: 16)!
        XCTAssertEqual(restore.id, b)
        XCTAssertEqual(ChatPrependHold.landing(unitY: restore.unitY, height: 50, viewportHeight: 400, topInset: 20, bottomInset: 16), restore.y, accuracy: 0.001)
    }

    func testARowBehindTheBottomMarginIsNotAVisibleAnchor() {
        let id = UUID()
        let frames = [id: ChatRowFrame(minY: 540, height: 50)]
        XCTAssertNotNil(ChatPrependHold.visibleAnchor(frames: frames, offset: 0, viewportHeight: 600))
        XCTAssertNil(ChatPrependHold.visibleAnchor(frames: frames, offset: 0, viewportHeight: 600, bottomInset: 16), "Its bottom is under the margin")
    }

    func testStillReadingsWaitForTheListToBeQuietBeforeSettling() {
        // 6f41b07: three still readings came 2 ms apart, the hold ended, and
        // the framework's scroll to the anchor landed afterwards, 1.67 pt off.
        var hold = ChatPrependHold(anchor: UUID(), offsetBefore: 100, contentHeightBefore: 1000, anchorYBefore: 48.57, generation: 1, insertMovesOffset: false)
        var m = ChatScrollMetrics(offset: 100, topInset: 0, bottomInset: 16, contentHeight: 1490, viewportHeight: 520)
        XCTAssertNil(hold.offsetForInsert(m, now: 10.000))
        XCTAssertEqual(hold.offsetForAnchor(y: 46.90, metrics: m, confirming: false, now: 10.001)!, 98.33, accuracy: 0.001, "Corrected against the pre-insert y")
        m.offset = 98.33
        for t in [10.002, 10.003, 10.004] {
            XCTAssertNil(hold.offsetForAnchor(y: 48.57, metrics: m, now: t))
        }
        XCTAssertFalse(hold.settled, "Three still readings in 3 ms aren't the list at rest")
        XCTAssertTrue(hold.waitingForQuiet)
        // The framework applies its scroll to the anchor: the list moves, the row is off.
        hold.listMoved(at: 10.05)
        m.offset = 100
        XCTAssertEqual(hold.offsetForAnchor(y: 46.90, metrics: m, now: 10.051)!, 98.33, accuracy: 0.001, "Undone exactly, still measured from the pre-insert y")
        m.offset = 98.33
        hold.listMoved(at: 10.052)
        for t in [10.06, 10.07, 10.08] { _ = hold.offsetForAnchor(y: 48.57, metrics: m, now: t) }
        XCTAssertFalse(hold.settled)
        XCTAssertNil(hold.offsetForAnchor(y: 48.57, metrics: m, now: 10.052 + ChatPrependHold.settleQuiet + 0.001))
        XCTAssertTrue(hold.settled, "Still and quiet: done, at the pre-insert y")
    }

    func testWithoutAClockStillReadingsSettleAsBefore() {
        var hold = ChatPrependHold(anchor: UUID(), offsetBefore: 0, contentHeightBefore: 100, anchorYBefore: 10, insertMovesOffset: false)
        let m = ChatScrollMetrics(offset: 0, topInset: 0, bottomInset: 0, contentHeight: 600, viewportHeight: 300)
        _ = hold.offsetForInsert(m)
        for _ in 0..<ChatPrependHold.stableReads { _ = hold.offsetForAnchor(y: 10, metrics: m) }
        XCTAssertTrue(hold.settled)
    }

    func testViewportStickUsesThePinSlack() {
        XCTAssertEqual(ChatViewportStick.pinnedSlack, 32)
        let near = metrics(offset: 7670, content: 8000, viewport: 300)
        var shorter = near
        shorter.viewportHeight = 250
        XCTAssertEqual(ChatViewportStick.offset(before: near, after: shorter), 7750, "30pt from the bottom still sticks")
    }

    // MARK: Pending open (push before or after the chat's first load)

    func testPushBeforeTheFirstLoadOpensWhenItFinishes() {
        var open = ChatPendingOpen()
        let id = ChatLongSeed.id(0)
        XCTAssertNil(open.request(id), "Cold launch: the history isn't here yet, so hold it")
        XCTAssertEqual(open.target, id)
        XCTAssertEqual(open.chatLoaded(), id, "Opens when the first load finishes")
        XCTAssertNil(open.target)
        XCTAssertNil(open.chatLoaded(), "Exactly once: a later reload doesn't open it again")
    }

    func testPushAfterTheFirstLoadOpensRightAway() {
        var open = ChatPendingOpen()
        XCTAssertNil(open.chatLoaded())
        let id = ChatLongSeed.id(0)
        XCTAssertEqual(open.request(id), id)
        XCTAssertNil(open.request(id), "The same push settling again doesn't reopen it")
        XCTAssertNil(open.chatLoaded())
    }

    func testANewerPushReplacesAHeldOne() {
        var open = ChatPendingOpen()
        XCTAssertNil(open.request(ChatLongSeed.id(1)))
        XCTAssertNil(open.request(ChatLongSeed.id(2)))
        XCTAssertEqual(open.chatLoaded(), ChatLongSeed.id(2))
    }

    func testSquadChangeWaitsForThatSquadsLoad() {
        var open = ChatPendingOpen()
        _ = open.chatLoaded()
        open.chatReset()
        XCTAssertNil(open.request(ChatLongSeed.id(3)), "The new squad's history isn't loaded yet")
        XCTAssertEqual(open.chatLoaded(), ChatLongSeed.id(3))
        open.clear()
        XCTAssertFalse(open.chatReady)
        XCTAssertNil(open.request(ChatLongSeed.id(3)), "Sign-out forgets what was opened; held until the next load")
        XCTAssertEqual(open.chatLoaded(), ChatLongSeed.id(3))
    }

    func testLongSeedIsMoreThanOneRead() {
        let messages = ChatLongSeed.messages(viewerId: me, squadId: squad, now: base)
        XCTAssertGreaterThan(messages.count, SupabaseChatService.historyLimit)
        XCTAssertEqual(Set(messages.map(\.id)).count, messages.count)
        XCTAssertEqual(messages.first?.sentAt, messages[1].sentAt, "Pairs share a second, so paging has to break ties")
    }
}

private final class LogBox: @unchecked Sendable {
    var log = ChatLog()
}

/// The same paths through the session model (mock backend, injected outbox).
@MainActor
final class ChatDurabilityModelTests: XCTestCase {
    private func model(_ scenario: LaunchScenario, outbox: ChatOutbox) -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: scenario,
            outbox: outbox
        )
    }

    private func tempOutbox() -> ChatOutbox {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("outbox-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: dir) }
        return ChatOutbox(directory: dir)
    }

    private let me = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    func testOlderPagesLoadKeepThePlaceAndEndAtTheStart() async {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        await model.reloadChat()
        XCTAssertEqual(model.log.entries.count, 200)
        XCTAssertEqual(model.olderPaging.state, .idle)
        await model.loadOlder()
        XCTAssertEqual(model.log.entries.count, 250)
        XCTAssertEqual(model.log.ordered.first?.id, ChatLongSeed.id(10))
        await model.loadOlder()
        XCTAssertEqual(model.log.entries.count, 260)
        XCTAssertEqual(model.olderPaging.state, .reachedStart)
    }

    func testFlingAskingTwiceLoadsOnePageThenTheNext() async throws {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        await model.reloadChat()
        // A slow page, so the second ask really lands while the first is running.
        let mock = try XCTUnwrap(model.mockChatService)
        mock.olderDelay = 0.2
        let first = Task { await model.loadOlder() }
        var spins = 0
        while model.olderPaging.state != .loading, spins < 200 {
            await Task.yield()
            spins += 1
        }
        let running = model.olderPaging.state
        XCTAssertEqual(running, .loading, "The first page never started")
        await model.loadOlder()
        let afterSecond = model.log.entries.count
        XCTAssertEqual(afterSecond, 200, "The second ask returned without starting a page")
        await first.value
        let reads = mock.olderReads
        XCTAssertEqual(reads, 1, "Two asks during one page are one read")
        XCTAssertEqual(model.log.entries.count, 250, "Two asks during one page are one page")
        XCTAssertEqual(model.olderPaging.state, .idle, "Back to idle, so the list can ask again")
        await model.loadOlder()
        XCTAssertEqual(model.olderPaging.state, .reachedStart)
    }

    func testPushedOldMessageIsPagedInThenOpened() async {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        await model.reloadChat()
        await model.reveal(messageId: ChatLongSeed.id(0))
        XCTAssertEqual(model.followSend, ChatLongSeed.id(0))
        await model.reveal(messageId: UUID())
        XCTAssertEqual(model.chatToast, ChatReveal.notInChatText)
    }

    func testWarmPushForAMessageTheChatHasNotReceivedYetOpensIt() async throws {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        await model.reloadChat()
        let mock = try XCTUnwrap(model.mockChatService)
        let newest = try XCTUnwrap(model.log.ordered.last?.sentAt)
        let pushed = RemoteMessage(id: UUID(), squadId: ChatSeed.squadId, senderId: ChatSeed.otherId, body: "beat the socket", sentAt: newest.addingTimeInterval(5))
        mock.seed(pushed)
        let before = model.log.entries.count
        await model.reveal(messageId: pushed.id)
        XCTAssertEqual(model.followSend, pushed.id, "The pushed message opens")
        XCTAssertEqual(model.chatToast, "", "No 'too far back' or 'not in this chat' line")
        XCTAssertEqual(model.log.entries.count, before + 1)
        XCTAssertEqual(mock.olderReads, 0, "A newer message doesn't page back")
    }

    func testPushArrivingBeforeTheFirstLoadOpensTheOldMessage() async {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        model.requestOpen(messageId: ChatLongSeed.id(0))
        let early = model.followSend
        XCTAssertNil(early, "Nothing to open before the history is here")
        await model.reloadChat()
        let opened = model.followSend
        XCTAssertEqual(opened, ChatLongSeed.id(0), "Opened from the end of the first load")
        XCTAssertEqual(model.log.entries.count, 260)
    }

    func testPushArrivingAfterTheFirstLoadOpensTheOldMessage() async {
        let model = model(.chatLongHistory, outbox: tempOutbox())
        await model.reloadChat()
        model.requestOpen(messageId: ChatLongSeed.id(0))
        await model.openTask?.value
        let opened = model.followSend
        XCTAssertEqual(opened, ChatLongSeed.id(0))
        // Once: a reload doesn't page back and open it again.
        model.followSend = nil
        await model.reloadChat()
        let again = model.followSend
        XCTAssertNil(again)
    }

    func testUnsentMessageIsRestoredAndRetriedWithItsId() async {
        let outbox = tempOutbox()
        let id = UUID()
        outbox.add(OutboxItem(id: id, squadId: ChatSeed.squadId, senderId: me, body: "from before the kill", createdAt: Date()))
        let model = model(.chatPolish, outbox: outbox)
        await model.reloadChat()
        let restored = model.log.entries.first { $0.id == id }
        XCTAssertEqual(restored?.delivery, .failed)
        await model.retry(id)
        let sent = model.log.entries.first { $0.id == id }
        XCTAssertEqual(sent?.delivery, .sent)
        XCTAssertTrue(outbox.load(squadId: ChatSeed.squadId, userId: me).isEmpty)
    }

    func testSignOutClearsTheOutbox() async {
        let outbox = tempOutbox()
        outbox.add(OutboxItem(id: UUID(), squadId: ChatSeed.squadId, senderId: me, body: "left behind", createdAt: Date()))
        let model = model(.chatPolish, outbox: outbox)
        await model.signOut()
        XCTAssertTrue(outbox.load(squadId: ChatSeed.squadId, userId: me).isEmpty)
    }
}
