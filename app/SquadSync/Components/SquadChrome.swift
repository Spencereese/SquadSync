import SwiftUI

/// Avatar with a status ring for the presence strip. Unknown presence gets a
/// dashed neutral ring, never a green one.
struct SQAvatar: View {
    let initial: String
    let status: SquadPresenceStatus
    var size: CGFloat = 40
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            Circle()
                .fill(SQColor.surface3)
            Text(initial)
                .font(.headline.weight(.bold))
                .foregroundStyle(SQColor.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .padding(SQSpace.xs)
        }
        .frame(width: dimension, height: dimension)
        .overlay {
            ring
        }
        .overlay(alignment: .bottomTrailing) {
            if let symbol = badgeSymbol {
                Image(systemName: symbol)
                    .accessibilityHidden(true)
                    .font(.system(size: 8, weight: .heavy))
                    .dynamicTypeSize(.large)
                    .foregroundStyle(SQColor.onSignal)
                    .padding(3)
                    .background(ringColor, in: Circle())
                    .overlay(Circle().stroke(SQColor.surface1, lineWidth: 1.5))
            }
        }
        .accessibilityHidden(true)
    }

    /// Accessibility sizes get a bigger target, capped so the strip stays one row.
    private var dimension: CGFloat {
        typeSize.isAccessibilitySize ? size + 12 : size
    }

    @ViewBuilder
    private var ring: some View {
        if status == .unknown || status == .notCheckedIn {
            Circle()
                .strokeBorder(SQColor.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
        } else {
            Circle()
                .strokeBorder(ringColor, lineWidth: 2.5)
        }
    }

    private var ringColor: Color {
        switch status {
        case .locked: SQColor.accent
        case .inSpot: SQColor.signal
        case .availableNow: SQColor.online.opacity(0.8)
        case .later: SQColor.warning
        case .cantPlay: SQColor.danger.opacity(0.7)
        case .you: SQColor.signal.opacity(0.55)
        case .notCheckedIn, .unknown: SQColor.hairline
        }
    }

    private var badgeSymbol: String? {
        switch status {
        case .locked: "lock.fill"
        case .inSpot: "gamecontroller.fill"
        case .later: "clock"
        case .cantPlay: "minus"
        case .availableNow, .you, .notCheckedIn, .unknown: nil
        }
    }
}

/// Small capsule label: link state, voice, "presence not live".
struct PresencePill: View {
    let text: String
    var systemImage: String?
    var tint: Color = SQColor.subtle
    var filled = false
    /// What VoiceOver reads. The symbol is decoration and is never read.
    var spoken: String? = nil
    /// A drawn dashed ring instead of a symbol. Shapes carry no label, so nothing
    /// can leak a symbol name to VoiceOver or the accessibility tree.
    var dashedMark = false
    /// A drawn dot instead of a symbol, for the same reason as `dashedMark`.
    var dotMark = false

    var body: some View {
        HStack(spacing: SQSpace.xs) {
            if dashedMark {
                Circle()
                    .strokeBorder(.foreground, style: StrokeStyle(lineWidth: 1.5, dash: [2, 2]))
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            } else if dotMark {
                Circle()
                    .fill(.foreground)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            } else if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
            Text(text)
                .lineLimit(1)
        }
        .fixedSize()
        .font(SQType.label)
        .foregroundStyle(filled ? SQColor.onSignal : tint)
        .padding(.horizontal, SQSpace.s + 2)
        .padding(.vertical, SQSpace.xs + 1)
        .background {
            Capsule()
                .fill(filled ? AnyShapeStyle(tint) : AnyShapeStyle(SQColor.surface3.opacity(0.9)))
        }
        .overlay {
            Capsule().stroke(filled ? Color.clear : tint.opacity(0.35), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken ?? text)
    }
}

/// Glass header bar. The title slot stays on its own row at accessibility sizes
/// so the trailing actions never squeeze it out.
struct SQHeaderBar<Title: View, Actions: View, Accessory: View>: View {
    /// False keeps one row even at accessibility sizes (the compact header while typing).
    var stacksAtAccessibilitySizes: Bool = true
    @ViewBuilder var title: () -> Title
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var accessory: () -> Accessory
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if typeSize.isAccessibilitySize && stacksAtAccessibilitySizes {
                title()
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: SQSpace.m) {
                    Spacer(minLength: 0)
                    actions()
                }
            } else {
                HStack(alignment: .center, spacing: SQSpace.m) {
                    title()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                    actions()
                }
            }
            accessory()
        }
        .padding(.horizontal, SQSpace.m)
        .padding(.vertical, SQSpace.s)
        .sqSurface(.bar, radius: SQRadius.xl)
    }
}

/// Card surface for in-chat content. S2 moves the spot card onto this.
struct SQCardSurface<Content: View>: View {
    var padding: CGFloat = SQSpace.m
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .sqSurface(.card, radius: SQRadius.l)
    }
}
