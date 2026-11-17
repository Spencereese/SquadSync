import SwiftUI

// Message polish (redesign S3). Small views for the squad chat thread. Layout
// rules live in `ChatThread.swift`; these only draw them. Every text wraps
// (`fixedSize(horizontal: false, vertical: true)`) so nothing clips at AX5, and
// decorative symbols are hidden from VoiceOver.

/// "Today", "Yesterday", or a date between days. A header for VoiceOver rotor navigation.
struct ChatDaySeparator: View {
    let label: String

    var body: some View {
        HStack(spacing: SQSpace.s) {
            line
            Text(label)
                .font(SQType.caption.weight(.semibold))
                .foregroundStyle(SQColor.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            line
        }
        .padding(.vertical, SQSpace.s)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityAddTraits(.isHeader)
        .accessibilityIdentifier("day-separator")
    }

    private var line: some View {
        Rectangle()
            .fill(SQColor.hairline)
            .frame(height: 1)
            .frame(minWidth: SQSpace.l)
            .accessibilityHidden(true)
    }
}

/// Where the messages you hadn't read yet start.
struct ChatUnreadDivider: View {
    let count: Int

    var body: some View {
        HStack(spacing: SQSpace.s) {
            Text(ChatThread.unreadLabel(count))
                .font(SQType.caption.weight(.semibold))
                .foregroundStyle(SQColor.signal)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Rectangle()
                .fill(SQColor.signal)
                .frame(height: 1)
                .accessibilityHidden(true)
        }
        .padding(.vertical, SQSpace.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(ChatThread.unreadLabel(count))
        .accessibilityIdentifier("unread-divider")
    }
}

/// Name and quiet time at the top of a group. VoiceOver hears both on the bubble.
struct ChatGroupHeader: View {
    let name: String
    let time: String
    let mine: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: SQSpace.s) {
                nameText
                timeText
            }
            VStack(alignment: .leading, spacing: 0) {
                nameText
                timeText
            }
        }
        .accessibilityHidden(true)
    }

    private var nameText: some View {
        Text(name)
            .font(SQType.label)
            .foregroundStyle(mine ? SQColor.accent : SQColor.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var timeText: some View {
        Text(time)
            .font(SQType.micro.monospacedDigit())
            .foregroundStyle(SQColor.subtle)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The quoted message over a reply. Its own element so VoiceOver reads it first.
struct ChatReplyQuoteView: View {
    let quote: ChatReplyQuote
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(alignment: .top, spacing: SQSpace.s) {
            RoundedRectangle(cornerRadius: 1)
                .fill(SQColor.accent)
                .frame(width: 3)
                .accessibilityHidden(true)
            Text(quote.text)
                .font(SQType.caption)
                .foregroundStyle(SQColor.muted)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(quote.spoken)
        .accessibilityIdentifier("reply-quote")
    }
}

/// One reaction under a message. Tapping adds yours or takes it back. At least
/// 44 by 44 points at every text size.
struct ChatReactionChipButton: View {
    let chip: ChatReactionChip
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.xs) {
                Text(chip.emoji)
                Text("\(chip.count)")
                    .monospacedDigit()
            }
            .font(SQType.label)
            .foregroundStyle(chip.mine ? SQColor.ink : SQColor.muted)
            .fixedSize()
            .padding(.horizontal, SQSpace.m)
            .padding(.vertical, SQSpace.xs)
            .frame(minWidth: 44, minHeight: 44)
            .background(chip.mine ? SQColor.surface3 : SQColor.surface2, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(chip.mine ? SQColor.accent : SQColor.hairline, lineWidth: chip.mine ? 1.5 : 1)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.spoken)
        .accessibilityHint(chip.hint)
        .accessibilityAddTraits(chip.mine ? .isSelected : [])
        .accessibilityIdentifier("reaction-chip-\(chip.tapback.rawValue)")
    }
}

/// Over the composer while you write a reply.
struct ChatReplyBanner: View {
    let quote: ChatReplyQuote
    let cancel: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SQSpace.s) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Replying to \(quote.sender ?? "a message")")
                    .font(SQType.label)
                    .foregroundStyle(SQColor.accent)
                    .fixedSize(horizontal: false, vertical: true)
                Text(quote.body ?? ChatReplyQuote.missing)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.muted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(quote.spoken)
            .accessibilityIdentifier("reply-banner")
            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(SQType.label)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cancel reply")
            .accessibilityIdentifier("reply-cancel")
        }
        .padding(.leading, SQSpace.s)
        .background(SQColor.surface2, in: RoundedRectangle(cornerRadius: SQRadius.m, style: .continuous))
    }
}

/// Floats over the bottom of the list while you're scrolled up.
struct ChatJumpButton: View {
    let newCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: SQSpace.xs) {
                Image(systemName: "arrow.down")
                    .accessibilityHidden(true)
                Text(ChatJump.title(newCount: newCount))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(SQType.label)
            .foregroundStyle(SQColor.onSignal)
            .padding(.horizontal, SQSpace.m)
            .padding(.vertical, SQSpace.s)
            .frame(minWidth: 44, minHeight: 44)
            .background(SQColor.signal, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(ChatJump.label(newCount: newCount))
        .accessibilityIdentifier("jump-to-latest")
    }
}

/// Loading, empty, and error states for the thread's history read.
struct ChatHistoryRow: View {
    let display: ChatHistoryState.Display
    let retry: () -> Void

    var body: some View {
        switch display {
        case .loading:
            HStack(spacing: SQSpace.s) {
                ProgressView()
                    .accessibilityHidden(true)
                text(ChatHistoryState.loadingText)
            }
            .padding(.vertical, SQSpace.l)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chat-loading")
        case .empty:
            text(ChatHistoryState.emptyText)
                .multilineTextAlignment(.center)
                .padding(.vertical, SQSpace.xl)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("chat-empty")
        case .failed(let reason), .stale(let reason):
            HStack(alignment: .center, spacing: SQSpace.s) {
                text(reason)
                    .accessibilityIdentifier("chat-error")
                Spacer(minLength: 0)
                Button("Retry", action: retry)
                    .font(SQType.label)
                    .frame(minHeight: 44)
                    .accessibilityLabel("Retry loading messages")
                    .accessibilityIdentifier("chat-retry")
            }
            .padding(.vertical, SQSpace.s)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func text(_ value: String) -> some View {
        Text(value)
            .font(SQType.caption)
            .foregroundStyle(SQColor.subtle)
            .fixedSize(horizontal: false, vertical: true)
    }
}
