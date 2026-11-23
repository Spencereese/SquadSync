import SwiftUI

/// The squad's always-open voice room (live backend): join, leave, mute, and who's
/// in it. Rules and copy live in `SquadVoiceState` (SquadVoice.swift); this only
/// draws them. While voice isn't set up (function not deployed, Stream secrets
/// unset, or no voice SDK in this build) it says "Voice isn't set up yet" and
/// never shows anyone as connected.
struct SquadVoiceSheet: View {
    let model: LiveSessionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let state = model.squadVoiceState
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: SQSpace.l) {
                    status(state)
                    if state.phase == .connected {
                        roster(state)
                    }
                    buttons(state)
                }
                .padding(SQSpace.l)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(SQColor.surface0)
            .navigationTitle("Squad voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("voice-done")
                }
            }
        }
        .accessibilityIdentifier("voice-sheet")
        .presentationDetents(typeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(SQColor.surface0)
        .onDisappear { model.voiceSheetOpen = false }
    }

    @ViewBuilder
    private func status(_ state: SquadVoiceState) -> some View {
        switch state.phase {
        case .loading:
            HStack(spacing: SQSpace.s) {
                ProgressView()
                    .accessibilityHidden(true)
                line(state.statusLine, color: SQColor.subtle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("voice-loading")
        case .notSetUp:
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                Text(state.statusLine)
                    .font(SQType.detail.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                line("Nobody can join until it is. Nothing here is connected.", color: SQColor.subtle)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("voice-not-set-up")
        case .failed:
            line(state.statusLine, color: SQColor.danger)
                .accessibilityIdentifier("voice-error")
        case .idle, .connected:
            line(state.statusLine, color: SQColor.ink)
                .accessibilityIdentifier("voice-status")
        }
    }

    private func line(_ text: String, color: Color) -> some View {
        Text(text)
            .font(SQType.detail)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func roster(_ state: SquadVoiceState) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Text("In the room")
                .font(SQType.section)
                .foregroundStyle(SQColor.ink)
                .accessibilityAddTraits(.isHeader)
            if let empty = state.emptyLine {
                line(empty, color: SQColor.subtle)
                    .accessibilityIdentifier("voice-empty")
            } else {
                ForEach(state.members) { member in
                    HStack(spacing: SQSpace.s) {
                        Image(systemName: member.muted ? "mic.slash.fill" : (member.speaking ? "waveform" : "mic.fill"))
                            .foregroundStyle(member.speaking && !member.muted ? SQColor.signal : SQColor.subtle)
                            .accessibilityHidden(true)
                        Text(member.isYou ? "\(member.name) (you)" : member.name)
                            .font(SQType.detail)
                            .foregroundStyle(SQColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .frame(minHeight: 44)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(member.spoken)
                    .accessibilityIdentifier("voice-member-\(member.id)")
                }
            }
        }
    }

    private func buttons(_ state: SquadVoiceState) -> some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.s))
            : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
        return layout {
            if state.canJoin {
                Button {
                    Task { await model.joinSquadVoice() }
                } label: {
                    Text(state.joinTitle).frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("voice-join")
            }
            if state.canMute {
                Button {
                    Task { await model.toggleSquadVoiceMute() }
                } label: {
                    Text(state.muted ? "Unmute" : "Mute").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(state.muted ? "Unmute your mic" : "Mute your mic")
                .accessibilityIdentifier("voice-mute")
            }
            if state.canLeave {
                Button(role: .destructive) {
                    Task { await model.leaveSquadVoice() }
                } label: {
                    Text("Leave").frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Leave voice")
                .accessibilityIdentifier("voice-leave")
            }
        }
    }
}
