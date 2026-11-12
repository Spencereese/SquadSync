import SwiftUI

struct SpaceView: View {
    @Bindable var store: MockStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        List {
            if typeSize.isAccessibilitySize {
                members
                channels
            } else {
                channels
                members
            }
        }
        .listRowSpacing(typeSize.isAccessibilitySize ? 0 : 8)
        .contentMargins(.bottom, SQSpace.s, for: .scrollContent)
        .modifier(AccessibilityListTop(enabled: typeSize.isAccessibilitySize))
        .navigationBarTitleDisplayMode(typeSize.isAccessibilitySize ? .inline : .large)
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

    private var channels: some View {
        Section("Channels") {
            ForEach(store.conversations.filter { $0.kind == .channel || $0.kind == .squadSpace }) { channel in
                NavigationLink(value: channel.id) {
                    Text(channel.title).lineLimit(typeSize.isAccessibilitySize ? 1 : 2)
                }
            }
        }
    }

    private var members: some View {
        Section("Members") {
            ForEach(store.people) { person in
                memberRow(person)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("member-\(person.id)")
                    .modifier(CompactListRow(enabled: typeSize.isAccessibilitySize))
            }
        }
    }

    private func memberRow(_ person: Person) -> some View {
        HStack(alignment: .center, spacing: SQSpace.m) {
            PresenceAvatar(person: person, size: typeSize.isAccessibilitySize ? 36 : 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                    .font(.headline)
                    .lineLimit(typeSize.isAccessibilitySize ? 1 : 2)
                Text(status(person))
                    .font(.caption)
                    .foregroundStyle(SQColor.muted)
                    .lineLimit(typeSize.isAccessibilitySize ? 1 : nil)
                    .fixedSize(horizontal: false, vertical: true)
                if typeSize.isAccessibilitySize {
                    RoleTag(role: person.role, compact: true)
                }
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: SQSpace.s)
                RoleTag(role: person.role)
                    .fixedSize()
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

private struct AccessibilityListTop: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.contentMargins(.top, 0, for: .scrollContent)
        } else {
            content
        }
    }
}

private struct CompactListRow: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        } else {
            content
        }
    }
}

#Preview("Space") {
    NavigationStack { SpaceView(store: .preview()) }
}
