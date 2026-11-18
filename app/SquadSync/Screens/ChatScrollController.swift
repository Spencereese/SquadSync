import SwiftUI
import UIKit

/// The message list's UIScrollView, for what SwiftUI can't do exactly on iOS 17:
/// read the real scroll geometry on every change, stop a fling, and move the
/// offset by an exact amount inside the layout pass that inserted rows.
///
/// The decisions themselves are Foundation types (`ChatOlderTrigger`,
/// `ChatPrependHold`, `ChatViewportStick`, `ChatBottomPin`) with unit tests; this class only feeds
/// them numbers and applies the offsets they return. If the scroll view is never
/// found, every method is a no-op and the list behaves like a plain ScrollView.
@MainActor
final class ChatScrollController: NSObject {
    private weak var scrollView: UIScrollView?
    private var observations: [NSKeyValueObservation] = []
    private var hold: ChatPrependHold?
    /// Whether the reader is staying at the newest message.
    private var pin = ChatBottomPin()
    private var turnEndScheduled = false
    /// Content-space y of every message row that's laid out now, from the latest
    /// report only (rows the lazy stack dropped are gone, so a stale position
    /// can't claim a row is on screen), and the layout generation it came from.
    private var rowContentY: [UUID: Double] = [:]
    private var reportGeneration = 0
    /// A failed row whose top must be in view once it's laid out.
    private var revealTopOf: UUID?

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

    /// On-screen tops of all laid-out rows at the current offset.
    private func liveScreenY(offset: Double) -> [UUID: Double] {
        rowContentY.mapValues { $0 - offset }
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
        pin.reset()
        rowContentY = [:]
        revealTopOf = nil
    }

    /// Before the person's own scroll (jump to a message, to the latest) so a hold
    /// doesn't pull the list back.
    func endHold() {
        hold = nil
    }

    /// Call right before the app scrolls the list itself: to the newest message
    /// (`toBottom`, pins) or anywhere else (unpins, so it isn't pulled back down).
    func jumped(toBottom: Bool) {
        pin.jumped(toBottom: toBottom)
        // The app moved the list on purpose; there's no place left to hold.
        hold = nil
        // Positions from before a jump say nothing about where rows are after it;
        // the next report fills them in again.
        rowContentY = [:]
        if !toBottom { revealTopOf = nil }
    }

    /// The person tapped something that grows in place (reaction menu, locking the
    /// spot card): the list stays where it is, and stops following the bottom.
    func expanded() {
        pin.expanded()
        revealTopOf = nil
    }

    /// The thread's last row is new or changed its send state: a pinned list
    /// follows the content growth from it until that layout is done.
    func endChanged(failedRow: UUID? = nil) {
        pin.endChanged()
        if let failedRow, pin.pinned { revealTopOf = failedRow }
        // Two main-queue hops: past this update's layout pass and the one after.
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async { self?.pin.endSettled() }
        }
        scheduleTurnEnd()
    }

    // MARK: Older pages

    /// Call right before older rows go into the thread. `generation` is the layout
    /// generation the rows will be reported with once they're in.
    func prepareForPrepend(generation: Int) {
        guard let view = scrollView else { return }
        let before = Self.metrics(of: view)
        // Stop the fling (and any bounce past the top) so the corrections below
        // aren't competing with momentum.
        let resting = before.clamped(before.offset)
        if view.isDecelerating || resting != before.offset {
            set(view, offset: resting)
        }
        // Hold what the reader is looking at: the topmost row on screen, at its
        // live position. Not the oldest loaded row, which can be far off screen.
        let anchor = ChatPrependHold.anchorRow(screenY: liveScreenY(offset: resting), viewportHeight: before.viewportHeight)
        hold = ChatPrependHold(
            anchor: anchor?.id ?? UUID(),
            offsetBefore: resting,
            contentHeightBefore: Double(view.contentSize.height),
            anchorYBefore: anchor?.y,
            generation: generation
        )
    }

    /// Every laid-out message row's top in content space, from the list's preference.
    func rowsMoved(_ report: ChatRowReport) {
        rowContentY = report.rows.mapValues { Double($0) }
        reportGeneration = report.generation
        guard let view = scrollView else { return }
        applyHold(view)
        revealFailedTop(view)
    }

    /// Step 2 of the hold, from the anchor's stored content position and the
    /// current offset, only once a report from a layout with the new rows is in.
    private func applyHold(_ view: UIScrollView) {
        guard var current = hold, current.insertApplied else { return }
        guard let contentY = rowContentY[current.anchor] else {
            if current.anchorYBefore == nil { hold = nil }
            return
        }
        let metrics = Self.metrics(of: view)
        let target = current.offsetForAnchor(y: contentY - metrics.offset, measuredIn: reportGeneration, metrics: metrics)
        hold = current.settled ? nil : current
        if let target { set(view, offset: target) }
    }

    private func revealFailedTop(_ view: UIScrollView) {
        guard let id = revealTopOf, hold == nil, let contentY = rowContentY[id] else { return }
        let metrics = Self.metrics(of: view)
        revealTopOf = nil
        guard let target = ChatBottomPin.offsetRevealingTop(rowY: contentY - metrics.offset, metrics: metrics) else { return }
        // The row is taller than the list: show its top and stop following the bottom.
        pin.jumped(toBottom: false)
        set(view, offset: target)
    }

    // MARK: Observers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began else { return }
        userHasScrolled = true
        hold = nil
        revealTopOf = nil
        onUserDrag?()
    }

    private func geometryChanged(_ view: UIScrollView) {
        repin(view, change: .offset)
        onGeometry?(Self.metrics(of: view))
    }

    /// Back to the bottom for the changes a pinned list follows (see ChatBottomPin).
    /// The person's drags and flings decide whether it's pinned.
    private func repin(_ view: UIScrollView, change: ChatBottomPin.Change) {
        let interacting = view.isTracking || view.isDragging || view.isDecelerating
        if let target = pin.observe(Self.metrics(of: view), change: change, interacting: interacting, holding: hold != nil) {
            set(view, offset: target)
            scheduleTurnEnd()
        }
    }

    private func scheduleTurnEnd() {
        guard !turnEndScheduled else { return }
        turnEndScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.turnEndScheduled = false
            self?.pin.turnEnded()
        }
    }

    private func contentSizeChanged(_ view: UIScrollView) {
        if var current = hold, let target = current.offsetForInsert(Self.metrics(of: view)) {
            hold = current.settled ? nil : current
            set(view, offset: target)
        }
        repin(view, change: .content)
        applyHold(view)
        onGeometry?(Self.metrics(of: view))
    }

    private func viewportChanged(_ view: UIScrollView, oldHeight: Double) {
        let after = Self.metrics(of: view)
        var before = after
        before.viewportHeight = oldHeight
        if let target = ChatViewportStick.offset(before: before, after: after) {
            set(view, offset: target)
        }
        repin(view, change: .viewport)
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

/// Content-space tops of the laid-out message rows, and the layout generation
/// (older pages that had gone in) they were measured in.
struct ChatRowReport: Equatable {
    var rows: [UUID: CGFloat] = [:]
    var generation = 0
}

struct ChatRowYKey: PreferenceKey {
    static let defaultValue = ChatRowReport()
    static func reduce(value: inout ChatRowReport, nextValue: () -> ChatRowReport) {
        let next = nextValue()
        value.rows.merge(next.rows, uniquingKeysWith: { _, new in new })
        value.generation = max(value.generation, next.generation)
    }
}
