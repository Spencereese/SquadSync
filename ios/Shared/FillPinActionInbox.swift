import Foundation

/// App-group queue from lock-screen App Intents → Runner channel.
///
/// Suite: `group.com.example.codSquadApp`. Spencer must enable App Groups
/// on both App IDs (see ios/PeacockLockWidget/SPENCER.txt). Not a second
/// notify send path — Dart still calls FillPinLiveActivity.applyChannelAction.
enum FillPinActionInbox {
  static let suiteName = "group.com.example.codSquadApp"
  static let queueKey = "fillPinPendingActions"
  static let darwinName = "com.example.codSquadApp.fillPinAction" as CFString

  static func enqueue(
    actionId: String,
    chatGroupId: String,
    pinId: String,
    lobbyId: String
  ) {
    let item: [String: String] = [
      "actionId": actionId,
      "chatGroupId": chatGroupId,
      "pinId": pinId,
      "lobbyId": lobbyId,
    ]
    let defaults = UserDefaults(suiteName: suiteName)
    var queue = defaults?.array(forKey: queueKey) as? [[String: String]] ?? []
    queue.append(item)
    defaults?.set(queue, forKey: queueKey)
    CFNotificationCenterPostNotification(
      CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(darwinName),
      nil,
      nil,
      true
    )
  }

  static func drain() -> [[String: String]] {
    let defaults = UserDefaults(suiteName: suiteName)
    let queue = defaults?.array(forKey: queueKey) as? [[String: String]] ?? []
    defaults?.removeObject(forKey: queueKey)
    return queue
  }
}
