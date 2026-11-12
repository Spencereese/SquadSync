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

    var polls: Bool { self != .connected }

    var notice: String? {
        switch self {
        case .connecting:
            "Connecting to live chat."
        case .connected:
            nil
        case .reconnecting:
            "Reconnecting. Messages are checked until the socket is back."
        case .down:
            "Live chat is down. Messages are checked every few seconds."
        }
    }
}

enum ChatBackfill {
    static func apply(_ log: inout ChatLog, history: [ChatEntry]) {
        log.ingest(history)
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
