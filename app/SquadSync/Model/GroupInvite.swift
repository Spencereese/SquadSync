import Foundation

/// The tap-to-join link. Any member can make one (0029's `sq8_member_invite`);
/// the owner role only matters for removing people. The group still tops out at 8.
///
/// The link is a custom scheme, `squadsync://join/CODE`, because there's no
/// domain for universal links yet. Messages doesn't always make a custom scheme
/// tappable, so the share text carries the code too.
enum InviteLink {
    static let scheme = "squadsync"
    static let host = "join"

    static func url(code: String) -> URL? {
        let clean = normalized(code)
        guard !clean.isEmpty else { return nil }
        return URL(string: "\(scheme)://\(host)/\(clean)")
    }

    /// `squadsync://join/ABCD2345`, `squadsync://join?code=ABCD2345`, any case.
    static func code(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host?.lowercased() == host else { return nil }
        let fromPath = url.pathComponents.filter { $0 != "/" }.first
        let fromQuery = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "code" }?.value
        let code = normalized(fromPath ?? fromQuery ?? "")
        return isPlausible(code) ? code : nil
    }

    static func normalized(_ code: String) -> String {
        code.uppercased().filter { $0.isLetter || $0.isNumber }
    }

    /// Codes are 6 to 16 letters and digits. Anything else isn't worth a request.
    static func isPlausible(_ code: String) -> Bool {
        (6...16).contains(code.count) && code.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static func shareText(groupName: String, code: String) -> String {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = url(code: code)?.absoluteString ?? ""
        let lead = name.isEmpty ? "Join my group on SquadSync" : "Join \(name) on SquadSync"
        return "\(lead): \(link)\nOr open SquadSync and enter code \(normalized(code))."
    }

    static func expiryNote(_ expiresAt: Date?, now: Date) -> String {
        guard let expiresAt else { return "Anyone with the link can join until the group has 8." }
        let days = max(1, Int(ceil(expiresAt.timeIntervalSince(now) / 86_400)))
        return days == 1 ? "Works for 1 more day, until the group has 8." : "Works for \(days) more days, until the group has 8."
    }
}

/// An invite link that arrived before the app could use it (signed out, or
/// still loading) waits here until it can.
struct PendingInvite: Equatable {
    var code: String

    enum Action: Equatable {
        /// Signed in with no group: fill the code and join.
        case join(String)
        /// Already in this group: nothing to do.
        case alreadyIn
        /// In another group: say so instead of trying.
        case inAnotherGroup
        /// Not signed in yet: keep it.
        case wait
    }

    static func action(code: String, signedIn: Bool, hasGroup: Bool) -> Action {
        guard signedIn else { return .wait }
        return hasGroup ? .inAnotherGroup : .join(code)
    }
}
