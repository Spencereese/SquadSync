import SwiftUI

struct HandoffSheet: View {
    @Bindable var store: MockStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Stay here") {
                    Button {
                        Task { await store.joinVoice() }
                        store.postSystem("Staying in the Lounge.")
                        store.openVoiceAfterHandoff = true
                        store.handoffSheetPresented = false
                    } label: {
                        Label("Stay in the Lounge", systemImage: "waveform")
                    }
                }
            }
            .navigationTitle("Handoff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview("Handoff") {
    HandoffSheet(store: .preview())
}
