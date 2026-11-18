import Foundation

// Chat durability: paging older history, keeping unsent messages across an app
// kill, and opening a pushed message that isn't loaded yet. All Foundation, so it
// runs in the Linux harness.

// MARK: Older history

/// The row at the top of the thread that pages older messages.
struct ChatOlderPaging: Equatable {
    enum State: Equatable {
        /// More may exist; the row loads them when it comes into view.
        case idle
        case loading
        case failed(String)
        /// The server has nothing older: "Start of chat".
        case reachedStart
    }

    static let pageSize = 50
    static let loadingText = "Loading earlier messages…"
    static let failedText = "Couldn't load earlier messages."
    static let startText = "Start of chat"

    private(set) var state: State = .idle

    /// The first history read decides whether there's anything older: fewer rows
    /// than the read's limit means the whole chat is already here.
    mutating func settleFirstRead(rowCount: Int, limit: Int) {
        state = rowCount < limit ? .reachedStart : .idle
    }

    /// Starts a page. False when one is already running or the start was reached.
    mutating func begin() -> Bool {
        switch state {
        case .idle, .failed:
            state = .loading
            return true
        case .loading, .reachedStart:
            return false
        }
    }

    /// A page came back. A short page means nothing older is left.
    mutating func finish(rowCount: Int, pageSize: Int = ChatOlderPaging.pageSize) {
        state = rowCount < pageSize ? .reachedStart : .idle
    }

    mutating func fail(_ reason: String = ChatOlderPaging.failedText) {
        state = .failed(reason)
    }

    mutating func reset() {
        state = .idle
    }

    /// The oldest confirmed message, which is where the next page starts (strictly
    /// before it by `sent_at`, then by id). Unsent local rows don't count.
    /// Runs on every scroll-geometry change; `ordered` is kept sorted by the log,
    /// so this is a short scan, not a sort.
    static func cursor(_ log: ChatLog) -> ChatPageCursor? {
        let oldest = log.ordered.first(where: { $0.delivery == .sent })
        guard let oldest else { return nil }
        return ChatPageCursor(sentAt: oldest.sentAt, id: oldest.id, stamp: oldest.serverStamp)
    }
}

// MARK: Scroll geometry (deterministic paging and place-keeping)
//
// Both decisions below run on numbers read straight from the message list's
// UIScrollView (ChatScrollController), never on row onAppear/onDisappear or a
// delay. That's what made the earlier attempts flaky: onAppear fires once, so a
// row that stayed on screen stalled paging, and a scrollTo fired "a moment after"
// the insert raced fling momentum and lazy row measurement.

/// The list's geometry, in points, as UIScrollView reports it.
struct ChatScrollMetrics: Equatable {
    var offset: Double
    var topInset: Double
    var bottomInset: Double
    var contentHeight: Double
    var viewportHeight: Double

    /// How far the visible top is below the top of the content.
    var distanceFromTop: Double { offset + topInset }
    /// How far the visible bottom is above the end of the content.
    var distanceFromBottom: Double { contentHeight + bottomInset - (offset + viewportHeight) }
    var minOffset: Double { -topInset }
    var maxOffset: Double { max(minOffset, contentHeight + bottomInset - viewportHeight) }

    func clamped(_ value: Double) -> Double { min(max(value, minOffset), maxOffset) }
}

/// Whether to start the next older page. Evaluated on every scroll-offset change,
/// every content-size change, and every paging-state change, so there's no state
/// in which a page is due and nothing asks for it.
enum ChatOlderTrigger {
    /// Prefetch when the top of the content is within this share of a screen.
    static let nearTopShare = 0.25

    /// - Parameters:
    ///   - oldestRowY: where the oldest loaded message's top is on screen (0 is the
    ///     list's top edge), or nil when it hasn't been laid out.
    ///   - userHasScrolled: the person has dragged the list since this squad loaded,
    ///     so the first render (which starts at the top before jumping to the newest
    ///     message) never pages.
    ///   - settlingPrepend: a page has been handed to the list but its rows aren't
    ///     laid out yet, so the geometry is stale.
    static func isDue(
        metrics: ChatScrollMetrics,
        oldestRowY: Double?,
        userHasScrolled: Bool,
        settlingPrepend: Bool,
        paging: ChatOlderPaging,
        hasMessages: Bool
    ) -> Bool {
        guard userHasScrolled, !settlingPrepend, hasMessages, paging.state == .idle, metrics.viewportHeight > 0 else { return false }
        // The oldest message has come up into view from the bottom edge.
        if let oldestRowY, oldestRowY < metrics.viewportHeight { return true }
        return metrics.distanceFromTop <= metrics.viewportHeight * nearTopShare
    }
}

/// Keeps the reader's place when a page of older messages goes in above them.
///
/// The content height a lazy stack reports after an insert is mostly estimates:
/// for the new rows, and re-estimates for unlaid rows below the screen too. So
/// "offset += content growth" can be hundreds of points off, and when it is, the
/// rows it was meant to hold are moved out of the laid-out range and can't be
/// measured to fix it. The hold therefore prefers a row the reader can see:
///
/// - Visible anchor (`visibleAnchor`): the topmost row fully on screen right
///   before the insert. The offset is not moved on content growth; instead the
///   list scrolls to that row so it sits where it was (`ChatPrependRestore`): the
///   framework lays the row out exactly, whatever the estimates. Then step 2.
/// - Fallback, nothing tracked on screen: the previous oldest message if it's laid
///   out, else nothing (the reader is far from the insert). Step 1 moves the
///   offset by the content growth, then step 2 if there's an anchor.
///
/// Step 2: each report of the anchor from a layout that has the new rows (its
/// generation) moves the offset by however far the anchor is from where it was,
/// until two readings in a row, a run-loop turn apart, find it within half a
/// point (at most `maxCorrections`). Positions from before the insert are never
/// used. A drag by the person ends the hold.
struct ChatPrependHold: Equatable {
    let anchor: UUID
    let offsetBefore: Double
    let contentHeightBefore: Double
    let anchorYBefore: Double?
    /// Row positions measured in a layout that already has the new page carry
    /// this generation (or later); older measurements are stale for step 2.
    let generation: Int
    /// False with a visible anchor: the scroll to the anchor places the rows, not
    /// the (estimated) content growth.
    let insertMovesOffset: Bool
    private(set) var insertApplied = false
    private(set) var settled = false
    /// In-place readings in a row; the hold ends after `stableReads` (the last one
    /// taken a run-loop turn later, after any layout the previous one caused).
    private(set) var inPlaceReads = 0
    private(set) var corrections = 0
    static let stableReads = 2
    /// A layout that never stops moving the anchor can't keep the hold going.
    static let maxCorrections = 12

    init(anchor: UUID, offsetBefore: Double, contentHeightBefore: Double, anchorYBefore: Double?, generation: Int = 0, insertMovesOffset: Bool = true) {
        self.anchor = anchor
        self.offsetBefore = offsetBefore
        self.contentHeightBefore = contentHeightBefore
        self.anchorYBefore = anchorYBefore
        self.generation = generation
        self.insertMovesOffset = insertMovesOffset
    }

    /// The topmost row whose whole frame is on screen (top at or below 0, bottom
    /// at or above the viewport's bottom), from content-space frames of laid-out
    /// rows and the current offset. `unitY` is the point of the row, as a share of
    /// its height, that lines up with the same share of the viewport when the list
    /// scrolls to it, so its top lands back at `y`.
    static func visibleAnchor(frames: [UUID: ChatRowFrame], offset: Double, viewportHeight: Double) -> ChatPrependRestore? {
        let onScreen = frames.compactMap { id, frame -> (UUID, Double, Double)? in
            let y = frame.minY - offset
            guard y >= 0, y + frame.height <= viewportHeight, frame.height > 0 else { return nil }
            return (id, y, frame.height)
        }
        guard let top = onScreen.min(by: { $0.1 != $1.1 ? $0.1 < $1.1 : $0.0.uuidString < $1.0.uuidString }) else { return nil }
        let room = viewportHeight - top.2
        let unitY = room > 0 ? min(max(top.1 / room, 0), 1) : 0
        return ChatPrependRestore(id: top.0, y: top.1, unitY: unitY)
    }

    /// Step 1. Returns the new offset for the first content growth after the hold
    /// was made, or nil when this change isn't it.
    mutating func offsetForInsert(_ metrics: ChatScrollMetrics) -> Double? {
        guard !insertApplied else { return nil }
        let growth = metrics.contentHeight - contentHeightBefore
        guard growth > 0 else { return nil }
        insertApplied = true
        if anchorYBefore == nil { settled = true }
        guard insertMovesOffset else { return nil }
        return metrics.clamped(offsetBefore + growth)
    }

    /// Step 2. Returns the corrected offset when the anchor has drifted, nil when
    /// it's in place (which settles the hold).
    /// `measuredIn` is the generation of the layout the anchor's position came
    /// from; a position from before the page went in is ignored, not corrected for.
    mutating func offsetForAnchor(y: Double, measuredIn: Int = .max, metrics: ChatScrollMetrics) -> Double? {
        guard insertApplied, !settled, measuredIn >= generation, let before = anchorYBefore else { return nil }
        let drift = y - before
        guard abs(drift) > 0.5 else {
            inPlaceReads += 1
            if inPlaceReads >= Self.stableReads { settled = true }
            return nil
        }
        inPlaceReads = 0
        corrections += 1
        if corrections >= Self.maxCorrections { settled = true }
        return metrics.clamped(metrics.offset + drift)
    }
}

/// A laid-out row's frame in the message stack's own coordinate space.
struct ChatRowFrame: Equatable {
    var minY: Double
    var height: Double
}

/// Where to put the visible anchor back after an older page goes in: scroll to
/// `id` with the unit point (0.5, `unitY`), which puts its top at `y` again.
struct ChatPrependRestore: Equatable {
    let id: UUID
    let y: Double
    let unitY: Double
}

/// When the list gets shorter or taller (the keyboard), a reader at the bottom
/// stays at the bottom. Anyone scrolled up keeps their offset.
enum ChatViewportStick {
    static let pinnedSlack = ChatBottomPin.slack

    static func offset(before: ChatScrollMetrics, after: ChatScrollMetrics) -> Double? {
        guard before.viewportHeight != after.viewportHeight else { return nil }
        guard before.distanceFromBottom <= pinnedSlack else { return nil }
        return after.maxOffset
    }
}

/// Whether the reader is staying at the bottom, as state rather than a distance
/// read at the moment something changes, and when a pinned list follows.
///
/// Only the person changes the state: while their finger or fling is moving the
/// list (`interacting`), at the bottom within `slack` pins and anywhere else
/// unpins. The app's own jumps say where they leave the reader
/// (`jumped(toBottom:)`), and an in-place expansion the person tapped (the
/// reaction menu, locking the spot card) unpins (`expanded()`), so the tapped
/// thing stays where it is.
///
/// A pinned list goes back to the bottom only for:
/// - keyboard, viewport or inset changes (`.layout`), and
/// - content growth right after the end of the thread changed (`endChanged()`:
///   a new row appended, or the last row's send state changing to failed, sent),
///   until `endSettled()`.
/// Any other content growth (a row in the middle expanding) leaves the offset
/// alone, and so does an offset change that isn't the person's (`.scroll`). At
/// most `budget` corrections per run-loop turn (`turnEnded()`), each only when
/// more than half a point off, so it can't feed back into a layout loop. While
/// an older page is being held in place the pin doesn't move anything.
struct ChatBottomPin: Equatable {
    static let slack = 32.0
    static let budget = 3

    enum Change: Equatable {
        /// The scroll view's size changed (keyboard, header, composer).
        case viewport
        /// The content height changed.
        case content
        /// The offset changed; upgraded to a layout change when the insets moved.
        case offset
    }

    /// A new chat opens at its newest message.
    private(set) var pinned = true
    /// The end of the thread just changed; content growth follows it.
    private(set) var endPending = false
    private var insets: [Double]?
    private var corrections = 0

    /// Feed every geometry change. Returns the offset to move to, if any.
    mutating func observe(_ metrics: ChatScrollMetrics, change: Change, interacting: Bool = false, holding: Bool = false) -> Double? {
        let now = [metrics.topInset, metrics.bottomInset]
        let insetsMoved = insets.map { $0 != now } ?? false
        insets = now
        guard !holding else { return nil }
        if interacting {
            pinned = metrics.distanceFromBottom <= Self.slack
            return nil
        }
        guard pinned else { return nil }
        let follows: Bool
        switch change {
        case .viewport: follows = true
        case .content: follows = endPending
        case .offset: follows = insetsMoved
        }
        guard follows, corrections < Self.budget, abs(metrics.maxOffset - metrics.offset) > 0.5 else { return nil }
        corrections += 1
        return metrics.maxOffset
    }

    /// The thread's last row is new, or its send state changed.
    mutating func endChanged() { endPending = true }
    /// The layout for that change is done.
    mutating func endSettled() { endPending = false }
    /// The person tapped something that grows in place.
    mutating func expanded() {
        pinned = false
        endPending = false
    }
    /// The app scrolled the list itself: to the newest message (pins) or to
    /// something else (unpins).
    mutating func jumped(toBottom: Bool) {
        pinned = toBottom
        if !toBottom { endPending = false }
    }
    /// A run-loop turn is over: the correction budget refills.
    mutating func turnEnded() { corrections = 0 }

    /// A different squad, or signed out.
    mutating func reset() { self = ChatBottomPin() }
}

/// Where an older page starts: messages strictly before this one, ordered by
/// `sent_at` then `id`, the same order as the server's paging index.
struct ChatPageCursor: Equatable {
    let sentAt: Date
    let id: UUID
    /// The server's `sent_at` text for this row. `sent_at` is microseconds and
    /// `Date` holds milliseconds, so a cursor rebuilt from `sentAt` could fall
    /// between rows in the same millisecond and skip them.
    var stamp: String? = nil

    /// What goes in the filter: the server's own text when it's safe to quote,
    /// otherwise `sentAt` formatted (whole seconds and milliseconds round-trip).
    var filterStamp: String? {
        if let stamp, !stamp.isEmpty, !stamp.contains("\""), !stamp.contains("\\"), !stamp.contains(",") {
            return stamp
        }
        return BackendJSON.parseStamp(sentAt)
    }

    /// True when a message at (`other`, `otherId`) sorts strictly before the cursor, by the same rule as
    /// `ChatLog.ordered` (time, then the id's string).
    func precedes(sentAt other: Date, id otherId: UUID) -> Bool {
        if other != sentAt { return other < sentAt }
        return otherId.uuidString < id.uuidString
    }
}

// MARK: Opening a pushed message

enum ChatReveal {
    enum Outcome: Equatable {
        case found
        /// The server doesn't have it for this squad (deleted, or another squad).
        case notInChat
        /// It exists but is more than `maxPages` pages back.
        case tooFarBack
        case failed
    }

    static let maxPages = 10
    static let notInChatText = "That message isn't in this chat anymore."
    static let tooFarBackText = "That message is too far back to open here. Scroll up to find it."
    static let failedText = "Couldn't open that message. Try again."

    static func text(_ outcome: Outcome) -> String? {
        switch outcome {
        case .found: nil
        case .notInChat: notInChatText
        case .tooFarBack: tooFarBackText
        case .failed: failedText
        }
    }

    /// Pages older history until the message is loaded, up to `maxPages` pages.
    /// `loaded` says whether it's in the thread now; `exists` asks the server once;
    /// `loadOlderPage` adds one page and returns false when the start is reached.
    @MainActor
    static func run(
        loaded: () -> Bool,
        exists: () async throws -> Bool,
        loadOlderPage: () async throws -> Bool,
        maxPages: Int = ChatReveal.maxPages
    ) async -> Outcome {
        if loaded() { return .found }
        do {
            guard try await exists() else { return .notInChat }
            for _ in 0..<maxPages {
                let more = try await loadOlderPage()
                if loaded() { return .found }
                if !more { return .notInChat }
            }
            return loaded() ? .found : .tooFarBack
        } catch {
            return .failed
        }
    }
}

/// The message a push asked to open, held until the chat's first load for the
/// squad has finished, then handed out exactly once. Either order works: the
/// push can arrive before the history (cold launch) or after it (app open).
struct ChatPendingOpen: Equatable {
    private(set) var target: UUID?
    private(set) var chatReady = false
    /// Targets already handed out, so a repeated settle of the same push doesn't
    /// open (and page back for) the same message again.
    private(set) var handled: Set<UUID> = []

    /// A push asked for `id`. Returns it when it should open now.
    mutating func request(_ id: UUID) -> UUID? {
        guard !handled.contains(id) else { return nil }
        target = id
        return takeIfReady()
    }

    /// The chat's load finished. Returns the held target when there is one.
    mutating func chatLoaded() -> UUID? {
        chatReady = true
        return takeIfReady()
    }

    /// A different squad is loading: wait for its first load again.
    mutating func chatReset() {
        chatReady = false
    }

    /// Sign-out.
    mutating func clear() {
        self = ChatPendingOpen()
    }

    private mutating func takeIfReady() -> UUID? {
        guard chatReady, let target else { return nil }
        self.target = nil
        handled.insert(target)
        return target
    }
}

// MARK: Unsent messages on disk

/// One outgoing message that hasn't been confirmed by the server. Its id is the
/// client id the insert uses, so a retry after relaunch is the same row to the
/// server (`resolution=ignore-duplicates`).
struct OutboxItem: Codable, Equatable {
    let id: UUID
    let squadId: UUID
    let senderId: UUID
    let body: String
    let createdAt: Date
    let replyToId: UUID?

    init(id: UUID, squadId: UUID, senderId: UUID, body: String, createdAt: Date, replyToId: UUID? = nil) {
        self.id = id
        self.squadId = squadId
        self.senderId = senderId
        self.body = body
        self.createdAt = createdAt
        self.replyToId = replyToId
    }

    init(_ message: RemoteMessage) {
        self.init(id: message.id, squadId: message.squadId, senderId: message.senderId, body: message.body, createdAt: message.sentAt, replyToId: message.replyToId)
    }

    var message: RemoteMessage {
        RemoteMessage(id: id, squadId: squadId, senderId: senderId, body: body, sentAt: createdAt, replyToId: replyToId)
    }
}

/// Pending and failed sends, one JSON file per user and squad under Application
/// Support. Written on every change, so a kill at any point leaves the latest list.
final class ChatOutbox {
    let directory: URL
    private let fileManager = FileManager.default

    init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/SquadSync/Outbox` (live) or `OutboxMock` (mock data,
    /// so UI tests never mix with a real account's unsent messages).
    static func standard(mock: Bool) -> ChatOutbox {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return ChatOutbox(directory: base.appendingPathComponent("SquadSync", isDirectory: true)
            .appendingPathComponent(mock ? "OutboxMock" : "Outbox", isDirectory: true))
    }

    func fileURL(squadId: UUID, userId: UUID) -> URL {
        directory.appendingPathComponent("\(userId.uuidString.lowercased())_\(squadId.uuidString.lowercased()).json")
    }

    func load(squadId: UUID, userId: UUID) -> [OutboxItem] {
        guard let data = try? Data(contentsOf: fileURL(squadId: squadId, userId: userId)),
              let items = try? Self.decoder.decode([OutboxItem].self, from: data) else { return [] }
        return items.filter { $0.squadId == squadId && $0.senderId == userId }
    }

    /// Adds or replaces by id.
    func add(_ item: OutboxItem) {
        var items = load(squadId: item.squadId, userId: item.senderId)
        items.removeAll { $0.id == item.id }
        items.append(item)
        write(items, squadId: item.squadId, userId: item.senderId)
    }

    func remove(id: UUID, squadId: UUID, userId: UUID) {
        let items = load(squadId: squadId, userId: userId)
        guard items.contains(where: { $0.id == id }) else { return }
        write(items.filter { $0.id != id }, squadId: squadId, userId: userId)
    }

    /// Sign-out: every squad's unsent messages for this person.
    func clear(userId: UUID) {
        let prefix = userId.uuidString.lowercased() + "_"
        let files = (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in files where name.hasPrefix(prefix) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    func clearAll() {
        try? fileManager.removeItem(at: directory)
    }

    private func write(_ items: [OutboxItem], squadId: UUID, userId: UUID) {
        let url = fileURL(squadId: squadId, userId: userId)
        if items.isEmpty {
            try? fileManager.removeItem(at: url)
            return
        }
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? Self.encoder.encode(items) else { return }
        #if os(iOS)
        try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try? data.write(to: url, options: .atomic)
        #endif
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum OutboxRestore {
    /// Puts unsent messages back in the thread after a relaunch, as failed so the
    /// person decides whether to send them. Returns the ids the server already has
    /// (sent before the kill, confirmation lost), which can leave the outbox.
    @discardableResult
    static func apply(_ items: [OutboxItem], to log: inout ChatLog) -> [UUID] {
        var delivered: [UUID] = []
        for item in items {
            if log.entries.contains(where: { $0.id == item.id && $0.delivery == .sent }) {
                delivered.append(item.id)
            } else {
                log.restoreUnsent(ChatEntry(
                    id: item.id,
                    senderId: item.senderId,
                    body: item.body,
                    sentAt: item.createdAt,
                    delivery: .failed,
                    replyToId: item.replyToId
                ))
            }
        }
        return delivered
    }
}

/// The `chatLongHistory` mock thread: more than one history read (200), so the
/// older-history row has pages to load. Pairs share a second, as real sends often
/// do at `.iso8601` precision, so paging has to break ties on id.
enum ChatLongSeed {
    static let count = 260

    static func id(_ index: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", 0x1000 + index))!
    }

    static func body(_ index: Int) -> String { "Long thread message \(index + 1)" }

    static func messages(viewerId: UUID, squadId: UUID, now: Date) -> [RemoteMessage] {
        (0..<count).map { index in
            let pair = (count - index + 1) / 2
            return RemoteMessage(
                id: id(index),
                squadId: squadId,
                senderId: index % 3 == 0 ? viewerId : ChatSeed.otherId,
                body: body(index),
                sentAt: now.addingTimeInterval(-Double(pair) * 120)
            )
        }
    }
}
