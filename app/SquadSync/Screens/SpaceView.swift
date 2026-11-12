import SwiftUI

struct SpaceView: View {
    @Bindable var store: MockStore

    var body: some View {
        List {
            Section("Channels") {
                ForEach(store.conversations.filter { $0.kind == .channel || $0.kind == .squadSpace }) { channel in
                    NavigationLink(channel.title) {
                        ThreadView(store: store, conversation: channel)
                    }
                }
            }
            Section("Members") {
                ForEach(store.people) { person in
                    HStack(spacing: SQSpace.m) {
                        PresenceAvatar(person: person, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name).font(.headline)
                            Text(status(person))
                                .font(.caption)
                                .foregroundStyle(SQColor.muted)
                        }
                        Spacer()
                        RoleTag(role: person.role)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .navigationTitle("Space")
        .overlay {
            if store.screen == .empty {
                StateBanner(title: "No members", detail: "The mock squad is empty.")
                    .padding()
            }
        }
    }

    private func status(_ person: Person) -> String {
        if let game = person.game { return "Playing \(game)" }
        switch person.availability {
        case .upToPlay: return "Up to play"
        case .onlineOnly: return "Online, not up to play"
        case .later: return "Maybe later"
        case .cant: return "Can't"
        }
    }
}

#Preview("Space") {
    NavigationStack { SpaceView(store: .preview()) }
}
