import SwiftUI

enum AppTab: Hashable {
    case inbox
    case space
}

enum LaunchScreen: String {
    case inbox
    case threadGeneral = "thread-general"
    case threadWarzone = "thread-warzone"
    case party
    case voice
    case voicePill = "voice-pill"
    case space
    case handoff
}

struct LaunchOptions {
    var screen: LaunchScreen = .inbox
    var scenario: LaunchScenario = .seated
    var largeText = false

    var path: [String] {
        switch screen {
        case .threadGeneral, .party, .voice:
            ["general"]
        case .threadWarzone:
            ["warzone"]
        default:
            []
        }
    }

    static func current(_ arguments: [String] = ProcessInfo.processInfo.arguments) -> LaunchOptions {
        var options = LaunchOptions()
        if let value = flag("-screen", in: arguments), let screen = LaunchScreen(rawValue: value) {
            options.screen = screen
        }
        if let value = flag("-scenario", in: arguments), let scenario = LaunchScenario(rawValue: value) {
            options.scenario = scenario
        }
        options.largeText = arguments.contains("-uitest-largeText")
        return options
    }

    private static func flag(_ name: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: name), arguments.index(after: index) < arguments.endIndex else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }
}

@main
struct SquadSyncApp: App {
    @State private var store: MockStore
    private let launch: LaunchOptions

    init() {
        let launch = LaunchOptions.current()
        self.launch = launch
        _store = State(initialValue: MockStore.seeded(scenario: launch.scenario))
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: store, launch: launch)
        }
    }
}

struct RootView: View {
    @Bindable var store: MockStore
    var launch: LaunchOptions = LaunchOptions()
    @State private var tab: AppTab
    @State private var path: [String]
    @State private var appliedLaunch = false

    init(store: MockStore, launch: LaunchOptions = LaunchOptions()) {
        self.store = store
        self.launch = launch
        _tab = State(initialValue: launch.screen == .space ? .space : .inbox)
        _path = State(initialValue: launch.path)
    }

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack(path: $path) {
                InboxView(store: store)
            }
            .safeAreaInset(edge: .bottom, spacing: SQSpace.s) { voicePill }
            .tabItem {
                Label("Inbox", systemImage: "bubble.left.and.bubble.right")
                    .accessibilityLabel("Inbox")
                    .accessibilityIdentifier("tab-inbox")
            }
            .tag(AppTab.inbox)

            NavigationStack {
                SpaceView(store: store)
            }
            .safeAreaInset(edge: .bottom, spacing: SQSpace.s) { voicePill }
            .tabItem {
                Label("Space", systemImage: "person.3")
                    .accessibilityLabel("Space")
                    .accessibilityIdentifier("tab-space")
            }
            .tag(AppTab.space)
        }
        .tint(SQColor.accent)
        .toolbar(.visible, for: .tabBar)
        .sheet(isPresented: $store.voiceSheetPresented, onDismiss: {
            if !store.voiceSheetPresented, !store.voice.occupantIds.isEmpty {
                store.voice.collapsed = true
            }
        }) {
            VoiceRoomView(store: store)
        }
        .sheet(isPresented: $store.handoffSheetPresented, onDismiss: {
            if store.openVoiceAfterHandoff {
                store.openVoiceAfterHandoff = false
                store.openVoice()
            }
        }) {
            HandoffSheet(store: store)
        }
        .onAppear(perform: applyLaunch)
        .modifier(LargeTextLaunch(enabled: launch.largeText))
    }

    @ViewBuilder
    private var voicePill: some View {
        if store.showsVoicePill {
            VoicePill(room: store.voice) { store.openVoice() }
                .padding(.horizontal, SQSpace.l)
                .padding(.bottom, SQSpace.s)
                .accessibilityIdentifier("voice-pill")
        }
    }

    private func applyLaunch() {
        guard !appliedLaunch else { return }
        appliedLaunch = true
        switch launch.screen {
        case .voice:
            store.openVoice()
        case .voicePill:
            store.collapseVoice()
        case .handoff:
            store.handoffSheetPresented = true
        default:
            break
        }
    }
}

private struct LargeTextLaunch: ViewModifier {
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.accessibility5)
        } else {
            content
        }
    }
}

#Preview("Root") {
    RootView(store: .preview())
}
