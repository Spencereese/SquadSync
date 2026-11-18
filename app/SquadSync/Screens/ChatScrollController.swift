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
    /// now. Each row reports itself (`rowMoved`) and leaves when the lazy stack
    /// drops it (`rowGone`), so a stale position can't claim it's on screen.
    /// Content space doesn't change while the list scrolls, so reports come only
    /// when layout does. `rowGenerations` is the layout generation (older pages
    /// in) each was measured in.
    private var rowFrames: [UUID: ChatRowFrame] = [:]
    private var rowGenerations: [UUID: Int] = [:]
    /// The thread's last row when it's your message that failed to send, and its
    /// frame in the list's visible coordinates (0 is the list's top edge), so its
    /// "Not delivered" and Retry can be kept inside the list (`fitFailedRow`).
    private var failedRow: UUID?
    private var failedFrame: ChatRowFrame?
    private var failedFits = 0
    private static let maxFailedFitsPerTurn = 2
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
                MainActor.assumeIsolated { self?.insetsChanged(view) }
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
        rowGenerations = [:]
        failedRow = nil
        failedFrame = nil
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
        // Content-space positions stay true across a jump (rows the jump takes out
        // of the laid-out range remove themselves), so they're kept.
        if !toBottom { failedRow = nil }
    }

    /// The person tapped something that grows in place (reaction menu, locking the
    /// spot card): the list stays where it is, and stops following the bottom.
    func expanded() {
        pin.expanded()
        failedRow = nil
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
        fitFailedRow(view)
    }

    // MARK: Failed send

    /// The thread's last row is your message that failed (nil: it isn't). While
    /// set, its measured frame keeps "Not delivered" and Retry inside the list
    /// once the composer and header have settled, instead of trusting that "the
    /// bottom" puts them there.
    func watchFailedRow(_ id: UUID?) {
        guard failedRow != id else { return }
        failedRow = id
        failedFrame = nil
    }

    /// The failed row's frame in the list's visible coordinates, on every change.
    func failedRowMoved(_ id: UUID, frame: ChatRowFrame) {
        guard id == failedRow else { return }
        failedFrame = frame
        guard let view = scrollView, !pin.endPending else { return }
        fitFailedRow(view)
    }

    /// Moves the list by exactly what the failed row sticks out (bottom first:
    /// Retry and "Not delivered" are its last lines). Only for a pinned list the
    /// person isn't moving, never during a hold, at most twice a run-loop turn.
    /// After a move the measured frame is stale until the row reports again.
    private func fitFailedRow(_ view: UIScrollView) {
        guard failedRow != nil, let frame = failedFrame, pin.pinned, hold == nil else { return }
        guard !(view.isTracking || view.isDragging || view.isDecelerating) else { return }
        guard failedFits < Self.maxFailedFitsPerTurn else { return }
        let metrics = Self.metrics(of: view)
        guard let target = ChatRowFit.offset(rowTop: frame.minY, rowBottom: frame.minY + frame.height, metrics: metrics) else { return }
        failedFits += 1
        failedFrame = nil
        set(view, offset: target)
        scheduleTurnEnd()
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
        // Only rows measured in the current layout can anchor the hold.
        let frames = rowFrames.filter { rowGenerations[$0.key] == generation - 1 }
        if let restore = ChatPrependHold.visibleAnchor(frames: frames, offset: resting, viewportHeight: before.viewportHeight) {
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
            anchorYBefore: frames[oldest].map { $0.minY - resting },
            generation: generation
        )
        return nil
    }

    /// A tracked row's content-space frame, from that row, whenever it changes
    /// (and once when it's laid out). No SwiftUI state is written here.
    func rowMoved(_ id: UUID, frame: ChatRowFrame, generation: Int) {
        rowFrames[id] = frame
        rowGenerations[id] = generation
        guard id == hold?.anchor, let view = scrollView else { return }
        applyHold(view, confirming: false)
    }

    /// The lazy stack dropped a tracked row: its position no longer says anything.
    func rowGone(_ id: UUID) {
        rowFrames[id] = nil
        rowGenerations[id] = nil
    }

    /// Step 2 of the hold: from the anchor's position measured in a layout that
    /// has the new rows, and the current offset. Drift is corrected exactly
    /// whenever it's read; the hold ends only on confirming readings, each a
    /// run-loop turn after the last (after whatever layout the previous one, or
    /// the scroll to the anchor, caused).
    private func applyHold(_ view: UIScrollView, confirming: Bool) {
        guard var current = hold, current.insertApplied else { return }
        guard current.anchorYBefore != nil else {
            hold = nil
            return
        }
        guard let frame = rowFrames[current.anchor], let measuredIn = rowGenerations[current.anchor],
              measuredIn >= current.generation else { return }
        let metrics = Self.metrics(of: view)
        let target = current.offsetForAnchor(y: frame.minY - metrics.offset, measuredIn: measuredIn, metrics: metrics, confirming: confirming)
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
            if let view = self.scrollView { self.applyHold(view, confirming: true) }
        }
    }

    // MARK: Observers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began else { return }
        userHasScrolled = true
        hold = nil
        failedRow = nil
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
            self?.failedFits = 0
            self?.pin.turnEnded()
        }
    }

    private func contentSizeChanged(_ view: UIScrollView) {
        if var current = hold, let target = current.offsetForInsert(Self.metrics(of: view)) {
            hold = current.settled ? nil : current
            set(view, offset: target)
        }
        repin(view, change: .content)
        applyHold(view, confirming: false)
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
        if !pin.endPending { fitFailedRow(view) }
    }

    private func insetsChanged(_ view: UIScrollView) {
        repin(view, change: .viewport)
        if !pin.endPending { fitFailedRow(view) }
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
