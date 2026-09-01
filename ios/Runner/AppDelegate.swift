import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var runtimeChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
#if targetEnvironment(simulator)
    let stripped = Self.strippingSimulatorAppLinks(from: launchOptions)
    Self.logLaunchStrip(stage: "willFinish", original: launchOptions, stripped: stripped)
    return super.application(application, willFinishLaunchingWithOptions: stripped)
#else
    return super.application(application, willFinishLaunchingWithOptions: launchOptions)
#endif
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    var options = launchOptions
#if targetEnvironment(simulator)
    options = Self.strippingSimulatorAppLinks(from: launchOptions)
    Self.logLaunchStrip(stage: "didFinish", original: launchOptions, stripped: options)
    Self.confirmNoAssociatedDomainLeftover(options)
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
    let launched = super.application(application, didFinishLaunchingWithOptions: options)
    registerRuntimeChannel()
    return launched
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
      return true
    }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if Self.shouldClearSimulatorUserActivity(userActivity) {
      NSLog(
        "Cod Squad: swallow simulator universal-link handoff type=\(userActivity.activityType) url=\(userActivity.webpageURL?.absoluteString ?? "nil")"
      )
      userActivity.invalidate()
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

  private func registerRuntimeChannel() {
    if runtimeChannel != nil { return }
    guard let messenger = flutterMessenger() else {
      NSLog("Cod Squad: runtime channel messenger missing; retry")
      DispatchQueue.main.async { [weak self] in
        self?.registerRuntimeChannel()
      }
      return
    }
    let channel = FlutterMethodChannel(
      name: "com.example.codSquadApp/runtime",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      if call.method == "isIosSimulator" {
#if targetEnvironment(simulator)
        result(true)
#else
        result(false)
#endif
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    runtimeChannel = channel
  }

  private func flutterMessenger() -> FlutterBinaryMessenger? {
    if let controller = window?.rootViewController as? FlutterViewController {
      return controller.binaryMessenger
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for window in scenes.flatMap({ $0.windows }) {
      if let controller = window.rootViewController as? FlutterViewController {
        return controller.binaryMessenger
      }
    }
    return nil
  }

#if targetEnvironment(simulator)
  private static func strippingSimulatorAppLinks(
    from launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> [UIApplication.LaunchOptionsKey: Any]? {
    guard var options = launchOptions else { return launchOptions }
    if let url = options[.url] as? URL, shouldSwallowSimulatorAppLink(url) {
      NSLog("Cod Squad: strip launch URL scheme=\(url.scheme ?? "")")
      options.removeValue(forKey: .url)
    }
    if let dict = options[.userActivityDictionary] as? [AnyHashable: Any] {
      var filtered: [AnyHashable: Any] = [:]
      var removedSwallow = false
      for (key, value) in dict {
        if let activity = value as? NSUserActivity,
           shouldClearSimulatorUserActivity(activity) {
          NSLog(
            "Cod Squad: strip launch userActivity type=\(activity.activityType) url=\(activity.webpageURL?.absoluteString ?? "nil")"
          )
          activity.invalidate()
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

  private static func confirmNoAssociatedDomainLeftover(
    _ options: [UIApplication.LaunchOptionsKey: Any]?
  ) {
    let url = options?[.url] as? URL
    let dict = options?[.userActivityDictionary] as? [AnyHashable: Any]
    var leftover = false
    if let url, shouldSwallowSimulatorAppLink(url) { leftover = true }
    if let dict {
      for value in dict.values {
        if let activity = value as? NSUserActivity,
           shouldClearSimulatorUserActivity(activity) {
          leftover = true
        }
      }
    }
    NSLog(
      "Cod Squad: launchOptions leftover=\(leftover) url=\(url?.absoluteString ?? "nil") userActivity=\(dict != nil)"
    )
  }

  private static func logLaunchStrip(
    stage: String,
    original: [UIApplication.LaunchOptionsKey: Any]?,
    stripped: [UIApplication.LaunchOptionsKey: Any]?
  ) {
    let originalUrl = (original?[.url] as? URL)?.absoluteString ?? "nil"
    let strippedUrl = (stripped?[.url] as? URL)?.absoluteString ?? "nil"
    let originalActivity = original?[.userActivityDictionary] != nil
    let strippedActivity = stripped?[.userActivityDictionary] != nil
    NSLog(
      "Cod Squad: \(stage) launch strip originalUrl=\(originalUrl) strippedUrl=\(strippedUrl) originalActivity=\(originalActivity) strippedActivity=\(strippedActivity)"
    )
  }

  static func shouldClearSimulatorUserActivity(_ activity: NSUserActivity) -> Bool {
    if activity.activityType == NSUserActivityTypeBrowsingWeb {
      return true
    }
    if let url = activity.webpageURL {
      return shouldSwallowSimulatorAppLink(url)
    }
    return false
  }

  static func shouldSwallowSimulatorAppLink(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme == "com.example.codsquadapp" { return false }
    if scheme.contains("googleusercontent") { return false }
    if scheme == "codsquadapp" { return true }
    let host = url.host?.lowercased() ?? ""
    if scheme == "https" || scheme == "http" {
      if host == "lobbiesync.app" || host.hasSuffix(".lobbiesync.app") {
        return true
      }
      if host.contains("supabase.co") && !url.path.lowercased().contains("/auth") {
        return true
      }
    }
    return false
  }
#endif
}
