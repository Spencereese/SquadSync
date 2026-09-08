import ActivityKit
import Flutter
import Foundation

/// Peacock-lock Live Activity bridge on the existing Runner target.
///
/// Starts / updates / ends via `com.squadsync/live_activities`.
/// Lock Screen UI still requires a Widget Extension (separate App ID in
/// the Apple Developer portal): `com.example.codSquadApp.PeacockLockWidget`.
/// Identity only — no new lock-screen UI in this file. Runner bundle ID
/// stays `com.example.codSquadApp`.
struct PeacockLockAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var phase: String
    var seatedCount: Int
    var readyCount: Int
    var gameName: String
    var title: String
    var body: String
    var deepLink: String
  }

  var lobbyId: String
}

enum PeacockLockLiveActivityBridge {
  static let channelName = "com.squadsync/live_activities"
  private static var registered = false

  static func register(on messenger: FlutterBinaryMessenger) {
    if registered { return }
    registered = true
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handle(call, result: result)
    }
  }

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(isSupported())
    case "startPeacockLockActivity":
      start(call.arguments, result: result)
    case "updatePeacockLockActivity":
      update(call.arguments, result: result)
    case "startFillPinActivity":
      startFillPin(call.arguments, result: result)
    case "updateFillPinActivity":
      updateFillPin(call.arguments, result: result)
    case "endActivity":
      end(call.arguments, result: result)
    case "endAllActivities":
      endAll(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func isSupported() -> Bool {
    if #available(iOS 16.1, *) {
      return ActivityAuthorizationInfo().areActivitiesEnabled
    }
    return false
  }

  private static func args(_ raw: Any?) -> [String: Any] {
    raw as? [String: Any] ?? [:]
  }

  private static func start(_ raw: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    let payload = args(raw)
    do {
      let id = try requestActivity(payload)
      result(id)
    } catch {
      NSLog("Cod Squad: peacock lock Live Activity start failed: \(error)")
      result(nil)
    }
  }

  private static func update(_ raw: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }
    let payload = args(raw)
    let activityId = payload["activityId"] as? String
    let state = contentState(from: payload)
    Task {
      await applyUpdate(activityId: activityId, state: state)
      result(true)
    }
  }

  private static func startFillPin(_ raw: Any?, result: @escaping FlutterResult) {
    FillPinLiveActivityBridge.start(raw, result: result)
  }

  private static func updateFillPin(_ raw: Any?, result: @escaping FlutterResult) {
    FillPinLiveActivityBridge.update(raw, result: result)
  }

  private static func end(_ raw: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    let activityId = args(raw)["activityId"] as? String
    Task {
      await applyEnd(activityId: activityId)
      result(nil)
    }
  }

  private static func endAll(result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    Task {
      await applyEnd(activityId: nil)
      result(nil)
    }
  }

  @available(iOS 16.1, *)
  private static func requestActivity(_ payload: [String: Any]) throws -> String {
    let lobbyId = payload["lobbyId"] as? String ?? ""
    let attributes = PeacockLockAttributes(lobbyId: lobbyId)
    let state = contentState(from: payload)
    if #available(iOS 16.2, *) {
      let content = ActivityContent(state: state, staleDate: nil)
      let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: nil
      )
      return activity.id
    }
    let activity = try Activity.request(
      attributes: attributes,
      contentState: state,
      pushType: nil
    )
    return activity.id
  }

  @available(iOS 16.1, *)
  private static func contentState(from payload: [String: Any]) -> PeacockLockAttributes.ContentState {
    PeacockLockAttributes.ContentState(
      phase: payload["phase"] as? String ?? "ready",
      seatedCount: payload["seatedCount"] as? Int ?? 0,
      readyCount: payload["readyCount"] as? Int ?? 0,
      gameName: payload["gameName"] as? String ?? "",
      title: payload["title"] as? String ?? "",
      body: payload["body"] as? String ?? "",
      deepLink: payload["deepLink"] as? String ?? ""
    )
  }

  @available(iOS 16.1, *)
  private static func applyUpdate(
    activityId: String?,
    state: PeacockLockAttributes.ContentState
  ) async {
    for activity in Activity<PeacockLockAttributes>.activities {
      if let activityId, activity.id != activityId { continue }
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
      } else {
        await activity.update(using: state)
      }
    }
  }

  @available(iOS 16.1, *)
  private static func applyEnd(activityId: String?) async {
    for activity in Activity<PeacockLockAttributes>.activities {
      if let activityId, activity.id != activityId { continue }
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
    await FillPinLiveActivityBridge.applyEnd(activityId: activityId)
  }
}

/// PIN WAVE P2 — Fill PIN Live Activity attributes on the existing Runner
/// target. Payload carries Sit / Coming / Can't + Coming mm:ss + chat
/// deep link. Lock Screen *buttons* still need a Widget Extension +
/// App Intents (`com.example.codSquadApp.FillPinWidget`) — identity only
/// here. Flight / Spencer: verify start/update payload on device; buttons
/// and tap-through will not appear until that extension exists.
struct FillPinAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var phase: String
    var seated: Int
    var maxSpots: Int
    var gameName: String
    var holdLabel: String
    var holdRemainingSeconds: Int
    var actions: [String]
    var actionIds: [String]
    var title: String
    var body: String
    var deepLink: String
  }

  var pinId: String
  var chatGroupId: String
  var lobbyId: String
}

enum FillPinLiveActivityBridge {
  private static func args(_ raw: Any?) -> [String: Any] {
    raw as? [String: Any] ?? [:]
  }

  static func start(_ raw: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(nil)
      return
    }
    let payload = args(raw)
    do {
      let id = try requestActivity(payload)
      result(id)
    } catch {
      NSLog("Cod Squad: fill pin Live Activity start failed: \(error)")
      result(nil)
    }
  }

  static func update(_ raw: Any?, result: @escaping FlutterResult) {
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }
    let payload = args(raw)
    let activityId = payload["activityId"] as? String
    let state = contentState(from: payload)
    Task {
      await applyUpdate(activityId: activityId, state: state)
      result(true)
    }
  }

  @available(iOS 16.1, *)
  static func applyEnd(activityId: String?) async {
    for activity in Activity<FillPinAttributes>.activities {
      if let activityId, activity.id != activityId { continue }
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: activity.content.state, staleDate: nil)
        await activity.end(content, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }

  @available(iOS 16.1, *)
  private static func requestActivity(_ payload: [String: Any]) throws -> String {
    let attributes = FillPinAttributes(
      pinId: payload["pinId"] as? String ?? "",
      chatGroupId: payload["chatGroupId"] as? String ?? "",
      lobbyId: payload["lobbyId"] as? String ?? ""
    )
    let state = contentState(from: payload)
    if #available(iOS 16.2, *) {
      let content = ActivityContent(state: state, staleDate: nil)
      let activity = try Activity.request(
        attributes: attributes,
        content: content,
        pushType: nil
      )
      return activity.id
    }
    let activity = try Activity.request(
      attributes: attributes,
      contentState: state,
      pushType: nil
    )
    return activity.id
  }

  private static func stringList(_ raw: Any?, fallback: [String]) -> [String] {
    if let list = raw as? [String], !list.isEmpty { return list }
    if let list = raw as? [Any] {
      let mapped = list.map { "\($0)" }.filter { !$0.isEmpty }
      if !mapped.isEmpty { return mapped }
    }
    return fallback
  }

  @available(iOS 16.1, *)
  private static func contentState(from payload: [String: Any]) -> FillPinAttributes.ContentState {
    FillPinAttributes.ContentState(
      phase: payload["phase"] as? String ?? "open",
      seated: (payload["seated"] as? NSNumber)?.intValue ?? payload["seated"] as? Int ?? 0,
      maxSpots: (payload["maxSpots"] as? NSNumber)?.intValue ?? payload["maxSpots"] as? Int ?? 0,
      gameName: payload["gameName"] as? String ?? "",
      holdLabel: payload["holdLabel"] as? String ?? "",
      holdRemainingSeconds: (payload["holdRemainingSeconds"] as? NSNumber)?.intValue
        ?? payload["holdRemainingSeconds"] as? Int
        ?? 0,
      actions: stringList(payload["actions"], fallback: ["Sit", "Coming", "Can't"]),
      actionIds: stringList(payload["actionIds"], fallback: ["sit", "coming", "cant"]),
      title: payload["title"] as? String ?? "",
      body: payload["body"] as? String ?? "",
      deepLink: payload["deepLink"] as? String ?? ""
    )
  }

  @available(iOS 16.1, *)
  private static func applyUpdate(
    activityId: String?,
    state: FillPinAttributes.ContentState
  ) async {
    for activity in Activity<FillPinAttributes>.activities {
      if let activityId, activity.id != activityId { continue }
      if #available(iOS 16.2, *) {
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
      } else {
        await activity.update(using: state)
      }
    }
  }
}
