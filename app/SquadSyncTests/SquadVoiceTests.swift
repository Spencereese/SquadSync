import XCTest
@testable import SquadSync

// Squad voice (Stream): the token function's answers, the room's states, and
// that nothing ever shows a connection that didn't happen. Foundation only
// (no @MainActor), so the Linux harness runs these too.

final class SquadVoiceScriptTransport: HTTPTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var queue: [(Int, Data)]
    private(set) var requests: [URLRequest] = []
    var offline = false

    init(_ responses: [(Int, String)]) {
        queue = responses.map { ($0.0, Data($0.1.utf8)) }
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let (next, isOffline) = lock.withLock { () -> ((Int, Data), Bool) in
            requests.append(request)
            return (queue.isEmpty ? (500, Data()) : queue.removeFirst(), offline)
        }
        if isOffline { throw URLError(.notConnectedToInternet) }
        let response = HTTPURLResponse(url: request.url!, statusCode: next.0, httpVersion: nil, headerFields: nil)!
        return (next.1, response)
    }
}

final class SquadVoiceRefresher: TokenRefreshing {
    var result: TokenRefreshResult
    private(set) var calls = 0
    init(_ result: TokenRefreshResult) { self.result = result }
    func refreshAfterRejection() async -> TokenRefreshResult {
        calls += 1
        return result
    }
}

final class FakeSquadVoiceTokens: SquadVoiceTokenFetching {
    var result: Result<SquadVoiceGrant, SquadVoiceProblem>
    private(set) var calls = 0
    init(_ result: Result<SquadVoiceGrant, SquadVoiceProblem>) { self.result = result }
    func grant(squadId: UUID) async throws -> SquadVoiceGrant {
        calls += 1
        return try result.get()
    }
}

/// A stand-in for a linked SDK: connects only when told to, reports members.
final class FakeSquadVoiceEngine: SquadVoiceEngine {
    var isLinked = true
    var onMembers: (([SquadVoiceMember]) -> Void)?
    var onDropped: ((String) -> Void)?
    var connectError: Error?
    var muteError: Error?
    var roster: [SquadVoiceMember] = []
    private(set) var connected: [SquadVoiceGrant] = []
    private(set) var mutes: [Bool] = []
    private(set) var leaves = 0

    func connect(_ grant: SquadVoiceGrant, name: String, muted: Bool) async throws -> [SquadVoiceMember] {
        if let connectError { throw connectError }
        connected.append(grant)
        return roster
    }

    func setMuted(_ muted: Bool) async throws {
        if let muteError { throw muteError }
        mutes.append(muted)
    }

    func leave() async { leaves += 1 }
}

final class SquadVoiceTests: XCTestCase {
    private let squad = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let grantJSON = """
    {"ok":true,"api_key":"testkey","token":"a.b.c","user_id":"u1","call_type":"default",\
    "call_id":"sq8-11111111-2222-4333-8444-555555555555","expires_at":"2026-11-19T21:30:00Z"}
    """

    private var grant: SquadVoiceGrant {
        SquadVoiceGrant(apiKey: "testkey", token: "a.b.c", userId: "u1", callType: "default",
                        callId: "sq8-\(squad.uuidString.lowercased())", expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
    }

    private let you = SquadVoiceMember(id: "u1", name: "Spencer", muted: false, speaking: false, isYou: true)

    // MARK: The function's answers

    func testAMemberGetsTheGrant() throws {
        let outcome = SquadVoiceFunction.outcome(status: 200, body: Data(grantJSON.utf8))
        let grant = try outcome.get()
        XCTAssertEqual(grant.apiKey, "testkey")
        XCTAssertEqual(grant.callType, "default")
        XCTAssertEqual(grant.callId, "sq8-11111111-2222-4333-8444-555555555555")
        XCTAssertEqual(grant.expiresAt, ISO8601DateFormatter().date(from: "2026-11-19T21:30:00Z"))
    }

    func testNotDeployedAndSecretsUnsetAreBothNotSetUp() {
        let missing = SquadVoiceFunction.outcome(status: 404, body: Data(#"{"code":"NOT_FOUND","message":"Requested function was not found"}"#.utf8))
        XCTAssertEqual(missing, .failure(.notSetUp))
        let unset = SquadVoiceFunction.outcome(status: 503, body: Data(#"{"ok":false,"reason":"voice_not_configured"}"#.utf8))
        XCTAssertEqual(unset, .failure(.notSetUp))
        XCTAssertEqual(SquadVoiceProblem.notSetUp.message, "Voice isn't set up yet")
    }

    func testOtherAnswersSayWhatHappened() {
        XCTAssertEqual(SquadVoiceFunction.outcome(status: 401, body: Data()), .failure(.signedOut))
        XCTAssertEqual(SquadVoiceFunction.outcome(status: 403, body: Data()), .failure(.notMember))
        guard case .failure(.failed(let text)) = SquadVoiceFunction.outcome(status: 502, body: Data(#"{"ok":false,"reason":"membership_unreadable"}"#.utf8)) else {
            return XCTFail("502 should be a plain failure")
        }
        XCTAssertTrue(text.contains("502"), text)
    }

    func testAnUnreadableSuccessIsNotAGrant() {
        let empty = SquadVoiceFunction.outcome(status: 200, body: Data(#"{"ok":true}"#.utf8))
        guard case .failure(.failed) = empty else { return XCTFail("a 200 without a token must not connect") }
        let blankToken = SquadVoiceFunction.outcome(status: 200, body: Data(grantJSON.replacingOccurrences(of: "a.b.c", with: "").utf8))
        guard case .failure(.failed) = blankToken else { return XCTFail("an empty token must not connect") }
    }

    func testTheRequestNamesTheSquadInLowercase() throws {
        let body = SquadVoiceFunction.requestBody(squadId: squad)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: String]
        XCTAssertEqual(json?["squad_id"], "11111111-2222-4333-8444-555555555555")
    }

    func testTheGrantIsRefreshedBeforeItRunsOut() {
        let soon = grant.expiresAt.addingTimeInterval(-SquadVoiceGrant.refreshMargin)
        XCTAssertTrue(grant.needsRefresh(now: soon))
        XCTAssertFalse(grant.needsRefresh(now: soon.addingTimeInterval(-1)))
    }

    // MARK: The token client

    func testTheClientPostsAsTheSignedInUser() async throws {
        let transport = SquadVoiceScriptTransport([(200, grantJSON)])
        let client = SupabaseSquadVoiceTokens(config: config, currentToken: { "user-jwt" }, transport: transport)
        let got = try await client.grant(squadId: squad)
        XCTAssertEqual(got.callId, "sq8-11111111-2222-4333-8444-555555555555")
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.url?.absoluteString, "https://example.supabase.co/functions/v1/sq8-voice-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer user-jwt")
        XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "anon-test")
    }

    func testThe503IsNotSetUpNotAConnection() async {
        let transport = SquadVoiceScriptTransport([(503, #"{"ok":false,"reason":"voice_not_configured"}"#)])
        let client = SupabaseSquadVoiceTokens(config: config, currentToken: { "user-jwt" }, transport: transport)
        do {
            _ = try await client.grant(squadId: squad)
            XCTFail("503 must not produce a grant")
        } catch {
            XCTAssertEqual(error as? SquadVoiceProblem, .notSetUp)
        }
    }

    func testA401RefreshesOnceAndRetriesWithTheNewToken() async throws {
        let transport = SquadVoiceScriptTransport([(401, #"{"ok":false,"reason":"signed_out"}"#), (200, grantJSON)])
        let refresher = SquadVoiceRefresher(.refreshed("fresh-jwt"))
        let client = SupabaseSquadVoiceTokens(config: config, currentToken: { "old-jwt" }, refresher: refresher, transport: transport)
        _ = try await client.grant(squadId: squad)
        let auths = transport.requests.map { $0.value(forHTTPHeaderField: "Authorization") }
        XCTAssertEqual(auths, ["Bearer old-jwt", "Bearer fresh-jwt"])
        XCTAssertEqual(refresher.calls, 1)
    }

    func testARejectedRefreshIsSignedOut() async {
        let transport = SquadVoiceScriptTransport([(401, "{}")])
        let client = SupabaseSquadVoiceTokens(config: config, currentToken: { "old-jwt" }, refresher: SquadVoiceRefresher(.rejected), transport: transport)
        do {
            _ = try await client.grant(squadId: squad)
            XCTFail("expected signed out")
        } catch {
            XCTAssertEqual(error as? SquadVoiceProblem, .signedOut)
        }
    }

    func testNoSessionAndOfflineAreSaidPlainly() async {
        let signedOut = SupabaseSquadVoiceTokens(config: config, currentToken: { nil }, transport: SquadVoiceScriptTransport([]))
        do { _ = try await signedOut.grant(squadId: squad); XCTFail("expected signed out") } catch {
            XCTAssertEqual(error as? SquadVoiceProblem, .signedOut)
        }
        let transport = SquadVoiceScriptTransport([])
        transport.offline = true
        let offline = SupabaseSquadVoiceTokens(config: config, currentToken: { "jwt" }, transport: transport)
        do { _ = try await offline.grant(squadId: squad); XCTFail("expected offline") } catch {
            XCTAssertEqual(error as? SquadVoiceProblem, .offline)
        }
    }

    func testAnUnconfiguredAppIsNotSetUpAndSendsNothing() async {
        let transport = SquadVoiceScriptTransport([])
        let client = SupabaseSquadVoiceTokens(config: BackendConfig(urlText: "", anonKey: ""), currentToken: { "jwt" }, transport: transport)
        do { _ = try await client.grant(squadId: squad); XCTFail("expected not set up") } catch {
            XCTAssertEqual(error as? SquadVoiceProblem, .notSetUp)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    // MARK: The room

    func testThisBuildWithoutTheSDKSaysNotSetUpAndAsksForNothing() async {
        let tokens = FakeSquadVoiceTokens(.success(grant))
        let session = SquadVoiceSession(tokens: tokens, engine: UnlinkedSquadVoiceEngine())
        await session.join(squadId: squad, name: "Spencer")
        let state = session.state
        XCTAssertEqual(state.phase, .notSetUp)
        XCTAssertEqual(state.statusLine, "Voice isn't set up yet")
        XCTAssertFalse(state.joined)
        XCTAssertTrue(state.members.isEmpty, "Nobody is shown in a room that isn't there")
        XCTAssertEqual(tokens.calls, 0, "No token is asked for when nothing could use it")
        XCTAssertEqual(state.pillTitle, "Voice · not set up")
    }

    func testFunctionMissingOrSecretsUnsetNeverConnects() async {
        let engine = FakeSquadVoiceEngine()
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.failure(.notSetUp)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        let state = session.state
        XCTAssertEqual(state.phase, .notSetUp)
        XCTAssertFalse(state.joined)
        XCTAssertTrue(engine.connected.isEmpty)
        XCTAssertTrue(state.canJoin, "Check again stays possible")
        XCTAssertEqual(state.joinTitle, "Check again")
    }

    func testJoinConnectsWithTheGrantAndShowsWhoIsIn() async {
        let engine = FakeSquadVoiceEngine()
        engine.roster = [you]
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        var seen: [SquadVoicePhase] = []
        session.onChange = { seen.append($0.phase) }
        await session.join(squadId: squad, name: "Spencer")
        let state = session.state
        XCTAssertEqual(seen, [.loading, .connected])
        XCTAssertEqual(engine.connected, [grant])
        XCTAssertEqual(state.members, [you])
        XCTAssertTrue(state.joined)
        XCTAssertEqual(state.pillTitle, "In voice · 1")
        XCTAssertNil(state.emptyLine)
        XCTAssertTrue(state.canMute && state.canLeave && !state.canJoin)
    }

    func testOthersJoiningAndLeavingComeFromTheEngine() async {
        let engine = FakeSquadVoiceEngine()
        engine.roster = [you]
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        let alex = SquadVoiceMember(id: "u2", name: "Alex", muted: false, speaking: true, isYou: false)
        engine.onMembers?([you, alex])
        let both = session.state.members
        XCTAssertEqual(both.map(\.id), ["u1", "u2"])
        XCTAssertEqual(alex.spoken, "Alex, speaking")
        engine.onMembers?([])
        let empty = session.state.emptyLine
        XCTAssertEqual(empty, "No one else is here yet.")
    }

    func testMembersBeforeConnectingAreIgnored() {
        let engine = FakeSquadVoiceEngine()
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        engine.onMembers?([you])
        let members = session.state.members
        XCTAssertTrue(members.isEmpty)
        XCTAssertEqual(session.state.phase, .idle)
    }

    func testAFailedConnectIsAFailureWithRetry() async {
        let engine = FakeSquadVoiceEngine()
        engine.connectError = SquadVoiceProblem.failed("Stream said no.")
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        let state = session.state
        XCTAssertEqual(state.phase, .failed(.failed("Stream said no.")))
        XCTAssertEqual(state.statusLine, "Stream said no.")
        XCTAssertEqual(state.joinTitle, "Try again")
        XCTAssertFalse(state.joined)
    }

    func testNotAMemberAndSignedOutSayWhy() async {
        for (problem, line) in [(SquadVoiceProblem.notMember, "You're not in this squad"), (.signedOut, "Sign in again")] {
            let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.failure(problem)), engine: FakeSquadVoiceEngine())
            await session.join(squadId: squad, name: "Spencer")
            let status = session.state.statusLine
            XCTAssertTrue(status.hasPrefix(line), status)
        }
    }

    func testMuteFlipsOnlyWhenTheEngineTookIt() async {
        let engine = FakeSquadVoiceEngine()
        engine.roster = [you]
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        await session.toggleMute()
        let muted = session.state
        XCTAssertTrue(muted.muted)
        XCTAssertEqual(muted.statusLine, "In voice, muted")
        XCTAssertEqual(engine.mutes, [true])
        engine.muteError = SquadVoiceProblem.offline
        await session.toggleMute()
        let still = session.state.muted
        XCTAssertTrue(still, "A mute the engine refused doesn't flip")
    }

    func testLeaveEndsTheRoomAndTellsTheEngine() async {
        let engine = FakeSquadVoiceEngine()
        engine.roster = [you]
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        await session.leave()
        let state = session.state
        XCTAssertEqual(state.phase, .idle)
        XCTAssertTrue(state.members.isEmpty)
        XCTAssertEqual(engine.leaves, 1)
        XCTAssertEqual(state.pillTitle, "Voice")
    }

    func testADroppedRoomIsAFailureNotStillConnected() async {
        let engine = FakeSquadVoiceEngine()
        engine.roster = [you]
        let session = SquadVoiceSession(tokens: FakeSquadVoiceTokens(.success(grant)), engine: engine)
        await session.join(squadId: squad, name: "Spencer")
        engine.onDropped?("Lost the voice connection.")
        let state = session.state
        XCTAssertEqual(state.phase, .failed(.failed("Lost the voice connection.")))
        XCTAssertTrue(state.members.isEmpty)
    }

    func testThePillSpeaksEveryState() {
        var state = SquadVoiceState()
        XCTAssertEqual(state.pillSpoken, "Squad voice room. You're not in it. Double tap to open.")
        state.phase = .notSetUp
        XCTAssertEqual(state.pillSpoken, "Squad voice room. Voice isn't set up yet. Double tap to open.")
        state.phase = .connected
        state.members = [you]
        state.muted = true
        XCTAssertEqual(state.pillSpoken, "Squad voice room. You're in it, muted. 1 person is in it. Double tap to open.")
        var pill = VoicePillState()
        pill.live = state
        XCTAssertEqual(pill.title, "In voice · 1")
        XCTAssertTrue(pill.isIn)
        XCTAssertFalse(pill.spoken.contains(VoicePillState.mockTag), "Live voice never calls itself a mock")
    }

    func testTheMockPillIsUnchanged() {
        var pill = VoicePillState()
        XCTAssertTrue(pill.spoken.contains("mock"))
        pill.joined = true
        pill.count = 2
        XCTAssertEqual(pill.title, "In voice · 2")
        XCTAssertTrue(pill.isIn)
    }
}

/// The live model: the pill opens the sheet, and with this build's engine the
/// room says "Voice isn't set up yet". (@MainActor, so Mac only.)
@MainActor
final class SquadVoiceModelTests: XCTestCase {
    func testLiveVoiceStartsHonestAndThePillOpensTheSheet() async {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .live,
            sessionStore: MemorySessionStore()
        )
        let live = model.voicePill.live
        XCTAssertEqual(live, SquadVoiceState())
        XCTAssertFalse(model.voicePill.spoken.contains("mock"))
        await model.toggleVoice()
        XCTAssertTrue(model.voiceSheetOpen)
        let joined = model.voicePill.isIn
        XCTAssertFalse(joined, "Opening the sheet joins nothing")
    }

    func testTheMockBackendKeepsTheInMemoryPill() async {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .invite
        )
        XCTAssertNil(model.voicePill.live)
        await model.toggleVoice()
        XCTAssertFalse(model.voiceSheetOpen)
        XCTAssertTrue(model.voicePill.joined)
    }
}
