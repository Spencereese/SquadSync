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
    func testRestoreReturnsTheSavedSession() throws {
        let store = MemorySessionStore()
        let session = AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: "a@b.c"
        )
        try store.save(session)
        let auth = MockAuthService(store: store)
        XCTAssertEqual(try auth.restore(), session)
    }

    func testSignOutClearsTheRestoredSession() async throws {
        let store = MemorySessionStore()
        try store.save(AuthSession(
            accessToken: "access",
            refreshToken: "refresh",
            userId: UUID(),
            email: "a@b.c"
        ))
        let auth = MockAuthService(store: store)
        try await auth.signOut()
        XCTAssertNil(try auth.restore())
    }

    func testLaunchBackendDefaultsToMock() {
        let options = LaunchOptions.current(["SquadSync", "-screen", "inbox"])
        XCTAssertEqual(options.backend, .mock)
        XCTAssertEqual(LaunchOptions.current(["-backend", "live"]).backend, .live)
    }
}

final class BackendConfigTests: XCTestCase {
    func testParseReadsBothKeys() {
        let config = BackendConfig.parse([
            "SupabaseURL": "https://sfckxrnoiwetmzdycqaa.supabase.co",
            "SupabaseAnonKey": "anon-key"
        ])
        XCTAssertEqual(config.url?.host, "sfckxrnoiwetmzdycqaa.supabase.co")
        XCTAssertTrue(config.isConfigured)
        XCTAssertNil(config.configurationError)
    }

    func testEmptyDictionaryNamesBothKeys() {
        let config = BackendConfig.parse([:])
        XCTAssertFalse(config.isConfigured)
        XCTAssertEqual(
            config.configurationError,
            "Supabase is not configured. Empty: SupabaseURL, SupabaseAnonKey."
        )
    }

    func testPlaceholderKeyNamesOnlyTheAnonKey() {
        let config = BackendConfig.parse([
            "SupabaseURL": "https://sfckxrnoiwetmzdycqaa.supabase.co",
            "SupabaseAnonKey": "paste-anon-key-here"
        ])
        XCTAssertEqual(
            config.configurationError,
            "Supabase is not configured. Empty: SupabaseAnonKey."
        )
    }
}

final class SignInCodeTests: XCTestCase {
    func testAcceptsSixThroughTenDigits() {
        XCTAssertTrue(SignInCode.isValid("123456"))
        XCTAssertTrue(SignInCode.isValid("12345678"))
        XCTAssertTrue(SignInCode.isValid(" 1234567890 "))
        XCTAssertFalse(SignInCode.isValid("12345"))
        XCTAssertFalse(SignInCode.isValid("12345678901"))
        XCTAssertFalse(SignInCode.isValid("12345a"))
        XCTAssertFalse(SignInCode.isValid(""))
    }
}

final class SquadNameTests: XCTestCase {
    func testTrimsToOneThroughFortyCharacters() {
        XCTAssertNil(SquadName.validationError(" A "))
        XCTAssertNil(SquadName.validationError(String(repeating: "a", count: 40)))
        XCTAssertEqual(SquadName.validationError("   "), "Enter a squad name.")
        XCTAssertEqual(
            SquadName.validationError(String(repeating: "a", count: 41)),
            "Use 40 characters or fewer."
        )
    }

    func testCreateSquadKeepsTheTrimmedName() async throws {
        let service = MockSquadService()
        let squad = try await service.createSquad(ownerId: UUID(), name: "  Friday  ")
        XCTAssertEqual(squad.name, "Friday")
        let again = MockSquadService()
        do {
            _ = try await again.createSquad(ownerId: UUID(), name: " ")
            XCTFail("A blank name should be rejected.")
        } catch let failure as BackendFailure {
            XCTAssertEqual(failure, .rejected("Enter a squad name."))
        }
    }
}

final class KeychainFallbackTests: XCTestCase {
    func testMissingEntitlementFallsBackOnlyWhenAllowed() {
        let status = KeychainFallbackPolicy.missingEntitlement
        XCTAssertEqual(
            KeychainFallbackPolicy.choose(status: status, allowsFallback: true),
            .insecureFallback
        )
        XCTAssertEqual(
            KeychainFallbackPolicy.choose(status: status, allowsFallback: false),
            .failure(status)
        )
    }

    func testOtherKeychainErrorsStayFailures() {
        let status: OSStatus = -25299
        XCTAssertEqual(
            KeychainFallbackPolicy.choose(status: status, allowsFallback: true),
            .failure(status)
        )
    }

    func testSuccessAndMissingItemStayOnTheKeychain() {
        XCTAssertEqual(KeychainFallbackPolicy.choose(status: 0, allowsFallback: false), .keychain)
        XCTAssertEqual(KeychainFallbackPolicy.choose(status: -25300, allowsFallback: true), .keychain)
    }
}
