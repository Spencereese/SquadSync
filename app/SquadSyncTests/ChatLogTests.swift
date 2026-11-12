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

    func testPollAndRealtimeDedupeById() {
        let them = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var log = ChatLog()
        let id = UUID()
        let row = ChatEntry(id: id, senderId: them, body: "hi", sentAt: start, delivery: .sent)
        log.ingest([row])
        ChatBackfill.apply(&log, history: [row, row])
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(RealtimeLink.connected.polls, false)
        XCTAssertEqual(RealtimeLink.reconnecting.polls, true)
        XCTAssertEqual(RealtimeLink.down.polls, true)
    }

    func testReconnectBackfillAddsTheMissedRow() {
        let them = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var log = ChatLog()
        let kept = UUID()
        let missed = UUID()
        log.ingest([ChatEntry(id: kept, senderId: them, body: "kept", sentAt: start, delivery: .sent)])
        ChatBackfill.apply(&log, history: [
            ChatEntry(id: kept, senderId: them, body: "kept", sentAt: start, delivery: .sent),
            ChatEntry(id: missed, senderId: them, body: "missed", sentAt: start.addingTimeInterval(5), delivery: .sent)
        ])
        XCTAssertEqual(log.ordered.map(\.body), ["kept", "missed"])
    }

    func testInviteErrorsMatchTheServerCodes() {
        XCTAssertEqual(InviteProblem.from(serverCode: "expired"), .expired)
        XCTAssertEqual(InviteProblem.from(serverCode: "invalid"), .revokedOrUnknown)
        XCTAssertEqual(InviteProblem.from(serverCode: "full"), .full)
        XCTAssertEqual(InviteProblem.from(serverCode: "already_in_squad"), .alreadyInASquad)
        XCTAssertEqual(InviteProblem.expired.message, "This invite has expired.")
        XCTAssertEqual(InviteProblem.full.message, "That squad is full (8).")
        XCTAssertTrue(InviteProblem.revokedOrUnknown.message.contains("revoked"))
        XCTAssertEqual(InviteProblem.alreadyInASquad.message, "You're already in a squad.")
    }

    func testReactionToggleReplacesAndRemoves() {
        var board = ReactionBoard()
        let message = UUID()
        let user = UUID()
        XCTAssertEqual(board.toggle(messageId: message, userId: user, emoji: "👍"), [.insert("👍")])
        XCTAssertEqual(board.toggle(messageId: message, userId: user, emoji: "🎮"), [.remove("👍"), .insert("🎮")])
        XCTAssertEqual(board.marks.map(\.emoji), ["🎮"])
        XCTAssertEqual(board.toggle(messageId: message, userId: user, emoji: "🎮"), [.remove("🎮")])
        XCTAssertTrue(board.marks.isEmpty)
    }

    func testUnreadIgnoresTheCursorInstantAndOwnMessages() {
        let me = UUID()
        let them = UUID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        var log = ChatLog()
        log.ingest([
            ChatEntry(id: UUID(), senderId: them, body: "at cursor", sentAt: start, delivery: .sent),
            ChatEntry(id: UUID(), senderId: me, body: "mine later", sentAt: start.addingTimeInterval(5), delivery: .sent),
            ChatEntry(id: UUID(), senderId: them, body: "after", sentAt: start.addingTimeInterval(5), delivery: .sent)
        ])
        log.markRead(at: start)
        XCTAssertEqual(log.unreadCount(viewerId: me), 1)
        XCTAssertEqual(
            Receipts.seenNames(
                messageSentAt: start,
                reads: [(id: them, name: "Riley", at: start)],
                viewerId: me
            ),
            ["Riley"]
        )
    }

    func testCancellationIsNotAStatus() {
        XCTAssertTrue(RequestNoise.isCancellation(CancellationError()))
        XCTAssertTrue(RequestNoise.isCancellation(URLError(.cancelled)))
        XCTAssertTrue(RequestNoise.isCancellation(BackendFailure.rejected("cancelled")))
        let ns = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertTrue(RequestNoise.isCancellation(ns))
        XCTAssertFalse(RequestNoise.isCancellation(BackendFailure.rejected("Squad is full.")))
    }

    func testSendIsConfirmedWithoutAnEcho() {
        var log = ChatLog()
        let id = UUID()
        let me = UUID()
        log.beginSend(id: id, senderId: me, body: "rt test 3", now: Date())
        XCTAssertEqual(OutboundSend.result(error: nil), .sent)
        if OutboundSend.result(error: nil) == .sent { log.markSent(id: id) }
        XCTAssertEqual(log.entries.first?.delivery, .sent)
        XCTAssertEqual(OutboundSend.result(error: CancellationError()), .staySending)
        log.ingest([ChatEntry(id: id, senderId: me, body: "rt test 3", sentAt: Date(), delivery: .sent)])
        XCTAssertEqual(log.entries.count, 1)
    }

    func testBackfillAfterAGapKeepsTheOldRowAndAddsTheNewOne() {
        var log = ChatLog()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let them = UUID()
        let kept = ChatEntry(id: UUID(), senderId: them, body: "kept", sentAt: start, delivery: .sent)
        let missed = ChatEntry(id: UUID(), senderId: them, body: "rt test 3", sentAt: start.addingTimeInterval(30), delivery: .sent)
        log.ingest([kept])
        XCTAssertEqual(ChatBackfill.missing(in: log, history: [kept, missed]).map(\.body), ["rt test 3"])
        ChatBackfill.apply(&log, history: [kept, missed])
        XCTAssertEqual(log.ordered.map(\.body), ["kept", "rt test 3"])
    }

    func testEmptySquadNameUsesYourSquad() {
        XCTAssertEqual(SquadTitle.line(name: "", memberCount: 1), "Your squad · 1 of 8")
        XCTAssertEqual(SquadTitle.line(name: "   ", memberCount: 1), "Your squad · 1 of 8")
        XCTAssertEqual(SquadTitle.line(name: "Friday", memberCount: 3), "Friday · 3 of 8")
    }

    func testReloadDecodesTheSquadName() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000002","owner_id":"00000000-0000-0000-0000-000000000001","name":"Friday"}
        """.data(using: .utf8)!
        let reloaded = try JSONDecoder().decode(SquadDetails.self, from: json)
        XCTAssertEqual(reloaded.name, "Friday")
        XCTAssertEqual(reloaded.ownerId.uuidString, "00000000-0000-0000-0000-000000000001")
        XCTAssertEqual(SquadSelect.columns, "id,owner_id,name")
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
