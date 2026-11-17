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

    func testScrollAnchorHoldsThePreviousTopMessage() {
        var log = ChatLog()
        log.ingest([remote(10, at: 100), remote(11, at: 110)].map { $0.entry() })
        let top = ChatScrollAnchor.before(log)
        XCTAssertEqual(top, ChatLongSeed.id(10))
        XCTAssertNil(ChatScrollAnchor.after(previousTop: top, log: log), "Nothing was added above it")
        log.ingest([remote(8, at: 80), remote(9, at: 90)].map { $0.entry() })
        XCTAssertEqual(ChatScrollAnchor.after(previousTop: top, log: log), ChatLongSeed.id(10))
        XCTAssertNil(ChatScrollAnchor.after(previousTop: UUID(), log: log), "Gone (another squad) means no jump")
        XCTAssertNil(ChatScrollAnchor.after(previousTop: nil, log: log))
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
        XCTAssertFalse(paging.shouldLoad(rowVisible: true, pinnedToBottom: false, hasMessages: true), "Failed waits for Retry, no auto loop")
        XCTAssertTrue(paging.begin(), "Retry starts the page again")
        paging.finish(rowCount: 50)
        XCTAssertEqual(paging.state, .idle)
    }

    func testRowOnlyLoadsWhenScrolledUpToIt() {
        let paging = ChatOlderPaging()
        XCTAssertTrue(paging.shouldLoad(rowVisible: true, pinnedToBottom: false, hasMessages: true))
        XCTAssertFalse(paging.shouldLoad(rowVisible: true, pinnedToBottom: true, hasMessages: true), "First render draws the top before jumping down")
        XCTAssertFalse(paging.shouldLoad(rowVisible: false, pinnedToBottom: false, hasMessages: true))
        XCTAssertFalse(paging.shouldLoad(rowVisible: true, pinnedToBottom: false, hasMessages: false))
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
        XCTAssertEqual(model.olderLanding?.anchor, ChatLongSeed.id(60), "The old top message goes back to the top")
        await model.loadOlder()
        XCTAssertEqual(model.log.entries.count, 260)
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
