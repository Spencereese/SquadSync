import UIKit

/// Haptic feedback for the shell. Every call is a no-op under XCTest, so
/// unit tests never touch the Taptic Engine and stay deterministic.
enum SQHaptics {
    enum Kind: Equatable {
        /// A light tap: opening a panel, toggling a pill.
        case tap
        /// Selection moved: Ready on or off.
        case selection
        /// Something finished: a message sent, a spot locked.
        case success
        /// Something was refused.
        case warning
    }

    /// False while a test bundle is loaded into the process.
    static var isEnabled: Bool {
        isEnabled(environment: ProcessInfo.processInfo.environment)
    }

    static func isEnabled(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
            && environment["XCTestBundlePath"] == nil
            && environment["XCTestSessionIdentifier"] == nil
    }

    /// Returns true when feedback was sent. Tests use the return value only.
    @MainActor
    @discardableResult
    static func play(_ kind: Kind) -> Bool {
        guard isEnabled else { return false }
        switch kind {
        case .tap:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .selection:
            UISelectionFeedbackGenerator().selectionChanged()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning:
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
        return true
    }
}
