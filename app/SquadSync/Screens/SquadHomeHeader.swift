import SwiftUI

/// Header for the chat-first home: squad name (opens the squad panel), a
/// voice-room pill that stays a mock, and the squad's presence. Identifiers
/// `squad-title`, `members`, and `account` keep the navigation-bar names the
/// UI tests already use.
///
/// Default sizes: two rows, name and actions over a horizontal presence strip.
/// Accessibility sizes: always one row (name plus capped icon buttons). Presence
/// folds behind `presence-toggle`; the session screen floats `SquadPresenceRoster`
/// over the top of the chat, so opening it never pushes the chat down.
struct SquadHomeHeader: View {
    let squad: SquadRecord?
    let entries: [SquadPresenceEntry]
    /// True while the composer is focused at large text. The strip hides so the
    /// pinned spot bar and the composer keep their room above the keyboard.
    let compact: Bool
    let voice: VoicePillState
    let linkNote: String?
    let onOpenPanel: () -> Void
    let onAccount: () -> Void
    let onVoice: () -> Void
    /// Opens the who's-in sheet: avatars and the "Who's in" pill.
    let onOpenWhosIn: () -> Void
    /// Large-text roster state. The roster itself is drawn by the session screen.
    @Binding var rosterOpen: Bool

    @Environment(\.dynamicTypeSize) private var typeSize

    private var large: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        SQHeaderBar(stacksAtAccessibilitySizes: false) {
            titleButton
        } actions: {
            actionButtons
        } accessory: {
            if squad != nil && !large && !compact {
                presenceStrip
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
        VoiceRoomPillButton(voice: voice, onVoice: onVoice)
    }

    // MARK: Default-size strip

    private var presenceStrip: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: SQSpace.s) {
                // First, so it's on screen however many avatars follow.
                whosInPill
                    .padding(.top, SQSpace.s)
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

    private var whosInPill: some View {
        Button {
            SQHaptics.play(.tap)
            onOpenWhosIn()
        } label: {
            // A drawn dot, not an SF Symbol: the symbol's name leaked to VoiceOver
            // here ("person.2.wave.2"). A shape has no label to leak.
            PresencePill(
                text: SquadPresence.whosInPill(entries),
                tint: SQColor.signal,
                spoken: SquadPresence.whosInSpoken(entries),
                dotMark: true
            )
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(SquadPresence.whosInSpoken(entries))
        .accessibilityHint("Opens Who's in: check in and see who can play")
        .accessibilityIdentifier("whos-in-open")
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
            onOpenWhosIn()
        } label: {
            VStack(spacing: 2) {
                SQAvatar(initial: entry.initial, status: entry.status)
                Text(entry.isViewer ? "You" : entry.name)
                    .font(SQType.micro.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if typeSize <= .xLarge, let caption = presenceCaption(entry) {
                    Text(caption)
                        .font(SQType.micro)
                        .italic(entry.status == .unknown || entry.status == .you || entry.status == .notCheckedIn)
                        .foregroundStyle(presenceCaptionColor(entry))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
            .frame(width: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.spokenLabel)
        .accessibilityHint("Opens Who's in")
        .accessibilityIdentifier("presence-\(entry.name)")
    }
}

// MARK: Captions

/// Seated status wins; otherwise the game; nothing at all beats a guess.
private func presenceCaption(_ entry: SquadPresenceEntry) -> String? {
    switch entry.status {
    case .locked, .inSpot, .availableNow, .later, .cantPlay:
        return entry.status.shortLabel
    case .you, .unknown, .notCheckedIn:
        return entry.gameCaption
    }
}

private func presenceCaptionColor(_ entry: SquadPresenceEntry) -> Color {
    switch entry.status {
    case .locked, .inSpot, .availableNow: SQColor.signal
    case .later: SQColor.warning
    case .cantPlay, .you, .unknown, .notCheckedIn: SQColor.subtle
    }
}

/// Voice-room pill. Mock backend: tapping only flips local state. Live: opens the
/// squad voice sheet.
struct VoiceRoomPillButton: View {
    let voice: VoicePillState
    let onVoice: () -> Void

    var body: some View {
        Button {
            SQHaptics.play(.tap)
            onVoice()
        } label: {
            PresencePill(
                text: voice.title,
                systemImage: voice.isIn ? "waveform" : "mic.slash",
                tint: voice.isIn ? SQColor.signal : SQColor.subtle,
                filled: voice.isIn
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(voice.spoken)
        .accessibilityIdentifier("voice-room-pill")
    }
}

/// Large-text presence roster. The session screen floats it over the top of the
/// message list (an overlay, not a row in the stack), so the chat keeps its height
/// and the pinned spot bar above stays uncovered.
///
/// It never scrolls: it shows the longest roster that fits the space it is offered,
/// and folds the rest into "N more", so its last row is always fully on screen.
/// Only the rows are tappable. The panel's background and padding let taps through
/// to the chat underneath.
struct SquadPresenceRoster: View {
    let entries: [SquadPresenceEntry]
    let voice: VoicePillState
    /// Rows, "N more", and the Who's in button open the who's-in sheet.
    let onOpenWhosIn: () -> Void
    let onVoice: () -> Void

    var body: some View {
        let limits = SquadPresence.rosterLimits(count: entries.count)
        return ViewThatFits(in: .vertical) {
            panel(limit: limits[0])
            panel(limit: limits[1])
            panel(limit: limits[2])
            panel(limit: limits[3])
            panel(limit: limits[4])
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Squad presence")
        .accessibilityIdentifier("presence-strip")
    }

    private func panel(limit: Int) -> some View {
        let shown = Array(entries.prefix(limit))
        let hidden = entries.count - shown.count
        return VStack(alignment: .leading, spacing: SQSpace.s) {
            VoiceRoomPillButton(voice: voice, onVoice: onVoice)
            ForEach(shown) { entry in
                row(entry)
            }
            if hidden > 0 {
                Button {
                    SQHaptics.play(.tap)
                    onOpenWhosIn()
                } label: {
                    Text(SquadPresence.moreLabel(hidden))
                        .font(SQType.detail.weight(.semibold))
                        .foregroundStyle(SQColor.signal)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Who's in")
                .accessibilityIdentifier("presence-more")
            }
            Button {
                SQHaptics.play(.tap)
                onOpenWhosIn()
            } label: {
                Text(SquadPresence.whosInPill(entries))
                    .font(SQType.detail.weight(.semibold))
                    .foregroundStyle(SQColor.signal)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Who's in: check in and see who can play")
            .accessibilityIdentifier("whos-in-open")
            if SquadPresence.hasUntracked(entries) {
                Text(SquadPresence.untrackedSpoken)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("presence-untracked")
            }
        }
        .padding(SQSpace.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous)
                .fill(SQColor.surface1)
                .overlay {
                    RoundedRectangle(cornerRadius: SQRadius.l, style: .continuous)
                        .stroke(SQColor.hairline, lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                .allowsHitTesting(false)
        }
    }

    /// Avatar, name, and status or game. The button hugs its content, so the space
    /// to its right is not a tap target.
    private func row(_ entry: SquadPresenceEntry) -> some View {
        Button {
            SQHaptics.play(.tap)
            onOpenWhosIn()
        } label: {
            HStack(alignment: .center, spacing: SQSpace.s) {
                SQAvatar(initial: entry.initial, status: entry.status, size: 32)
                VStack(alignment: .leading, spacing: 0) {
                    Text(entry.isViewer ? "You" : entry.name)
                        .font(SQType.detail.weight(.semibold))
                        .foregroundStyle(SQColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if let caption = presenceCaption(entry) {
                        Text(caption)
                            .font(SQType.caption)
                            .foregroundStyle(presenceCaptionColor(entry))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.spokenLabel)
        .accessibilityHint("Opens Who's in")
        .accessibilityIdentifier("presence-\(entry.name)")
    }
}
