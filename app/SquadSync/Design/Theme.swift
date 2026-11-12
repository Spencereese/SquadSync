import SwiftUI

enum SQSpace {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum SQColor {
    static let canvas = adaptive(light: 0xF4F6FB, dark: 0x07090F)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x121722)
    static let ink = adaptive(light: 0x10141C, dark: 0xF2F5FB)
    static let muted = adaptive(light: 0x5C677A, dark: 0x9AA6BD)
    static let line = adaptive(light: 0xD7DEEA, dark: 0x243044)
    static let accent = adaptive(light: 0x2F6BFF, dark: 0x7AA2FF)
    static let mine = adaptive(light: 0x2F6BFF, dark: 0x3D7EFF)
    static let theirs = adaptive(light: 0xE7ECF5, dark: 0x1C2433)
    static let online = Color(red: 0.24, green: 0.86, blue: 0.55)
    static let warning = Color(red: 1.0, green: 0.72, blue: 0.28)
    static let danger = Color(red: 1.0, green: 0.38, blue: 0.42)

    static func role(_ role: Role) -> Color {
        switch role {
        case .owner: Color(red: 0.96, green: 0.76, blue: 0.36)
        case .admin: Color(red: 0.45, green: 0.82, blue: 0.98)
        case .member: Color(red: 0.62, green: 0.70, blue: 0.82)
        case .guest: Color(red: 0.78, green: 0.56, blue: 0.98)
        }
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? ui(dark) : ui(light)
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
