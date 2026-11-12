import SwiftUI

struct SpaceView: View {
    @Bindable var store: MockStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            Section("Channels") {
                ForEach(store.conversations.filter { $0.kind == .channel || $0.kind == .squadSpace }) { channel in
                    NavigationLink(value: channel.id) {
                        Text(channel.title).lineLimit(2)
                    }
                }
            }
            Section("Members") {
                ForEach(store.people) { person in
                    ViewThatFits(in: .horizontal) {
                        memberRow(person, stacked: false)
                        memberRow(person, stacked: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: typeSize.isAccessibilitySize ? SQSpace.tabClearanceAX : SQSpace.tabClearance)
                .accessibilityHidden(true)
        }
        .safeAreaPadding(.bottom, typeSize.isAccessibilitySize ? SQSpace.m : SQSpace.s)
        .navigationDestination(for: String.self) { id in
            if let conversation = store.conversations.first(where: { $0.id == id }) {
                ThreadView(store: store, conversation: conversation)
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

    private func memberRow(_ person: Person, stacked: Bool) -> some View {
        let identity = HStack(spacing: SQSpace.m) {
            PresenceAvatar(person: person, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name).font(.headline).lineLimit(2)
                Text(status(person))
                    .font(.caption)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: SQSpace.s) {
                    identity
                    RoleTag(role: person.role)
                }
            } else {
                HStack(spacing: SQSpace.m) {
                    identity
                    Spacer(minLength: SQSpace.s)
                    RoleTag(role: person.role)
                        .fixedSize()
                }
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
