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

    private func isUnread(_ entry: ChatEntry) -> Bool {
        guard let lastReadAt else { return true }
        return entry.sentAt > lastReadAt
    }
}
