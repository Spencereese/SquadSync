import Foundation
import os
import UIKit
import UserNotifications

@MainActor
@Observable
final class PushCoordinator {
    static let shared = PushCoordinator()

    var notice = ""
    var openedChat = false
    var openedSquad = false
    var focusMessage: UUID?
    /// A side-thread reply tap that landed and hasn't been opened yet.
    private(set) var threadOpen: PushThreadOpen?
    private(set) var pending: PushPayload?
    /// Goes up each time a tap lands; the session screen closes its sheets when it changes.
    private(set) var coverSerial = 0
    var viewingSquad: UUID?
    /// The side thread on screen, if any. Its replies don't banner.
    var viewingThread: UUID?
    /// Latest device token, including one whose store has not succeeded yet.
    private(set) var seenToken: String?
    /// Token the register RPC accepted.
    private(set) var storedToken: String?
    /// Empty when the last store succeeded. Debug-visible; not a user-facing alarm.
    private(set) var storeFailure = ""
    private var asked = false

    private let tokenKey = "sq8.push.registered-token"
    private let seenKey = "sq8.push.seen-token"
    private let askedKey = "sq8.push.permission-asked"

    init() {
        storedToken = UserDefaults.standard.string(forKey: tokenKey)
        seenToken = UserDefaults.standard.string(forKey: seenKey)
        asked = UserDefaults.standard.bool(forKey: askedKey)
    }

    func consumeLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        switch PushDebugTap.plan(
            json: LaunchOptions.flag("-debug-push-open", in: arguments),
            delayText: LaunchOptions.flag("-debug-push-open-after", in: arguments)
        ) {
        case .none:
            break
        case .atLaunch(let payload):
            pending = payload
        case .later(let payload, let seconds):
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                self?.receive(payload)
            }
        }
        if let token = LaunchOptions.flag("-debug-push-token", in: arguments) {
            noteSeen(token)
        }
    }

    func receive(_ userInfo: [AnyHashable: Any]) {
        guard let payload = PushPayloadParser.parse(userInfo) else { return }
        receive(payload)
    }

    /// A tap while the app is running: hold it and ask the session screen to settle it.
    func receive(_ payload: PushPayload) {
        pending = payload
        NotificationCenter.default.post(name: .sq8PushRoute, object: nil)
    }

    func showsBanner(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let payload = PushPayloadParser.parse(userInfo) else { return true }
        return PushBanner.shows(viewingSquad: viewingSquad, viewingThread: viewingThread, payload: payload)
    }

    func settle(signedIn: Bool, squadId: UUID?, membershipKnown: Bool) {
        viewingSquad = signedIn ? squadId : nil
        guard let pending else { return }
        let member = squadId == pending.squadId
        let step = PushLanding.step(
            payload: pending,
            signedIn: signedIn,
            membershipKnown: membershipKnown,
            memberOfTarget: member
        )
        if step.closesCovers { coverSerial += 1 }
        switch step {
        case .holdUntilSignedIn:
            return
        case .notAMember:
            notice = PushNotice.notAMember
            openedChat = false
            openedSquad = false
            focusMessage = nil
            threadOpen = nil
            self.pending = nil
        case .open(let payload):
            notice = ""
            switch PushDestination.of(payload) {
            case .chat(let message):
                openedChat = true
                openedSquad = false
                focusMessage = message
                threadOpen = nil
            case .squad:
                openedChat = false
                openedSquad = true
                focusMessage = payload.messageId
                threadOpen = nil
            case .thread(let thread, let reply):
                // The side thread opens over the chat; the chat isn't scrolled for it.
                openedChat = false
                openedSquad = false
                focusMessage = nil
                threadOpen = PushThreadOpen(thread: thread, reply: reply)
            }
            self.pending = nil
        }
    }

    /// Hands the landed side-thread tap to the screen once.
    func takeThreadOpen() -> PushThreadOpen? {
        defer { threadOpen = nil }
        return threadOpen
    }

    func dismissToast() {
        notice = ""
        openedChat = false
        openedSquad = false
    }

    /// The pushed message couldn't be opened: drop "Opened this chat." so only the reason shows.
    func dismissOpenedToast() {
        openedChat = false
    }

    /// Calls `register` when this launch should ask APNs for the current device token.
    func performRegistration(status: PushAuthState, register: () -> Void) {
        guard status.registersForRemoteNotifications else { return }
        register()
    }

    func askIfReady(signedIn: Bool, hasSquad: Bool, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard PushPermissionMoment.shouldAsk(
            signedIn: signedIn,
            hasSquad: hasSquad,
            alreadyAsked: asked,
            automated: PushPermissionMoment.isAutomated(arguments)
        ) else { return }
        asked = true
        UserDefaults.standard.set(true, forKey: askedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    func noteSeen(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        seenToken = trimmed
        UserDefaults.standard.set(trimmed, forKey: seenKey)
    }

    func plan(_ token: String) -> TokenRotation.Action {
        TokenRotation.onToken(token, previous: storedToken)
    }

    func remember(_ token: String) {
        storedToken = token
        seenToken = token
        storeFailure = ""
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(token, forKey: seenKey)
    }

    func noteStoreFailure(_ reason: String) {
        storeFailure = reason
        SquadLog.http.info("push token store failed: \(reason, privacy: .public)")
    }

    func noteRegistrationFailure(_ reason: String) {
        storeFailure = reason
        SquadLog.http.info("push registration failed: \(reason, privacy: .public)")
    }

    func signOutAction() -> TokenRotation.Action {
        let action = TokenRotation.onSignOut(previous: storedToken)
        storedToken = nil
        seenToken = nil
        storeFailure = ""
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: seenKey)
        viewingSquad = nil
        viewingThread = nil
        threadOpen = nil
        return action
    }

    #if DEBUG
    func resetForTests() {
        pending = nil
        notice = ""
        openedChat = false
        openedSquad = false
        focusMessage = nil
        threadOpen = nil
        viewingThread = nil
        storedToken = nil
        seenToken = nil
        storeFailure = ""
        asked = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: seenKey)
        UserDefaults.standard.removeObject(forKey: askedKey)
    }
    #endif
}

enum PushTokenSync {
    /// Stores `token` when it is not already the one the RPC accepted. A missing RPC records a reason and returns.
    @MainActor
    static func apply(token: String, service: SquadService, coordinator: PushCoordinator) async {
        coordinator.noteSeen(token)
        let action = coordinator.plan(token)
        let tokenToStore: String
        let previous: String?
        switch action {
        case .none:
            return
        case .register(let value):
            tokenToStore = value
            previous = nil
        case .replace(let old, let new):
            tokenToStore = new
            previous = old
        case .unregister(let value):
            guard await service.pushTokenRPCAvailable() else {
                coordinator.noteStoreFailure(PushStoreFailure.missingRPC)
                return
            }
            do {
                try await service.unregisterPushToken(value)
            } catch {
                coordinator.noteStoreFailure(PushStoreFailure.reason(error))
            }
            return
        }
        guard await service.pushTokenRPCAvailable() else {
            coordinator.noteStoreFailure(PushStoreFailure.missingRPC)
            return
        }
        do {
            try await service.registerPushToken(tokenToStore)
        } catch {
            coordinator.noteStoreFailure(PushStoreFailure.reason(error))
            return
        }
        if let previous {
            do {
                try await service.unregisterPushToken(previous)
            } catch {
                coordinator.noteStoreFailure(PushStoreFailure.reason(error))
            }
        }
        let kept = TokenPersistence.rememberAfter(action: action, registerSucceeded: true)
        if let kept {
            coordinator.remember(kept)
        }
    }
}

final class PushAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Task { @MainActor in
                PushCoordinator.shared.receive(remote)
            }
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .sq8PushToken, object: DeviceTokenHex.string(from: deviceToken))
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        let reason = error.localizedDescription
        Task { @MainActor in
            PushCoordinator.shared.noteRegistrationFailure(reason)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        let show = await MainActor.run { PushCoordinator.shared.showsBanner(userInfo) }
        return show ? [.banner, .sound] : []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { PushCoordinator.shared.receive(userInfo) }
    }
}

extension Notification.Name {
    static let sq8PushToken = Notification.Name("sq8.push.token")
    static let sq8PushRoute = Notification.Name("sq8.push.route")
}

extension PushAuthState {
    init(status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined:
            self = .notDetermined
        case .denied:
            self = .denied
        case .authorized:
            self = .authorized
        case .provisional:
            self = .provisional
        case .ephemeral:
            self = .ephemeral
        @unknown default:
            self = .unknown
        }
    }
}
