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

    mutating func beginSend(id: UUID, senderId: UUID, body: String, now: Date) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].delivery = .sending
            return
        }
        entries.append(ChatEntry(id: id, senderId: senderId, body: body, sentAt: now, delivery: .sending))
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
            } else {
                var stored = item
                stored.delivery = .sent
                entries.append(stored)
            }
        }
    }

    mutating func markRead(at date: Date) {
        lastReadAt = date
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

    /// The PostgREST insert response confirms the send. A cancelled request is not a failure, and no realtime echo is required.
    static func result(error: Error?) -> Result {
        guard let error else { return .sent }
        if RequestNoise.isCancellation(error) { return .staySending }
        return .failed
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

enum InviteProblem: Error, Equatable {
    case expired
    case revokedOrUnknown
    case full
    case alreadyInASquad
    case ownsSquadWithMembers
    case notOwner
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
        default: .other(serverCode)
        }
    }
}
