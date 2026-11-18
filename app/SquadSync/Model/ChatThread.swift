import Foundation

// Message polish (redesign S3). Pure rules for how the squad chat lays out:
// grouping, day separators, quiet timestamps, delivery captions, read receipts,
// the unread divider, reaction chips, reply quotes, and history load states.
// The SwiftUI rows in `ChatRows.swift` only draw what these return.

/// One reply quote over a message. `body` is nil when the original isn't loaded.
struct ChatReplyQuote: Equatable {
    let id: UUID
    let sender: String?
    let body: String?

    static let missing = "Original message isn't loaded."

    var text: String {
        guard let body else { return Self.missing }
        guard let sender else { return body }
        return "\(sender): \(body)"
    }

    var spoken: String {
        guard let body else { return "Replying to a message that isn't loaded" }
        return "Replying to \(sender ?? "a message"): \(body)"
    }
}

/// How one message sits in the thread.
struct ChatBubble: Equatable {
    let entry: ChatEntry
    let mine: Bool
    /// First message of a run by the same sender. Shows the name and a quiet time.
    let startsGroup: Bool
    /// Last message of the run. Gets a little more space under it.
    let endsGroup: Bool
    let senderName: String
    let time: String
    /// Only on your own messages: Sending…, Not delivered, or Sent on your latest one.
    let caption: String?
    /// Only on the latest message in the thread, and only when someone read it.
    let seen: String?
    let reply: ChatReplyQuote?
}

/// Not Identifiable on purpose: the list iterates `ChatRowItem`, which stores
/// this identity, so it's worked out once per row build and never per diff.
enum ChatRow: Equatable {
    case day(key: String, label: String)
    case unread(count: Int)
    case message(ChatBubble)
    case spot(SpotCall)

    var identity: String {
        switch self {
        case .day(let key, _): "day-\(key)"
        case .unread: "unread-divider"
        case .message(let bubble): "message-\(bubble.entry.id.uuidString)"
        case .spot(let call): "spot-\(call.id.uuidString)"
        }
    }
}

/// A thread row with its identity worked out once, when the row is built. The
/// list's ForEach reads `id` for every row on every diff; as a computed string
/// (interpolating a UUID each time) it was the top cost in a profile of the
/// list, ahead of layout itself.
///
/// The row itself sits behind one class reference, so copying an item is a
/// string and a pointer, not the whole bubble (entry, names, caption, seen line,
/// reply quote) or spot call (seats array): the lazy stack copies and destroys
/// every item each time it walks the ForEach (prefetch phases, preferences), and
/// 6f41b07's thread-groups profile had those copies as its two top frames, with
/// the reply quote's enum tag checks under them.
struct ChatRowItem: Identifiable, Equatable {
    let id: String
    private let storage: Storage
    var row: ChatRow { storage.row }

    init(_ row: ChatRow) {
        self.id = row.identity
        self.storage = Storage(row)
    }

    static func == (lhs: ChatRowItem, rhs: ChatRowItem) -> Bool {
        lhs.id == rhs.id && (lhs.storage === rhs.storage || lhs.storage.row == rhs.storage.row)
    }

    private final class Storage {
        let row: ChatRow
        init(_ row: ChatRow) { self.row = row }
    }
}

/// The thread's rows, built once per change of what they're made from (the
/// messages and calls, names, reads, the unread anchor, the viewer, and the
/// day, since separators say Today or Yesterday), not on every render of the
/// list. Not observable: reading or refilling it never asks for a render.
final class ChatRowMemo {
    private struct Key: Equatable {
        let items: [SpotThreadItem]
        let viewerId: UUID?
        let names: [UUID: String]
        let reads: [MemberRead]
        let unreadAnchor: UUID?
        let today: String
        let zone: String
        let locale: String
    }

    private var key: Key?
    private var cached: [ChatRowItem] = []
    /// How many times the rows were actually built.
    private(set) var builds = 0

    func rows(items: [SpotThreadItem], context: ChatThread.Context) -> [ChatRowItem] {
        let key = Key(
            items: items,
            viewerId: context.viewerId,
            names: context.names,
            reads: context.reads,
            unreadAnchor: context.unreadAnchor,
            today: context.clock.dayKey(context.now),
            zone: context.clock.calendar.timeZone.identifier,
            locale: context.clock.locale.identifier
        )
        if key == self.key { return cached }
        self.key = key
        cached = ChatThread.rows(items: items, context: context).map(ChatRowItem.init)
        builds += 1
        return cached
    }
}

/// Formats dates the way the thread shows them. The calendar's time zone and the
/// locale are injected so tests don't depend on the device.
struct ChatClock {
    var calendar: Calendar
    var locale: Locale

    static var current: ChatClock {
        ChatClock(calendar: .autoupdatingCurrent, locale: .autoupdatingCurrent)
    }

    /// "3:04 PM" in en_US. ICU's narrow no-break space becomes a plain space.
    func time(_ date: Date) -> String {
        format(date, template: "jmm")
    }

    /// Today, Yesterday, a weekday within the last week, then "Nov 3", then "Nov 3, 2025".
    func day(_ date: Date, now: Date) -> String {
        let start = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let days = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        if days == 0 { return "Today" }
        if days == 1 { return "Yesterday" }
        if days > 1 && days < 7 { return format(date, template: "EEEE") }
        if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            return format(date, template: "MMMd")
        }
        return format(date, template: "yMMMd")
    }

    func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    func sameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    private func format(_ date: Date, template: String) -> String {
        ChatFormatterCache.shared.formatter(template: template, calendar: calendar, locale: locale).string(from: date)
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}

/// One DateFormatter per template, locale, calendar and time zone. Building one
/// per message time on every render was a top cost of scrolling a long chat.
/// A change of locale, calendar or zone gets a new key, so a new formatter.
final class ChatFormatterCache: @unchecked Sendable {
    static let shared = ChatFormatterCache()
    private let lock = NSLock()
    private var formatters: [String: DateFormatter] = [:]
    private(set) var built = 0

    func formatter(template: String, calendar: Calendar, locale: Locale) -> DateFormatter {
        let key = [template, locale.identifier, "\(calendar.identifier)", calendar.timeZone.identifier].joined(separator: "|")
        lock.lock()
        defer { lock.unlock() }
        if let cached = formatters[key] { return cached }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate(template)
        formatters[key] = formatter
        built += 1
        return formatter
    }
}

enum ChatThread {
    /// Messages by the same sender closer than this stay in one group.
    static let groupGap: TimeInterval = 5 * 60
    static let you = "You"
    static let unknownSender = "Player"

    struct Context {
        var viewerId: UUID?
        /// Display names by user id, from the squad roster.
        var names: [UUID: String]
        var reads: [MemberRead]
        /// First unread message when the chat opened. Frozen until you send.
        var unreadAnchor: UUID?
        var clock: ChatClock
        var now: Date
    }

    /// Thread rows: a day separator before each new day, the unread divider before
    /// the anchor, and messages grouped by sender and time. A spot card breaks a group.
    static func rows(items: [SpotThreadItem], context: Context) -> [ChatRow] {
        let messages = items.compactMap { item -> ChatEntry? in
            if case .message(let entry) = item { return entry }
            return nil
        }
        let latest = messages.last
        let latestMine = messages.last { $0.senderId == context.viewerId && $0.delivery == .sent }
        let seenLine = latest.flatMap { seen(for: $0, context: context) }
        let byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let unreadCount = context.unreadAnchor.map { anchor in
            unreadMessages(from: anchor, in: messages, viewerId: context.viewerId)
        } ?? 0

        var rows: [ChatRow] = []
        var lastDay: Date?
        for (index, item) in items.enumerated() {
            let date = itemDate(item)
            if lastDay.map({ !context.clock.sameDay($0, date) }) ?? true {
                rows.append(.day(key: context.clock.dayKey(date), label: context.clock.day(date, now: context.now)))
            }
            lastDay = date
            switch item {
            case .spot(let call):
                rows.append(.spot(call))
            case .message(let entry):
                if entry.id == context.unreadAnchor, unreadCount > 0 {
                    rows.append(.unread(count: unreadCount))
                }
                let previous = index > 0 ? items[index - 1] : nil
                let next = index + 1 < items.count ? items[index + 1] : nil
                let starts = !continues(previous: previous, current: entry, clock: context.clock)
                    || entry.id == context.unreadAnchor
                let ends = next.map { item -> Bool in
                    guard case .message(let after) = item else { return true }
                    if after.id == context.unreadAnchor { return true }
                    return !continues(previous: .message(entry), current: after, clock: context.clock)
                } ?? true
                let mine = entry.senderId == context.viewerId
                let isLatest = entry.id == latest?.id
                let seen = isLatest ? seenLine : nil
                rows.append(.message(ChatBubble(
                    entry: entry,
                    mine: mine,
                    startsGroup: starts,
                    endsGroup: ends,
                    senderName: name(for: entry.senderId, context: context),
                    time: context.clock.time(entry.sentAt),
                    caption: mine ? caption(entry, isLatestMine: entry.id == latestMine?.id, hasSeenLine: seen != nil) : nil,
                    seen: seen,
                    reply: entry.replyToId.map { replyId in
                        let original = byId[replyId]
                        return ChatReplyQuote(
                            id: replyId,
                            sender: original.map { name(for: $0.senderId, context: context) },
                            body: original?.body
                        )
                    }
                )))
            }
        }
        return rows
    }

    static func name(for userId: UUID, context: Context) -> String {
        if userId == context.viewerId { return you }
        return context.names[userId] ?? unknownSender
    }

    /// Same sender, same day, within the gap, and nothing else in between.
    static func continues(previous: SpotThreadItem?, current: ChatEntry, clock: ChatClock) -> Bool {
        guard case .message(let before) = previous else { return false }
        return before.senderId == current.senderId
            && clock.sameDay(before.sentAt, current.sentAt)
            && current.sentAt.timeIntervalSince(before.sentAt) < groupGap
            && current.sentAt >= before.sentAt
    }

    static func caption(_ entry: ChatEntry, isLatestMine: Bool, hasSeenLine: Bool) -> String? {
        switch entry.delivery {
        case .sending: return "Sending…"
        case .failed: return "Not delivered"
        case .sent: return isLatestMine && !hasSeenLine ? "Sent" : nil
        }
    }

    /// Who has read the latest message, not counting you or whoever sent it.
    /// Unsent messages and a server without read rows get no line, and neither
    /// does a render before you're known (your own read would be counted).
    static func seen(for entry: ChatEntry, context: Context) -> String? {
        guard entry.delivery == .sent, context.viewerId != nil else { return nil }
        let names = context.reads
            .filter { $0.userId != context.viewerId && $0.userId != entry.senderId && $0.lastReadAt >= entry.sentAt }
            .map { context.names[$0.userId] ?? unknownSender }
            .sorted()
        return seenLine(names)
    }

    static func seenLine(_ names: [String]) -> String? {
        switch names.count {
        case 0: nil
        case 1: "Seen by \(names[0])"
        case 2: "Seen by \(names[0]) and \(names[1])"
        default: "Seen by \(names.count)"
        }
    }

    static func unreadMessages(from anchor: UUID, in messages: [ChatEntry], viewerId: UUID?) -> Int {
        guard let start = messages.firstIndex(where: { $0.id == anchor }) else { return 0 }
        return messages[start...].filter { $0.senderId != viewerId && $0.delivery == .sent }.count
    }

    static func unreadLabel(_ count: Int) -> String {
        count == 1 ? "1 unread message" : "\(count) unread messages"
    }

    private static func itemDate(_ item: SpotThreadItem) -> Date {
        switch item {
        case .message(let entry): entry.sentAt
        case .spot(let call): SpotThread.endedAt(call)
        }
    }
}

/// Where the unread divider goes. Settled once when a squad's chat first loads, so
/// reading the chat doesn't make it jump away. Cleared when you send.
struct ChatUnreadMarker: Equatable {
    private(set) var anchor: UUID?
    private(set) var settled = false

    /// The first message from someone else after your read cursor, or nothing.
    static func firstUnread(in log: ChatLog, viewerId: UUID?) -> UUID? {
        guard let cursor = log.lastReadAt else { return nil }
        return log.ordered.first { entry in
            entry.senderId != viewerId && entry.delivery == .sent && entry.sentAt > cursor
        }?.id
    }

    mutating func settle(log: ChatLog, viewerId: UUID?) {
        guard !settled else { return }
        settled = true
        anchor = Self.firstUnread(in: log, viewerId: viewerId)
    }

    mutating func clear() {
        anchor = nil
        settled = true
    }

    mutating func reset() {
        anchor = nil
        settled = false
    }
}

/// One reaction chip under a message.
struct ChatReactionChip: Equatable, Identifiable {
    let tapback: Tapback
    let emoji: String
    let count: Int
    let mine: Bool

    var id: String { tapback.rawValue }

    var spoken: String {
        let people = count == 1 ? "1 reaction" : "\(count) reactions"
        return mine ? "\(tapback.spoken), \(people), including yours" : "\(tapback.spoken), \(people)"
    }

    var hint: String {
        mine ? "Removes your reaction" : "Adds your \(tapback.spoken) reaction"
    }
}

enum ChatReactions {
    /// Fixed order so chips don't jump around as counts change.
    static let order: [Tapback] = [.thumbs, .love, .laugh, .emphasize, .question, .game]

    static func chips(marks: [ReactionMark], messageId: UUID, viewerId: UUID?) -> [ChatReactionChip] {
        order.compactMap { tapback in
            let emoji = SquadReaction.emoji(for: tapback)
            let matching = marks.filter { $0.messageId == messageId && $0.emoji == emoji }
            guard !matching.isEmpty else { return nil }
            return ChatReactionChip(
                tapback: tapback,
                emoji: emoji,
                count: Set(matching.map(\.userId)).count,
                mine: matching.contains { $0.userId == viewerId }
            )
        }
    }

    static func spoken(_ chips: [ChatReactionChip]) -> String? {
        guard !chips.isEmpty else { return nil }
        return "Reactions: " + chips.map { "\($0.tapback.spoken) \($0.count)" }.joined(separator: ", ")
    }
}

enum ChatSpeech {
    /// The bubble's VoiceOver line: who, what, and when. The reply quote, reaction
    /// chips, delivery caption, and seen line are their own elements right next to
    /// it, so they are not repeated here.
    static func bubble(_ bubble: ChatBubble) -> String {
        "\(bubble.senderName), \(bubble.entry.body), \(bubble.time)"
    }
}

/// Long-press actions for one message. Reply only when the server has `reply_to_id`.
enum ChatAction: Equatable, CaseIterable {
    case react
    case reply
    case copy
    case retry

    var title: String {
        switch self {
        case .react: "React"
        case .reply: "Reply"
        case .copy: "Copy"
        case .retry: "Retry sending"
        }
    }

    static func available(for entry: ChatEntry, repliesAvailable: Bool) -> [ChatAction] {
        var actions: [ChatAction] = []
        if entry.delivery == .sent { actions.append(.react) }
        if entry.delivery == .sent, repliesAvailable { actions.append(.reply) }
        actions.append(.copy)
        if entry.delivery == .failed { actions.append(.retry) }
        return actions
    }
}

/// What the server lets the chat do. Probed read-only; unknown means off.
struct ChatCapabilities: Equatable {
    var replies: Bool

    static let unknown = ChatCapabilities(replies: false)
    static let repliesUnavailable = "Replies aren't set up on this server yet."
}

/// History load for the open squad.
enum ChatHistoryState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)

    static let loadingText = "Loading messages…"
    static let emptyText = "No messages yet. Say hi to the squad."
    static let failedText = "Messages couldn't load."
    static let staleText = "Couldn't refresh messages. Showing what's here."
    static let notSetUpText = "Chat isn't set up on this server yet."

    enum Display: Equatable {
        case loading
        case empty
        case failed(String)
        /// A refresh failed but older messages are still on screen.
        case stale(String)
    }

    func display(hasMessages: Bool) -> Display? {
        switch self {
        case .idle:
            return nil
        case .loading:
            return hasMessages ? nil : .loading
        case .loaded:
            return hasMessages ? nil : .empty
        case .failed(let reason):
            return hasMessages ? .stale(Self.staleText) : .failed(reason)
        }
    }

    static func failure(_ error: Error) -> ChatHistoryState {
        if let failure = error as? BackendFailure, case .notSetUp = failure {
            return .failed(notSetUpText)
        }
        return .failed(failedText)
    }
}

/// The floating button that brings you back to the newest message.
enum ChatJump {
    static func shows(pinned: Bool, hasMessages: Bool) -> Bool {
        !pinned && hasMessages
    }

    static func label(newCount: Int) -> String {
        switch newCount {
        case 0: "Jump to latest"
        case 1: "1 new message, jump to latest"
        default: "\(newCount) new messages, jump to latest"
        }
    }

    static func title(newCount: Int) -> String {
        newCount == 0 ? "Latest" : "\(newCount) new"
    }
}
