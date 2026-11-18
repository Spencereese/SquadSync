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
        XCTAssertNil(hold.offsetForAnchor(y: 450.3, metrics: metrics(offset: 3240, content: 11_240)), "Within half a point")
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
        for _ in 0..<3 {
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

    // MARK: Staying at the bottom

    func testFailedLastMessageKeepsAReaderAtTheBottom() {
        // AX5 with the keyboard up: the reader is at the bottom, their message fails
        // and grows by "Not delivered" + Retry. The list goes back to the bottom,
        // however far the row grew (here 27pt, past a distance-only check).
        var pin = ChatBottomPin()
        var m = metrics(offset: 7700, content: 8000, viewport: 300)
        XCTAssertNil(pin.observe(m))
        XCTAssertTrue(pin.pinned)
        m.contentHeight += 27
        XCTAssertEqual(pin.observe(m), 7727, "Back to the bottom after the failed row lays out")
        m.offset = 7727
        XCTAssertNil(pin.observe(m))
        XCTAssertTrue(pin.pinned)
        m.contentHeight += 120
        XCTAssertEqual(pin.observe(m), 7847, "Any growth of the last row, not just under the slack")
    }

    func testHeaderAndComposerChangingOnSendStayPinned() {
        // On Send the header comes back (top inset +55, offset +55 in the same pass)
        // and the field shrinks (bottom inset -27), then the row fails and grows.
        // None of that is the person scrolling, so they stay pinned to the end.
        var pin = ChatBottomPin()
        var m = metrics(offset: 7700, content: 8000, viewport: 300)
        _ = pin.observe(m)
        m.topInset += 55
        m.offset += 55
        _ = pin.observe(m)
        XCTAssertTrue(pin.pinned, "Insets and offset moving together isn't a scroll")
        m.bottomInset -= 27
        let afterShrink = pin.observe(m)
        XCTAssertTrue(pin.pinned)
        XCTAssertEqual(afterShrink, m.maxOffset)
        m.offset = m.maxOffset
        m.contentHeight += 28
        XCTAssertEqual(pin.observe(m), m.maxOffset, "The failed row lays out and the list follows it")
        m.offset = m.maxOffset
        XCTAssertEqual(m.distanceFromBottom, 0)
    }

    func testReaderWhoScrolledUpIsNotPulledDown() {
        var pin = ChatBottomPin()
        var m = metrics(offset: 7700, content: 8000, viewport: 300)
        _ = pin.observe(m)
        m.offset = 7600
        XCTAssertNil(pin.observe(m, interacting: true))
        XCTAssertFalse(pin.pinned, "100pt up unpins")
        m.contentHeight += 40
        XCTAssertNil(pin.observe(m), "A new or failed row doesn't move someone reading up")
        m.topInset += 55
        m.offset += 55
        XCTAssertNil(pin.observe(m))
        XCTAssertFalse(pin.pinned, "Only the person re-pins")
        m.offset = m.maxOffset - 20
        XCTAssertNil(pin.observe(m, interacting: true))
        XCTAssertTrue(pin.pinned, "Within \(ChatBottomPin.slack)pt of the bottom pins again")
    }

    func testPushOpenJumpUnpinsAndIsNotPulledBack() {
        var pin = ChatBottomPin()
        var m = metrics(offset: 7700, content: 8000, viewport: 300)
        _ = pin.observe(m)
        pin.jumped(toBottom: false)
        m.offset = 0
        XCTAssertNil(pin.observe(m), "The jump to message 1 isn't undone")
        m.contentHeight += 60
        XCTAssertNil(pin.observe(m), "Later layout (lazy row heights, a new row) doesn't pull it down")
        m.bottomInset += 30
        XCTAssertNil(pin.observe(m))
        XCTAssertFalse(pin.pinned)
    }

    func testJumpToLatestPins() {
        var pin = ChatBottomPin()
        var m = metrics(offset: 3000, content: 8000, viewport: 300)
        _ = pin.observe(m, interacting: true)
        XCTAssertFalse(pin.pinned)
        pin.jumped(toBottom: true)
        XCTAssertEqual(pin.observe(m), 7700, "Goes (and stays) at the newest message")
        m.offset = 7700
        m.contentHeight += 27
        XCTAssertEqual(pin.observe(m), 7727)
    }

    func testPinWaitsOutDragsAndOlderPages() {
        var pin = ChatBottomPin()
        var m = metrics(offset: 7700, content: 8000, viewport: 300)
        _ = pin.observe(m)
        m.contentHeight += 30
        XCTAssertNil(pin.observe(m, interacting: true), "Never fights a finger or a fling")
        XCTAssertTrue(pin.pinned, "30pt is within the slack")
        m.contentHeight += 2000
        XCTAssertNil(pin.observe(m, holding: true), "An older page being held in place wins")
        pin.jumped(toBottom: false)
        pin.reset()
        XCTAssertTrue(pin.pinned, "A new squad opens at the newest message")
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
