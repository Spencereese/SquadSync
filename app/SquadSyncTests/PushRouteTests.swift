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
        let absent = SupabaseSquadService(config: config, accessToken: "access", transport: hidden)
        let available = await absent.pushTokenRPCAvailable()
        XCTAssertFalse(available)
        let probe = try XCTUnwrap(hidden.requests.first)
        XCTAssertEqual(probe.httpMethod, "GET")
        XCTAssertNil(probe.httpBody)
        XCTAssertTrue(probe.url?.query?.contains("device_token=probe") == true)
        XCTAssertTrue(probe.url?.query?.contains("device_platform=ios") == true)

        let present = ScriptedTransport(responses: [
            (405, Data("{\"message\":\"cannot execute INSERT in a read-only transaction\"}".utf8)),
            (204, Data()),
            (204, Data())
        ])
        let service = SupabaseSquadService(config: config, accessToken: "access", transport: present)
        let ready = await service.pushTokenRPCAvailable()
        XCTAssertTrue(ready)
        try await service.registerPushToken("abc")
        try await service.unregisterPushToken("abc")
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
        let absent = SupabaseSquadService(config: config, accessToken: "access", transport: missing)
        let injected = try XCTUnwrap(coordinator.seenToken)
        await PushTokenSync.apply(token: injected, service: absent, coordinator: coordinator)
        XCTAssertEqual(coordinator.storeFailure, PushStoreFailure.missingRPC)
        XCTAssertNil(coordinator.storedToken)
        XCTAssertEqual(coordinator.seenToken, "aabbcc")
        XCTAssertFalse(missing.requests.contains { $0.httpMethod == "POST" })

        let refused = Data("{\"message\":\"cannot execute INSERT in a read-only transaction\"}".utf8)
        let failedStore = ScriptedTransport(responses: [
            (405, refused),
            (500, Data("{\"message\":\"not stored\"}".utf8))
        ])
        let failing = SupabaseSquadService(config: config, accessToken: "access", transport: failedStore)
        await PushTokenSync.apply(token: "aabbcc", service: failing, coordinator: coordinator)
        XCTAssertEqual(coordinator.storeFailure, "not stored")
        XCTAssertNil(coordinator.storedToken)
        XCTAssertEqual(coordinator.plan("aabbcc"), .register("aabbcc"))

        let stored = ScriptedTransport(responses: [
            (405, refused),
            (204, Data())
        ])
        let ready = SupabaseSquadService(config: config, accessToken: "access", transport: stored)
        await PushTokenSync.apply(token: "aabbcc", service: ready, coordinator: coordinator)
        let posts = stored.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(posts.count, 1)
        let body = try JSONSerialization.jsonObject(with: posts[0].httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(body?["device_token"] as? String, "aabbcc")
        XCTAssertEqual(body?["device_platform"] as? String, "ios")
        XCTAssertTrue(posts[0].url?.path.hasSuffix("sq8_register_device_token") == true)
        XCTAssertEqual(coordinator.storedToken, "aabbcc")
        XCTAssertEqual(coordinator.storeFailure, "")

        let idle = ScriptedTransport(responses: [])
        let done = SupabaseSquadService(config: config, accessToken: "access", transport: idle)
        await PushTokenSync.apply(token: "aabbcc", service: done, coordinator: coordinator)
        XCTAssertTrue(idle.requests.isEmpty)
        coordinator.resetForTests()
    }

    func testLiveFooterNamesSpotsAndPushHonestly() {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .noSquad
        )
        XCTAssertEqual(model.notes.first, LiveShellCopy.footer)
        XCTAssertEqual(
            LiveShellCopy.footer,
            "Voice stays mock. Spots are live. Push is wired but not live until the server side ships."
        )
    }
}
