import ActivityKit
import Foundation

/// Fill PIN Live Activity attributes. Compiled into Runner and
/// PeacockLockWidget so ActivityKit shares one type name.
///
/// Identity: Runner `com.example.codSquadApp`, widget
/// `com.example.codSquadApp.PeacockLockWidget`.
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

    var seatLabel: String { "\(seated)/\(maxSpots)" }

    var isLive: Bool { phase != "ended" }

    var isComing: Bool { phase == "coming" }

    var openURL: URL? {
      let raw = deepLink.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !raw.isEmpty else { return nil }
      return URL(string: raw)
    }
  }

  var pinId: String
  var chatGroupId: String
  var lobbyId: String
}
