import SwiftUI

enum SQSpace {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48
}

/// Corner radii. Cards and sheets use continuous corners.
enum SQRadius {
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 22
    /// Capsules. SwiftUI clamps an oversized radius to half the height.
    static let pill: CGFloat = 999
}

enum SQColor {
    static let canvas = adaptive(SQPalette.canvas)
    static let card = adaptive(SQPalette.card)
    static let ink = adaptive(SQPalette.ink)
    static let muted = adaptive(SQPalette.muted)
    static let line = adaptive(SQPalette.line)
    static let accent = adaptive(SQPalette.accent)
    static let mine = adaptive(SQPalette.mine)
    static let theirs = adaptive(SQPalette.theirs)
    static let online = adaptive(SQPalette.online)
    static let warning = adaptive(SQPalette.warning)
    static let danger = adaptive(SQPalette.danger)

    // MARK: Redesign tokens (dark-first)
    //
    // The chat-first shell renders in dark mode. Light values exist so a
    // preview or a future light theme still reads, but dark is the design.
    // Hex values live in `SQPalette`, where the contrast tests check them.

    /// Layer 0: the window behind everything.
    static let surface0 = adaptive(SQPalette.surface0)
    /// Layer 1: header bar and composer tray.
    static let surface1 = adaptive(SQPalette.surface1)
    /// Layer 2: cards and bubbles from other people.
    static let surface2 = adaptive(SQPalette.surface2)
    /// Layer 3: raised controls inside a card.
    static let surface3 = adaptive(SQPalette.surface3)
    /// Hairline between layers.
    static let hairline = adaptive(SQPalette.hairline)
    /// The one sharp accent: an electric mint used for live, ready, and primary actions.
    static let signal = adaptive(SQPalette.signal)
    /// Text drawn on top of `signal`.
    static let onSignal = adaptive(SQPalette.onSignal)
    /// Secondary text on dark surfaces.
    static let subtle = adaptive(SQPalette.subtle)

    static func role(_ role: Role) -> Color {
        switch role {
        case .owner: Color(red: 0.96, green: 0.76, blue: 0.36)
        case .admin: Color(red: 0.45, green: 0.82, blue: 0.98)
        case .member: Color(red: 0.62, green: 0.70, blue: 0.82)
        case .guest: Color(red: 0.78, green: 0.56, blue: 0.98)
        }
    }

    private static func adaptive(_ pair: SQPalette.Pair) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? ui(pair.dark) : ui(pair.light)
        })
    }

    private static func ui(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct SQCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(SQSpace.m)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SQColor.line.opacity(0.7), lineWidth: 1)
            )
    }
}

extension View {
    func sqCard() -> some View { modifier(SQCard()) }
}
