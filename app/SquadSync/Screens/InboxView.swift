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
        PresenceStrip(people: store.people)
            .padding(.horizontal, -SQSpace.s)
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

private struct PresenceStrip: View {
    let people: [Person]
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showRest = false

    var body: some View {
        GeometryReader { proxy in
            let plan = layout(width: proxy.size.width)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(plan.visible) { person in
                    cell(person)
                }
                if !plan.hidden.isEmpty {
                    overflow(plan.hidden)
                }
            }
            .overlay(alignment: .trailing) {
                if !plan.hidden.isEmpty {
                    LinearGradient(
                        colors: [SQColor.canvas.opacity(0), SQColor.canvas],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: 32)
                    .padding(.trailing, cueWidth)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                }
            }
        }
        .frame(height: typeSize.isAccessibilitySize ? 112 : 64)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showRest) { restSheet }
    }

    private var cellWidth: CGFloat { typeSize.isAccessibilitySize ? 84 : 52 }
    private var avatarSize: CGFloat { typeSize.isAccessibilitySize ? 40 : 32 }
    private var cueWidth: CGFloat { 48 }
    private var spacing: CGFloat { SQSpace.s }

    private func layout(width: CGFloat) -> (visible: [Person], hidden: [Person]) {
        let stride = cellWidth + spacing
        guard stride > 0, !people.isEmpty else { return ([], []) }
        if CGFloat(people.count) * stride - spacing <= width {
            return (people, [])
        }
        let room = max(stride, width - cueWidth)
        let count = min(people.count, max(1, Int(room / stride)))
        return (Array(people.prefix(count)), Array(people.dropFirst(count)))
    }

    private func cell(_ person: Person) -> some View {
        VStack(spacing: 4) {
            PresenceAvatar(person: person, size: avatarSize)
            Text(person.name)
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: cellWidth)
        }
        .accessibilityElement(children: .combine)
    }

    private func overflow(_ hidden: [Person]) -> some View {
        Button { showRest = true } label: {
            Text("+\(hidden.count)")
                .font(.subheadline.weight(.semibold))
                .frame(width: avatarSize, height: avatarSize)
                .background(SQColor.card, in: Circle())
                .overlay(Circle().stroke(SQColor.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(hidden.count) more: \(hidden.map(\.name).joined(separator: ", "))")
        .accessibilityHint("Shows the rest of the squad")
    }

    private var restSheet: some View {
        NavigationStack {
            List(people) { person in
                HStack(spacing: SQSpace.m) {
                    PresenceAvatar(person: person, size: 36)
                    Text(person.name)
                        .font(.headline)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: SQSpace.s)
                    RoleTag(role: person.role)
                }
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Who's around")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showRest = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
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
