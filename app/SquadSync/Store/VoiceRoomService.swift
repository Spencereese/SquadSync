import Foundation

/// One person in the always-open lounge. `speakingLevel` is 0 when silent
/// and 1 at full volume. A muted person stays at 0.
struct VoiceParticipant: Identifiable, Equatable {
    let id: String
    var muted: Bool
    var speakingLevel: Double
}

/// The in-app voice room. Phase 1 uses an in-memory fake. A hosted provider
/// can adopt this later. No SDK and no account are part of this protocol.
protocol VoiceRoomService: AnyObject {
    var connection: VoiceConnectionState { get }
    var participants: [VoiceParticipant] { get }

    func join(userId: String) async
    func leave(userId: String) async
    func mute(userId: String, muted: Bool) async
}

/// Local stand-in. Join moves through connecting into connected.
/// The room can also be marked reconnecting or failed without a network.
final class InMemoryVoiceRoomService: VoiceRoomService {
    private(set) var connection: VoiceConnectionState
    private(set) var participants: [VoiceParticipant]

    init(
        participants: [VoiceParticipant] = [],
        connection: VoiceConnectionState = .idle
    ) {
        self.participants = participants
        self.connection = connection
    }

    func join(userId: String) async {
        connection = .connecting
        if let index = participants.firstIndex(where: { $0.id == userId }) {
            if !participants[index].muted, participants[index].speakingLevel == 0 {
                participants[index].speakingLevel = 0.35
            }
        } else {
            participants.append(VoiceParticipant(id: userId, muted: false, speakingLevel: 0.35))
        }
        connection = .connected
    }

    func leave(userId: String) async {
        participants.removeAll { $0.id == userId }
        connection = participants.isEmpty ? .idle : .connected
    }

    func mute(userId: String, muted: Bool) async {
        guard let index = participants.firstIndex(where: { $0.id == userId }) else { return }
        participants[index].muted = muted
        if muted {
            participants[index].speakingLevel = 0
        } else if participants[index].speakingLevel == 0 {
            participants[index].speakingLevel = 0.35
        }
    }

    func markReconnecting() {
        connection = .reconnecting
    }

    func markFailed(_ reason: String) {
        connection = .failed(reason)
    }
}
