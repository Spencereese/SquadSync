import Flutter
import UIKit
import UserNotifications

enum SimulatorAppLinks {
  static func isAuthScheme(_ url: URL) -> Bool {
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme.contains("googleusercontent") { return true }
    let host = url.host?.lowercased() ?? ""
    let path = url.path.lowercased()
    if scheme == "com.example.codsquadapp" {
      return host == "auth-callback" || path.contains("auth-callback")
    }
    if (scheme == "https" || scheme == "http") && host.contains("supabase.co") {
      return path.contains("/auth")
    }
    return false
  }

  static func shouldSwallowSimulatorAppLink(_ url: URL) -> Bool {
    if isAuthScheme(url) { return false }
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme == "codsquadapp" || scheme == "com.example.codsquadapp" {
      return true
    }
    let host = url.host?.lowercased() ?? ""
    if scheme == "https" || scheme == "http" {
      if host == "lobbiesync.app" || host.hasSuffix(".lobbiesync.app") {
        return true
      }
      if host.contains("supabase.co") { return true }
    }
    return false
  }

  static func shouldClearSimulatorUserActivity(_ activity: NSUserActivity) -> Bool {
    if activity.activityType == NSUserActivityTypeBrowsingWeb { return true }
    if let url = activity.webpageURL {
      return shouldSwallowSimulatorAppLink(url)
    }
    return false
  }

  static func logOpen(source: String, url: URL, swallow: Bool) {
    NSLog(
      "Cod Squad: sim \(source) scheme=\(url.scheme ?? "") host=\(url.host ?? "") path=\(url.path) swallow=\(swallow)"
    )
  }

  static func consumeSceneConnection(_ options: UIScene.ConnectionOptions) {
    NSLog(
      "Cod Squad: sim scene connect urls=\(options.URLContexts.count) activities=\(options.userActivities.count)"
    )
    for context in options.URLContexts {
      let swallow = shouldSwallowSimulatorAppLink(context.url)
      logOpen(source: "scene URLContexts", url: context.url, swallow: swallow)
    }
    for activity in options.userActivities {
      if let url = activity.webpageURL {
        logOpen(
          source: "scene userActivity",
          url: url,
          swallow: shouldSwallowSimulatorAppLink(url)
        )
      } else {
        NSLog("Cod Squad: sim scene userActivity type=\(activity.activityType) url=nil")
      }
      if shouldClearSimulatorUserActivity(activity) {
        activity.invalidate()
      }
    }
  }

  static func clearPendingUniversalLinkHandoff() {
    NSUserActivity.deleteAllSavedUserActivities {
      NSLog("Cod Squad: sim cleared saved NSUserActivity handoff")
    }
    for scene in UIApplication.shared.connectedScenes {
      scene.userActivity = nil
      scene.session.stateRestorationActivity = nil
      if let windowScene = scene as? UIWindowScene {
        for window in windowScene.windows {
          window.windowScene?.userActivity = nil
        }
      }
    }
    NSLog("Cod Squad: sim cleared pending UL / associated-domains handoff")
  }
}

#if targetEnvironment(simulator)
class RunnerSceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    SimulatorAppLinks.consumeSceneConnection(connectionOptions)
    super.scene(scene, willConnectTo: session, options: connectionOptions)
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    var remaining = Set<UIOpenURLContext>()
    for context in URLContexts {
      let swallow = SimulatorAppLinks.shouldSwallowSimulatorAppLink(context.url)
      SimulatorAppLinks.logOpen(source: "scene:openURLContexts", url: context.url, swallow: swallow)
      if !swallow {
        remaining.insert(context)
      }
    }
    if remaining.isEmpty { return }
    super.scene(scene, openURLContexts: remaining)
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    if let url = userActivity.webpageURL {
      let swallow = SimulatorAppLinks.shouldSwallowSimulatorAppLink(url)
      SimulatorAppLinks.logOpen(source: "scene:continue", url: url, swallow: swallow)
    } else {
      NSLog("Cod Squad: sim scene:continue type=\(userActivity.activityType) url=nil")
    }
    if SimulatorAppLinks.shouldClearSimulatorUserActivity(userActivity) {
      userActivity.invalidate()
      return
    }
    super.scene(scene, continue: userActivity)
  }
}
#endif

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
    SimulatorAppLinks.clearPendingUniversalLinkHandoff()
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
    SimulatorAppLinks.clearPendingUniversalLinkHandoff()
    Self.observeSimulatorScenes()
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
  override func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    SimulatorAppLinks.consumeSceneConnection(options)
    let config = UISceneConfiguration(
      name: nil,
      sessionRole: connectingSceneSession.role
    )
    config.delegateClass = RunnerSceneDelegate.self
    return config
  }

  /// Consume leftover universal / custom-scheme chat links on Simulator so
  /// iOS does not show "Open in Cod Squad?" over ChatScreen.
  /// Google / Supabase auth schemes are not swallowed.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let swallow = SimulatorAppLinks.shouldSwallowSimulatorAppLink(url)
    SimulatorAppLinks.logOpen(source: "application:open url", url: url, swallow: swallow)
    if swallow { return true }
    return super.application(app, open: url, options: options)
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if let url = userActivity.webpageURL {
      let swallow = SimulatorAppLinks.shouldSwallowSimulatorAppLink(url)
      SimulatorAppLinks.logOpen(source: "application:continue", url: url, swallow: swallow)
    } else {
      NSLog("Cod Squad: sim application:continue type=\(userActivity.activityType) url=nil")
    }
    if SimulatorAppLinks.shouldClearSimulatorUserActivity(userActivity) {
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
  private static func observeSimulatorScenes() {
    NotificationCenter.default.addObserver(
      forName: UIScene.willConnectNotification,
      object: nil,
      queue: .main
    ) { note in
      guard let scene = note.object as? UIScene else { return }
      NSLog("Cod Squad: sim UIScene.willConnect role=\(scene.session.role.rawValue)")
      if let activity = scene.session.stateRestorationActivity {
        if SimulatorAppLinks.shouldClearSimulatorUserActivity(activity) {
          activity.invalidate()
          scene.session.stateRestorationActivity = nil
        }
      }
      SimulatorAppLinks.clearPendingUniversalLinkHandoff()
    }
  }

  private static func strippingSimulatorAppLinks(
    from launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> [UIApplication.LaunchOptionsKey: Any]? {
    guard var options = launchOptions else { return launchOptions }
    if let url = options[.url] as? URL {
      let swallow = SimulatorAppLinks.shouldSwallowSimulatorAppLink(url)
      SimulatorAppLinks.logOpen(source: "launchOptions.url", url: url, swallow: swallow)
      if swallow {
        options.removeValue(forKey: .url)
      }
    }
    if let dict = options[.userActivityDictionary] as? [AnyHashable: Any] {
      var filtered: [AnyHashable: Any] = [:]
      var removedSwallow = false
      for (key, value) in dict {
        if let activity = value as? NSUserActivity,
           SimulatorAppLinks.shouldClearSimulatorUserActivity(activity) {
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
    if let url, SimulatorAppLinks.shouldSwallowSimulatorAppLink(url) { leftover = true }
    if let dict {
      for value in dict.values {
        if let activity = value as? NSUserActivity,
           SimulatorAppLinks.shouldClearSimulatorUserActivity(activity) {
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
#endif
}
