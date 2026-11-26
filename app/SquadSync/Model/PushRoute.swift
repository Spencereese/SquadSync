import Foundation

enum PushKind: String, Equatable {
    case chat = "squad_message"
    case squad = "squad"
    /// A reply in a side thread (a side group or DM, `sq8_thread_messages`).
    case thread = "thread_message"
    /// Someone started a Game on (`sq8_spot_calls` kind `game_on`). Opens the chat,
    /// where the card is pinned.
    case gameOn = "game_on"
}

struct PushPayload: Equatable {
    var kind: PushKind
    var squadId: UUID
    var messageId: UUID?
    /// Only for `.thread`: the side thread the reply is in.
    var threadId: UUID? = nil
    /// Only for `.gameOn`: the Game on that was started.
    var callId: UUID? = nil
}

enum PushPayloadParser {
    static func parse(_ userInfo: [AnyHashable: Any]) -> PushPayload? {
        let values = userInfo.reduce(into: [String: Any]()) { partial, item in
            if let key = item.key as? String { partial[key] = item.value }
        }
        return parse(values)
    }

    static func parse(jsonText: String) -> PushPayload? {
        guard let data = jsonText.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return parse(object)
    }

    static func parse(_ values: [String: Any]) -> PushPayload? {
        let type = string(values["type"])
        guard let kind = type.flatMap(PushKind.init(rawValue:)),
              let squadId = uuid(values["squad_id"]) else { return nil }
        let messageId = uuid(values["message_id"])
        if kind == .chat && messageId == nil { return nil }
        if kind == .thread {
            // A thread tap needs both: which thread, and which reply to show.
            guard let threadId = uuid(values["thread_id"]), let messageId else { return nil }
            return PushPayload(kind: kind, squadId: squadId, messageId: messageId, threadId: threadId)
        }
        if kind == .gameOn {
            guard let callId = uuid(values["call_id"]) else { return nil }
            return PushPayload(kind: kind, squadId: squadId, messageId: nil, callId: callId)
        }
        return PushPayload(kind: kind, squadId: squadId, messageId: messageId)
    }

    private static func string(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        return nil
    }

    private static func uuid(_ value: Any?) -> UUID? {
        if let id = value as? UUID { return id }
        if let text = value as? String { return UUID(uuidString: text) }
        return nil
    }
}

enum PushBanner {
    /// A message for the squad chat already on screen does not raise a banner.
    static func shows(viewingSquad: UUID?, payload: PushPayload) -> Bool {
        shows(viewingSquad: viewingSquad, viewingThread: nil, payload: payload)
    }

    /// A side-thread reply banners unless that same side thread is open. While a
    /// side thread is open it covers the squad chat, so a squad message banners too.
    static func shows(viewingSquad: UUID?, viewingThread: UUID?, payload: PushPayload) -> Bool {
        if payload.kind == .thread {
            guard let viewingThread, let threadId = payload.threadId else { return true }
            return threadId != viewingThread
        }
        if viewingThread != nil { return true }
        guard let viewingSquad else { return true }
        return payload.squadId != viewingSquad
    }
}

enum PushLanding {
    enum Step: Equatable {
        case holdUntilSignedIn(PushPayload)
        case open(PushPayload)
        case notAMember(PushPayload)
    }

    /// Cold, warm, and signed-out are the same decision. Membership is only known after a squad load.
    static func step(
        payload: PushPayload,
        signedIn: Bool,
        membershipKnown: Bool,
        memberOfTarget: Bool
    ) -> Step {
        if !signedIn || !membershipKnown { return .holdUntilSignedIn(payload) }
        if !memberOfTarget { return .notAMember(payload) }
        return .open(payload)
    }
}

extension PushLanding.Step {
    /// A tap that lands (opened or "not in that squad") closes every sheet and
    /// confirmation over the chat, so the message and the line about it are on
    /// screen. A held tap changes nothing yet.
    var closesCovers: Bool {
        switch self {
        case .holdUntilSignedIn: false
        case .open, .notAMember: true
        }
    }
}

/// Everything that can sit over the squad chat when a push tap lands.
/// Closing the voice sheet does not leave the room; the pill stays.
enum PushCover: CaseIterable, Equatable {
    case signOutConfirm
    case endSpotConfirm
    case leaveConfirm
    case members
    case callSpotSheet
    case voiceSheet
    case whosInSheet
    case largeTextRoster
    case gameOnSheet
}

/// DEBUG launch flags that stand in for a notification tap. `-debug-push-open <json>`
/// alone is a cold-launch tap. Adding `-debug-push-open-after <seconds>` delivers
/// the same payload that many seconds after launch instead, like a tap while the
/// app is already open (a warm tap).
enum PushDebugTap {
    enum Plan: Equatable {
        case none
        case atLaunch(PushPayload)
        case later(PushPayload, seconds: TimeInterval)
    }

    static let maxDelay: TimeInterval = 120

    static func plan(json: String?, delayText: String?) -> Plan {
        guard let json, let payload = PushPayloadParser.parse(jsonText: json) else { return .none }
        guard let delayText,
              let seconds = TimeInterval(delayText.trimmingCharacters(in: .whitespaces)),
              seconds > 0, seconds <= maxDelay else { return .atLaunch(payload) }
        return .later(payload, seconds: seconds)
    }
}

/// When the app asks to send notifications. Not at sign-in any more: the first
/// time you start or join a Game on, when a notification plainly helps.
enum PushAskMoment: Equatable {
    /// Sign-in, launch, joining the group. Never asks.
    case launch
    /// You started or joined a Game on.
    case gameOn
}

enum PushPermissionMoment {
    static func shouldAsk(signedIn: Bool, hasSquad: Bool, alreadyAsked: Bool, automated: Bool, moment: PushAskMoment = .launch) -> Bool {
        moment == .gameOn && signedIn && hasSquad && !alreadyAsked && !automated
    }

    static func isAutomated(_ arguments: [String]) -> Bool {
        arguments.contains("-scenario")
            || arguments.contains("-uitest-largeText")
            || arguments.contains("-debug-push-open")
            || arguments.contains("-debug-push-token")
    }
}

enum TokenRotation {
    enum Action: Equatable {
        case none
        case register(String)
        case replace(old: String, new: String)
        case unregister(String)
    }

    static func onToken(_ token: String, previous: String?) -> Action {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .none }
        guard let previous, !previous.isEmpty else { return .register(trimmed) }
        if previous == trimmed { return .none }
        return .replace(old: previous, new: trimmed)
    }

    static func onSignOut(previous: String?) -> Action {
        guard let previous, !previous.isEmpty else { return .none }
        return .unregister(previous)
    }
}

enum TokenPersistence {
    /// Local memory updates only after the register RPC succeeds, so a failure retries.
    static func rememberAfter(action: TokenRotation.Action, registerSucceeded: Bool) -> String? {
        guard registerSucceeded else { return nil }
        switch action {
        case .register(let token):
            return token
        case .replace(_, let new):
            return new
        case .none, .unregister:
            return nil
        }
    }
}

enum DeviceTokenHex {
    static func string(from data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

enum PushNotice {
    static let notAMember = "You're not in that group."
    static let openedChat = "Opened this chat."
    static let openedSquad = "Opened this group."
}

struct PushThreadOpen: Equatable {
    let thread: UUID
    let reply: UUID
}

/// Where a landed tap goes. A side-thread reply opens that thread over the squad
/// chat; the chat itself is not scrolled for it.
enum PushDestination: Equatable {
    case chat(message: UUID?)
    case squad
    case thread(UUID, reply: UUID)

    static func of(_ payload: PushPayload) -> PushDestination {
        switch payload.kind {
        case .chat:
            return .chat(message: payload.messageId)
        case .gameOn:
            // The card sits pinned over the chat, so the chat is where it lands.
            return .chat(message: nil)
        case .squad:
            return .squad
        case .thread:
            guard let thread = payload.threadId, let reply = payload.messageId else { return .squad }
            return .thread(thread, reply: reply)
        }
    }
}

enum PushToast {
    static let lifetime: TimeInterval = 8

    static func text(notice: String, openedChat: Bool, openedSquad: Bool) -> String? {
        if !notice.isEmpty { return notice }
        if openedChat { return PushNotice.openedChat }
        if openedSquad { return PushNotice.openedSquad }
        return nil
    }

    static func identifier(notice: String, openedChat: Bool, openedSquad: Bool) -> String? {
        if !notice.isEmpty { return "push-notice" }
        if openedChat { return "push-opened-chat" }
        if openedSquad { return "push-opened-squad" }
        return nil
    }

    static func shouldDismiss(shownAt: Date, now: Date, lifetime: TimeInterval = lifetime) -> Bool {
        now.timeIntervalSince(shownAt) >= lifetime
    }
}

enum PushAuthState: Equatable {
    case notDetermined
    case denied
    case authorized
    case provisional
    case ephemeral
    case unknown

    /// A later launch registers again only when the system will actually hand back a token.
    var registersForRemoteNotifications: Bool {
        self == .authorized || self == .provisional
    }
}

enum PushStoreFailure {
    static let missingRPC = "sq8_register_device_token is not set up."
    static let signedOut = "Not signed in."

    static func reason(_ error: Error) -> String {
        if let failure = error as? BackendFailure {
            // The real POST is the check now: a missing function reads as missing.
            if case .notSetUp = failure { return missingRPC }
            switch SessionFailurePolicy.surface(failure) {
            case .message(let text):
                return text
            case .signIn(let text):
                return text
            case .reconnecting:
                return SessionFailurePolicy.reconnecting
            }
        }
        return error.localizedDescription
    }
}

/// The one status line under sign-in and the panel. It says only what's true
/// for the backend the app launched with, and never claims a device test.
enum LiveShellCopy {
    static let liveFooter = "Spots are live. Push and voice are on the server but not yet tested on a phone."
    static let mockFooter = "Sample data. Nothing here reaches the server."

    static func footer(for backend: BackendMode) -> String {
        switch backend {
        case .live: return liveFooter
        case .mock: return mockFooter
        }
    }
}
