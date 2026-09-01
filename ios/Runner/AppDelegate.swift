import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var options = launchOptions
#if targetEnvironment(simulator)
    options = Self.strippingSimulatorAppLinks(from: launchOptions)
    DispatchQueue.main.async {
      Self.dismissOpenInAppPromptIfPresent()
    }
#endif
    GeneratedPluginRegistrant.register(with: self)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    // Do not call registerForRemoteNotifications() at launch.
    // The example GoogleService-Info.plist uses YOUR_ placeholders and has
    // no real APNs/FCM identity. Firebase Messaging registers after the
    // in-app permission prompt once a real plist is in place.
    // UIScene plugin deprecations: parked. Flutter still uses
    // FlutterAppDelegate; no UIApplicationSceneManifest rewrite.
    if !Self.hasRealFirebasePlist() {
      NSLog("Cod Squad: skipping APNs registration (placeholder GoogleService-Info)")
    }
    return super.application(application, didFinishLaunchingWithOptions: options)
  }

#if targetEnvironment(simulator)
  /// Consume leftover universal / custom-scheme chat links on Simulator so
  /// iOS does not show "Open in Cod Squad?" over ChatScreen.
  /// Auth schemes (Supabase / Google) are not swallowed.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if Self.shouldSwallowSimulatorAppLink(url) {
      NSLog("Cod Squad: swallow simulator app link scheme=\(url.scheme ?? "")")
      DispatchQueue.main.async {
        Self.dismissOpenInAppPromptIfPresent()
      }
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
       let url = userActivity.webpageURL,
       Self.shouldSwallowSimulatorAppLink(url) {
      NSLog("Cod Squad: swallow simulator universal link")
      DispatchQueue.main.async {
        Self.dismissOpenInAppPromptIfPresent()
      }
      return true
    }
    return super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
  }
#endif

  /// True only when GoogleService-Info.plist looks like a real Firebase app.
  private static func hasRealFirebasePlist() -> Bool {
    guard
      let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
      let dict = NSDictionary(contentsOfFile: path),
      let googleAppId = dict["GOOGLE_APP_ID"] as? String,
      let projectId = dict["PROJECT_ID"] as? String
    else {
      return false
    }
    let haystack = "\(googleAppId) \(projectId)".uppercased()
    let placeholders = ["YOUR_", "YOUR_FIREBASE", "YOUR_GCM", "YOUR_IOS"]
    return !placeholders.contains { haystack.contains($0) }
  }

#if targetEnvironment(simulator)
  private static func strippingSimulatorAppLinks(
    from launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> [UIApplication.LaunchOptionsKey: Any]? {
    guard var options = launchOptions else { return launchOptions }
    if let url = options[.url] as? URL, shouldSwallowSimulatorAppLink(url) {
      options.removeValue(forKey: .url)
    }
    if let dict = options[.userActivityDictionary] as? [AnyHashable: Any] {
      var filtered: [AnyHashable: Any] = [:]
      var removedSwallow = false
      for (key, value) in dict {
        if let activity = value as? NSUserActivity,
           let url = activity.webpageURL,
           shouldSwallowSimulatorAppLink(url) {
          removedSwallow = true
          continue
        }
        filtered[key] = value
      }
      if removedSwallow {
        let hasRemainingActivity = filtered.values.contains { $0 is NSUserActivity }
        if hasRemainingActivity {
          options[.userActivityDictionary] = filtered
        } else {
          options.removeValue(forKey: .userActivityDictionary)
        }
      }
    }
    return options
  }

  /// Both "open in" and "cod squad", or Cancel + Open action titles.
  static func shouldDismissOpenInAppPrompt(
    title: String?,
    message: String?,
    actionTitles: [String]
  ) -> Bool {
    let text = "\(title ?? "") \(message ?? "")".lowercased()
    let hasOpenIn = text.contains("open in")
    let hasCodSquad = text.contains("cod squad")
    if hasOpenIn && hasCodSquad { return true }
    let actions = Set(actionTitles.map { $0.lowercased() })
    return actions.contains("cancel") && actions.contains("open")
  }

  private static func shouldSwallowSimulatorAppLink(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme == "codsquadapp" { return true }
    let host = url.host?.lowercased() ?? ""
    if scheme == "https" || scheme == "http" {
      return host == "lobbiesync.app" || host.hasSuffix(".lobbiesync.app")
    }
    return false
  }

  private static func dismissOpenInAppPromptIfPresent() {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for window in scenes.flatMap({ $0.windows }) {
      guard var top = window.rootViewController else { continue }
      while let presented = top.presentedViewController {
        top = presented
      }
      guard let alert = top as? UIAlertController else { continue }
      if Self.shouldDismissOpenInAppPrompt(
        title: alert.title,
        message: alert.message,
        actionTitles: alert.actions.compactMap { $0.title }
      ) {
        alert.dismiss(animated: false)
      }
    }
  }
#endif
}
