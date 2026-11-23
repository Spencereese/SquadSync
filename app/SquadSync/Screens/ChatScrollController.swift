import SwiftUI
import UIKit
import os

/// The message list's UIScrollView, for what SwiftUI can't do exactly on iOS 17:
/// read the real scroll geometry on every change, stop a fling, and move the
/// offset by an exact amount inside the layout pass that inserted rows.
///
/// The decisions themselves are Foundation types (`ChatOlderTrigger`,
/// `ChatPrependHold`, `ChatViewportStick`, `ChatBottomPin`, `ChatTrackedRows`,
/// `ChatFailedFit`) with unit tests; this class only feeds them numbers and
/// applies the offsets they return. If the scroll view is never found, every
/// method is a no-op and the list behaves like a plain ScrollView.
///
/// DEBUG builds count what it does per second (`ChatScrollTrace`, Logger
/// subsystem com.spencereese.squadsync, category chat-scroll).
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
    /// now, stamped with the layout generation they were reported in.
    private var rows = ChatTrackedRows()
    /// The thread's last row when it's your message that failed to send, and its
    /// frame in content coordinates (see `ChatFailedFit`), so its "Not delivered"
    /// and Retry can be kept inside the list.
    private var failedRow: UUID?
    private var failedContentTop: Double?
    private var failedHeight: Double?
    private var failedFits = 0
    private static let maxFailedFitsPerTurn = 2
    /// Fixed checks (seconds) after the send fails and after every keyboard,
    /// header or composer change while the failed row is last: the fit doesn't
    /// depend on which layout pass happened to report last.
    private static let failedFitChecks: [Double] = [0.05, 0.15, 0.3, 0.5, 0.8, 1.2, 1.8]
    private var failedFitSeries = 0
    private var lastFitNote: String?
    private var holdRecheckScheduled = false
    /// Rechecks since the hold was made; a hold whose anchor never reports again
    /// can't stay forever (it blocks the bottom pin).
    private var holdRechecks = 0
    private static let maxHoldRechecks = 60

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
        guard let frame = rows.frames[id], let metrics else { return nil }
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
                #if DEBUG
                HangProbe.mark(.offsetKVO)
                #endif
                MainActor.assumeIsolated { self?.geometryChanged(view) }
            },
            view.observe(\.contentSize, options: [.new]) { [weak self] view, _ in
                #if DEBUG
                HangProbe.mark(.sizeKVO)
                #endif
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
                #if DEBUG
                HangProbe.mark(.viewportKVO)
                #endif
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
        endHold("reset")
        pin.reset()
        rows.reset()
        stopWatchingFailedRow()
    }

    /// Before the person's own scroll (jump to a message, to the latest) so a hold
    /// doesn't pull the list back.
    func endHold() {
        endHold("app scroll")
    }

    private func endHold(_ why: String) {
        guard let current = hold else { return }
        ChatScrollTrace.hold("ended (\(why)) anchor=\(ChatScrollTrace.short(current.anchor)) corrections=\(current.corrections)")
        hold = nil
    }

    /// Call right before the app scrolls the list itself: to the newest message
    /// (`toBottom`, pins) or anywhere else (unpins, so it isn't pulled back down).
    func jumped(toBottom: Bool) {
        pin.jumped(toBottom: toBottom)
        // The app moved the list on purpose; there's no place left to hold.
        endHold("jump")
        // Content-space positions stay true across a jump (rows the jump takes out
        // of the laid-out range remove themselves), so they're kept.
        if !toBottom { stopWatchingFailedRow() }
    }

    /// The person tapped something that grows in place (reaction menu, locking the
    /// spot card): the list stays where it is, and stops following the bottom.
    func expanded() {
        pin.expanded()
        stopWatchingFailedRow()
    }

    /// The thread's last row is new or changed its send state: a pinned list
    /// follows the content growth from it until that layout is done.
    func endChanged() {
        pin.endChanged()
        // Two main-queue hops: past this update's layout pass and the one after
        // (the composer and header finish changing size). Then once more to the
        // bottom if still pinned, for anything that moved without a notification.
        // A failed last row then gets its fixed fit checks.
        DispatchQueue.main.async { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                self.pin.endSettled()
                self.settlePinnedEnd()
                if self.failedRow != nil { self.armFailedFit("end settled") }
            }
        }
        scheduleTurnEnd()
    }

    private func settlePinnedEnd() {
        guard let view = scrollView, pin.pinned, hold == nil else { return }
        guard !(view.isTracking || view.isDragging || view.isDecelerating) else { return }
        let metrics = Self.metrics(of: view)
        if abs(metrics.maxOffset - metrics.offset) > 0.5 {
            ChatScrollTrace.count(.pinCorrection)
            set(view, offset: metrics.maxOffset)
        }
        fitFailedRow(view, why: "end settled")
    }

    // MARK: Failed send

    /// The thread's last row is your message that failed (nil: it isn't). While
    /// set, "Not delivered" and Retry are kept inside the list: from the row's
    /// measured frame when there is one, else by going to the bottom.
    func watchFailedRow(_ id: UUID?) {
        guard failedRow != id else { return }
        guard let id else {
            stopWatchingFailedRow()
            return
        }
        failedRow = id
        failedContentTop = nil
        failedHeight = nil
        lastFitNote = nil
        armFailedFit("send failed")
    }

    private func stopWatchingFailedRow() {
        failedRow = nil
        failedContentTop = nil
        failedHeight = nil
        // Cancels the scheduled checks.
        failedFitSeries += 1
    }

    /// The failed row's frame in the list's visible coordinates (0 is the list's
    /// top edge), on every change. Kept in content coordinates, so the list's own
    /// moves don't make it stale.
    func failedRowMoved(_ id: UUID, frame: ChatRowFrame) {
        ChatScrollTrace.count(.rowGeometry)
        guard id == failedRow, let view = scrollView else { return }
        guard frame.height > 0 else { return }
        failedContentTop = frame.minY + Double(view.contentOffset.y)
        failedHeight = frame.height
        guard !pin.endPending else { return }
        fitFailedRow(view, why: "row moved")
    }

    /// The fixed checks: each a separate turn, each a no-op once the row fits.
    private func armFailedFit(_ why: String) {
        failedFitSeries += 1
        let series = failedFitSeries
        for (index, delay) in Self.failedFitChecks.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, series == self.failedFitSeries, let view = self.scrollView else { return }
                self.failedFits = 0
                self.fitFailedRow(view, why: "check \(index + 1) after \(why)")
            }
        }
    }

    /// Moves the list so the failed row's last lines are inside it (`ChatFailedFit`).
    /// Only for a pinned list the person isn't moving, never during a hold, at
    /// most twice a run-loop turn. Every skip says why (DEBUG log).
    private func fitFailedRow(_ view: UIScrollView, why: String) {
        guard failedRow != nil else { return }
        guard pin.pinned else { return noteFit("skip: not pinned", why) }
        guard hold == nil else { return noteFit("skip: older-page hold", why) }
        guard !(view.isTracking || view.isDragging || view.isDecelerating) else { return noteFit("skip: person scrolling", why) }
        guard failedFits < Self.maxFailedFitsPerTurn else { return noteFit("skip: turn budget", why) }
        let metrics = Self.metrics(of: view)
        let decision = ChatFailedFit.decide(contentTop: failedContentTop, height: failedHeight, metrics: metrics)
        let rowBottom = failedContentTop.flatMap { top in failedHeight.map { top + $0 - metrics.offset } }
        let detail = "offset=\(ChatScrollTrace.pt(metrics.offset)) max=\(ChatScrollTrace.pt(metrics.maxOffset)) "
            + "rowBottom=\(rowBottom.map(ChatScrollTrace.pt) ?? "unknown") visibleBottom=\(ChatScrollTrace.pt(metrics.viewportHeight - metrics.bottomInset))"
        guard let target = decision.offset else {
            return noteFit(decision.reason.rawValue, why, detail)
        }
        failedFits += 1
        ChatScrollTrace.count(.fit)
        noteFit("move \(decision.reason.rawValue)", why, "\(detail) -> \(ChatScrollTrace.pt(target))", always: true)
        set(view, offset: target)
        scheduleTurnEnd()
    }

    /// Logs a fit outcome when it differs from the last one (moves always), with
    /// what asked for it.
    private func noteFit(_ outcome: String, _ why: String, _ detail: String = "", always: Bool = false) {
        guard always || outcome != lastFitNote else { return }
        lastFitNote = outcome
        ChatScrollTrace.event("fit \(outcome) [\(why)] \(detail)")
    }

    // MARK: Older pages

    /// Call right before older rows go into the thread. `oldest` is the current
    /// oldest message (the fallback anchor); `generation` is the layout generation
    /// the rows will be reported in once they're in. Returns where to scroll so
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
        // Rows measured in the layout before this page (the current one).
        let frames = rows.framesMeasured(since: generation - 1)
        // From here on, every report is from a layout that has the page.
        rows.begin(generation: generation)
        if let restore = ChatPrependHold.visibleAnchor(frames: frames, offset: resting, viewportHeight: before.viewportHeight, topInset: before.topInset, bottomInset: before.bottomInset) {
            hold = ChatPrependHold(
                anchor: restore.id,
                offsetBefore: resting,
                contentHeightBefore: contentHeight,
                anchorYBefore: restore.y,
                generation: generation,
                insertMovesOffset: false
            )
            ChatScrollTrace.hold("start gen=\(generation) anchor=\(ChatScrollTrace.short(restore.id)) visible y=\(ChatScrollTrace.pt(restore.y)) unitY=\(ChatScrollTrace.pt(restore.unitY)) insets=\(ChatScrollTrace.pt(before.topInset))/\(ChatScrollTrace.pt(before.bottomInset)) tracked=\(frames.count)")
            return restore
        }
        let fallbackY = frames[oldest].map { $0.minY - resting }
        hold = ChatPrependHold(
            anchor: oldest,
            offsetBefore: resting,
            contentHeightBefore: contentHeight,
            anchorYBefore: fallbackY,
            generation: generation
        )
        ChatScrollTrace.hold("start gen=\(generation) FALLBACK oldest=\(ChatScrollTrace.short(oldest)) y=\(fallbackY.map(ChatScrollTrace.pt) ?? "not laid out") tracked=\(frames.count) (no tracked row whole on screen)")
        return nil
    }

    /// A tracked row's content-space frame, from that row, whenever it changes
    /// (and once when it's laid out). No SwiftUI state is written here.
    func rowMoved(_ id: UUID, frame: ChatRowFrame) {
        ChatScrollTrace.count(.rowGeometry)
        rows.moved(id, frame: frame)
        guard id == hold?.anchor, let view = scrollView else { return }
        applyHold(view, confirming: false)
    }

    /// The lazy stack dropped a tracked row: its position no longer says anything,
    /// except the hold's anchor, which keeps its last reading until it reports again.
    func rowGone(_ id: UUID) {
        if !rows.gone(id, holdAnchor: hold?.anchor) {
            ChatScrollTrace.hold("anchor \(ChatScrollTrace.short(id)) left the layout; reading kept")
        }
    }

    /// Step 2 of the hold: from the anchor's position measured in a layout that
    /// has the new rows, and the current offset. Drift is corrected exactly
    /// whenever it's read; the hold ends only on confirming readings, each a
    /// run-loop turn after the last (after whatever layout the previous one, or
    /// the scroll to the anchor, caused).
    private func applyHold(_ view: UIScrollView, confirming: Bool) {
        guard var current = hold, current.insertApplied else { return }
        guard let before = current.anchorYBefore else {
            ChatScrollTrace.hold("ended (no anchor reading; step 1 only)")
            hold = nil
            return
        }
        guard let measured = rows.measured(current.anchor), measured.generation >= current.generation else { return }
        let metrics = Self.metrics(of: view)
        let y = measured.frame.minY - metrics.offset
        let target = current.offsetForAnchor(y: y, measuredIn: measured.generation, metrics: metrics, confirming: confirming, now: CACurrentMediaTime())
        ChatScrollTrace.count(.holdDecision)
        if let target {
            ChatScrollTrace.hold("correct anchor=\(ChatScrollTrace.short(current.anchor)) pre=\(ChatScrollTrace.pt(before)) post=\(ChatScrollTrace.pt(y)) dy=\(ChatScrollTrace.pt(y - before)) -> \(ChatScrollTrace.pt(target))")
        }
        if current.settled {
            let why = current.corrections >= ChatPrependHold.maxCorrections ? "max corrections" : "\(ChatPrependHold.stableReads) still readings"
            ChatScrollTrace.hold("settled (\(why)) anchor=\(ChatScrollTrace.short(current.anchor)) pre=\(ChatScrollTrace.pt(before)) post=\(ChatScrollTrace.pt(y)) dy=\(ChatScrollTrace.pt(y - before)) corrections=\(current.corrections)")
        }
        hold = current.settled ? nil : current
        if let target { set(view, offset: target) }
        // Still, but the list moved a moment ago: read again once it's been quiet.
        if let hold { scheduleHoldRecheck(after: hold.waitingForQuiet ? ChatPrependHold.settleQuiet : 0) }
    }

    private func scheduleHoldRecheck(after delay: Double = 0) {
        guard !holdRecheckScheduled else { return }
        holdRechecks += 1
        guard holdRechecks <= Self.maxHoldRechecks else {
            endHold("\(Self.maxHoldRechecks) rechecks without settling")
            return
        }
        holdRecheckScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            self.holdRecheckScheduled = false
            if let view = self.scrollView { self.applyHold(view, confirming: true) }
        }
    }

    // MARK: Observers

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard gesture.state == .began else { return }
        userHasScrolled = true
        endHold("drag")
        stopWatchingFailedRow()
        onUserDrag?()
    }

    private func geometryChanged(_ view: UIScrollView) {
        ChatScrollTrace.count(.offsetChange)
        // The scroll back to the anchor (or a correction) moved the list: read the
        // anchor again a turn later, after the layout that move causes.
        if hold?.insertApplied == true {
            hold?.listMoved(at: CACurrentMediaTime())
            scheduleHoldRecheck()
        }
        repin(view, change: .offset)
        onGeometry?(Self.metrics(of: view))
    }

    /// Back to the bottom for the changes a pinned list follows (see ChatBottomPin).
    /// The person's drags and flings decide whether it's pinned.
    private func repin(_ view: UIScrollView, change: ChatBottomPin.Change) {
        let interacting = view.isTracking || view.isDragging || view.isDecelerating
        let wasSuspended = pin.suspended
        let target = pin.observe(Self.metrics(of: view), change: change, interacting: interacting, holding: hold != nil, now: CACurrentMediaTime())
        if pin.suspended != wasSuspended {
            ChatScrollTrace.event(pin.suspended
                ? "pin: more than \(ChatBottomPin.cycleLimit) automatic corrections in \(ChatBottomPin.cycleWindow)s (last: \(change)); cycle cut, not following until a drag, jump, end change or \(ChatBottomPin.cycleQuiet)s quiet"
                : "pin: following again (\(change))")
        }
        if let target {
            ChatScrollTrace.count(.pinCorrection)
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
        ChatScrollTrace.count(.contentSizeChange)
        // Step 1. The mutated hold is stored whether or not it moves the offset: a
        // visible-anchor hold moves nothing here, but only once `insertApplied` is
        // stored does step 2 (the exact correction from the anchor's next report)
        // ever run. Before, that copy was dropped, so the scroll to the anchor's
        // unit point was the only placement and its rounding stayed as drift.
        if var current = hold, !current.insertApplied {
            let target = current.offsetForInsert(Self.metrics(of: view), now: CACurrentMediaTime())
            if current.insertApplied {
                ChatScrollTrace.hold("insert in gen=\(current.generation): content \(ChatScrollTrace.pt(current.contentHeightBefore)) -> \(ChatScrollTrace.pt(Double(view.contentSize.height))) step1=\(target.map(ChatScrollTrace.pt) ?? "none (scroll to anchor places it)")")
            }
            hold = current.settled ? nil : current
            if let target { set(view, offset: target) }
        }
        repin(view, change: .content)
        applyHold(view, confirming: false)
        onGeometry?(Self.metrics(of: view))
    }

    private func viewportChanged(_ view: UIScrollView, oldHeight: Double) {
        ChatScrollTrace.count(.viewportChange)
        let after = Self.metrics(of: view)
        var before = after
        before.viewportHeight = oldHeight
        // Mid-cycle (see ChatBottomPin) the stick would be one more mover.
        if !pin.suspended, let target = ChatViewportStick.offset(before: before, after: after) {
            ChatScrollTrace.count(.pinCorrection)
            set(view, offset: target)
        }
        repin(view, change: .viewport)
        if failedRow != nil {
            if !pin.endPending { fitFailedRow(view, why: "viewport") }
            armFailedFit("viewport")
        }
    }

    private func insetsChanged(_ view: UIScrollView) {
        ChatScrollTrace.count(.insetChange)
        repin(view, change: .insets)
        if failedRow != nil {
            if !pin.endPending { fitFailedRow(view, why: "insets") }
            armFailedFit("insets")
        }
    }

    private func set(_ view: UIScrollView, offset: Double) {
        guard abs(Double(view.contentOffset.y) - offset) > 0.01 || view.isDecelerating else { return }
        #if DEBUG
        HangProbe.mark(.offsetSet)
        #endif
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

/// DEBUG-only counters for the message list, so a Mac run can see a loop from
/// `log stream` instead of guessing from a profile. Every second in which anything
/// happened, one line (Logger subsystem com.spencereese.squadsync, category
/// chat-scroll):
///
///     1s list=… rows=… memo=… pin=… fit=… offset=… size=… inset=… viewport=… rowgeo=… hold=…
///
/// - list: message-list body evaluations; rows: message-row evaluations;
///   memo: thread-row rebuilds (ChatRowMemo).
/// - pin: bottom-pin/viewport-stick corrections; fit: failed-row moves.
/// - offset/size/inset/viewport: UIScrollView changes seen by the controller.
/// - rowgeo: tracked-row geometry callbacks; hold: prepend-hold readings.
///
/// Hold steps, fit outcomes and a pin cycle being cut are logged as they happen.
/// A settled list logs nothing. Release builds compile all of this to no-ops.
@MainActor
enum ChatScrollTrace {
    enum Counter: Int, CaseIterable {
        case listBody, rowBody, memoBuild, pinCorrection, fit
        case offsetChange, contentSizeChange, insetChange, viewportChange, rowGeometry, holdDecision

        var label: String {
            switch self {
            case .listBody: "list"
            case .rowBody: "rows"
            case .memoBuild: "memo"
            case .pinCorrection: "pin"
            case .fit: "fit"
            case .offsetChange: "offset"
            case .contentSizeChange: "size"
            case .insetChange: "inset"
            case .viewportChange: "viewport"
            case .rowGeometry: "rowgeo"
            case .holdDecision: "hold"
            }
        }
    }

    #if DEBUG
    private static let log = Logger(subsystem: "com.spencereese.squadsync", category: "chat-scroll")
    private static var counts = [Int](repeating: 0, count: Counter.allCases.count)
    private static var flushScheduled = false
    #endif

    /// For use inside a view body: `let _ = ChatScrollTrace.counted(.listBody)`.
    @discardableResult
    static func counted(_ counter: Counter) -> Bool {
        count(counter)
        return true
    }

    static func count(_ counter: Counter) {
        #if DEBUG
        counts[counter.rawValue] += 1
        scheduleFlush()
        #endif
    }

    static func hold(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        log.notice("hold \(text, privacy: .public)")
        #endif
    }

    static func event(_ message: @autoclosure () -> String) {
        #if DEBUG
        let text = message()
        log.notice("\(text, privacy: .public)")
        #endif
    }

    /// The last 4 hex digits of an id: enough to tell rows apart in a log
    /// (mock ids end in the message number).
    nonisolated static func short(_ id: UUID) -> String {
        String(id.uuidString.suffix(4))
    }

    nonisolated static func pt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    #if DEBUG
    private static func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            MainActor.assumeIsolated { flush() }
        }
    }

    private static func flush() {
        flushScheduled = false
        guard counts.contains(where: { $0 > 0 }) else { return }
        let line = Counter.allCases.map { "\($0.label)=\(counts[$0.rawValue])" }.joined(separator: " ")
        counts = [Int](repeating: 0, count: Counter.allCases.count)
        log.notice("1s \(line, privacy: .public)")
    }
    #endif
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

#if DEBUG
/// DEBUG only. Counts of main-thread work that can feed a layout loop, readable
/// from the stall watcher's thread while the main thread is stuck: if these
/// climb during a hang it's a loop through them; if they stay flat the main
/// thread is blocked somewhere else (a wait, a lock, a framework call).
final class HangProbe: @unchecked Sendable {
    enum Mark: Int, CaseIterable {
        case offsetKVO, sizeKVO, viewportKVO, offsetSet, rowGeometry, rowBuild, listBody, chipFlowSize, chipFlowPlace
    }

    private static let shared = HangProbe()
    private let lock = NSLock()
    private var counts = [Int](repeating: 0, count: Mark.allCases.count)

    static func mark(_ mark: Mark) {
        shared.lock.lock()
        shared.counts[mark.rawValue] += 1
        shared.lock.unlock()
    }

    static func read() -> [Int] {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared.counts
    }

    /// "offsetKVO=12 sizeKVO=3 ..." for the counts that moved, or "none".
    static func delta(from before: [Int], to after: [Int]) -> String {
        let moved = Mark.allCases.compactMap { mark -> String? in
            let change = after[mark.rawValue] - before[mark.rawValue]
            return change == 0 ? nil : "\(mark)=\(change)"
        }
        return moved.isEmpty ? "none" : moved.joined(separator: " ")
    }
}

/// DEBUG only. A background thread (not the main thread, so a hard hang can't
/// silence it) pings the main thread twice a second. A ping that waits 250 ms
/// is reported when it ends, as "main thread stalled N ms" with the HangProbe
/// counts that moved meanwhile. While the main thread stays blocked, it logs
/// "main thread blocked N ms so far" once a second, from the background
/// thread, with that second's counts. The first watcher (6b38612) waited for
/// the main thread before logging anything, so a hard hang logged nothing at all.
///
/// With SQ_HANG_ABORT_SECONDS set in the app's environment (UI tests forward
/// it from TEST_RUNNER_SQ_HANG_ABORT_SECONDS), a block that long aborts the
/// app so the simulator writes a crash report with the main thread's stack
/// (~/Library/Logs/DiagnosticReports/SquadSync-*.ips on the Mac).
/// Capture: `log stream --level debug --predicate 'subsystem == "com.spencereese.squadsync"'`.
enum MainThreadStallWatch {
    private static let log = Logger(subsystem: "com.spencereese.squadsync", category: "main-stall")
    @MainActor private static var started = false

    @MainActor static func start() {
        guard !started else { return }
        started = true
        let abortAfter = ProcessInfo.processInfo.environment["SQ_HANG_ABORT_SECONDS"].flatMap { Double($0) }
        log.debug("watching the main thread off-main (report at 250 ms, abort after \(abortAfter.map { "\($0) s" } ?? "never", privacy: .public))")
        let watcher = Thread {
            while true {
                let before = HangProbe.read()
                let sent = DispatchTime.now()
                let answered = DispatchSemaphore(value: 0)
                DispatchQueue.main.async { answered.signal() }
                if answered.wait(timeout: sent + .milliseconds(250)) == .timedOut {
                    var lastSecond = HangProbe.read()
                    while answered.wait(timeout: .now() + .seconds(1)) == .timedOut {
                        let blocked = elapsedMilliseconds(since: sent)
                        let now = HangProbe.read()
                        log.error("main thread blocked \(blocked, privacy: .public) ms so far; last second: \(HangProbe.delta(from: lastSecond, to: now), privacy: .public)")
                        lastSecond = now
                        if let abortAfter, Double(blocked) >= abortAfter * 1000 {
                            log.fault("main thread blocked \(blocked, privacy: .public) ms: aborting for a crash report with its stack")
                            abort()
                        }
                    }
                    let waited = elapsedMilliseconds(since: sent)
                    log.error("main thread stalled \(waited, privacy: .public) ms; during it: \(HangProbe.delta(from: before, to: HangProbe.read()), privacy: .public)")
                }
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        watcher.name = "main-stall-watch"
        watcher.qualityOfService = .userInitiated
        watcher.start()
    }

    private static func elapsedMilliseconds(since start: DispatchTime) -> UInt64 {
        (DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
    }
}
#endif
