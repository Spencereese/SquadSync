import SwiftUI

/// Compact card for a finished spot call in the chat thread. One VoiceOver element
/// that reads the whole call; no symbols, so nothing decorative is read aloud.
struct SpotHistoryCard: View {
    let call: SpotCall
    let outcome: SpotOutcome

    @Environment(\.dynamicTypeSize) private var typeSize

    /// At accessibility sizes the game gets its own line and wraps fully, with the
    /// time underneath, so a long name is never cut off.
    struct Layout: Equatable {
        let stacksTime: Bool
        let gameLineLimit: Int?

        init(accessibilitySize: Bool) {
            stacksTime = accessibilitySize
            gameLineLimit = accessibilitySize ? nil : 2
        }
    }

    var body: some View {
        let time = SpotHistoryCard.time(SpotThread.endedAt(call))
        let layout = Layout(accessibilitySize: typeSize.isAccessibilitySize)
        VStack(alignment: .leading, spacing: 2) {
            if layout.stacksTime {
                gameText(layout)
                timeText(time)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: SQSpace.s) {
                    gameText(layout)
                    Spacer(minLength: SQSpace.xs)
                    timeText(time)
                }
            }
            Text(SpotThread.detail(call, outcome: outcome))
                .font(SQType.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            if SpotThread.showsLocalExpiryNote(call, outcome: outcome) {
                Text(SpotThread.localExpiryNote)
                    .font(SQType.micro)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, SQSpace.m)
        .padding(.vertical, SQSpace.s)
        .sqSurface(.card, radius: SQRadius.m)
        .padding(.vertical, SQSpace.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SpotThread.spoken(call, outcome: outcome, time: time))
        .accessibilityIdentifier("spot-history")
    }

    private func gameText(_ layout: Layout) -> some View {
        Text(call.game)
            .font(SQType.label)
            .foregroundStyle(SQColor.ink)
            .lineLimit(layout.gameLineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func timeText(_ time: String) -> some View {
        Text(time)
            .font(SQType.micro.monospacedDigit())
            .foregroundStyle(SQColor.subtle)
            .lineLimit(1)
    }

    private var tint: Color {
        switch outcome {
        case .ended: SQColor.signal
        case .cancelled, .expired: SQColor.subtle
        }
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

/// Honest placeholder where the spot card goes: loading, a failed read with Retry,
/// or a history read the server can't answer.
struct SpotStatusRow: View {
    let text: String
    var loading = false
    var identifier: String
    var retry: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: SQSpace.s) {
            if loading {
                ProgressView()
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(SQType.caption)
                .foregroundStyle(SQColor.subtle)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if let retry {
                Button("Retry", action: retry)
                    .font(SQType.label)
                    .accessibilityLabel("Retry loading the spot call")
                    .accessibilityIdentifier("spot-retry")
            }
        }
        .padding(.horizontal, SQSpace.m)
        .padding(.vertical, SQSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
