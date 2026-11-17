import Foundation

/// Which backend a launch uses. Friends get the live server; mock data only shows
/// up when a launch asks for it, and a build without server settings says so
/// instead of quietly falling back to sample data.
///
/// - `-backend mock` always means mock (UI tests and simulator runs).
/// - In Debug, a `-scenario <name>` launch with no `-backend` flag is a UI-test
///   launch and stays on mock. Release ignores a bare scenario.
/// - The app hosting unit tests stays on mock, so `xcodebuild test` never touches
///   the network or the Keychain session.
/// - Everything else is live when `SupabaseURL` and `SupabaseAnonKey` are set
///   (Config.xcconfig), and "not configured" when they aren't. That includes
///   `-backend live` on a build without settings.
enum LaunchBackend: Equatable {
    case live
    case mock
    case notConfigured(missing: [String])

    static func choose(arguments: [String], config: BackendConfig, isRelease: Bool, hostingUnitTests: Bool = false) -> LaunchBackend {
        let flag = value("-backend", in: arguments)
        if flag == BackendMode.mock.rawValue { return .mock }
        let askedForLive = flag == BackendMode.live.rawValue
        if !askedForLive, hostingUnitTests { return .mock }
        if !askedForLive, !isRelease, let scenario = value("-scenario", in: arguments), !scenario.isEmpty {
            return .mock
        }
        return config.isConfigured ? .live : .notConfigured(missing: config.missingKeys)
    }

    var mode: BackendMode? {
        switch self {
        case .live: .live
        case .mock: .mock
        case .notConfigured: nil
        }
    }

    static let notConfiguredTitle = "This build isn't connected to a server"

    /// The "not configured" screen's body. It names what's missing and says plainly
    /// that nothing will be shown from sample data instead.
    static func notConfiguredDetail(missing: [String]) -> String {
        let keys = missing.isEmpty ? "SupabaseURL, SupabaseAnonKey" : missing.joined(separator: ", ")
        return "SquadSync needs its server settings (Config.xcconfig) to sign you in, and it won't show sample data instead. Missing: \(keys)."
    }

    private static func value(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.index(after: index) < arguments.endIndex else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }
}

enum BuildFlavor {
    /// XCTest sets this in the app it hosts for unit tests (not in UI-test apps).
    static func hostingUnitTests(_ environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }

    static var isRelease: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }
}

/// Whether coming back to the foreground reconnects the socket and backfills.
/// iOS drops sockets in the background, so a socket that still says "connected"
/// can't be trusted after a trip there: always reconnect then. Without a trip to
/// the background (Control Center, a system sheet), reconnect only a signed-in
/// squad whose socket is down or retrying.
enum RealtimeResume {
    static func reconnects(wentToBackground: Bool, link: RealtimeLink, signedInWithSquad: Bool) -> Bool {
        if wentToBackground { return true }
        guard signedInWithSquad else { return false }
        return link == .down || link == .reconnecting
    }
}

/// The phoenix frames the realtime client sends, built here so they can be tested
/// without a socket.
enum RealtimeFrames {
    /// Supabase Realtime takes a fresh JWT on an open channel with an
    /// `access_token` event, so a refresh doesn't need a reconnect.
    static func accessToken(topic: String, token: String, ref: String) -> [String: Any] {
        [
            "topic": topic,
            "event": "access_token",
            "payload": ["access_token": token],
            "ref": ref,
            "join_ref": "1"
        ]
    }
}
