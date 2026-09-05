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

  static func isProductCustomScheme(_ url: URL) -> Bool {
    (url.scheme?.lowercased() ?? "") == "codsquadapp"
  }

  static func shouldSwallowSimulatorAppLink(_ url: URL) -> Bool {
    if isAuthScheme(url) { return false }
    // Product custom-scheme (codsquadapp://lobby/<id> etc.) must reach
    // Flutter. Leftover https UL and the bundle-id scheme still drop.
    if isProductCustomScheme(url) { return false }
    let scheme = url.scheme?.lowercased() ?? ""
    if scheme == "com.example.codsquadapp" {
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

  /// Logs leftover scene URLs. Does not dismiss SpringBoard's system
  /// "Open in Cod Squad?" sheet (Cancel + Open). In-app / VC dismiss cannot
  /// take down that overlay. Google / Supabase auth stays unsallowed.
  ///
  /// Sim Info.plist omits `codsquadapp` and `.chat` NSUserActivity.
  /// Default CODE_SIGN_ENTITLEMENTS is Runner.simulator.entitlements
  /// (no applinks) so Launch Services cannot register leftover UL.
  /// Device keeps applinks via [sdk=iphoneos*].
  ///
  /// After a clean Xcode 26 compile, rebuild LS then SpringBoard
  /// (do NOT erase the sim):
  ///   xcrun simctl terminate 748CAA89-6E32-4FDE-88A3-248F13D21235 com.example.codSquadApp
  ///   xcrun simctl terminate 748CAA89-6E32-4FDE-88A3-248F13D21235 com.apple.mobilesafari
  ///   xcrun simctl spawn 748CAA89-6E32-4FDE-88A3-248F13D21235 /usr/bin/killall lsd
  ///   xcrun simctl spawn 748CAA89-6E32-4FDE-88A3-248F13D21235 /usr/bin/killall SpringBoard
  static func consumeSceneConnection(_ options: UIScene.ConnectionOptions) {
    NSLog(
      "Cod Squad: sim scene connect urls=\(options.urlContexts.count) activities=\(options.userActivities.count)"
    )
    for context in options.urlContexts {
      let swallow = shouldSwallowSimulatorAppLink(context.url)
      logOpen(source: "scene urlContexts", url: context.url, swallow: swallow)
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
}

#if targetEnvironment(simulator)
class RunnerSceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    SimulatorAppLinks.consumeSceneConnection(connectionOptions)
    // Do not call super.scene(willConnect) — FlutterSceneDelegate treats
    // AppDelegate.window as a launch window, creates a second UIWindow,
    // and Dart paints off the Simulator-captured surface.
    hostFlutterView(on: scene)
    if let engine = (window?.rootViewController as? FlutterViewController)?.engine {
      _ = self.registerSceneLifeCycle(with: engine)
      AppDelegate.bindRuntimeChannelFromScene(window: window)
    } else {
      AppDelegate.scheduleDelayedRuntimeChannelBind()
    }
    DispatchQueue.main.async {
      AppDelegate.bindRuntimeChannelFromScene(window: self.window)
      // willConnect skips super.scene(willConnect) (second window).
      // Forward product custom-scheme URLs so AppLinks sees them.
      var remaining = Set<UIOpenURLContext>()
      for context in connectionOptions.urlContexts {
        if !SimulatorAppLinks.shouldSwallowSimulatorAppLink(context.url) {
          remaining.insert(context)
        }
      }
      if !remaining.isEmpty {
        self.scene(scene, openURLContexts: remaining)
      }
    }
  }

  /// One FlutterEngine only. AppDelegate/launchEngine already ran Dart
  /// (`didFinishRegistrar`). Do not storyboard.instantiateInitialViewController
  /// or FlutterViewController() — those create a second engine and SIGABRT
  /// ("This FlutterEngine was already invoked").
  private func hostFlutterView(on scene: UIScene) {
    guard let windowScene = scene as? UIWindowScene else { return }
    if window == nil {
      window = UIWindow(windowScene: windowScene)
    }
    window?.windowScene = windowScene
    for other in windowScene.windows where other !== window {
      other.isHidden = true
    }
    if let existing = AppDelegate.existingFlutterViewController() {
      if window?.rootViewController !== existing {
        window?.rootViewController = existing
      }
    } else if !(window?.rootViewController is FlutterViewController),
      let engine = AppDelegate.existingRunningEngine()
    {
      window?.rootViewController = FlutterViewController(
        engine: engine,
        nibName: nil,
        bundle: nil
      )
    }
    if let flutter = window?.rootViewController as? FlutterViewController {
      flutter.engine.viewController = flutter
      let host = window ?? UIWindow()
      flutter.view.isHidden = false
      flutter.view.alpha = 1
      if flutter.view.bounds.isEmpty || flutter.view.bounds.size == .zero {
        flutter.view.frame = host.bounds
      }
      host.layoutIfNeeded()
      flutter.view.layoutIfNeeded()
    }
    window?.isHidden = false
    window?.makeKeyAndVisible()
    let flutter = window?.rootViewController as? FlutterViewController
    let view = flutter?.view
    let hosted = flutter != nil
    let inHierarchy = view?.window != nil
    let size = view?.bounds.size ?? .zero
    let hidden = view?.isHidden ?? true
    let line =
      "Cod Squad: sim scene hosted FVC=\(hosted) key=\(window?.isKeyWindow == true) " +
      "inHierarchy=\(inHierarchy) size=\(size.width)x\(size.height) hidden=\(hidden)"
    NSLog("%@", line)
    print(line)
    if let data = (line + "\n").data(using: .utf8) {
      FileHandle.standardError.write(data)
    }
    // Native stderr before Dart attach is not captured by `flutter run`.
    // Replay the same line over the runtime channel after the engine binds.
    AppDelegate.noteSimSceneHosted(line)
  }

  override func scene(_ scene: UIScene, openURLContexts urlContexts: Set<UIOpenURLContext>) {
    var remaining = Set<UIOpenURLContext>()
    for context in urlContexts {
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
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  FlutterPluginRegistrant
{
  private var runtimeChannel: FlutterMethodChannel?
  private var runtimeChannelAttempts = 0
  private static let maxRuntimeChannelAttempts = 8
  private static let runtimeChannelRetryDelay: TimeInterval = 0.25
  private var simSceneHostedLine: String?
  private var simSceneHostedEmitAttempts = 0
  private static let maxSimSceneHostedEmitAttempts = 12
  private static let simSceneHostedEmitDelay: TimeInterval = 0.25

#if targetEnvironment(simulator)
  /// Scene-owned key window only. Ignore launch-window assignment so
  /// FlutterSceneDelegate does not move the FVC off the captured surface.
  override var window: UIWindow? {
    get {
      let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
      for scene in scenes {
        if let key = scene.windows.first(where: { $0.isKeyWindow }) {
          return key
        }
        if let hosted = scene.windows.first(where: {
          $0.rootViewController is FlutterViewController && !$0.isHidden
        }) {
          return hosted
        }
      }
      return nil
    }
    set {
      NSLog("Cod Squad: ignore AppDelegate.window set under UIScene")
    }
  }
#endif

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
    Self.logSimulatorAssociatedDomainsClaim()
#endif
    pluginRegistrant = self
    GeneratedPluginRegistrant.register(with: self)
    bindRuntimeChannelFromRegistry(self, source: "didFinishRegistrar")
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }
    // Do not call registerForRemoteNotifications() at launch.
    // The example GoogleService-Info.plist uses YOUR_ placeholders and has
    // no real APNs/FCM identity. Firebase Messaging registers after the
    // in-app permission prompt once a real plist is in place.
    if !Self.hasRealFirebasePlist() {
      NSLog("Cod Squad: skipping APNs registration (placeholder GoogleService-Info)")
    }
    let launched = super.application(application, didFinishLaunchingWithOptions: options)
    if runtimeChannel == nil {
      scheduleDelayedRuntimeChannelBind()
    }
    return launched
  }

  /// Flutter 3.47 UIScene path: implicit engine is ready before
  /// AppDelegate.window exists. Bind com.example.codSquadApp/runtime here
  /// so isIosSimulator answers on Simulator.
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    bindRuntimeChannel(
      on: engineBridge.applicationRegistrar.messenger(),
      source: "implicitEngine"
    )
  }

  func register(with registry: FlutterPluginRegistry) {
    GeneratedPluginRegistrant.register(with: registry)
    bindRuntimeChannelFromRegistry(registry, source: "pluginRegistrant")
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
    // Do not set config.storyboard — iOS would instantiate a second
    // Main FlutterViewController and re-invoke the running engine.
    return config
  }

  /// Consume leftover https Universal Links on Simulator so iOS does not
  /// show "Open in Cod Squad?" over ChatScreen. Product `codsquadapp://`
  /// URLs (lobby / squad / peacock / chat / join) are forwarded to Flutter.
  /// Google / Supabase auth schemes are not swallowed.
  /// Does not dismiss an already-presented SpringBoard sheet.
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

  static func existingFlutterViewController() -> FlutterViewController? {
    if let app = UIApplication.shared.delegate as? FlutterAppDelegate,
       let controller = app.window?.rootViewController as? FlutterViewController
    {
      return controller
    }
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for window in scenes.flatMap({ $0.windows }) {
      if let controller = window.rootViewController as? FlutterViewController {
        return controller
      }
    }
    return nil
  }

  /// Launch engine already ran Dart. takeLaunchEngine transfers it once.
  /// Never create a new implicit FlutterEngine after that.
  static func existingRunningEngine() -> FlutterEngine? {
    if let engine = existingFlutterViewController()?.engine {
      return engine
    }
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return nil }
    let selector = NSSelectorFromString("takeLaunchEngine")
    guard app.responds(to: selector) else { return nil }
    guard let result = app.perform(selector) else { return nil }
    return result.takeUnretainedValue() as? FlutterEngine
  }

  static func bindRuntimeChannelFromScene(window: UIWindow?) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    if let controller = window?.rootViewController as? FlutterViewController {
      app.bindRuntimeChannel(on: controller.binaryMessenger, source: "sceneDelegate")
      return
    }
    app.bindRuntimeChannelFromAvailableMessenger(source: "sceneWindows")
    if app.runtimeChannel == nil {
      app.scheduleDelayedRuntimeChannelBind()
    }
  }

  static func scheduleDelayedRuntimeChannelBind() {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    app.scheduleDelayedRuntimeChannelBind()
  }

  private func bindRuntimeChannelFromRegistry(
    _ registry: FlutterPluginRegistry,
    source: String
  ) {
    guard let registrar = registry.registrar(forPlugin: "CodSquadRuntime") else {
      NSLog("Cod Squad: runtime registrar missing source=\(source)")
      return
    }
    bindRuntimeChannel(on: registrar.messenger(), source: source)
  }

  private func bindRuntimeChannel(on messenger: FlutterBinaryMessenger, source: String) {
    PeacockLockLiveActivityBridge.register(on: messenger)
    if runtimeChannel != nil { return }
    let channel = FlutterMethodChannel(
      name: "com.example.codSquadApp/runtime",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "isIosSimulator" {
#if targetEnvironment(simulator)
        result(true)
#else
        result(false)
#endif
      } else if call.method == "getSimSceneHosted" {
        result(self?.simSceneHostedLine)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    runtimeChannel = channel
    NSLog("Cod Squad: runtime channel bound source=\(source)")
    simSceneHostedEmitAttempts = 0
    emitSimSceneHostedToDart()
  }

  static func noteSimSceneHosted(_ line: String) {
    guard let app = UIApplication.shared.delegate as? AppDelegate else { return }
    app.simSceneHostedLine = line
    app.simSceneHostedEmitAttempts = 0
    app.emitSimSceneHostedToDart()
  }

  /// Flutter `debugPrint` after Dart attach so `flutter run` stdout sees the host line.
  private func emitSimSceneHostedToDart() {
    guard let line = simSceneHostedLine else { return }
    if let channel = runtimeChannel {
      channel.invokeMethod("simSceneHosted", arguments: line)
    }
    simSceneHostedEmitAttempts += 1
    if simSceneHostedEmitAttempts >= Self.maxSimSceneHostedEmitAttempts {
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.simSceneHostedEmitDelay) {
      [weak self] in
      self?.emitSimSceneHostedToDart()
    }
  }

  private func bindRuntimeChannelFromAvailableMessenger(source: String) {
    if runtimeChannel != nil { return }
    if let messenger = flutterMessenger() {
      bindRuntimeChannel(on: messenger, source: source)
      return
    }
    bindRuntimeChannelFromRegistry(self, source: source)
  }

  private func scheduleDelayedRuntimeChannelBind() {
    if runtimeChannel != nil { return }
    runtimeChannelAttempts += 1
    if runtimeChannelAttempts > Self.maxRuntimeChannelAttempts {
      NSLog(
        "Cod Squad: runtime channel messenger missing; stop delayed retry after \(Self.maxRuntimeChannelAttempts)"
      )
      return
    }
    NSLog(
      "Cod Squad: runtime channel waiting for engine \(runtimeChannelAttempts)/\(Self.maxRuntimeChannelAttempts)"
    )
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.runtimeChannelRetryDelay) { [weak self] in
      guard let self else { return }
      self.bindRuntimeChannelFromAvailableMessenger(source: "delayed")
      if self.runtimeChannel == nil {
        self.scheduleDelayedRuntimeChannelBind()
      }
    }
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

  /// Launch Services reads embedded applinks. Sim builds must log absent.
  private static func logSimulatorAssociatedDomainsClaim() {
    let urls = [
      Bundle.main.url(forResource: "archived-expanded-entitlements", withExtension: "xcent"),
      Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
    ]
    var domains: Any?
    for url in urls.compactMap({ $0 }) {
      if let dict = NSDictionary(contentsOf: url) {
        domains = dict["com.apple.developer.associated-domains"]
        if domains != nil { break }
      }
    }
    if let domains {
      NSLog("Cod Squad: SIM STILL HAS associated-domains=\(domains)")
    } else {
      NSLog("Cod Squad: sim associated-domains absent (no leftover UL claim)")
    }
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
