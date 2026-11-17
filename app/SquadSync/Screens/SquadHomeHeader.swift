import SwiftUI

/// Header for the chat-first home: squad name (opens the squad panel), a
/// voice-room pill that stays a mock, and a horizontally scrolling presence
/// strip. Identifiers `squad-title`, `members`, and `account` keep the
/// navigation-bar names the UI tests already use.
struct SquadHomeHeader: View {
    let squad: SquadRecord?
    let entries: [SquadPresenceEntry]
    /// While typing at accessibility sizes the header drops to one row with no strip,
    /// so the pinned spot bar and the composer keep their room above the keyboard.
    let compact: Bool
    let voice: VoicePillState
    let linkNote: String?
    let onOpenPanel: () -> Void
    let onAccount: () -> Void
    let onVoice: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        SQHeaderBar(stacksAtAccessibilitySizes: !compact) {
            titleButton
        } actions: {
            actionButtons
        } accessory: {
            if squad != nil && !compact {
                presenceStrip
            }
        }
    }

    private var titleButton: some View {
        Button {
            SQHaptics.play(.tap)
            onOpenPanel()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SQSpace.xs) {
                    Text(SquadHeader.title(squad: squad))
                        .font(SQType.display)
                        .foregroundStyle(SQColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Image(systemName: "chevron.down")
                        .font(SQType.caption.weight(.bold))
                        .foregroundStyle(SQColor.subtle)
                }
                if !compact {
                    HStack(spacing: SQSpace.xs) {
                        if let linkNote {
                            Circle()
                                .fill(SQColor.warning)
                                .frame(width: 6, height: 6)
                            Text(linkNote)
                                .lineLimit(1)
                        } else {
                            Text(SquadHeader.detail(squad: squad))
                                .lineLimit(1)
                        }
                    }
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SquadHeader.spoken(squad: squad) ?? SquadHeader.noSquadTitle)
        .accessibilityHint("Opens the squad panel")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(squad == nil ? "squad-header-empty" : "squad-title")
    }

    private var actionButtons: some View {
        HStack(spacing: SQSpace.s) {
            if squad != nil && !typeSize.isAccessibilitySize {
                voicePill
            }
            Button {
                SQHaptics.play(.tap)
                onOpenPanel()
            } label: {
                Image(systemName: "person.3.fill")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Members")
            .accessibilityHint("Opens invite, join, and remove")
            .accessibilityIdentifier("members")
            Button {
                onAccount()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 36, minHeight: 36)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Account")
            .accessibilityIdentifier("account")
        }
        .foregroundStyle(SQColor.ink)
    }

    private var voicePill: some View {
        Button {
            SQHaptics.play(.tap)
            onVoice()
        } label: {
            PresencePill(
                text: voice.title,
                systemImage: voice.joined ? "waveform" : "mic.slash",
                tint: voice.joined ? SQColor.signal : SQColor.subtle,
                filled: voice.joined
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.spoken)
        .accessibilityIdentifier("voice-room-pill")
    }

    private var presenceStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: SQSpace.m) {
                if typeSize.isAccessibilitySize {
                    voicePill
                }
                ForEach(entries) { entry in
                    avatarButton(entry)
                }
                if SquadPresence.hasUntracked(entries) {
                    PresencePill(text: "Presence isn't live yet", systemImage: "antenna.radiowaves.left.and.right.slash")
                        .accessibilityIdentifier("presence-untracked")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Squad presence")
        .accessibilityIdentifier("presence-strip")
    }

    private func avatarButton(_ entry: SquadPresenceEntry) -> some View {
        Button {
            SQHaptics.play(.tap)
            onOpenPanel()
        } label: {
            VStack(spacing: 2) {
                SQAvatar(initial: entry.initial, status: entry.status)
                if !typeSize.isAccessibilitySize {
                    Text(entry.isViewer ? "You" : entry.name)
                        .font(SQType.micro.weight(.semibold))
                        .foregroundStyle(SQColor.ink)
                        .lineLimit(1)
                    Text(caption(entry))
                        .font(SQType.micro)
                        .foregroundStyle(entry.status == .unknown ? SQColor.subtle : SQColor.signal)
                        .lineLimit(1)
                }
            }
            .frame(width: typeSize.isAccessibilitySize ? nil : 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.spokenLabel)
        .accessibilityHint("Opens the squad panel")
        .accessibilityIdentifier("presence-\(entry.name)")
    }

    /// Seated status wins; otherwise the game line; an unknown with no game shows a dash.
    private func caption(_ entry: SquadPresenceEntry) -> String {
        switch entry.status {
        case .locked, .ready, .inSpot:
            return entry.status.shortLabel
        case .you, .unknown:
            return entry.gameCaption ?? "—"
        }
    }
}
