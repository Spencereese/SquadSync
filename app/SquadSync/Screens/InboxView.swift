import SwiftUI

struct InboxView: View {
    @Bindable var store: MockStore
    @State private var channelsOpen = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            switch store.screen {
            case .loading:
                StateBanner(title: "Loading the squad", detail: "Mock data is coming up. Nothing is on the network.")
                    .padding(SQSpace.l)
            case .failed:
                StateBanner(title: "Couldn't open the inbox", detail: "This prototype has no server. Try Ready again.")
                    .padding(SQSpace.l)
            case .empty:
                StateBanner(title: "No chats yet", detail: "Side groups and DMs will sit under the squad once someone starts one.")
                    .padding(SQSpace.l)
            case .ready:
                ready
            }
        }
        .background(SQColor.canvas)
        .navigationTitle("SquadSync")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu("States") {
                    Button("Ready") { store.screen = .ready }
                    Button("Loading") { store.screen = .loading }
                    Button("Empty") { store.screen = .empty }
                    Button("Error") { store.screen = .failed }
                }
                .accessibilityLabel("Preview loading, empty, and error")
            }
        }
    }

    private var ready: some View {
        let visible = store.visibleConversations()
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.l) {
                presence
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if let party = store.party {
                        NavigationLink(value: party.conversationId) {
                            FormingDock(party: party, now: context.date)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the squad thread")
                    }
                }
                section("Squad") {
                    spaceRow(visible)
                }
                section("Side groups") {
                    ForEach(visible.filter { $0.kind == .sideGroup }) { row($0) }
                }
                section("Direct messages") {
                    ForEach(visible.filter { $0.kind == .dm }) { row($0) }
                }
            }
            .padding(SQSpace.l)
        }
        .contentMargins(.bottom, typeSize.isAccessibilitySize ? SQSpace.xl : SQSpace.m, for: .scrollContent)
        .navigationDestination(for: String.self) { id in
            thread(for: id)
        }
    }

    private var presence: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: SQSpace.m) {
                ForEach(store.people) { person in
                    VStack(spacing: 4) {
                        PresenceAvatar(person: person)
                        Text(person.name)
                            .font(.caption2)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .padding(.horizontal, SQSpace.s)
            .padding(.trailing, SQSpace.l)
        }
        .accessibilityLabel("Who is around")
    }

    private func spaceRow(_ visible: [Conversation]) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if let space = visible.first(where: { $0.kind == .squadSpace }) {
                Button {
                    withAnimation(.snappy) { channelsOpen.toggle() }
                } label: {
                    HStack {
                        Image(systemName: "person.3.fill")
                        Text(space.title).font(.headline)
                        Spacer()
                        Image(systemName: channelsOpen ? "chevron.down" : "chevron.right")
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(space.title), \(channelsOpen ? "channels open" : "channels folded")")
                if channelsOpen {
                    ForEach(visible.filter { $0.parentId == space.id }) { row($0) }
                        .padding(.leading, SQSpace.l)
                }
            }
        }
    }

    private func row(_ conversation: Conversation) -> some View {
        NavigationLink(value: conversation.id) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title).font(.body.weight(.semibold))
                    if conversation.guestIds.isEmpty == false {
                        Text("Includes a guest")
                            .font(.caption)
                            .foregroundStyle(SQColor.role(.guest))
                    }
                }
                Spacer()
                if conversation.unread > 0 {
                    Text("\(conversation.unread)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(SQColor.accent, in: Capsule())
                        .foregroundStyle(.white)
                        .accessibilityLabel("\(conversation.unread) unread")
                }
            }
            .padding(.vertical, SQSpace.s)
        }
        .buttonStyle(.plain)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(SQColor.muted)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }

    @ViewBuilder
    private func thread(for id: String) -> some View {
        if let conversation = store.conversations.first(where: { $0.id == id }) {
            ThreadView(store: store, conversation: conversation)
        } else {
            StateBanner(title: "Missing thread", detail: "That chat is not in the mock.")
        }
    }
}

#Preview("Inbox") {
    NavigationStack { InboxView(store: .preview()) }
}

private struct LoadingInbox: View {
    @State private var store: MockStore = {
        let store = MockStore.preview()
        store.screen = .loading
        return store
    }()

    var body: some View {
        NavigationStack { InboxView(store: store) }
    }
}

#Preview("Inbox loading") {
    LoadingInbox()
}
