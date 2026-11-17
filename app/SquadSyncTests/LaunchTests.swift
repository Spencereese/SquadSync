import XCTest
@testable import SquadSync

/// Friends-ready launch: which backend a launch picks, and the realtime socket
/// keeping a fresh token and coming back after the background.
final class LaunchBackendTests: XCTestCase {
    private let configured = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    /// What Info.plist holds when Config.xcconfig is missing: unexpanded or empty.
    private let unexpanded = BackendConfig(urlText: "$(SUPABASE_URL)", anonKey: "$(SUPABASE_ANON_KEY)")
    private let blank = BackendConfig(urlText: "", anonKey: "")
    private let bothKeys = ["SupabaseURL", "SupabaseAnonKey"]

    func testReleaseWithConfigIsLive() {
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync"], config: configured, isRelease: true), .live)
        // A bare scenario doesn't switch a Release build to sample data.
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-scenario", "invite"], config: configured, isRelease: true), .live)
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-screen", "inbox"], config: configured, isRelease: true), .live)
    }

    func testDebugWithConfigIsLive() {
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync"], config: configured, isRelease: false), .live)
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-screen", "inbox"], config: configured, isRelease: false), .live)
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-backend", "live"], config: configured, isRelease: false), .live)
    }

    func testNoConfigSaysNotConfiguredInsteadOfMock() {
        for release in [false, true] {
            XCTAssertEqual(
                LaunchBackend.choose(arguments: ["SquadSync"], config: unexpanded, isRelease: release),
                .notConfigured(missing: bothKeys)
            )
            XCTAssertEqual(
                LaunchBackend.choose(arguments: ["SquadSync", "-backend", "live"], config: blank, isRelease: release),
                .notConfigured(missing: bothKeys)
            )
        }
        let placeholder = BackendConfig(urlText: "https://example.supabase.co", anonKey: "paste-anon-key-here")
        XCTAssertEqual(
            LaunchBackend.choose(arguments: ["SquadSync"], config: placeholder, isRelease: false),
            .notConfigured(missing: ["SupabaseAnonKey"])
        )
        XCTAssertNil(LaunchBackend.notConfigured(missing: bothKeys).mode)
    }

    func testBackendMockAlwaysMeansMock() {
        for config in [configured, unexpanded] {
            for release in [false, true] {
                XCTAssertEqual(
                    LaunchBackend.choose(arguments: ["SquadSync", "-backend", "mock", "-screen", "inbox"], config: config, isRelease: release),
                    .mock
                )
            }
        }
        XCTAssertEqual(LaunchBackend.mock.mode, .mock)
        XCTAssertEqual(LaunchBackend.live.mode, .live)
    }

    func testDebugUITestScenarioStaysMock() {
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-scenario", "onboarding"], config: configured, isRelease: false), .mock)
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync", "-scenario", "seated"], config: unexpanded, isRelease: false), .mock)
        // An explicit live flag wins over a scenario.
        XCTAssertEqual(
            LaunchBackend.choose(arguments: ["SquadSync", "-backend", "live", "-scenario", "invite"], config: configured, isRelease: false),
            .live
        )
    }

    func testTheUnitTestHostStaysMock() {
        XCTAssertEqual(LaunchBackend.choose(arguments: ["SquadSync"], config: configured, isRelease: false, hostingUnitTests: true), .mock)
        XCTAssertEqual(
            LaunchBackend.choose(arguments: ["SquadSync", "-backend", "live"], config: configured, isRelease: false, hostingUnitTests: true),
            .live
        )
        XCTAssertTrue(BuildFlavor.hostingUnitTests(["XCTestConfigurationFilePath": "/tmp/x.xctestconfiguration"]))
        XCTAssertFalse(BuildFlavor.hostingUnitTests([:]))
    }

    func testNotConfiguredCopyNamesWhatIsMissing() {
        XCTAssertEqual(LaunchBackend.notConfiguredTitle, "This build isn't connected to a server")
        let detail = LaunchBackend.notConfiguredDetail(missing: ["SupabaseAnonKey"])
        XCTAssertTrue(detail.hasSuffix("Missing: SupabaseAnonKey."), detail)
        XCTAssertTrue(detail.contains("won't show sample data"), detail)
        XCTAssertTrue(LaunchBackend.notConfiguredDetail(missing: []).contains("SupabaseURL, SupabaseAnonKey"))
    }
}

final class RealtimeResumeTests: XCTestCase {
    func testComingBackFromTheBackgroundAlwaysReconnects() {
        for link in [RealtimeLink.connecting, .connected, .reconnecting, .down] {
            XCTAssertTrue(RealtimeResume.reconnects(wentToBackground: true, link: link, signedInWithSquad: true))
            XCTAssertTrue(RealtimeResume.reconnects(wentToBackground: true, link: link, signedInWithSquad: false))
        }
    }

    func testWithoutTheBackgroundOnlyADownSocketReconnects() {
        XCTAssertTrue(RealtimeResume.reconnects(wentToBackground: false, link: .down, signedInWithSquad: true))
        XCTAssertTrue(RealtimeResume.reconnects(wentToBackground: false, link: .reconnecting, signedInWithSquad: true))
        XCTAssertFalse(RealtimeResume.reconnects(wentToBackground: false, link: .connected, signedInWithSquad: true))
        XCTAssertFalse(RealtimeResume.reconnects(wentToBackground: false, link: .connecting, signedInWithSquad: true))
        // The first activation at launch, before sign-in or a squad, does nothing.
        XCTAssertFalse(RealtimeResume.reconnects(wentToBackground: false, link: .down, signedInWithSquad: false))
    }

    func testAccessTokenFrameIsAChannelEvent() throws {
        let frame = RealtimeFrames.accessToken(topic: "realtime:sq8:abc", token: "jwt-2", ref: "7")
        XCTAssertEqual(frame["event"] as? String, "access_token")
        XCTAssertEqual(frame["topic"] as? String, "realtime:sq8:abc")
        XCTAssertEqual((frame["payload"] as? [String: String])?["access_token"], "jwt-2")
        XCTAssertEqual(frame["ref"] as? String, "7")
        XCTAssertNotNil(try? JSONSerialization.data(withJSONObject: frame))
    }
}

/// Collects what the realtime client would have written to the socket.
final class FrameLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [[String: Any]] = []
    var frames: [[String: Any]] { lock.withLock { stored } }
    var events: [String] { frames.compactMap { $0["event"] as? String } }

    func record(_ text: String) {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { return }
        lock.withLock { stored.append(object) }
    }

    func waitFor(count: Int, tries: Int = 200) async {
        for _ in 0..<tries where frames.count < count {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    /// The `access_token` a frame carries (join or update).
    static func token(of frame: [String: Any]?) -> String? {
        (frame?["payload"] as? [String: Any])?["access_token"] as? String
    }
}

/// The realtime client is main-actor; these tests hop to it with `await` so they
/// also run in the Linux harness.
final class RealtimeTokenTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let squad = UUID(uuidString: "6F0C3B5E-0000-4000-8000-000000000001")!

    private var joinReply: String {
        #"{"event":"phx_reply","topic":"realtime:sq8:\#(squad.uuidString.lowercased())","ref":"1","payload":{"status":"ok","response":{}}}"#
    }

    func testARefreshedTokenReachesTheOpenChannel() async {
        let log = FrameLog()
        let client = await RealtimeClient(sender: { text in log.record(text) })
        await client.start(config: config, accessToken: "jwt-1", squadId: squad)
        await log.waitFor(count: 1)
        XCTAssertEqual(log.events, ["phx_join"])
        XCTAssertEqual(FrameLog.token(of: log.frames.first), "jwt-1")
        await client.handle(joinReply)
        let joined = await client.joined
        XCTAssertTrue(joined)

        await client.updateAccessToken("jwt-2")
        await log.waitFor(count: 2)
        XCTAssertEqual(log.events, ["phx_join", "access_token"])
        let update = log.frames.last ?? [:]
        XCTAssertEqual(FrameLog.token(of: update), "jwt-2")
        XCTAssertEqual(update["topic"] as? String, "realtime:sq8:\(squad.uuidString.lowercased())")
        let current = await client.accessToken
        XCTAssertEqual(current, "jwt-2")

        // The same token again, or a blank one, sends nothing.
        await client.updateAccessToken("jwt-2")
        await client.updateAccessToken("  ")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(log.frames.count, 2)
        await client.stop()
    }

    func testATokenFromBeforeTheJoinIsUsedByTheJoin() async {
        let log = FrameLog()
        let client = await RealtimeClient(sender: { text in log.record(text) })
        await client.start(config: config, accessToken: "jwt-1", squadId: squad)
        await log.waitFor(count: 1)
        // Refreshed while the join is still unanswered: stored, no frame yet.
        await client.updateAccessToken("jwt-2")
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(log.events, ["phx_join"])
        let joinedEarly = await client.joined
        let stored = await client.accessToken
        XCTAssertFalse(joinedEarly)
        XCTAssertEqual(stored, "jwt-2")
        // The channel errors and rejoins (after the 1s backoff) with the newest token.
        await client.handle(#"{"event":"phx_error","topic":"realtime:sq8:x","payload":{}}"#)
        await log.waitFor(count: 2, tries: 300)
        XCTAssertEqual(log.events, ["phx_join", "phx_join"])
        XCTAssertEqual(FrameLog.token(of: log.frames.last), "jwt-2")
        await client.stop()
    }

    func testResumeRestartJoinsAgainWithTheFreshToken() async {
        let log = FrameLog()
        let phases = PhaseLog()
        let client = await RealtimeClient(sender: { text in log.record(text) })
        await MainActor.run {
            client.onEvent = { event in
                if case .phase(let link) = event { phases.add(link) }
            }
        }
        await client.start(config: config, accessToken: "jwt-1", squadId: squad)
        await log.waitFor(count: 1)
        await client.handle(joinReply)
        XCTAssertEqual(phases.links.last, .connected)
        // What becameActive does after a trip to the background: a new start with
        // the refreshed session's token. The old channel is dropped, not reused.
        await client.start(config: config, accessToken: "jwt-3", squadId: squad)
        let joinedAfterRestart = await client.joined
        XCTAssertFalse(joinedAfterRestart)
        await log.waitFor(count: 2)
        XCTAssertEqual(log.events, ["phx_join", "phx_join"])
        XCTAssertEqual(FrameLog.token(of: log.frames.last), "jwt-3")
        XCTAssertEqual(phases.links, [.connecting, .connected, .connecting])
        await client.handle(joinReply)
        let rejoined = await client.joined
        XCTAssertTrue(rejoined)
        await client.stop()
        let joinedAfterStop = await client.joined
        XCTAssertFalse(joinedAfterStop)
    }
}

final class PhaseLog: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [RealtimeLink] = []
    var links: [RealtimeLink] { lock.withLock { stored } }
    func add(_ link: RealtimeLink) { lock.withLock { stored.append(link) } }
}

final class RefreshHookTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let user = UUID(uuidString: "6F0C3B5E-0000-4000-8000-0000000000AA")!

    private func jwt(exp: Date) -> String {
        func part(_ json: String) -> String {
            Data(json.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(part(#"{"alg":"HS256"}"#)).\(part(#"{"exp":\#(Int(exp.timeIntervalSince1970))}"#)).sig"
    }

    func testEveryRefreshHandsTheNewSessionOn() async throws {
        let now = Date()
        let store = OnboardingTestStore()
        try store.save(AuthSession(accessToken: jwt(exp: now.addingTimeInterval(-10)), refreshToken: "r1", userId: user, email: "a@squad.test"))
        let fresh = jwt(exp: now.addingTimeInterval(3600))
        let body = #"{"access_token":"\#(fresh)","refresh_token":"r2","user":{"id":"\#(user.uuidString)","email":"a@squad.test"}}"#
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let auth = SupabaseAuthService(config: config, store: store, transport: transport)
        let seen = RefreshSeen()
        auth.onRefresh = { session in seen.add(session.accessToken) }
        let session = try await auth.prepareSession(now: now)
        XCTAssertEqual(session?.accessToken, fresh)
        let tokens = seen.tokens
        XCTAssertEqual(tokens, [fresh])
    }

    func testAFreshTokenDoesNotCallTheHook() async throws {
        let now = Date()
        let store = OnboardingTestStore()
        try store.save(AuthSession(accessToken: jwt(exp: now.addingTimeInterval(3600)), refreshToken: "r1", userId: user, email: "a@squad.test"))
        let auth = SupabaseAuthService(config: config, store: store, transport: ScriptedTransport())
        let seen = RefreshSeen()
        auth.onRefresh = { session in seen.add(session.accessToken) }
        _ = try await auth.prepareSession(now: now)
        let tokens = seen.tokens
        XCTAssertTrue(tokens.isEmpty)
    }
}

final class RefreshSeen: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []
    var tokens: [String] { lock.withLock { stored } }
    func add(_ token: String) { lock.withLock { stored.append(token) } }
}
