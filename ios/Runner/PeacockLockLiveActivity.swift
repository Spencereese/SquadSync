import ActivityKit
import Flutter
import Foundation

/// Peacock-lock Live Activity bridge on the existing Runner target.
///
/// Starts / updates / ends via `com.squadsync/live_activities`.
/// Lock Screen UI still requires a Widget Extension (separate App ID in
/// the Apple Developer portal). This file does not change the Runner
/// bundle ID `com.example.codSquadApp` and does not add entitlements.
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
  }
}
