import Foundation
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
    private(set) var pending: PushPayload?
    var viewingSquad: UUID?
    private var registeredToken: String?
    private var asked = false

    private let tokenKey = "sq8.push.registered-token"
    private let askedKey = "sq8.push.permission-asked"

    init() {
        registeredToken = UserDefaults.standard.string(forKey: tokenKey)
        asked = UserDefaults.standard.bool(forKey: askedKey)
    }

    func consumeLaunchArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let json = LaunchOptions.flag("-debug-push-open", in: arguments),
              let payload = PushPayloadParser.parse(jsonText: json) else { return }
        pending = payload
    }

    func receive(_ userInfo: [AnyHashable: Any]) {
        guard let payload = PushPayloadParser.parse(userInfo) else { return }
        pending = payload
        NotificationCenter.default.post(name: .sq8PushRoute, object: nil)
    }

    func showsBanner(_ userInfo: [AnyHashable: Any]) -> Bool {
        guard let payload = PushPayloadParser.parse(userInfo) else { return true }
        return PushBanner.shows(viewingSquad: viewingSquad, payload: payload)
    }

    func settle(signedIn: Bool, squadId: UUID?, membershipKnown: Bool) {
        viewingSquad = signedIn ? squadId : nil
        guard let pending else { return }
        let member = squadId == pending.squadId
        switch PushLanding.step(
            payload: pending,
            signedIn: signedIn,
            membershipKnown: membershipKnown,
            memberOfTarget: member
        ) {
        case .holdUntilSignedIn:
            return
        case .notAMember:
            notice = PushNotice.notAMember
            openedChat = false
            openedSquad = false
            focusMessage = nil
            self.pending = nil
        case .open(let payload):
            notice = ""
            openedChat = payload.kind == .chat
            openedSquad = payload.kind == .squad
            focusMessage = payload.messageId
            self.pending = nil
        }
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

    func plan(_ token: String) -> TokenRotation.Action {
        TokenRotation.onToken(token, previous: registeredToken)
    }

    func remember(_ token: String) {
        registeredToken = token
        UserDefaults.standard.set(token, forKey: tokenKey)
    }

    func signOutAction() -> TokenRotation.Action {
        let action = TokenRotation.onSignOut(previous: registeredToken)
        registeredToken = nil
        UserDefaults.standard.removeObject(forKey: tokenKey)
        viewingSquad = nil
        return action
    }

    #if DEBUG
    func resetForTests() {
        pending = nil
        notice = ""
        openedChat = false
        openedSquad = false
        focusMessage = nil
        registeredToken = nil
        asked = false
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: askedKey)
    }
    #endif
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
