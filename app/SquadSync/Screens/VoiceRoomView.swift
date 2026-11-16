import SwiftUI

struct VoiceRoomView: View {
    @Bindable var store: MockStore
    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.l) {
            Text(store.voice.title).font(.title2.weight(.semibold))
            Text(connectionLine)
                .font(.subheadline)
                .foregroundStyle(SQColor.muted)
            Text("\(store.voice.occupantIds.count) in the room")
                .font(.subheadline)
                .foregroundStyle(SQColor.muted)
            ForEach(store.voice.occupantIds, id: \.self) { id in
                if let person = store.person(id) {
                    HStack(spacing: SQSpace.m) {
                        PresenceAvatar(person: person, size: 40)
                            .overlay(speaking(person))
                        VStack(alignment: .leading) {
                            Text(person.name).font(.headline)
                            Text(line(for: id, person: person))
                                .font(.caption)
                                .foregroundStyle(SQColor.muted)
                        }
                        Spacer()
                        RoleTag(role: person.role)
                    }
                }
            }
            HStack {
                Button(store.voice.mutedIds.contains(store.viewerId) ? "Unmute" : "Mute") {
                    Task { await store.toggleMute() }
                }
                .buttonStyle(.bordered)
                Button("Leave", role: .destructive) {
                    Task { await store.leaveVoice() }
                }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Collapse") { store.collapseVoice() }
                    .accessibilityLabel("Collapse voice room")
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(SQSpace.l)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var connectionLine: String {
        switch store.voice.connection {
        case .idle: "Not connected"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .reconnecting: "Reconnecting…"
        case .failed(let reason): "Connection failed. \(reason)"
        }
    }

    private func line(for id: String, person: Person) -> String {
        if store.voice.mutedIds.contains(id) { return "Muted" }
        let level = store.voice.speakingLevels[id] ?? 0
        if level > 0.2 { return "Speaking" }
        return person.isSpeaking ? "Speaking" : "Listening"
    }

    @ViewBuilder
    private func speaking(_ person: Person) -> some View {
        if person.isSpeaking && !store.voice.mutedIds.contains(person.id) {
            Circle().stroke(SQColor.online, lineWidth: 3).frame(width: 48, height: 48)
        }
    }
}

#Preview("Voice") {
    Text("Lounge").sheet(isPresented: .constant(true)) {
        VoiceRoomView(store: .preview())
    }
}
