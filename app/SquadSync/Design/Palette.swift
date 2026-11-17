import Foundation

/// The color tokens as hex, light and dark. `SQColor` draws from these, and the
/// contrast tests check them, so a token can't drift below WCAG AA unnoticed.
///
/// The session screen runs in dark mode (it's the design). The light values still
/// pass, so a light preview or a future light theme reads.
enum SQPalette {
    struct Pair: Equatable {
        let light: UInt32
        let dark: UInt32
    }

    static let canvas = Pair(light: 0xF4F6FB, dark: 0x07090F)
    static let card = Pair(light: 0xFFFFFF, dark: 0x121722)
    static let ink = Pair(light: 0x10141C, dark: 0xF2F5FB)
    static let muted = Pair(light: 0x5C677A, dark: 0x9AA6BD)
    static let line = Pair(light: 0xD7DEEA, dark: 0x243044)
    // S5: light accent darkened from 0x2F6BFF (3.97:1 on surface2) to pass 4.5:1.
    static let accent = Pair(light: 0x1F55CC, dark: 0x7AA2FF)
    // S5: from 0x2F6BFF / 0x3D7EFF; white text on them was 4.49:1 and 3.4:1.
    static let mine = Pair(light: 0x2B66F5, dark: 0x2C62D6)
    static let theirs = Pair(light: 0xE7ECF5, dark: 0x1C2433)
    // S5: status colors get light values that pass as text; dark is unchanged.
    static let online = Pair(light: 0x0E7240, dark: 0x3DDB8C)
    static let warning = Pair(light: 0x8A5300, dark: 0xFFB847)
    static let danger = Pair(light: 0xB8202F, dark: 0xFF616B)

    static let surface0 = Pair(light: 0xF2F4F8, dark: 0x05070B)
    static let surface1 = Pair(light: 0xFFFFFF, dark: 0x0C1018)
    static let surface2 = Pair(light: 0xEEF1F6, dark: 0x141A25)
    static let surface3 = Pair(light: 0xE2E7EF, dark: 0x1D2533)
    static let hairline = Pair(light: 0xD5DCE7, dark: 0x232C3B)
    // S5: light signal from 0x00A884 (2.7:1 as text) to 0x00755B.
    static let signal = Pair(light: 0x00755B, dark: 0x2BF0C4)
    static let onSignal = Pair(light: 0xFFFFFF, dark: 0x02130E)
    // S5: subtle from 0x6A7487 / 0x7D889C; both fell under 4.5:1 on surface3.
    static let subtle = Pair(light: 0x56606F, dark: 0x8A95A8)

    /// Tokens drawn as text, and the surfaces they sit on.
    static let textTokens: [(String, Pair)] = [
        ("ink", ink), ("muted", muted), ("subtle", subtle), ("accent", accent),
        ("signal", signal), ("online", online), ("warning", warning), ("danger", danger)
    ]
    static let surfaces: [(String, Pair)] = [
        ("surface0", surface0), ("surface1", surface1), ("surface2", surface2),
        ("surface3", surface3), ("card", card), ("canvas", canvas)
    ]
}

/// WCAG 2 contrast.
enum Contrast {
    /// Normal-size text needs 4.5:1 (AA).
    static let text = 4.5

    static func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }

    static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
