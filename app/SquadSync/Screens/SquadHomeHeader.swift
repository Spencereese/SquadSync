import SwiftUI

/// Header for the chat-first home: squad name (opens the squad panel), a
/// voice-room pill that stays a mock, and the squad's presence. Identifiers
/// `squad-title`, `members`, and `account` keep the navigation-bar names the
/// UI tests already use.
///
/// Default sizes: two rows, name and actions over a horizontal presence strip.
/// Accessibility sizes: always one row (name plus capped icon buttons). Presence
/// folds behind `presence-toggle` and opens as a vertical roster, so the chat
/// keeps most of the screen.
struct SquadHomeHeader: View {
    let squad: SquadRecord?
    let entries: [SquadPresenceEntry]
    /// True while the composer is focused. The large-text roster closes so the
    /// pinned spot bar and the composer keep their room above the keyboard.
    let compact: Bool
    let voice: VoicePillState
    let linkNote: String?
    let onOpenPanel: () -> Void
    let onAccount: () -> Void
    let onVoice: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var rosterOpen = false

    private var large: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        SQHeaderBar(stacksAtAccessibilitySizes: false) {
            titleButton
        } actions: {
            actionButtons
        } accessory: {
            if squad != nil {
                if large {
                    if rosterOpen && !compact {
                        largeRoster
                    }
                } else if !compact {
                    presenceStrip
                }
            }
        }
    }

    // MARK: Title

    private var titleButton: some View {
        Button {
            SQHaptics.play(.tap)
            onOpenPanel()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: SQSpace.xs) {
                    if large && linkNote != nil {
                        Circle()
                            .fill(SQColor.warning)
                            .frame(width: 8, height: 8)
                    }
                    Text(SquadHeader.title(squad: squad))
                        .font(SQType.display)
                        .foregroundStyle(SQColor.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    if !large {
                        Image(systemName: "chevron.down")
                            .font(SQType.caption.weight(.bold))
                            .foregroundStyle(SQColor.subtle)
                    }
                }
                if !large && !compact {
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
        .accessibilityValue(linkNote ?? "")
        .accessibilityHint("Opens the squad panel")
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier(squad == nil ? "squad-header-empty" : "squad-title")
    }

    // MARK: Actions

    private var actionButtons: some View {
        HStack(spacing: large ? SQSpace.xs : SQSpace.s) {
            if squad != nil && !large {
                voicePill
            }
            if squad != nil && large {
                iconButton(
                    rosterOpen ? "person.2.circle.fill" : "person.2.circle",
                    label: rosterOpen ? "Hide squad presence" : "Show squad presence",
                    identifier: "presence-toggle"
                ) {
                    SQHaptics.play(.tap)
                    rosterOpen.toggle()
                }
            }
            iconButton("person.3.fill", label: "Members", identifier: "members", hint: "Opens invite, join, and remove") {
                SQHaptics.play(.tap)
                onOpenPanel()
            }
            iconButton("ellipsis.circle", label: "Account", identifier: "account") {
                onAccount()
            }
        }
        .foregroundStyle(SQColor.ink)
    }

    /// Icons stop growing at xxxLarge so three of them and the name fit one row at AX5.
    private func iconButton(
        _ symbol: String,
        label: String,
        identifier: String,
        hint: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityIdentifier(identifier)
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

    // MARK: Default-size strip

    private var presenceStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: SQSpace.s) {
                ForEach(entries) { entry in
                    avatarButton(entry)
                }
                if SquadPresence.hasUntracked(entries) {
                    untrackedPill
                        .padding(.top, SQSpace.s)
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Squad presence")
        .accessibilityIdentifier("presence-strip")
    }

    private var untrackedPill: some View {
        PresencePill(
            text: SquadPresence.untrackedShort,
            spoken: SquadPresence.untrackedSpoken,
            dashedMark: true
        )
        .accessibilityIdentifier("presence-untracked")
    }

    /// Names and captions get a fixed 72-point column. Above xLarge (still a
    /// non-accessibility size) the caption drops so the column stays two lines.
    private func avatarButton(_ entry: SquadPresenceEntry) -> some View {
        Button {
            SQHaptics.play(.tap)
            onOpenPanel()
        } label: {
            VStack(spacing: 2) {
                SQAvatar(initial: entry.initial, status: entry.status)
                Text(entry.isViewer ? "You" : entry.name)
                    .font(SQType.micro.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if typeSize <= .xLarge, let caption = caption(entry) {
                    Text(caption)
                        .font(SQType.micro)
                        .italic(entry.status == .unknown || entry.status == .you)
                        .foregroundStyle(captionColor(entry))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(width: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.spokenLabel)
        .accessibilityHint("Opens the squad panel")
        .accessibilityIdentifier("presence-\(entry.name)")
    }

    // MARK: Large-text roster

    /// One row per member: avatar, name, and status or game wrapping under it.
    private var largeRoster: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            voicePill
            ForEach(entries) { entry in
                Button {
                    SQHaptics.play(.tap)
                    onOpenPanel()
                } label: {
                    HStack(alignment: .center, spacing: SQSpace.s) {
                        SQAvatar(initial: entry.initial, status: entry.status, size: 32)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.isViewer ? "You" : entry.name)
                                .font(SQType.detail.weight(.semibold))
                                .foregroundStyle(SQColor.ink)
                                .fixedSize(horizontal: false, vertical: true)
                            if let caption = caption(entry) {
                                Text(caption)
                                    .font(SQType.caption)
                                    .foregroundStyle(captionColor(entry))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(entry.spokenLabel)
                .accessibilityHint("Opens the squad panel")
                .accessibilityIdentifier("presence-\(entry.name)")
            }
            if SquadPresence.hasUntracked(entries) {
                Text(SquadPresence.untrackedSpoken)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("presence-untracked")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Squad presence")
        .accessibilityIdentifier("presence-strip")
    }

    // MARK: Captions

    /// Seated status wins; otherwise the game; nothing at all beats a guess.
    private func caption(_ entry: SquadPresenceEntry) -> String? {
        switch entry.status {
        case .locked, .ready, .inSpot:
            return entry.status.shortLabel
        case .you, .unknown:
            return entry.gameCaption
        }
    }

    private func captionColor(_ entry: SquadPresenceEntry) -> Color {
        switch entry.status {
        case .locked, .ready, .inSpot: SQColor.signal
        case .you, .unknown: SQColor.subtle
        }
    }
}
