import XCTest
@testable import SquadSync

@MainActor
final class PushRouteTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private let message = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    private let other = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

    func testPayloadParsesAChatAndASquad() {
        let chat = PushPayloadParser.parse([
            "type": "squad_message",
            "squad_id": squad.uuidString,
            "message_id": message.uuidString
        ])
        XCTAssertEqual(chat, PushPayload(kind: .chat, squadId: squad, messageId: message))
        let card = PushPayloadParser.parse(jsonText: "{\"type\":\"squad\",\"squad_id\":\"\(squad.uuidString)\"}")
        XCTAssertEqual(card?.kind, .squad)
        XCTAssertEqual(card?.squadId, squad)
        XCTAssertNil(card?.messageId)
        XCTAssertNil(PushPayloadParser.parse(["type": "squad_message", "squad_id": squad.uuidString]))
        XCTAssertNil(PushPayloadParser.parse(["type": "other", "squad_id": squad.uuidString]))
    }

    func testLandingCoversSignedOutColdAndWarm() {
        let payload = PushPayload(kind: .chat, squadId: squad, messageId: message)
        XCTAssertEqual(
            PushLanding.step(payload: payload, signedIn: false, membershipKnown: false, memberOfTarget: false),
            .holdUntilSignedIn(payload)
        )
        XCTAssertEqual(
            PushLanding.step(payload: payload, signedIn: true, membershipKnown: false, memberOfTarget: false),
            .holdUntilSignedIn(payload)
        )
        XCTAssertEqual(
            PushLanding.step(payload: payload, signedIn: true, membershipKnown: true, memberOfTarget: true),
            .open(payload)
        )
        XCTAssertEqual(
            PushLanding.step(payload: payload, signedIn: true, membershipKnown: true, memberOfTarget: false),
            .notAMember(payload)
        )
    }

    func testViewingTheSameChatDoesNotBanner() {
        let payload = PushPayload(kind: .chat, squadId: squad, messageId: message)
        XCTAssertFalse(PushBanner.shows(viewingSquad: squad, payload: payload))
        XCTAssertTrue(PushBanner.shows(viewingSquad: other, payload: payload))
        XCTAssertTrue(PushBanner.shows(viewingSquad: nil, payload: payload))
        let card = PushPayload(kind: .squad, squadId: squad, messageId: nil)
        XCTAssertFalse(PushBanner.shows(viewingSquad: squad, payload: card))
    }

    func testTokenRotatesAndClearsOnSignOut() {
        XCTAssertEqual(TokenRotation.onToken("abc", previous: nil), .register("abc"))
        XCTAssertEqual(TokenRotation.onToken("abc", previous: "abc"), .none)
        XCTAssertEqual(TokenRotation.onToken("def", previous: "abc"), .replace(old: "abc", new: "def"))
        XCTAssertEqual(TokenRotation.onToken("  ", previous: "abc"), .none)
        XCTAssertEqual(TokenRotation.onSignOut(previous: "abc"), .unregister("abc"))
        XCTAssertEqual(TokenRotation.onSignOut(previous: nil), .none)
        XCTAssertNil(TokenPersistence.rememberAfter(action: .register("def"), registerSucceeded: false))
        XCTAssertEqual(
            TokenPersistence.rememberAfter(action: .replace(old: "abc", new: "def"), registerSucceeded: true),
            "def"
        )
        let hex = DeviceTokenHex.string(from: Data([0x0a, 0xff]))
        XCTAssertEqual(hex, "0aff")
    }

    func testPermissionWaitsUntilThereIsASquad() {
        XCTAssertFalse(PushPermissionMoment.shouldAsk(signedIn: false, hasSquad: false, alreadyAsked: false, automated: false))
        XCTAssertFalse(PushPermissionMoment.shouldAsk(signedIn: true, hasSquad: false, alreadyAsked: false, automated: false))
        XCTAssertTrue(PushPermissionMoment.shouldAsk(signedIn: true, hasSquad: true, alreadyAsked: false, automated: false))
        XCTAssertFalse(PushPermissionMoment.shouldAsk(signedIn: true, hasSquad: true, alreadyAsked: true, automated: false))
        XCTAssertFalse(PushPermissionMoment.shouldAsk(signedIn: true, hasSquad: true, alreadyAsked: false, automated: true))
        XCTAssertTrue(PushPermissionMoment.isAutomated(["-scenario", "invite"]))
    }

    func testCoordinatorHoldsASignedOutTapUntilTheSquadIsKnown() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        let payload = PushPayload(kind: .chat, squadId: squad, messageId: message)
        coordinator.receive([
            "type": "squad_message",
            "squad_id": squad.uuidString,
            "message_id": message.uuidString
        ])
        coordinator.settle(signedIn: false, squadId: nil, membershipKnown: false)
        XCTAssertEqual(coordinator.notice, "")
        coordinator.settle(signedIn: true, squadId: nil, membershipKnown: true)
        XCTAssertEqual(coordinator.notice, PushNotice.notAMember)
        coordinator.resetForTests()
        coordinator.receive([
            "type": payload.kind.rawValue,
            "squad_id": squad.uuidString,
            "message_id": message.uuidString
        ])
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertTrue(coordinator.openedChat)
        XCTAssertEqual(coordinator.focusMessage, message)
        XCTAssertFalse(coordinator.showsBanner([
            "type": "squad_message",
            "squad_id": squad.uuidString,
            "message_id": message.uuidString
        ]))
        coordinator.resetForTests()
    }

    func testOnlyALandedTapClosesTheSheets() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        let start = coordinator.coverSerial
        coordinator.receive(PushPayload(kind: .chat, squadId: squad, messageId: message))
        coordinator.settle(signedIn: false, squadId: nil, membershipKnown: false)
        XCTAssertEqual(coordinator.coverSerial, start, "A held tap leaves the screen alone")
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.coverSerial, start + 1, "Opening the chat closes what's over it")
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.coverSerial, start + 1, "A settle with nothing pending changes nothing")
        coordinator.receive(PushPayload(kind: .chat, squadId: other, messageId: message))
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.notice, PushNotice.notAMember)
        XCTAssertEqual(coordinator.coverSerial, start + 2, "The not-in-that-squad line has to be visible too")
        coordinator.resetForTests()
    }

    func testAMessageThatCannotOpenDropsTheOpenedLine() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        coordinator.receive(PushPayload(kind: .chat, squadId: squad, messageId: message))
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(PushToast.text(notice: coordinator.notice, openedChat: coordinator.openedChat, openedSquad: coordinator.openedSquad), PushNotice.openedChat)
        coordinator.dismissOpenedToast()
        XCTAssertNil(PushToast.text(notice: coordinator.notice, openedChat: coordinator.openedChat, openedSquad: coordinator.openedSquad))
        coordinator.resetForTests()
    }

    func testAWarmDebugTapArrivesAfterItsDelay() async throws {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        let json = "{\"type\":\"squad_message\",\"squad_id\":\"\(squad.uuidString)\",\"message_id\":\"\(message.uuidString)\"}"
        coordinator.consumeLaunchArguments(["-debug-push-open", json, "-debug-push-open-after", "0.2"])
        XCTAssertNil(coordinator.pending, "Not a cold-launch tap")
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(coordinator.pending, PushPayload(kind: .chat, squadId: squad, messageId: message))
        coordinator.resetForTests()
    }

    func testASignedOutLaunchWaitsAndThenOpens() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        let json = "{\"type\":\"squad\",\"squad_id\":\"\(squad.uuidString)\"}"
        coordinator.consumeLaunchArguments(["-debug-push-open", json])
        coordinator.settle(signedIn: false, squadId: nil, membershipKnown: false)
        XCTAssertFalse(coordinator.openedSquad)
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertTrue(coordinator.openedSquad)
        XCTAssertEqual(coordinator.notice, "")
        coordinator.resetForTests()
    }

    func testRegisterAndUnregisterUseTheDeviceTokenRPC() async throws {
        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let missing = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function public.sq8_register_device_token in the schema cache\"}".utf8)
        let hidden = ScriptedTransport(responses: [(404, missing)])
        let absent = SupabaseSquadService(config: config, accessToken: "access", transport: hidden, presence: FunctionPresence())
        let assumed = await absent.pushTokenRPCAvailable()
        XCTAssertTrue(assumed, "Available until a real call says otherwise")
        XCTAssertTrue(hidden.requests.isEmpty, "The availability check sends nothing (it used to GET device_token=probe)")
        do {
            try await absent.registerPushToken("abc")
            XCTFail("A missing function should throw")
        } catch BackendFailure.notSetUp {
        }
        let available = await absent.pushTokenRPCAvailable()
        XCTAssertFalse(available, "A 404 / PGRST202 on the real POST is remembered")
        XCTAssertEqual(hidden.requests.count, 1)
        XCTAssertEqual(hidden.requests.first?.httpMethod, "POST")

        let present = ScriptedTransport(responses: [
            (204, Data()),
            (204, Data())
        ])
        let service = SupabaseSquadService(config: config, accessToken: "access", transport: present, presence: FunctionPresence())
        let ready = await service.pushTokenRPCAvailable()
        XCTAssertTrue(ready)
        try await service.registerPushToken("abc")
        try await service.unregisterPushToken("abc")
        XCTAssertFalse(present.requests.contains { $0.httpMethod == "GET" }, "No GET probe")
        let posts = present.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 2)
        let registered = try JSONSerialization.jsonObject(with: posts[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(registered?["device_token"] as? String, "abc")
        XCTAssertEqual(registered?["device_platform"] as? String, "ios")
        let removed = try JSONSerialization.jsonObject(with: posts[1].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(removed?["device_token"] as? String, "abc")
        XCTAssertTrue(posts[0].url?.path.hasSuffix("sq8_register_device_token") == true)
        XCTAssertTrue(posts[1].url?.path.hasSuffix("sq8_unregister_device_token") == true)
    }

    func testToastSitsOnScreenAndThenDismisses() {
        XCTAssertEqual(
            PushToast.text(notice: PushNotice.notAMember, openedChat: false, openedSquad: false),
            PushNotice.notAMember
        )
        XCTAssertEqual(
            PushToast.identifier(notice: PushNotice.notAMember, openedChat: false, openedSquad: false),
            "push-notice"
        )
        XCTAssertEqual(
            PushToast.text(notice: "", openedChat: true, openedSquad: false),
            PushNotice.openedChat
        )
        XCTAssertEqual(
            PushToast.identifier(notice: "", openedChat: false, openedSquad: true),
            "push-opened-squad"
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(PushToast.shouldDismiss(shownAt: start, now: start.addingTimeInterval(7)))
        XCTAssertTrue(PushToast.shouldDismiss(shownAt: start, now: start.addingTimeInterval(8)))
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        coordinator.receive([
            "type": "squad",
            "squad_id": other.uuidString
        ])
        coordinator.settle(signedIn: true, squadId: squad, membershipKnown: true)
        XCTAssertEqual(coordinator.notice, PushNotice.notAMember)
        coordinator.dismissToast()
        XCTAssertEqual(coordinator.notice, "")
        XCTAssertFalse(coordinator.openedChat)
        XCTAssertFalse(coordinator.openedSquad)
        coordinator.resetForTests()
    }

    func testLaterLaunchesRegisterWhenAuthorizedOrProvisional() {
        let coordinator = PushCoordinator.shared
        var calls = 0
        coordinator.performRegistration(status: .notDetermined) { calls += 1 }
        coordinator.performRegistration(status: .denied) { calls += 1 }
        coordinator.performRegistration(status: .ephemeral) { calls += 1 }
        XCTAssertEqual(calls, 0)
        coordinator.performRegistration(status: .authorized) { calls += 1 }
        coordinator.performRegistration(status: .provisional) { calls += 1 }
        XCTAssertEqual(calls, 2)
        XCTAssertTrue(PushAuthState.authorized.registersForRemoteNotifications)
        XCTAssertTrue(PushAuthState.provisional.registersForRemoteNotifications)
    }

    func testRegistrationFailureStaysVisibleForDebug() {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        coordinator.noteRegistrationFailure("no aps-environment")
        XCTAssertEqual(coordinator.storeFailure, "no aps-environment")
        coordinator.resetForTests()
        XCTAssertEqual(coordinator.storeFailure, "")
    }

    func testInjectedTokenRegistersAndAMissingRPCFailsHonestly() async throws {
        let coordinator = PushCoordinator.shared
        coordinator.resetForTests()
        coordinator.consumeLaunchArguments(["-debug-push-token", " aabbcc "])
        XCTAssertEqual(coordinator.seenToken, "aabbcc")
        XCTAssertNil(coordinator.storedToken)

        let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
        let missingBody = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function public.sq8_register_device_token in the schema cache\"}".utf8)
        let missing = ScriptedTransport(responses: [(404, missingBody)])
        let absentPresence = FunctionPresence()
        let absent = SupabaseSquadService(config: config, accessToken: "access", transport: missing, presence: absentPresence)
        let injected = try XCTUnwrap(coordinator.seenToken)
        await PushTokenSync.apply(token: injected, service: absent, coordinator: coordinator)
        XCTAssertEqual(coordinator.storeFailure, PushStoreFailure.missingRPC)
        XCTAssertNil(coordinator.storedToken)
        XCTAssertEqual(coordinator.seenToken, "aabbcc")
        XCTAssertEqual(missing.requests.map(\.httpMethod), ["POST"], "One real POST is the check; no GET probe")
        await PushTokenSync.apply(token: injected, service: absent, coordinator: coordinator)
        XCTAssertEqual(missing.requests.count, 1, "Missing is remembered for the session")
        XCTAssertEqual(coordinator.storeFailure, PushStoreFailure.missingRPC)

        let failedStore = ScriptedTransport(responses: [
            (500, Data("{\"message\":\"not stored\"}".utf8))
        ])
        let failing = SupabaseSquadService(config: config, accessToken: "access", transport: failedStore, presence: FunctionPresence())
        await PushTokenSync.apply(token: "aabbcc", service: failing, coordinator: coordinator)
        XCTAssertEqual(coordinator.storeFailure, "not stored")
        XCTAssertNil(coordinator.storedToken)
        XCTAssertEqual(coordinator.plan("aabbcc"), .register("aabbcc"))

        let stored = ScriptedTransport(responses: [
            (204, Data())
        ])
        let ready = SupabaseSquadService(config: config, accessToken: "access", transport: stored, presence: FunctionPresence())
        await PushTokenSync.apply(token: "aabbcc", service: ready, coordinator: coordinator)
        let posts = stored.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(stored.requests.count, 1, "No GET probe before the register")
        let body = try JSONSerialization.jsonObject(with: posts[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(body?["device_token"] as? String, "aabbcc")
        XCTAssertEqual(body?["device_platform"] as? String, "ios")
        XCTAssertTrue(posts[0].url?.path.hasSuffix("sq8_register_device_token") == true)
        XCTAssertEqual(coordinator.storedToken, "aabbcc")
        XCTAssertEqual(coordinator.storeFailure, "")

        let idle = ScriptedTransport(responses: [])
        let done = SupabaseSquadService(config: config, accessToken: "access", transport: idle, presence: FunctionPresence())
        await PushTokenSync.apply(token: "aabbcc", service: done, coordinator: coordinator)
        XCTAssertTrue(idle.requests.isEmpty)
        coordinator.resetForTests()
    }

    func testTheMockFooterSaysItIsSampleData() {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .noSquad
        )
        XCTAssertEqual(model.notes, [LiveShellCopy.mockFooter])
        XCTAssertEqual(LiveShellCopy.mockFooter, "Sample data. Nothing here reaches the server.")
    }

    func testTheLiveFooterNamesSpotsPushAndVoiceWithoutClaimingADeviceTest() {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .live,
            sessionStore: MemorySessionStore()
        )
        XCTAssertEqual(model.notes, [LiveShellCopy.liveFooter])
        XCTAssertEqual(
            LiveShellCopy.liveFooter,
            "Spots are live. Push and voice are on the server but not yet tested on a phone."
        )
        XCTAssertFalse(LiveShellCopy.liveFooter.lowercased().contains("mock"))
        XCTAssertEqual(LiveShellCopy.footer(for: .live), LiveShellCopy.liveFooter)
        XCTAssertEqual(LiveShellCopy.footer(for: .mock), LiveShellCopy.mockFooter)
    }
}

/// Tap routing that runs without UIKit (also in the Linux harness).
final class PushTapRoutingTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private let message = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!

    func testALandedTapClosesWhatCoversTheChatAndAHeldOneWaits() {
        let chat = PushPayload(kind: .chat, squadId: squad, messageId: message)
        let card = PushPayload(kind: .squad, squadId: squad, messageId: nil)
        XCTAssertTrue(PushLanding.Step.open(chat).closesCovers, "The pushed message has to be on screen")
        XCTAssertTrue(PushLanding.Step.open(card).closesCovers, "So does the squad card")
        XCTAssertTrue(PushLanding.Step.notAMember(chat).closesCovers, "The line saying why sits on the chat screen")
        XCTAssertFalse(PushLanding.Step.holdUntilSignedIn(chat).closesCovers, "Nothing closes before the tap can be settled")
        let held = PushLanding.step(payload: chat, signedIn: false, membershipKnown: false, memberOfTarget: false)
        XCTAssertFalse(held.closesCovers)
        let warm = PushLanding.step(payload: chat, signedIn: true, membershipKnown: true, memberOfTarget: true)
        XCTAssertTrue(warm.closesCovers)
    }

    func testEverySheetOverTheChatIsACover() {
        XCTAssertEqual(Set(PushCover.allCases.map { "\($0)" }), [
            "signOutConfirm", "endSpotConfirm", "leaveConfirm", "members",
            "callSpotSheet", "voiceSheet", "whosInSheet", "largeTextRoster"
        ])
    }

    func testDebugTapIsColdUnlessGivenADelay() {
        let json = "{\"type\":\"squad_message\",\"squad_id\":\"\(squad.uuidString)\",\"message_id\":\"\(message.uuidString)\"}"
        let payload = PushPayload(kind: .chat, squadId: squad, messageId: message)
        XCTAssertEqual(PushDebugTap.plan(json: nil, delayText: "5"), .none)
        XCTAssertEqual(PushDebugTap.plan(json: "{\"type\":\"squad_message\"}", delayText: nil), .none, "No squad id is no tap")
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: nil), .atLaunch(payload))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "6"), .later(payload, seconds: 6))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: " 2.5 "), .later(payload, seconds: 2.5))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "0"), .atLaunch(payload))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "-3"), .atLaunch(payload))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "soon"), .atLaunch(payload))
        XCTAssertEqual(PushDebugTap.plan(json: json, delayText: "121"), .atLaunch(payload), "Capped so a typo can't stall a run")
    }

    func testTheLiveFunctionPayloadOpensTheExactMessage() {
        // The shape sq8-notify-message (apns.ts) sends: type, squad_id, message_id next to aps.
        let userInfo: [AnyHashable: Any] = [
            "aps": ["alert": ["title": "SquadSync", "body": "New message"], "thread-id": "squad:\(squad.uuidString)"],
            "type": "squad_message",
            "squad_id": squad.uuidString.lowercased(),
            "message_id": message.uuidString.lowercased()
        ]
        let payload = PushPayloadParser.parse(userInfo)
        XCTAssertEqual(payload, PushPayload(kind: .chat, squadId: squad, messageId: message))
        guard let payload else { return }
        XCTAssertEqual(
            PushLanding.step(payload: payload, signedIn: true, membershipKnown: true, memberOfTarget: true),
            .open(payload)
        )
    }
}
