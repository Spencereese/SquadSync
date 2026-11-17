import SwiftUI

/// Type scale for the chat-first shell. Every step is a Dynamic Type text
/// style, so it grows with the system setting and with `-uitest-largeText`.
enum SQType {
    /// Squad name in the header.
    static let display = Font.title2.weight(.bold)
    /// Sheet and panel titles.
    static let title = Font.title3.weight(.semibold)
    /// Section headings inside a panel or card.
    static let section = Font.headline
    /// Message text and form fields.
    static let body = Font.body
    /// Secondary lines under a title.
    static let detail = Font.subheadline
    /// Labels on pills and chips.
    static let label = Font.footnote.weight(.semibold)
    /// Names under avatars, timestamps.
    static let caption = Font.caption
    /// The smallest legible line: hints and gap notes.
    static let micro = Font.caption2
    /// Countdown and seat counts. Digits keep their width so the timer does not jitter.
    static let timer = Font.title3.monospacedDigit().weight(.semibold)
    /// Smaller countdown for pinned bars and pills.
    static let timerSmall = Font.subheadline.monospacedDigit().weight(.semibold)
}

extension View {
    /// Monospaced-digit timer style with the warning tint the spot card already uses.
    func sqTimerStyle(compact: Bool = false) -> some View {
        font(compact ? SQType.timerSmall : SQType.timer)
            .foregroundStyle(SQColor.warning)
            .lineLimit(1)
    }
}
