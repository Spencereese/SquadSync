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
    @State private var spacePath: [String] = []
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if path.isEmpty { voicePill }
            }
            .tabItem { InboxTabLabel() }
            .tag(AppTab.inbox)

            NavigationStack(path: $spacePath) {
                SpaceView(store: store)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if spacePath.isEmpty { voicePill }
            }
            .tabItem { SpaceTabLabel() }
            .tag(AppTab.space)
        }
        .overlay(alignment: .topLeading) {
            TabBarAccessibility()
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
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

private struct InboxTabLabel: View {
    var body: some View {
        Label("Inbox", systemImage: "bubble.left.and.bubble.right")
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Inbox")
            .accessibilityIdentifier("tab-inbox")
    }
}

private struct SpaceTabLabel: View {
    var body: some View {
        Label("Space", systemImage: "person.3")
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel("Space")
            .accessibilityIdentifier("tab-space")
    }
}

/// SwiftUI's tab item does not publish an identifier to the real tab bar.
/// Copy Inbox and Space onto the UITabBar items the accessibility tree uses.
private struct TabBarAccessibility: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var started = false
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard !context.coordinator.started else { return }
        context.coordinator.started = true
        stampLater(view: uiView, tries: 20)
    }

    private func stampLater(view: UIView, tries: Int) {
        DispatchQueue.main.async {
            let stamped = self.stamp(from: view)
            if !stamped, tries > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.stampLater(view: view, tries: tries - 1)
                }
            }
        }
    }

    @discardableResult
    private func stamp(from view: UIView) -> Bool {
        let bars = tabBars(from: view)
        let named = [("Inbox", "tab-inbox"), ("Space", "tab-space")]
        for bar in bars {
            for (item, pair) in zip(bar.items ?? [], named) {
                item.title = pair.0
                item.accessibilityLabel = pair.0
                item.accessibilityIdentifier = pair.1
                var traits = item.accessibilityTraits
                traits.insert(.button)
                item.accessibilityTraits = traits
            }
        }
        return !bars.isEmpty && bars.contains { !($0.items ?? []).isEmpty }
    }

    private func tabBars(from view: UIView) -> [UITabBar] {
        var found: [UITabBar] = []
        var responder: UIResponder? = view
        while let next = responder {
            if let controller = next as? UITabBarController {
                found.append(controller.tabBar)
            }
            responder = next.next
        }
        if let window = view.window {
            found.append(contentsOf: collectTabBars(in: window))
        }
        return found
    }

    private func collectTabBars(in view: UIView) -> [UITabBar] {
        var found: [UITabBar] = []
        if let bar = view as? UITabBar { found.append(bar) }
        for child in view.subviews { found.append(contentsOf: collectTabBars(in: child)) }
        return found
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
