import SwiftUI

struct VoiceRoomView: View {
    @Bindable var store: MockStore
    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.l) {
            Text(store.voice.title).font(.title2.weight(.semibold))
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
                            Text(store.voice.mutedIds.contains(id) ? "Muted" : (person.isSpeaking ? "Speaking" : "Listening"))
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
                    store.toggleMute()
                }
                .buttonStyle(.bordered)
                Button("Leave", role: .destructive) { store.leaveVoice() }
                    .buttonStyle(.bordered)
                Spacer()
                Button("Collapse") { store.voice.collapsed = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(SQSpace.l)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
