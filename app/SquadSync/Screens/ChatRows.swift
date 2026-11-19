import SwiftUI

// Message polish (redesign S3). Small views for the squad chat thread. Layout
// rules live in `ChatThread.swift`; these only draw them. Every text wraps
// (`fixedSize(horizontal: false, vertical: true)`) so nothing clips at AX5, and
// decorative symbols are hidden from VoiceOver.

/// "Today", "Yesterday", or a date between days. A header for VoiceOver rotor navigation.
struct ChatDaySeparator: View {
    let label: String

    var body: some View {
        // One accessibility element: the label carries the identifier and header
        // trait, the rules are hidden, and the stack adds no element of its own.
        // (A combined container still exposed its inner Text, so VoiceOver met
        // "Today" twice.)
        HStack(spacing: SQSpace.s) {
            line
            Text(label)
                .font(SQType.caption.weight(.semibold))
                .foregroundStyle(SQColor.subtle)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("day-separator")
            line
        }
        .padding(.vertical, SQSpace.s)
        .frame(maxWidth: .infinity)
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

enum ChatRowMetrics {
    /// Space kept on the far side of a bubble so yours and theirs never line up.
    static let gutter: CGFloat = 48
    static let avatar: CGFloat = 28
}

/// Their initial beside the first message of a run. The column stays reserved
/// on the rest of the run so the bubbles line up. VoiceOver hears the name on the bubble.
struct ChatSenderAvatar: View {
    let initial: String
    let visible: Bool

    var body: some View {
        ZStack {
            if visible {
                Circle().fill(SQColor.surface3)
                Text(initial)
                    .font(SQType.label.weight(.bold))
                    .foregroundStyle(SQColor.ink)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
        .frame(width: ChatRowMetrics.avatar, height: ChatRowMetrics.avatar)
        .padding(.top, visible ? SQSpace.l : 0)
        .accessibilityHidden(true)
    }
}

/// "+" after the chips: opens the emoji row for this message.
struct ChatAddReactionButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "face.smiling")
                .font(SQType.label)
                .foregroundStyle(SQColor.muted)
                .frame(minWidth: 44, minHeight: 44)
                .background(SQColor.surface2, in: Capsule())
                .overlay { Capsule().stroke(SQColor.hairline, lineWidth: 1) }
                .contentShape(Capsule())
                .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a reaction")
        .accessibilityIdentifier("reaction-add")
    }
}

/// Name and quiet time at the top of a group. VoiceOver hears both on the bubble.
/// Your own runs show only the time: the side and color already say it's you.
struct ChatGroupHeader: View {
    let name: String
    let time: String
    let mine: Bool

    var body: some View {
        if mine {
            timeText
                .accessibilityHidden(true)
        } else {
            named
        }
    }

    private var named: some View {
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
    @Environment(\.dynamicTypeSize) private var typeSize

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
            // Side by side normally; stacked at accessibility sizes so the reason
            // gets the full width and Retry sits right under it.
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.xs))
                : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
            layout {
                text(reason)
                    .accessibilityIdentifier("chat-error")
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                Button(action: retry) {
                    Text("Retry")
                        .font(SQType.label)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Retry loading messages")
                .accessibilityIdentifier("chat-retry")
            }
            .padding(.vertical, SQSpace.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id(ChatHistoryRow.anchor)
        }
    }

    /// Scroll target for the history error, so its Retry can be brought into view.
    static let anchor = "chat-history-row"

    private func text(_ value: String) -> some View {
        Text(value)
            .font(SQType.caption)
            .foregroundStyle(SQColor.subtle)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// The top of the thread: pages older messages when it comes into view, says when
/// it's loading or failed (with a 44pt Retry), and marks the start of the chat.
struct ChatOlderRow: View {
    let state: ChatOlderPaging.State
    let retry: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        switch state {
        case .idle:
            // Invisible trigger: its appearance is what starts the next page.
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 8, maxHeight: 8)
                .accessibilityHidden(true)
        case .loading:
            HStack(spacing: SQSpace.s) {
                ProgressView()
                    .accessibilityHidden(true)
                text(ChatOlderPaging.loadingText)
            }
            .padding(.vertical, SQSpace.s)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("chat-older-loading")
        case .failed(let reason):
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: SQSpace.xs))
                : AnyLayout(HStackLayout(alignment: .center, spacing: SQSpace.s))
            layout {
                text(reason)
                    .accessibilityIdentifier("chat-older-error")
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                Button(action: retry) {
                    Text("Retry")
                        .font(SQType.label)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Retry loading earlier messages")
                .accessibilityIdentifier("chat-older-retry")
            }
            .padding(.vertical, SQSpace.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
        case .reachedStart:
            text(ChatOlderPaging.startText)
                .multilineTextAlignment(.center)
                .padding(.vertical, SQSpace.s)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("chat-start")
        }
    }

    private func text(_ value: String) -> some View {
        Text(value)
            .font(SQType.caption)
            .foregroundStyle(SQColor.subtle)
            .fixedSize(horizontal: false, vertical: true)
    }
}
