import SwiftUI

@main
struct SquadSyncApp: App {
    @State private var store = MockStore.preview()

    var body: some Scene {
        WindowGroup {
            RootView(store: store)
        }
    }
}

struct RootView: View {
    @Bindable var store: MockStore

    var body: some View {
        TabView {
            NavigationStack {
                InboxView(store: store)
            }
            .tabItem { Label("Inbox", systemImage: "bubble.left.and.bubble.right") }

            NavigationStack {
                SpaceView(store: store)
            }
            .tabItem { Label("Space", systemImage: "person.3") }
        }
        .tint(SQColor.accent)
        .safeAreaInset(edge: .bottom) {
            if store.voice.collapsed && !store.voice.occupantIds.isEmpty {
                VoicePill(room: store.voice) { store.voice.collapsed = false }
                    .padding(.bottom, SQSpace.s)
            }
        }
    }
}

#Preview("Root") {
    RootView(store: .preview())
}
