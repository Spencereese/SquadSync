#if canImport(StreamVideo)
import Combine
import Foundation
import StreamVideo

// The real squad voice engine, on the Stream Video Swift SDK (pinned in the
// Xcode project; see "Voice" in app/README.md). Written against the public API
// of stream-video-swift 1.57.0: `StreamVideo(apiKey:user:token:tokenProvider:)`,
// `call(callType:callId:callSettings:)`, `Call.join(create:callSettings:)`,
// `Call.microphone.enable()/disable()`, `Call.leave()`, `CallState.$participants`
// and `CallState.$reconnectionStatus`.
//
// Audio only: every CallSettings here has `videoOn: false`, and the app has no
// camera usage string, so the SDK keeps video off on its own too.
//
// Only built where the SDK can be imported (the Xcode app). The Linux harness
// never sees this file; the pure parts it uses live in SquadVoice.swift
// (`SquadVoiceRoster`, `SquadVoiceJoinFailure`) and are tested there.

final class StreamVoiceEngine: SquadVoiceEngine {
    let isLinked = true
    var onMembers: (([SquadVoiceMember]) -> Void)?
    var onDropped: ((String) -> Void)?

    /// Asked again when Stream says the call token expired.
    private let tokens: SquadVoiceTokenFetching
    private var client: StreamVideo?
    private var call: Call?
    private var watchers = Set<AnyCancellable>()

    /// How many have been made in this process (tests prove the mock makes none).
    private(set) static var made = 0

    /// Touches nothing in the SDK: the Stream client is only built in `connect`.
    init(tokens: SquadVoiceTokenFetching) {
        self.tokens = tokens
        Self.made += 1
    }

    func connect(_ grant: SquadVoiceGrant, name: String, muted: Bool) async throws -> [SquadVoiceMember] {
        await leave()
        guard let squadId = SquadVoiceRoster.squadId(fromCallId: grant.callId) else {
            throw SquadVoiceProblem.failed(SquadVoiceJoinFailure.message(statusCode: nil))
        }
        let tokens = self.tokens
        let client = StreamVideo(
            apiKey: grant.apiKey,
            user: User(id: grant.userId, name: name),
            token: UserToken(rawValue: grant.token),
            tokenProvider: { result in
                Task {
                    do {
                        let fresh = try await tokens.grant(squadId: squadId)
                        result(.success(UserToken(rawValue: fresh.token)))
                    } catch {
                        result(.failure(error))
                    }
                }
            }
        )
        let settings = CallSettings(audioOn: !muted, videoOn: false, speakerOn: true)
        let call = client.call(callType: grant.callType, callId: grant.callId, callSettings: settings)
        self.client = client
        self.call = call
        do {
            try await call.join(create: true, callSettings: settings)
        } catch {
            await leave()
            if RequestNoise.isCancellation(error) { throw error }
            throw SquadVoiceProblem.failed(SquadVoiceJoinFailure.message(statusCode: Self.statusCode(of: error)))
        }
        let you = grant.userId
        // CallState is main-actor bound; read it and subscribe there.
        let (first, watchers) = await MainActor.run { [weak self] () -> ([SquadVoiceMember], [AnyCancellable]) in
            let roster = call.state.$participants
                .dropFirst()
                .receive(on: DispatchQueue.main)
                .sink { participants in
                    self?.onMembers?(StreamVoiceEngine.members(participants, you: you))
                }
            let link = call.state.$reconnectionStatus
                .removeDuplicates()
                .receive(on: DispatchQueue.main)
                .sink { status in
                    guard status == .disconnected, let engine = self, engine.call === call else { return }
                    engine.onDropped?(SquadVoiceJoinFailure.dropped)
                    Task { await engine.leave() }
                }
            return (StreamVoiceEngine.members(call.state.participants, you: you), [roster, link])
        }
        // A leave while this join was finishing already cleared the call.
        guard self.call === call else {
            throw SquadVoiceProblem.failed(SquadVoiceJoinFailure.dropped)
        }
        self.watchers = Set(watchers)
        return first
    }

    func setMuted(_ muted: Bool) async throws {
        guard let call else { throw SquadVoiceProblem.failed(SquadVoiceJoinFailure.dropped) }
        if muted {
            try await call.microphone.disable()
        } else {
            try await call.microphone.enable()
        }
    }

    func leave() async {
        watchers.removeAll()
        let call = self.call
        let client = self.client
        self.call = nil
        self.client = nil
        call?.leave()
        await client?.disconnect()
    }

    /// Stream's HTTP status, whether it threw the APIError itself or wrapped it.
    private static func statusCode(of error: Error) -> Int? {
        if let api = error as? APIError { return api.statusCode }
        if let client = error as? ClientError { return client.apiError?.statusCode }
        return nil
    }

    private static func members(_ participants: [CallParticipant], you: String) -> [SquadVoiceMember] {
        SquadVoiceRoster.members(
            participants.map {
                SquadVoiceRoster.Entry(
                    id: $0.id,
                    userId: $0.userId,
                    name: $0.name,
                    hasAudio: $0.hasAudio,
                    isSpeaking: $0.isSpeaking
                )
            },
            you: you
        )
    }
}
#endif
