import Foundation

// Squad voice: one always-open, audio-only room per squad on Stream Video.
//
// The app asks the sq8-voice-token function (supabase/functions/sq8-voice-token)
// for a short-lived Stream call token, then hands it to a `SquadVoiceEngine`.
// The Stream Swift SDK is not linked in this build (see "Voice" in app/README.md):
// the only engine here is
// `UnlinkedSquadVoiceEngine`, which never connects. So with the function not
// deployed (404), the Stream secrets unset (503) or no SDK, the room says
// "Voice isn't set up yet". Nothing in this file ever reports a connection
// that didn't happen.
//
// Foundation only, so the Linux harness builds and tests it.

/// What sq8-voice-token returns for a squad member.
struct SquadVoiceGrant: Equatable, Decodable {
    let apiKey: String
    let token: String
    let userId: String
    let callType: String
    let callId: String
    let expiresAt: Date

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case token
        case userId = "user_id"
        case callType = "call_type"
        case callId = "call_id"
        case expiresAt = "expires_at"
    }

    /// Ask again this long before the token runs out.
    static let refreshMargin: TimeInterval = 120

    func needsRefresh(now: Date) -> Bool {
        expiresAt.timeIntervalSince(now) <= Self.refreshMargin
    }
}

enum SquadVoiceProblem: Error, Equatable {
    /// The function isn't deployed, the Stream secrets aren't set, or this build
    /// has no voice SDK. Never shown as a connection.
    case notSetUp
    case notMember
    case signedOut
    case offline
    case failed(String)

    static let notSetUpText = "Voice isn't set up yet"

    var message: String {
        switch self {
        case .notSetUp: return Self.notSetUpText
        case .notMember: return "You're not in this squad, so you can't join its voice room."
        case .signedOut: return "Sign in again to use voice."
        case .offline: return "Couldn't reach voice. Check your connection and try again."
        case .failed(let text): return text
        }
    }
}

enum SquadVoiceFunction {
    static let path = "functions/v1/sq8-voice-token"

    private struct Answer: Decodable {
        let ok: Bool?
        let reason: String?
    }

    /// Maps the function's answer. 404 is "not deployed" (the platform's
    /// "Requested function was not found") and 503 is "secrets unset": both
    /// are `.notSetUp`.
    static func outcome(status: Int, body: Data) -> Result<SquadVoiceGrant, SquadVoiceProblem> {
        switch status {
        case 200..<300:
            guard let grant = try? BackendJSON.decoder.decode(SquadVoiceGrant.self, from: body),
                  !grant.token.isEmpty, !grant.apiKey.isEmpty, !grant.callId.isEmpty else {
                return .failure(.failed("Voice answered with something unreadable."))
            }
            return .success(grant)
        case 401:
            return .failure(.signedOut)
        case 403:
            return .failure(.notMember)
        case 404, 503:
            return .failure(.notSetUp)
        default:
            let reason = (try? JSONDecoder().decode(Answer.self, from: body))?.reason
            if reason == "voice_not_configured" { return .failure(.notSetUp) }
            return .failure(.failed("Voice isn't available right now (\(status)). Try again."))
        }
    }

    static func requestBody(squadId: UUID) -> Data {
        Data(#"{"squad_id":"\#(squadId.uuidString.lowercased())"}"#.utf8)
    }
}

protocol SquadVoiceTokenFetching: AnyObject {
    func grant(squadId: UUID) async throws -> SquadVoiceGrant
}

/// Calls sq8-voice-token as the signed-in user. One refresh and retry on 401.
final class SupabaseSquadVoiceTokens: SquadVoiceTokenFetching {
    private let config: BackendConfig
    /// The signed-in session's access token at the time of each request.
    private let currentToken: () async -> String?
    private let transport: HTTPTransport
    private weak var refresher: TokenRefreshing?

    init(config: BackendConfig, currentToken: @escaping () async -> String?, refresher: TokenRefreshing? = nil, transport: HTTPTransport = URLSessionTransport.shared) {
        self.config = config
        self.currentToken = currentToken
        self.refresher = refresher
        self.transport = transport
    }

    func grant(squadId: UUID) async throws -> SquadVoiceGrant {
        guard config.isConfigured, let base = config.url else { throw SquadVoiceProblem.notSetUp }
        guard let token = await currentToken() else { throw SquadVoiceProblem.signedOut }
        var outcome = try await call(base: base, token: token, squadId: squadId)
        if case .failure(.signedOut) = outcome, let refresher {
            switch await refresher.refreshAfterRejection() {
            case .refreshed(let fresh):
                outcome = try await call(base: base, token: fresh, squadId: squadId)
            case .rejected:
                throw SquadVoiceProblem.signedOut
            case .unreachable:
                throw SquadVoiceProblem.offline
            }
        }
        return try outcome.get()
    }

    private func call(base: URL, token: String, squadId: UUID) async throws -> Result<SquadVoiceGrant, SquadVoiceProblem> {
        var url = base
        for part in SquadVoiceFunction.path.split(separator: "/") { url.appendPathComponent(String(part)) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = SquadVoiceFunction.requestBody(squadId: squadId)
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            if RequestNoise.isCancellation(error) { throw error }
            throw SquadVoiceProblem.offline
        }
        guard let http = response as? HTTPURLResponse else { throw SquadVoiceProblem.offline }
        return SquadVoiceFunction.outcome(status: http.statusCode, body: data)
    }
}

/// One person in the room, as the engine reports them.
struct SquadVoiceMember: Identifiable, Equatable {
    let id: String
    var name: String
    var muted: Bool
    var speaking: Bool
    var isYou: Bool

    var spoken: String {
        let who = isYou ? "\(name), you" : name
        if muted { return "\(who), muted" }
        return speaking ? "\(who), speaking" : "\(who), listening"
    }
}

/// The audio connection itself (Stream's SDK in a build that links it).
/// Engines deliver `onMembers` and `onDropped` on the main queue.
protocol SquadVoiceEngine: AnyObject {
    /// False when this build has no voice SDK; the room then never tries.
    var isLinked: Bool { get }
    /// Called with the full list whenever someone joins, leaves, mutes or speaks.
    var onMembers: (([SquadVoiceMember]) -> Void)? { get set }
    /// Called when a connected room drops for good (the reason in plain words).
    var onDropped: ((String) -> Void)? { get set }
    func connect(_ grant: SquadVoiceGrant, name: String, muted: Bool) async throws -> [SquadVoiceMember]
    func setMuted(_ muted: Bool) async throws
    func leave() async
}

/// This build's engine: the Stream Swift SDK isn't linked, so it never connects.
final class UnlinkedSquadVoiceEngine: SquadVoiceEngine {
    let isLinked = false
    var onMembers: (([SquadVoiceMember]) -> Void)?
    var onDropped: ((String) -> Void)?

    func connect(_ grant: SquadVoiceGrant, name: String, muted: Bool) async throws -> [SquadVoiceMember] {
        throw SquadVoiceProblem.notSetUp
    }

    func setMuted(_ muted: Bool) async throws {}
    func leave() async {}
}

enum SquadVoicePhase: Equatable {
    case idle
    case loading
    case connected
    case notSetUp
    case failed(SquadVoiceProblem)
}

/// What the voice sheet and the header pill show. Pure, so it's tested directly.
struct SquadVoiceState: Equatable {
    var phase: SquadVoicePhase = .idle
    var members: [SquadVoiceMember] = []
    var muted = false

    var joined: Bool { phase == .connected }
    var canJoin: Bool {
        switch phase {
        case .idle, .failed, .notSetUp: return true
        case .loading, .connected: return false
        }
    }
    var canLeave: Bool { phase == .connected || phase == .loading }
    var canMute: Bool { phase == .connected }

    var statusLine: String {
        switch phase {
        case .idle: return "Not in voice"
        case .loading: return "Joining…"
        case .connected: return muted ? "In voice, muted" : "In voice"
        case .notSetUp: return SquadVoiceProblem.notSetUpText
        case .failed(let problem): return problem.message
        }
    }

    /// Only while connected: the list is what Stream says, never a guess.
    var emptyLine: String? {
        guard phase == .connected, members.isEmpty else { return nil }
        return "No one else is here yet."
    }

    var joinTitle: String {
        if case .failed = phase { return "Try again" }
        if phase == .notSetUp { return "Check again" }
        return "Join voice"
    }

    var pillTitle: String {
        switch phase {
        case .idle, .failed: return "Voice"
        case .loading: return "Voice · joining"
        case .connected: return "In voice · \(members.count)"
        case .notSetUp: return "Voice · not set up"
        }
    }

    var pillSpoken: String {
        switch phase {
        case .connected:
            let count = members.count == 1 ? "1 person is in it" : "\(members.count) people are in it"
            return "Squad voice room. You're in it\(muted ? ", muted" : ""). \(count). Double tap to open."
        case .notSetUp:
            return "Squad voice room. \(SquadVoiceProblem.notSetUpText). Double tap to open."
        case .loading:
            return "Squad voice room. Joining. Double tap to open."
        case .idle, .failed:
            return "Squad voice room. You're not in it. Double tap to open."
        }
    }
}

/// Join, leave and mute for one squad's room, in front of a token source and an
/// engine. Not actor-bound: the app's @MainActor model owns and calls it.
final class SquadVoiceSession {
    private(set) var state = SquadVoiceState()
    private let tokens: SquadVoiceTokenFetching
    private let engine: SquadVoiceEngine
    /// Joins are numbered so a leave during a slow join wins.
    private var attempt = 0
    /// Every state change, including ones the engine reports on its own.
    var onChange: ((SquadVoiceState) -> Void)?

    init(tokens: SquadVoiceTokenFetching, engine: SquadVoiceEngine) {
        self.tokens = tokens
        self.engine = engine
        engine.onMembers = { [weak self] members in
            guard let self, self.state.phase == .connected else { return }
            self.state.members = members
            self.onChange?(self.state)
        }
        engine.onDropped = { [weak self] reason in
            guard let self, self.state.phase == .connected else { return }
            self.state = SquadVoiceState(phase: .failed(.failed(reason)), members: [], muted: self.state.muted)
            self.onChange?(self.state)
        }
    }

    private func set(_ next: SquadVoiceState) {
        state = next
        onChange?(state)
    }

    func join(squadId: UUID, name: String) async {
        guard state.canJoin else { return }
        attempt += 1
        let mine = attempt
        set(SquadVoiceState(phase: .loading, members: [], muted: state.muted))
        // No SDK, no request: there's nothing a token could connect to.
        guard engine.isLinked else {
            set(SquadVoiceState(phase: .notSetUp, members: [], muted: state.muted))
            return
        }
        do {
            let grant = try await tokens.grant(squadId: squadId)
            guard mine == attempt else { return }
            let members = try await engine.connect(grant, name: name, muted: state.muted)
            guard mine == attempt else {
                await engine.leave()
                return
            }
            set(SquadVoiceState(phase: .connected, members: members, muted: state.muted))
        } catch let problem as SquadVoiceProblem {
            guard mine == attempt else { return }
            set(SquadVoiceState(phase: problem == .notSetUp ? .notSetUp : .failed(problem), members: [], muted: state.muted))
        } catch {
            guard mine == attempt else { return }
            if RequestNoise.isCancellation(error) {
                set(SquadVoiceState(phase: .idle, members: [], muted: state.muted))
                return
            }
            set(SquadVoiceState(phase: .failed(.failed("Couldn't join voice. Try again.")), members: [], muted: state.muted))
        }
    }

    func leave() async {
        attempt += 1
        let wasIn = state.phase == .connected || state.phase == .loading
        set(SquadVoiceState(phase: .idle, members: [], muted: state.muted))
        if wasIn { await engine.leave() }
    }

    /// Muted only flips once the engine took it; a failure leaves it as it was.
    func toggleMute() async {
        let next = !state.muted
        guard state.phase == .connected else {
            // Before joining it's a preference for the next join.
            var copy = state
            copy.muted = next
            set(copy)
            return
        }
        do {
            try await engine.setMuted(next)
            var copy = state
            copy.muted = next
            set(copy)
        } catch {
            // Stays as it was; the engine reports anything else that changed.
        }
    }
}
