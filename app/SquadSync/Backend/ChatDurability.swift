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

    /// Whether the row should start a page now. Only while the reader has scrolled
    /// away from the bottom: on first load the list draws its top before it jumps to
    /// the newest message, and that must not fire a page.
    func shouldLoad(rowVisible: Bool, pinnedToBottom: Bool, hasMessages: Bool) -> Bool {
        guard rowVisible, !pinnedToBottom, hasMessages else { return false }
        return state == .idle
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
    static func cursor(_ log: ChatLog) -> ChatPageCursor? {
        guard let oldest = log.ordered.first(where: { $0.delivery == .sent }) else { return nil }
        return ChatPageCursor(sentAt: oldest.sentAt, id: oldest.id)
    }
}

/// Where an older page starts: messages strictly before this one, ordered by
/// `sent_at` then `id`, the same order as the server's paging index.
struct ChatPageCursor: Equatable {
    let sentAt: Date
    let id: UUID

    /// True when a message at (`other`, `otherId`) sorts strictly before the cursor, by the same rule as
    /// `ChatLog.ordered` (time, then the id's string).
    func precedes(sentAt other: Date, id otherId: UUID) -> Bool {
        if other != sentAt { return other < sentAt }
        return otherId.uuidString < id.uuidString
    }
}

/// Keeps the reader's place when a page lands above them: the message that was at
/// the top before the page is scrolled back to the top after it.
enum ChatScrollAnchor {
    /// The id to hold on to before a page loads.
    static func before(_ log: ChatLog) -> UUID? {
        log.ordered.first?.id
    }

    /// The id to scroll back to once the page is in, or nil when it's gone
    /// (a different squad was loaded meanwhile) or nothing was added above it.
    static func after(previousTop: UUID?, log: ChatLog) -> UUID? {
        guard let previousTop else { return nil }
        let ids = log.ordered.map(\.id)
        guard let index = ids.firstIndex(of: previousTop), index > 0 else { return nil }
        return previousTop
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

/// An older page landed; the list scrolls `anchor` back to the top. `serial`
/// makes two landings on the same anchor still count as a change.
struct ChatOlderLanding: Equatable {
    let anchor: UUID
    let serial: Int
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
