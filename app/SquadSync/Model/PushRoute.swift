import Foundation

enum PushKind: String, Equatable {
    case chat = "squad_message"
    case squad = "squad"
}

struct PushPayload: Equatable {
    var kind: PushKind
    var squadId: UUID
    var messageId: UUID?
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

enum PushPermissionMoment {
    static func shouldAsk(signedIn: Bool, hasSquad: Bool, alreadyAsked: Bool, automated: Bool) -> Bool {
        signedIn && hasSquad && !alreadyAsked && !automated
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
    static let notAMember = "You're not in that squad."
    static let openedChat = "Opened this chat."
    static let openedSquad = "Opened this squad."
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

enum LiveShellCopy {
    static let footer = "Voice stays mock. Spots are live. Push is wired but not live until the server side ships."
}
