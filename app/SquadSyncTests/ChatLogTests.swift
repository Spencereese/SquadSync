import XCTest
@testable import SquadSync

final class ChatLogTests: XCTestCase {
    private let me = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let them = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    func testSendThenSent() {
        var log = ChatLog()
        let id = UUID()
        log.beginSend(id: id, senderId: me, body: "hi", now: start)
        XCTAssertEqual(log.entries.first?.delivery, .sending)
        log.markSent(id: id)
        XCTAssertEqual(log.entries.first?.delivery, .sent)
    }

    func testFailedRetryKeepsTheSameId() {
        var log = ChatLog()
        let id = UUID()
        log.beginSend(id: id, senderId: me, body: "hi", now: start)
        log.markFailed(id: id)
        XCTAssertEqual(log.entries.first?.delivery, .failed)
        log.retry(id: id)
        XCTAssertEqual(log.entries.map(\.id), [id])
        XCTAssertEqual(log.entries.first?.delivery, .sending)
        log.markSent(id: id)
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(log.entries.first?.delivery, .sent)
    }

    func testDuplicateEchoDoesNotDoubleTheRow() {
        var log = ChatLog()
        let id = UUID()
        log.beginSend(id: id, senderId: me, body: "hi", now: start)
        let echo = ChatEntry(id: id, senderId: me, body: "hi", sentAt: start, delivery: .sent)
        log.ingest([echo, echo])
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(log.entries.first?.delivery, .sent)
    }

    func testOrderingIsTimeThenId() {
        var log = ChatLog()
        let later = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
        let earlier = UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
        log.ingest([
            ChatEntry(id: later, senderId: them, body: "second", sentAt: start.addingTimeInterval(10), delivery: .sent),
            ChatEntry(id: earlier, senderId: them, body: "first", sentAt: start, delivery: .sent)
        ])
        XCTAssertEqual(log.ordered.map(\.body), ["first", "second"])
    }

    func testUnreadCountsOthersAfterTheCursor() {
        var log = ChatLog()
        log.ingest([
            ChatEntry(id: UUID(), senderId: them, body: "old", sentAt: start, delivery: .sent),
            ChatEntry(id: UUID(), senderId: me, body: "mine", sentAt: start.addingTimeInterval(5), delivery: .sent),
            ChatEntry(id: UUID(), senderId: them, body: "new", sentAt: start.addingTimeInterval(10), delivery: .sent)
        ])
        log.markRead(at: start.addingTimeInterval(1))
        XCTAssertEqual(log.unreadCount(viewerId: me), 1)
    }
}

final class AuthSessionTests: XCTestCase {
    func testRestoreReturnsTheSavedSession() {
        let store = MemorySessionStore()
        let session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: "a@b.c"
        )
        store.save(session)
        let auth = MockAuthService(store: store)
        XCTAssertEqual(auth.restore(), session)
    }

    func testSignOutClearsTheRestoredSession() async {
        let store = MemorySessionStore()
        store.save(AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userId: UUID(),
            email: "a@b.c"
        ))
        let auth = MockAuthService(store: store)
        await auth.signOut()
        XCTAssertNil(auth.restore())
    }

    func testLaunchBackendDefaultsToMock() {
        let options = LaunchOptions.current(["SquadSync", "-screen", "inbox"])
        XCTAssertEqual(options.backend, .mock)
        XCTAssertEqual(LaunchOptions.current(["-backend", "live"]).backend, .live)
    }
}
