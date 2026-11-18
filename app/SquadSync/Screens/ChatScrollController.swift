import SwiftUI
import UIKit

/// The message list's UIScrollView, for what SwiftUI can't do exactly on iOS 17:
/// read the real scroll geometry on every change, stop a fling, and move the
/// offset by an exact amount inside the layout pass that inserted rows.
///
/// The decisions themselves are Foundation types (`ChatOlderTrigger`,
/// `ChatPrependHold`, `ChatViewportStick`) with unit tests; this class only feeds
/// them numbers and applies the offsets they return. If the scroll view is never
/// found, every method is a no-op and the list behaves like a plain ScrollView.
@MainActor
final class ChatScrollController: NSObject {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var hold: ChatPrependHold?
    /// Content-space y of the rows the list reports (the oldest message and the
    /// hold's anchor), so a stale report can't claim a row is on screen.
    private var rowContentY: [UUID: Double] = [:]

    /// The person has dragged the list since this squad loaded.
    private(set) var userHasScrolled = false
    /// A load the controller asked for hasn't come back yet.
    var requestInFlight = false
    /// Fresh geometry after every offset or content-size change.
    var onGeometry: ((ChatScrollMetrics) -> Void)?
    /// The person started dragging the list.
    var onUserDrag: (() -> Void)?

    /// A page was handed to the list and its rows aren't laid out yet.
    var isSettlingPrepend: Bool {
        guard let hold else { return false }
        return !hold.insertApplied
    }

    var metrics: ChatScrollMetrics? {
        scrollView.map(Self.metrics(of:))
    }

    /// On-screen y of a reported row, from its content position and the current offset.
    func screenY(of id: UUID) -> Double? {
        guard let contentY = rowContentY[id], let metrics else { return nil }
        return contentY - metrics.offset
    }

    // MARK: Wiring

    func attach(_ view: UIScrollView) {
        guard view !== scrollView else { return }
        observations = []
        scrollView?.panGestureRecognizer.removeTarget(self, action: #selector(handlePan(_:)))
        scrollView = view
        view.panGestureRecognizer.addTarget(self, action: #selector(handlePan(_:)))
        observations = [
            view.observe(\.contentOffset, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.geometryChanged(view) }
            },
            view.observe(\.contentSize, options: [.new]) { [weak self] view, _ in
                MainActor.assumeIsolated { self?.contentSizeChanged(view) }
            },
            view.layer.observe(\.bounds, options: [.old, .new]) { [weak self, weak view] _, change in
                guard let old = change.oldValue, let new = change.newValue, old.size.height != new.size.height else { return }
                MainActor.assumeIsolated {
                    guard let view else { return }
                    self?.viewportChanged(view, oldHeight: Double(old.size.height))
                }
            }
        ]
    }

    /// A different squad: start over.
    func reset() {
        userHasScrolled = false
        requestInFlight = false
        hold = nil
        rowContentY = [:]
    }

    /// Before the person's own scroll (jump to a message, to the latest) so a hold
    /// doesn't pull the list back.
    func endHold() {
        hold = nil
    }

    // MARK: Older pages

    /// Call right before older rows go into the thread.
    func prepareForPrepend(anchor: UUID) {
        guard let view = scrollView else { return }
        let before = Self.metrics(of: view)
        // Stop the fling (and any bounce past the top) so the corrections below
        // aren't competing with momentum.
        let resting = before.clamped(before.offset)
        if view.isDecelerating || resting != before.offset {
            set(view, offset: resting)
        }
        let anchorY = rowContentY[anchor].map { $0 - resting }
        hold = ChatPrependHold(
            anchor: anchor,
            offsetBefore: resting,
            contentHeightBefore: Double(view.contentSize.height),
            anchorYBefore: anchorY
        )
    }

    /// The tracked rows' current on-screen tops, from the list's preference.
    func rowsMoved(_ screenY: [UUID: CGFloat]) {
        guard let view = scrollView else { return }
        let offset = Double(view.contentOffset.y)
        for (id, y) in screenY { rowContentY[id] = Double(y) + offset }
        guard var current = hold, let y = screenY[current.anchor] else { return }
        let target = current.offsetForAnchor(y: Double(y), metrics: Self.metrics(of: view))
        hold = current.settled ? nil : current
        if let target { set(view, offset: target) }
    }

    // MARK: Observers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began else { return }
        userHasScrolled = true
        hold = nil
        onUserDrag?()
    }

    private func geometryChanged(_ view: UIScrollView) {
        onGeometry?(Self.metrics(of: view))
    }

    private func contentSizeChanged(_ view: UIScrollView) {
        if var current = hold, let target = current.offsetForInsert(Self.metrics(of: view)) {
            hold = current.settled ? nil : current
            set(view, offset: target)
        }
        geometryChanged(view)
    }

    private func viewportChanged(_ view: UIScrollView, oldHeight: Double) {
        let after = Self.metrics(of: view)
        var before = after
        before.viewportHeight = oldHeight
        if let target = ChatViewportStick.offset(before: before, after: after) {
            set(view, offset: target)
        }
    }

    private func set(_ view: UIScrollView, offset: Double) {
        guard abs(Double(view.contentOffset.y) - offset) > 0.01 || view.isDecelerating else { return }
        view.setContentOffset(CGPoint(x: view.contentOffset.x, y: offset), animated: false)
    }

    private static func metrics(of view: UIScrollView) -> ChatScrollMetrics {
        ChatScrollMetrics(
            offset: Double(view.contentOffset.y),
            topInset: Double(view.adjustedContentInset.top),
            bottomInset: Double(view.adjustedContentInset.bottom),
            contentHeight: Double(view.contentSize.height),
            viewportHeight: Double(view.bounds.height)
        )
    }
}

/// A zero-size view inside the list's content that finds the enclosing
/// UIScrollView and hands it to the controller.
struct ChatScrollBridge: UIViewRepresentable {
    let controller: ChatScrollController

    func makeUIView(context: Context) -> Finder {
        let view = Finder()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.accessibilityElementsHidden = true
        view.controller = controller
        return view
    }

    func updateUIView(_ view: Finder, context: Context) {
        view.controller = controller
        view.attach()
    }

    final class Finder: UIView {
        weak var controller: ChatScrollController?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        func attach() {
            var next = superview
            while let view = next {
                if let scroll = view as? UIScrollView {
                    controller?.attach(scroll)
                    return
                }
                next = view.superview
            }
        }
    }
}

/// On-screen tops of the rows the scroll controller tracks.
struct ChatRowYKey: PreferenceKey {
    static let defaultValue: [UUID: CGFloat] = [:]
    static func reduce(value: inout [UUID: CGFloat], nextValue: () -> [UUID: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}
