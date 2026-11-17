import SwiftUI

// Motion (S5): subtle and purposeful. Every animation in the session screens goes
// through `MotionPolicy`, so Reduce Motion turns slides into fades and scrolls into jumps.

extension MotionPolicy {
    /// UI tests can't flip the system switch, so `-reduceMotion` stands in for it.
    static var launchOverride: Bool {
        ProcessInfo.processInfo.arguments.contains("-reduceMotion")
    }

    static func current(systemReduceMotion: Bool) -> MotionPolicy {
        resolve(systemReduceMotion: systemReduceMotion, launchOverride: launchOverride)
    }

    func animation(_ kind: Kind) -> Animation? {
        guard let seconds = duration(kind) else { return nil }
        return movesContent ? .smooth(duration: seconds) : .easeInOut(duration: seconds)
    }

    /// A new step slides in from the trailing edge with full motion, and only fades with reduced.
    var stepTransition: AnyTransition {
        movesContent
            ? .asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity)
            : .opacity
    }

    /// Error and status rows: a short drop-in with full motion, a fade with reduced.
    var appearTransition: AnyTransition {
        movesContent ? .move(edge: .top).combined(with: .opacity) : .opacity
    }
}

/// Runs `body` inside the policy's animation, or without one when the policy says so.
@MainActor
func withMotion(_ policy: MotionPolicy, _ kind: MotionPolicy.Kind, _ body: () -> Void) {
    if let animation = policy.animation(kind) {
        withAnimation(animation, body)
    } else {
        body()
    }
}
