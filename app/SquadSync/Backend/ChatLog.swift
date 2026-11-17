import Foundation

enum Delivery: Equatable {
    case sending
    case sent
    case failed
}

struct ChatEntry: Equatable, Identifiable {
    let id: UUID
    let senderId: UUID
    var body: String
    var sentAt: Date
    var delivery: Delivery
    /// The message this one replies to (0014 `reply_to_id`). Nil when it isn't a reply.
    var replyToId: UUID? = nil
}

struct ChatLog: Equatable {
    private(set) var entries: [ChatEntry] = []
    private(set) var lastReadAt: Date?

    var ordered: [ChatEntry] {
        entries.sorted { lhs, rhs in
            if lhs.sentAt != rhs.sentAt { return lhs.sentAt < rhs.sentAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func unreadCount(viewerId: UUID) -> Int {
        entries.filter { entry in
            entry.senderId != viewerId && entry.delivery == .sent && isUnread(entry)
        }.count
    }

    mutating func beginSend(id: UUID, senderId: UUID, body: String, now: Date, replyToId: UUID? = nil) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].delivery = .sending
            return
        }
        entries.append(ChatEntry(id: id, senderId: senderId, body: body, sentAt: now, delivery: .sending, replyToId: replyToId))
    }

    mutating func markSent(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].delivery = .sent
    }

    mutating func markFailed(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].delivery = .failed
    }

    /// Retry keeps the same id. A second insert of that id is the same message.
    mutating func retry(id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].delivery = .sending
    }

    /// Server rows and our own echo share an id. One row remains, marked sent.
    mutating func ingest(_ remote: [ChatEntry]) {
        for item in remote {
            if let index = entries.firstIndex(where: { $0.id == item.id }) {
                entries[index].body = item.body
                entries[index].sentAt = item.sentAt
                entries[index].delivery = .sent
                if let reply = item.replyToId { entries[index].replyToId = reply }
            } else {
                var stored = item
                stored.delivery = .sent
                entries.append(stored)
            }
        }
    }

    /// A full refresh of the same squad merges. Switching squads drops the previous thread, including unconfirmed sends for that squad.
    mutating func adopt(replacingSquad: Bool, history: [ChatEntry]) {
        if replacingSquad {
            entries = []
            lastReadAt = nil
        }
        ingest(history)
    }

    /// The cursor only moves forward. A slower refresh must not mark a seen message unread again.
    mutating func markRead(at date: Date) {
        if let lastReadAt, date <= lastReadAt { return }
        lastReadAt = date
    }

    /// An unsent message read back from disk after a relaunch. Shown as failed
    /// unless the thread already has that id (the server took it before the kill).
    mutating func restoreUnsent(_ entry: ChatEntry) {
        guard !entries.contains(where: { $0.id == entry.id }) else { return }
        var restored = entry
        restored.delivery = .failed
        entries.append(restored)
    }

    mutating func remove(id: UUID) {
        entries.removeAll { $0.id == id }
    }

    private func isUnread(_ entry: ChatEntry) -> Bool {
        guard let lastReadAt else { return true }
        return entry.sentAt > lastReadAt
    }
}

enum RealtimeLink: Equatable {
    case connecting
    case connected
    case reconnecting
    case down

    /// Poll only after the socket has failed or dropped. Connecting still has the launch fetch.
    var polls: Bool {
        switch self {
        case .down, .reconnecting:
            true
        case .connecting, .connected:
            false
        }
    }

    var notice: String? {
        switch self {
        case .connecting:
            "Connecting to live chat."
        case .connected:
            nil
        case .reconnecting:
            "Reconnecting…"
        case .down:
            "Live chat is down. Messages are checked every few seconds."
        }
    }
}

struct ScrollSample: Equatable {
    var offset: CGFloat
    var content: CGFloat
    var viewport: CGFloat
}

enum ChatFollow {
    static let slack: CGFloat = 48

    static func distanceFromBottom(_ sample: ScrollSample) -> CGFloat {
        sample.content - sample.viewport - sample.offset
    }

    static func isAtBottom(_ sample: ScrollSample) -> Bool {
        guard sample.viewport > 1 else { return true }
        return distanceFromBottom(sample) <= slack
    }

    /// Content growing does not change the offset, so a pinned reader stays pinned.
    /// Moving toward the bottom does not unpin mid-animation. Moving up does.
    static func pinned(previous: Bool, oldOffset: CGFloat, sample: ScrollSample) -> Bool {
        guard sample.content > 1, sample.viewport > 1 else { return previous }
        let delta = sample.offset - oldOffset
        if abs(delta) < 0.5 { return previous }
        if delta > 0 { return isAtBottom(sample) || previous }
        return isAtBottom(sample)
    }

    static func scrolls(pinned: Bool, ownSend: Bool) -> Bool {
        pinned || ownSend
    }
}

enum ChatSeed {
    static let squadId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    static let otherId = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    static let messageId = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!

    static func rowIdentifier(for id: UUID) -> String {
        id == messageId ? "message-row-seed-1" : "message-row-\(id.uuidString)"
    }

    /// Identifier on a message bubble: whether it opens a sender group (and so
    /// carries the name header) or continues the one above. Never spoken.
    static func bubbleIdentifier(startsGroup: Bool) -> String {
        startsGroup ? "bubble-group-start" : "bubble-group-continues"
    }
}

enum ChatBackfill {
    static func apply(_ log: inout ChatLog, history: [ChatEntry]) {
        log.ingest(history)
    }

    static func missing(in log: ChatLog, history: [ChatEntry]) -> [ChatEntry] {
        let ids = Set(log.entries.map(\.id))
        return history.filter { !ids.contains($0.id) }
    }
}

enum RequestNoise {
    static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let url = error as? URLError, url.code == .cancelled { return true }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled { return true }
        if let failure = error as? BackendFailure, case .rejected(let message) = failure {
            let text = message.lowercased()
            return text == "cancelled" || text == "canceled" || text.contains("-999")
        }
        return false
    }
}

enum OutboundSend {
    enum Result: Equatable {
        case sent
        case staySending
        case failed
    }

    /// Sent only when a stored row matches. An empty insert is not a failure until the follow-up read misses.
    static func result(receipt: SendReceipt?, error: Error?) -> Result {
        if let error {
            if RequestNoise.isCancellation(error) { return .staySending }
            return .failed
        }
        switch receipt {
        case .stored:
            return .sent
        case .missing, nil:
            return .failed
        }
    }
}

/// A send that goes through proves the connection and the session work again.
/// The line a failed send left behind (or the session-level "Reconnecting…")
/// clears; anything else the user is reading stays.
enum SendRecovery {
    static func status(afterSuccess current: String, sendFailure: String?) -> String {
        if current == SessionFailurePolicy.reconnecting { return "" }
        if let sendFailure, !sendFailure.isEmpty, current == sendFailure { return "" }
        return current
    }
}

enum HistoryMerge {
    /// A fetch for a squad we have already left must not be written into the new thread.
    static func accepts(requestSquad: UUID, loadedSquad: UUID?) -> Bool {
        requestSquad == loadedSquad
    }
}

enum MembershipPrompt {
    static let transfer = InviteProblem.ownerMustTransfer.message

    static func shows(selected: UUID?) -> Bool { selected == nil }

    static func status(afterSelecting current: String) -> String {
        current == transfer ? "" : current
    }
}

enum LeaveAvailabilityCopy {
    static func line(isOwner: Bool, leaveShown: Bool) -> String? {
        guard !leaveShown else { return nil }
        if isOwner {
            return "Leave isn't available on this server yet. You can still remove a member."
        }
        return "Only the owner can remove a member. You can't leave on your own."
    }
}

enum ChatCatchUp {
    /// Returning to the bottom, or tapping New messages, is the reader catching up.
    static func requests(becamePinned: Bool, tappedNewMessages: Bool) -> Bool {
        becamePinned || tappedNewMessages
    }

    /// The New messages pill is only for a reader who is still scrolled up.
    static func hidesNewMessages(pinned: Bool) -> Bool { pinned }
}

enum LeaveProbe {
    /// Only a missing function hides Leave. Any other response means the RPC is there.
    static func available(status: Int, body: String) -> Bool {
        if status == 404 { return false }
        let text = body.lowercased()
        if text.contains("pgrst202") || text.contains("could not find the function") { return false }
        return true
    }
}

enum ReadAdvance {
    /// Arriving over the socket is not the same as the reader being at the bottom.
    static func catchesUp(pinned: Bool) -> Bool { pinned }
}

struct ReceiptBook: Equatable {
    var reads: [MemberRead]

    mutating func apply(_ read: MemberRead) {
        if let index = reads.firstIndex(where: { $0.userId == read.userId }) {
            guard read.lastReadAt > reads[index].lastReadAt else { return }
            reads[index] = read
        } else {
            reads.append(read)
        }
    }
}

enum MessageSpeech {
    static func row(body: String, delivery: Delivery) -> String {
        switch delivery {
        case .sending: "\(body), sending"
        case .sent: body
        case .failed: "\(body), failed. Retry sending."
        }
    }
}

struct ReactionMark: Equatable {
    let messageId: UUID
    let userId: UUID
    let emoji: String
}

enum ReactionChange: Equatable {
    case insert(String)
    case remove(String)
}

struct ReactionBoard: Equatable {
    private(set) var marks: [ReactionMark] = []

    mutating func replace(with marks: [ReactionMark]) {
        self.marks = marks
    }

    mutating func add(_ mark: ReactionMark) {
        guard !marks.contains(mark) else { return }
        marks.append(mark)
    }

    mutating func remove(_ mark: ReactionMark) {
        marks.removeAll { $0 == mark }
    }

    /// One tapback per person. The same emoji removes it. A different emoji replaces it.
    mutating func toggle(messageId: UUID, userId: UUID, emoji: String) -> [ReactionChange] {
        let mine = marks.filter { $0.messageId == messageId && $0.userId == userId }
        if mine.contains(where: { $0.emoji == emoji }) {
            marks.removeAll { $0.messageId == messageId && $0.userId == userId && $0.emoji == emoji }
            return [.remove(emoji)]
        }
        var changes: [ReactionChange] = []
        for old in mine {
            marks.removeAll { $0.messageId == messageId && $0.userId == userId && $0.emoji == old.emoji }
            changes.append(.remove(old.emoji))
        }
        marks.append(ReactionMark(messageId: messageId, userId: userId, emoji: emoji))
        changes.append(.insert(emoji))
        return changes
    }
}

enum SquadReaction {
    static func emoji(for tapback: Tapback) -> String {
        switch tapback {
        case .thumbs: "👍"
        case .laugh: "😂"
        case .emphasize: "🔥"
        case .love: "❤️"
        case .question: "😮"
        case .game: "🎮"
        }
    }

    static func tapback(for emoji: String) -> Tapback? {
        switch emoji {
        case "👍": .thumbs
        case "😂": .laugh
        case "🔥": .emphasize
        case "❤️": .love
        case "😮": .question
        case "🎮": .game
        default: nil
        }
    }
}

enum Receipts {
    static func seenNames(messageSentAt: Date, reads: [(id: UUID, name: String, at: Date)], viewerId: UUID) -> [String] {
        reads
            .filter { $0.id != viewerId && $0.at >= messageSentAt }
            .map(\.name)
            .sorted()
    }
}

enum MembershipChange {
    static func note(beforeId: UUID?, beforeCount: Int, afterId: UUID?, afterCount: Int) -> String {
        if let beforeId, beforeId == afterId, beforeCount == afterCount {
            return "You're already in this squad."
        }
        return "Joined."
    }
}

enum InviteProblem: Error, Equatable {
    case expired
    case revokedOrUnknown
    case full
    case alreadyInASquad
    case ownsSquadWithMembers
    case notOwner
    case ownerMustTransfer
    case notInSquad
    case alreadyLeft
    case signedOut
    case other(String)

    var message: String {
        switch self {
        case .expired:
            "This invite has expired."
        case .revokedOrUnknown:
            "That code isn't valid, or it was revoked."
        case .full:
            "That squad is full (8)."
        case .alreadyInASquad:
            "You're already in a squad."
        case .ownsSquadWithMembers:
            "You own a squad that still has members."
        case .notOwner:
            "Only the owner can make an invite."
        case .ownerMustTransfer:
            "Choose the next owner before you leave."
        case .notInSquad:
            "You're not in a squad."
        case .alreadyLeft:
            "You already left this squad."
        case .signedOut:
            "Sign in again before leaving."
        case .other(let text):
            text
        }
    }

    static func from(serverCode: String) -> InviteProblem {
        switch serverCode {
        case "expired": .expired
        case "invalid": .revokedOrUnknown
        case "full": .full
        case "already_in_squad": .alreadyInASquad
        case "owns_squad_with_members": .ownsSquadWithMembers
        case "not_owner": .notOwner
        case "owner_must_transfer": .ownerMustTransfer
        case "not_in_squad": .notInSquad
        case "already_left": .alreadyLeft
        case "signed_out": .signedOut
        default: .other(serverCode)
        }
    }
}
