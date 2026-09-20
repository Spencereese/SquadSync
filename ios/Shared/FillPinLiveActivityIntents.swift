import AppIntents
import Foundation

/// Lock-screen Sit / Coming / Can't. One intent, three action ids.
///
/// Sit = seat taken, Coming = 300s hold (no auto-sit), Can't = release.
/// perform() only enqueues onto FillPinActionInbox — Runner forwards
/// that to com.squadsync/live_activities → applyChannelAction.
@available(iOS 17.0, *)
struct FillPinLockScreenIntent: LiveActivityIntent {
  static var title: LocalizedStringResource = "Fill PIN"
  static var openAppWhenRun = false
  static var isDiscoverable = false

  @Parameter(title: "Action")
  var actionId: String

  @Parameter(title: "Chat")
  var chatGroupId: String

  @Parameter(title: "Pin")
  var pinId: String

  @Parameter(title: "Lobby")
  var lobbyId: String

  init() {
    actionId = ""
    chatGroupId = ""
    pinId = ""
    lobbyId = ""
  }

  init(
    actionId: String,
    chatGroupId: String,
    pinId: String,
    lobbyId: String
  ) {
    self.actionId = actionId
    self.chatGroupId = chatGroupId
    self.pinId = pinId
    self.lobbyId = lobbyId
  }

  static func sit(chatGroupId: String, pinId: String, lobbyId: String) -> FillPinLockScreenIntent {
    FillPinLockScreenIntent(
      actionId: "sit",
      chatGroupId: chatGroupId,
      pinId: pinId,
      lobbyId: lobbyId
    )
  }

  static func coming(chatGroupId: String, pinId: String, lobbyId: String) -> FillPinLockScreenIntent {
    FillPinLockScreenIntent(
      actionId: "coming",
      chatGroupId: chatGroupId,
      pinId: pinId,
      lobbyId: lobbyId
    )
  }

  static func cant(chatGroupId: String, pinId: String, lobbyId: String) -> FillPinLockScreenIntent {
    FillPinLockScreenIntent(
      actionId: "cant",
      chatGroupId: chatGroupId,
      pinId: pinId,
      lobbyId: lobbyId
    )
  }

  func perform() async throws -> some IntentResult {
    FillPinActionInbox.enqueue(
      actionId: actionId,
      chatGroupId: chatGroupId,
      pinId: pinId,
      lobbyId: lobbyId
    )
    return .result()
  }
}
