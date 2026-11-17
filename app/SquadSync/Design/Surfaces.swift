import SwiftUI

/// Layered surfaces. Each level is a material with a tint and a hairline,
/// so content under the header and composer still reads through.
enum SQSurface {
    /// Header bar and composer tray: thin glass over the canvas.
    case bar
    /// Cards inside the chat.
    case card
    /// Raised controls such as pills.
    case raised

    var material: Material {
        switch self {
        case .bar: .ultraThinMaterial
        case .card: .regularMaterial
        case .raised: .thickMaterial
        }
    }

    var tint: Color {
        switch self {
        case .bar: SQColor.surface1.opacity(0.72)
        case .card: SQColor.surface2.opacity(0.78)
        case .raised: SQColor.surface3.opacity(0.85)
        }
    }
}

struct SQSurfaceBackground: ViewModifier {
    let level: SQSurface
    var radius: CGFloat = SQRadius.l

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                shape
                    .fill(level.material)
                    .overlay(shape.fill(level.tint))
            }
            .overlay(shape.stroke(SQColor.hairline, lineWidth: 1))
    }
}

extension View {
    /// Material surface with a tint and a hairline stroke.
    func sqSurface(_ level: SQSurface, radius: CGFloat = SQRadius.l) -> some View {
        modifier(SQSurfaceBackground(level: level, radius: radius))
    }
}
