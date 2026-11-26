import XCTest
@testable import SquadSync

/// Side-thread reply pushes: the payload, where a tap goes, when it banners, and
/// the side-thread panel's rules. Foundation only, so it runs on Linux too.
final class SideThreadPushTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private let thread = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    private let otherThread = UUID(uuidString: "00000000-0000-0000-0000-00000000B0FF")!
    private let reply = UUID(uuidString: "00000000-0000-0000-0000-00000000B103")!
    private let viewer = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let riley = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

    private var threadPayload: PushPayload {
        PushPayload(kind: .thread, squadId: squad, messageId: reply, threadId: thread)
    }

    func testAThreadPayloadParsesWithItsThreadAndReply() {
        let parsed = PushPayloadParser.parse([
            "type": "thread_message",
            "squad_id": squad.uuidString.lowercased(),
            "thread_id": thread.uuidString.lowercased(),
            "message_id": reply.uuidString.lowercased()
        ])
        XCTAssertEqual(parsed, threadPayload)
        let json = "{\"aps\":{\"alert\":{\"title\":\"Riley in Ranked\",\"body\":\"on in 5\"}},\"type\":\"thread_message\",\"squad_id\":\"\(squad.uuidString)\",\"thread_id\":\"\(thread.uuidString)\",\"message_id\":\"\(reply.uuidString)\"}"
        XCTAssertEqual(PushPayloadParser.parse(jsonText: json), threadPayload)
    }

    func testAThreadPayloadWithoutItsThreadOrReplyIsIgnored() {
        XCTAssertNil(PushPayloadParser.parse([
            "type": "thread_message",
            "squad_id": squad.uuidString,
            "message_id": reply.uuidString
        ]))
        XCTAssertNil(PushPayloadParser.parse([
            "type": "thread_message",
            "squad_id": squad.uuidString,
            "thread_id": thread.uuidString
        ]))
        XCTAssertNil(PushPayloadParser.parse([
            "type": "thread_message",
            "squad_id": squad.uuidString,
            "thread_id": "not-a-uuid",
            "message_id": reply.uuidString
        ]))
    }

    func testASquadMessageStillParsesWithNoThread() {
        let chat = PushPayloadParser.parse([
            "type": "squad_message",
            "squad_id": squad.uuidString,
            "message_id": reply.uuidString,
            "thread_id": thread.uuidString
        ])
        XCTAssertEqual(chat, PushPayload(kind: .chat, squadId: squad, messageId: reply))
        XCTAssertNil(chat?.threadId, "A squad message never carries a thread, even if the payload has one")
    }

    func testEachKindGoesToItsOwnPlace() {
        XCTAssertEqual(PushDestination.of(threadPayload), .thread(thread, reply: reply))
        XCTAssertEqual(PushDestination.of(PushPayload(kind: .chat, squadId: squad, messageId: reply)), .chat(message: reply))
        XCTAssertEqual(PushDestination.of(PushPayload(kind: .squad, squadId: squad, messageId: nil)), .squad)
    }

    func testAThreadReplyBannersUnlessThatThreadIsOpen() {
        XCTAssertFalse(PushBanner.shows(viewingSquad: squad, viewingThread: thread, payload: threadPayload))
        XCTAssertTrue(PushBanner.shows(viewingSquad: squad, viewingThread: otherThread, payload: threadPayload))
        XCTAssertTrue(PushBanner.shows(viewingSquad: squad, viewingThread: nil, payload: threadPayload), "The squad chat on screen isn't the side thread")
        XCTAssertTrue(PushBanner.shows(viewingSquad: nil, viewingThread: nil, payload: threadPayload))
        XCTAssertTrue(PushBanner.shows(viewingSquad: squad, payload: threadPayload), "The two-argument check never hides a thread reply")
    }

    func testAnOpenSideThreadLetsSquadMessagesBanner() {
        let chat = PushPayload(kind: .chat, squadId: squad, messageId: reply)
        XCTAssertTrue(PushBanner.shows(viewingSquad: squad, viewingThread: thread, payload: chat), "The side thread covers the chat")
        XCTAssertFalse(PushBanner.shows(viewingSquad: squad, viewingThread: nil, payload: chat))
        XCTAssertFalse(PushBanner.shows(viewingSquad: squad, payload: chat))
    }

    func testADebugThreadTapPlansLikeAChatTap() {
        let json = "{\"type\":\"thread_message\",\"squad_id\":\"\(squad.uuidString)\",\"thread_id\":\"\(thread.uuidString)\",\"message_id\":\"\(reply.uuidString)\"}"
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: nil), .atLaunch(threadPayload))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "12"), .later(threadPayload, seconds: 12))
    }

    private func row(_ id: String, thread: UUID? = nil, sender: UUID? = nil, at seconds: TimeInterval, body: String = "gg") -> SideThreadMessage {
        SideThreadMessage(
            id: UUID(uuidString: id)!,
            threadId: thread ?? self.thread,
            squadId: squad,
            senderId: sender ?? riley,
            body: body,
            sentAt: Date(timeIntervalSince1970: seconds)
        )
    }

    func testThePanelMergesInTimeOrderOnePerIdAndOnlyItsThread() {
        var panel = SideThreadPanel(threadId: thread, focus: reply)
        panel.merge([
            row("00000000-0000-0000-0000-00000000B102", at: 20),
            row("00000000-0000-0000-0000-00000000B101", at: 10)
        ])
        panel.merge([
            row("00000000-0000-0000-0000-00000000B102", at: 20, body: "edited"),
            row(reply.uuidString, at: 30),
            row("00000000-0000-0000-0000-00000000C001", thread: otherThread, at: 25)
        ])
        XCTAssertEqual(panel.messages.map(\.id.uuidString), [
            "00000000-0000-0000-0000-00000000B101",
            "00000000-0000-0000-0000-00000000B102",
            reply.uuidString
        ])
        XCTAssertEqual(panel.messages[1].body, "edited")
        XCTAssertTrue(panel.focusLoaded)
        XCTAssertEqual(panel.newest, Date(timeIntervalSince1970: 30))
    }

    func testTheFocusIsOnlyLoadedOnceItsRowIsThere() {
        var panel = SideThreadPanel(threadId: thread, focus: reply)
        XCTAssertFalse(panel.focusLoaded)
        panel.merge([row("00000000-0000-0000-0000-00000000B101", at: 10)])
        XCTAssertFalse(panel.focusLoaded)
        XCTAssertFalse(SideThreadPanel(threadId: thread, focus: nil).focusLoaded)
    }

    func testSendingNeedsALoadedThreadAndRealText() {
        var panel = SideThreadPanel(threadId: thread, focus: nil)
        panel.draft = "on my way"
        XCTAssertFalse(panel.canSend, "Not while loading")
        panel.load = .ready
        XCTAssertTrue(panel.canSend)
        XCTAssertNil(panel.outgoing(id: reply, senderId: viewer, now: Date()), "No thread info yet, so no squad to file it under")
        panel.info = SideThreadInfo(id: thread, squadId: squad, kind: "side_group", title: "Ranked")
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        panel.draft = "  on my way \n"
        let out = panel.outgoing(id: reply, senderId: viewer, now: now)
        XCTAssertEqual(out, SideThreadMessage(id: reply, threadId: thread, squadId: squad, senderId: viewer, body: "on my way", sentAt: now))
        panel.sending = true
        XCTAssertFalse(panel.canSend, "Not twice at once")
        panel.sending = false
        panel.draft = "   \n "
        XCTAssertFalse(panel.canSend, "Blank")
        panel.draft = String(repeating: "x", count: SideThreadCopy.maxLength + 1)
        XCTAssertFalse(panel.canSend, "Too long")
        panel.draft = String(repeating: "x", count: SideThreadCopy.maxLength)
        XCTAssertTrue(panel.canSend)
        panel.load = .notFound
        XCTAssertFalse(panel.canSend)
    }

    func testTheTitleNamesTheGroupOrTheOtherPerson() {
        let names = [viewer: "Spencer", riley: "Riley"]
        let group = SideThreadInfo(id: thread, squadId: squad, kind: "side_group", title: " Ranked ")
        XCTAssertEqual(SideThreadCopy.title(info: group, memberIds: [viewer, riley], viewerId: viewer, names: names), "Ranked")
        XCTAssertEqual(SideThreadCopy.context(info: group, memberIds: [viewer, riley]), "Side group · 2 people")
        XCTAssertEqual(SideThreadCopy.context(info: group, memberIds: [viewer]), "Side group · 1 person")
        let untitled = SideThreadInfo(id: thread, squadId: squad, kind: "side_group", title: "  ")
        XCTAssertEqual(SideThreadCopy.title(info: untitled, memberIds: [], viewerId: viewer, names: names), "Side thread")
        let dm = SideThreadInfo(id: thread, squadId: squad, kind: "dm", title: nil)
        XCTAssertEqual(SideThreadCopy.title(info: dm, memberIds: [viewer, riley], viewerId: viewer, names: names), "Riley")
        XCTAssertEqual(SideThreadCopy.context(info: dm, memberIds: [viewer, riley]), "Direct message")
        XCTAssertEqual(SideThreadCopy.title(info: dm, memberIds: [viewer], viewerId: viewer, names: names), "Direct message")
        XCTAssertEqual(SideThreadCopy.title(info: nil, memberIds: [], viewerId: viewer, names: names), "Side thread")
        XCTAssertEqual(SideThreadCopy.context(info: nil, memberIds: []), "")
    }

    func testRowIdentifiersAreLowercaseIds() {
        XCTAssertEqual(SideThreadIdentifiers.row(reply), "side-thread-message-00000000-0000-0000-0000-00000000b103")
    }

    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")

    func testTheServiceReadsTheNewestPageAndReturnsItOldestFirst() async throws {
        let body = """
        [{"id":"\(reply.uuidString.lowercased())","thread_id":"\(thread.uuidString.lowercased())","squad_id":"\(squad.uuidString.lowercased())","sender_id":"\(riley.uuidString.lowercased())","body":"on in 5","sent_at":"2026-11-26T09:02:00.123456+00:00"},
         {"id":"00000000-0000-0000-0000-00000000b101","thread_id":"\(thread.uuidString.lowercased())","squad_id":"\(squad.uuidString.lowercased())","sender_id":"\(riley.uuidString.lowercased())","body":"ranked?","sent_at":"2026-11-26T09:00:00+00:00"}]
        """
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let rows = try await service.messages(threadId: thread, limit: 100)
        XCTAssertEqual(rows.map(\.body), ["ranked?", "on in 5"])
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.path, "/rest/v1/sq8_thread_messages")
        let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(query.contains(URLQueryItem(name: "thread_id", value: "eq.\(thread.uuidString)")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "order", value: "sent_at.desc,id.desc")))
        XCTAssertTrue(query.contains(URLQueryItem(name: "limit", value: "100")))
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access")
    }

    func testTheServiceReadsTheThreadAndItsMembers() async throws {
        let info = "[{\"id\":\"\(thread.uuidString.lowercased())\",\"squad_id\":\"\(squad.uuidString.lowercased())\",\"kind\":\"dm\",\"title\":null}]"
        let members = "[{\"user_id\":\"\(viewer.uuidString.lowercased())\"},{\"user_id\":\"\(riley.uuidString.lowercased())\"}]"
        let transport = ScriptedTransport(responses: [(200, Data(info.utf8)), (200, Data(members.utf8)), (200, Data("[]".utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let found = try await service.thread(id: thread)
        XCTAssertEqual(found, SideThreadInfo(id: thread, squadId: squad, kind: "dm", title: nil))
        XCTAssertEqual(found?.isDirect, true)
        let ids = try await service.members(threadId: thread)
        XCTAssertEqual(ids, [viewer, riley])
        let missing = try await service.thread(id: otherThread)
        XCTAssertNil(missing, "Row level security hides a thread you're not in: an empty list")
        XCTAssertEqual(transport.requests.map { $0.url?.path ?? "" }, [
            "/rest/v1/sq8_threads",
            "/rest/v1/sq8_thread_members",
            "/rest/v1/sq8_threads"
        ])
    }

    func testTheServiceSendsTheRowWithTheClientId() async throws {
        let transport = ScriptedTransport(responses: [(201, Data())])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let message = SideThreadMessage(id: reply, threadId: thread, squadId: squad, senderId: viewer, body: "omw", sentAt: Date(timeIntervalSince1970: 1_700_000_000))
        try await service.send(message)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.path, "/rest/v1/sq8_thread_messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "return=minimal,resolution=ignore-duplicates")
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: request.httpBody ?? Data()) as? [String: Any])
        XCTAssertEqual(Set(sent.keys), ["id", "thread_id", "squad_id", "sender_id", "body", "sent_at"])
        XCTAssertEqual((sent["id"] as? String)?.lowercased(), reply.uuidString.lowercased())
        XCTAssertEqual((sent["thread_id"] as? String)?.lowercased(), thread.uuidString.lowercased())
        XCTAssertEqual(sent["body"] as? String, "omw")
    }

    func testARefusedSendThrows() async {
        let transport = ScriptedTransport(responses: [(403, Data("{\"code\":\"42501\",\"message\":\"new row violates row-level security policy\"}".utf8))])
        let service = SupabaseSideThreadService(config: config, accessToken: "access", transport: transport)
        let message = SideThreadMessage(id: reply, threadId: thread, squadId: squad, senderId: viewer, body: "omw", sentAt: Date())
        do {
            try await service.send(message)
            XCTFail("A refused insert should throw")
        } catch {
        }
    }
}

/// The coordinator and the session model with a side-thread tap (Mac only).
@MainActor
final class SideThreadPushModelTests: XCTestCase {
    private let squad = ChatSeed.squadId
    private let thread = MockSideThreadService.threadId
    private let reply = MockSideThreadService.replyId

    private func payload(squad: UUID? = nil) -> [AnyHashable: Any] {
        [
            "type": "thread_message",
            "squad_id": (squad ?? self.squad).uuidString,
            "thread_id": thread.uuidString,
            "message_id": reply.uuidString
        ]
    }

    func testALandedThreadTapOpensTheThreadNotTheChat() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        defer { coordinator.resetForTests() }
        let start = coordinator.coverSerial
        coordinator.receive(payload())
        coordinator.settle(signedIn: false, squadId: nil, membershipKnown: false)
        XCTAssertNil(coordinator.threadOpen, "Held until signed in")
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.threadOpen, PushThreadOpen(thread: thread, reply: reply))
        XCTAssertFalse(coordinator.openedChat)
        XCTAssertFalse(coordinator.openedSquad)
        XCTAssertNil(coordinator.focusMessage, "The squad chat isn't scrolled for a side-thread reply")
        XCTAssertEqual(coordinator.coverSerial, start + 1, "Sheets over the chat close, like a chat tap")
        XCTAssertEqual(coordinator.takeThreadOpen(), PushThreadOpen(thread: thread, reply: reply))
        XCTAssertNil(coordinator.takeThreadOpen(), "Handed over once")
    }

    func testAThreadTapForAnotherSquadSaysYouAreNotInIt() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        defer { coordinator.resetForTests() }
        coordinator.receive(payload(squad: UUID(uuidString: "00000000-0000-0000-0000-000000000099")!))
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.notice, PushNotice.notAMember)
        XCTAssertNil(coordinator.threadOpen)
    }

    func testTheOpenThreadDoesNotBannerAndSignOutForgetsIt() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        defer { coordinator.resetForTests() }
        coordinator.viewingSquad = squad
        XCTAssertTrue(coordinator.showsBanner(payload()))
        coordinator.viewingThread = thread
        XCTAssertFalse(coordinator.showsBanner(payload()))
        _ = coordinator.signOutAction()
        XCTAssertNil(coordinator.viewingThread)
        XCTAssertTrue(coordinator.showsBanner(payload()))
    }

    private func model() -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .invite
        )
    }

    func testOpeningLoadsTheThreadWithTheTappedReplyAndMarksItViewed() async {
        PushCoordinator.shared.resetForTests()
        defer { PushCoordinator.shared.resetForTests() }
        let model = model()
        model.openSideThread(thread, reply: reply)
        XCTAssertEqual(PushCoordinator.shared.viewingThread, thread)
        await model.loadSideThread()
        let panel = model.sideThread
        XCTAssertEqual(panel?.load, .ready)
        XCTAssertEqual(panel?.info?.title, "Ranked")
        XCTAssertTrue(panel?.focusLoaded == true, "The tapped reply is in the panel")
        XCTAssertEqual(panel?.messages.last?.body, "On in 5, bring the mic")
        XCTAssertEqual(panel?.note, "")
        model.closeSideThread()
        XCTAssertNil(model.sideThread)
        XCTAssertNil(PushCoordinator.shared.viewingThread)
    }

    func testAReplyThatIsGoneSaysSo() async {
        PushCoordinator.shared.resetForTests()
        defer { PushCoordinator.shared.resetForTests() }
        let model = model()
        model.openSideThread(thread, reply: UUID(uuidString: "00000000-0000-0000-0000-00000000B1FF")!)
        await model.loadSideThread()
        XCTAssertEqual(model.sideThread?.load, .ready)
        XCTAssertEqual(model.sideThread?.note, SideThreadCopy.replyMissing)
    }

    func testAThreadThatIsNotThereIsNotAvailable() async {
        PushCoordinator.shared.resetForTests()
        defer { PushCoordinator.shared.resetForTests() }
        let model = model()
        model.openSideThread(UUID(uuidString: "00000000-0000-0000-0000-00000000B0FF")!, reply: reply)
        await model.loadSideThread()
        XCTAssertEqual(model.sideThread?.load, .notFound)
        XCTAssertFalse(model.sideThread?.canSend ?? true)
    }

    func testAReplyIsSentToTheThreadAndShows() async {
        PushCoordinator.shared.resetForTests()
        defer { PushCoordinator.shared.resetForTests() }
        let model = model()
        model.openSideThread(thread, reply: reply)
        await model.loadSideThread()
        model.sideThread?.draft = "  omw  "
        await model.sendSideThreadReply()
        XCTAssertEqual(model.mockSideThreadSends.count, 1)
        let sent = model.mockSideThreadSends.first
        XCTAssertEqual(sent?.body, "omw")
        XCTAssertEqual(sent?.threadId, thread)
        XCTAssertEqual(sent?.squadId, squad)
        XCTAssertEqual(sent?.senderId, model.viewerId)
        XCTAssertEqual(model.sideThread?.draft, "")
        XCTAssertEqual(model.sideThread?.messages.last?.body, "omw")
        XCTAssertEqual(model.sideThread?.focus, sent?.id, "Your own reply is scrolled to")
        XCTAssertFalse(model.sideThread?.sending ?? true)
    }

    func testSignOutClosesTheThread() async {
        PushCoordinator.shared.resetForTests()
        defer { PushCoordinator.shared.resetForTests() }
        let model = model()
        model.openSideThread(thread, reply: reply)
        await model.loadSideThread()
        await model.signOut()
        XCTAssertNil(model.sideThread)
        XCTAssertNil(PushCoordinator.shared.viewingThread)
    }
}
