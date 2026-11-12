import SwiftUI

struct HandoffSheet: View {
    @Bindable var store: MockStore
    @Environment(\.dismiss) private var dismiss
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Stay here") {
                    Button {
                        Task { await store.joinVoice() }
                        store.postSystem("Staying in the Lounge.")
                        dismiss()
                    } label: {
                        Label("Stay in the Lounge", systemImage: "waveform")
                    }
                }
                Section("Open another app") {
                    linkRow("Discord", "Saved voice channel", "https://discord.com/channels/mock-server/mock-voice")
                    linkRow("Xbox", "Best-effort party link", "xbox://party/mock")
                    linkRow("PlayStation", "Best-effort party link", "psapp://party/mock")
                }
            }
            .navigationTitle("Handoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Couldn't open that app", isPresented: Binding(
                get: { failure != nil },
                set: { if !$0 { failure = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
        }
    }

    private func linkRow(_ title: String, _ detail: String, _ raw: String) -> some View {
        Button {
            open(title: title, raw: raw)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(SQColor.muted)
            }
        }
        .accessibilityLabel("\(title). \(detail)")
    }

    private func open(title: String, raw: String) {
        guard let url = URL(string: raw) else {
            failure = "\(title) link is not a valid address."
            return
        }
        let application = UIApplication.shared
        if application.canOpenURL(url) {
            application.open(url) { ok in
                if ok {
                    store.postSystem("Opened \(title).")
                    dismiss()
                } else {
                    failure = "\(title) didn't open. The link was left in chat."
                    store.postSystem("Couldn't open \(title).")
                }
            }
        } else {
            failure = "\(title) isn't available on this phone. The link was left in chat."
            store.postSystem("Couldn't open \(title).")
        }
    }
}

#Preview("Handoff") {
    HandoffSheet(store: .preview())
}
