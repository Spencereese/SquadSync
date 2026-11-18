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
    /// Content-space frames of the tracked rows (near the top of the loaded thread
    /// while older pages can still come, and the hold's anchor) that are laid out
    /// now, from the latest report only: a row
    /// the lazy stack dropped is gone, so a stale position can't claim it's on
    /// screen. Content space doesn't change while the list scrolls, so reports
    /// come only when layout does. `reportGeneration` is the layout generation
    /// (older pages in) the report was measured in.
    private var rowFrames: [UUID: ChatRowFrame] = [:]
    private var reportGeneration = 0
    private var holdRecheckScheduled = false
    /// Rechecks since the hold was made; a hold whose anchor never reports again
    /// can't stay forever (it blocks the bottom pin).
    private var holdRechecks = 0
    private static let maxHoldRechecks = 30

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
        guard let frame = rowFrames[id], let metrics else { return nil }
        return frame.minY - metrics.offset
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
            // contentMargins and the keyboard can change the insets with no offset
            // or size change; a pinned list follows that too.
            view.observe(\.contentInset, options: [.old, .new]) { [weak self] view, change in
                guard change.oldValue != change.newValue else { return }
                MainActor.assumeIsolated { self?.repin(view, change: .viewport) }
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
        rowFrames = [:]
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
        rowFrames = [:]
    }

    /// The person tapped something that grows in place (reaction menu, locking the
    /// spot card): the list stays where it is, and stops following the bottom.
    func expanded() {
        pin.expanded()
    }

    /// The thread's last row is new or changed its send state: a pinned list
    /// follows the content growth from it until that layout is done.
    func endChanged() {
        pin.endChanged()
        // Two main-queue hops: past this update's layout pass and the one after
        // (the composer and header finish changing size). Then once more to the
        // bottom if still pinned, for anything that moved without a notification,
        // so a failed message's "Not delivered" and Retry end above the composer.
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pin.endSettled()
                self.settlePinnedEnd()
            }
        }
        scheduleTurnEnd()
    }

    private func settlePinnedEnd() {
        guard let view = scrollView, pin.pinned, hold == nil else { return }
        guard !(view.isTracking || view.isDragging || view.isDecelerating) else { return }
        let metrics = Self.metrics(of: view)
        if abs(metrics.maxOffset - metrics.offset) > 0.5 { set(view, offset: metrics.maxOffset) }
    }

    // MARK: Older pages

    /// Call right before older rows go into the thread. `oldest` is the current
    /// oldest message (the fallback anchor); `generation` is the layout generation
    /// the rows will be reported with once they're in. Returns where to scroll so
    /// the topmost fully visible row stays put, or nil when no tracked row is on
    /// screen (then the content-growth step and the fallback anchor hold it).
    func prepareForPrepend(oldest: UUID, generation: Int) -> ChatPrependRestore? {
        guard let view = scrollView else { return nil }
        let before = Self.metrics(of: view)
        // Stop the fling (and any bounce past the top) so the corrections below
        // aren't competing with momentum.
        let resting = before.clamped(before.offset)
        if view.isDecelerating || resting != before.offset {
            set(view, offset: resting)
        }
        let contentHeight = Double(view.contentSize.height)
        holdRechecks = 0
        if let restore = ChatPrependHold.visibleAnchor(frames: rowFrames, offset: resting, viewportHeight: before.viewportHeight) {
            hold = ChatPrependHold(
                anchor: restore.id,
                offsetBefore: resting,
                contentHeightBefore: contentHeight,
                anchorYBefore: restore.y,
                generation: generation,
                insertMovesOffset: false
            )
            return restore
        }
        hold = ChatPrependHold(
            anchor: oldest,
            offsetBefore: resting,
            contentHeightBefore: contentHeight,
            anchorYBefore: rowFrames[oldest].map { $0.minY - resting },
            generation: generation
        )
        return nil
    }

    /// The tracked rows' frames in content space, from the list's preference.
    func rowsMoved(_ report: ChatRowReport) {
        rowFrames = report.rows
        reportGeneration = report.generation
        guard let view = scrollView else { return }
        applyHold(view)
    }

    /// Step 2 of the hold: from a report measured in a layout that has the new
    /// rows and still contains the anchor, and the current offset. An in-place
    /// reading is checked again a run-loop turn later (after whatever layout it
    /// caused) before the hold ends.
    private func applyHold(_ view: UIScrollView) {
        guard var current = hold, current.insertApplied else { return }
        guard current.anchorYBefore != nil else {
            hold = nil
            return
        }
        guard reportGeneration >= current.generation, let frame = rowFrames[current.anchor] else { return }
        let metrics = Self.metrics(of: view)
        let target = current.offsetForAnchor(y: frame.minY - metrics.offset, measuredIn: reportGeneration, metrics: metrics)
        hold = current.settled ? nil : current
        if let target { set(view, offset: target) }
        if hold != nil { scheduleHoldRecheck() }
    }

    private func scheduleHoldRecheck() {
        guard !holdRecheckScheduled else { return }
        holdRechecks += 1
        guard holdRechecks <= Self.maxHoldRechecks else {
            hold = nil
            return
        }
        holdRecheckScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.holdRecheckScheduled = false
            if let view = self.scrollView { self.applyHold(view) }
        }
    }

    // MARK: Observers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began else { return }
        userHasScrolled = true
        hold = nil
        onUserDrag?()
    }

    private func geometryChanged(_ view: UIScrollView) {
        // The scroll back to the anchor (or a correction) moved the list: read the
        // anchor again a turn later, after the layout that move causes.
        if hold?.insertApplied == true { scheduleHoldRecheck() }
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
        // Only when the controller changed: walking up the view tree on every
        // update of the list showed up in profiles.
        guard view.controller !== controller else { return }
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
    var rows: [UUID: ChatRowFrame] = [:]
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
