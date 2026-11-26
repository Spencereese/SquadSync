import Foundation

// Side threads: the side groups and DMs inside a squad (0017, guarded by 0024).
// Row level security shows a thread, its members, and its messages only to the
// people in that thread who are still in its squad. The app has no list of side
// threads yet; a reply's push opens the one it came from.

struct SideThreadInfo: Equatable, Identifiable, Decodable {
    let id: UUID
    let squadId: UUID
    /// "side_group" or "dm".
    let kind: String
    var title: String?

    var isDirect: Bool { kind == "dm" }

    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case kind
        case title
    }
}

struct SideThreadMessage: Equatable, Identifiable, Codable {
    let id: UUID
    let threadId: UUID
    let squadId: UUID
    let senderId: UUID
    var body: String
    var sentAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case squadId = "squad_id"
        case senderId = "sender_id"
        case body
        case sentAt = "sent_at"
    }
}

protocol SideThreadServing: AnyObject {
    /// The thread, or nil when it doesn't exist or this person can't see it.
    func thread(id: UUID) async throws -> SideThreadInfo?
    /// Who is in the thread (user ids).
    func members(threadId: UUID) async throws -> [UUID]
    /// The newest `limit` messages, oldest first.
    func messages(threadId: UUID, limit: Int) async throws -> [SideThreadMessage]
    /// One message by id in this thread, or nil.
    func message(threadId: UUID, id: UUID) async throws -> SideThreadMessage?
    func send(_ message: SideThreadMessage) async throws
}

enum SideThreadCopy {
    static let loading = "Loading side thread…"
    static let failed = "Couldn't load this side thread."
    static let notFound = "This side thread isn't available. You may not be in it anymore."
    static let replyMissing = "That reply isn't available anymore."
    static let sendFailed = "Couldn't send. Check your connection and try again."
    static let empty = "No messages yet."
    static let placeholder = "Reply"
    static let close = "Close"
    static let maxLength = 2000

    /// A side group shows its title; a DM shows the other person.
    static func title(info: SideThreadInfo?, memberIds: [UUID], viewerId: UUID?, names: [UUID: String]) -> String {
        guard let info else { return "Side thread" }
        if info.isDirect {
            let other = memberIds.first { $0 != viewerId }
            if let other, let name = names[other], !name.isEmpty { return name }
            return "Direct message"
        }
        let trimmed = info.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? "Side thread" : trimmed
    }

    /// The line under the title: what kind of thread it is and who's in it.
    static func context(info: SideThreadInfo?, memberIds: [UUID]) -> String {
        guard let info else { return "" }
        if info.isDirect { return "Direct message" }
        let count = memberIds.count
        return count == 1 ? "Side group · 1 person" : "Side group · \(count) people"
    }
}

/// What the side-thread panel shows. Pure, so the merge and send rules are testable.
struct SideThreadPanel: Equatable {
    enum Load: Equatable {
        case loading
        case ready
        case failed
        case notFound
    }

    static let pageSize = 100

    let threadId: UUID
    /// The reply a push tap opened. Scrolled to once it's loaded.
    var focus: UUID?
    var load: Load = .loading
    var info: SideThreadInfo?
    var memberIds: [UUID] = []
    /// Oldest first, one row per id.
    private(set) var messages: [SideThreadMessage] = []
    var draft = ""
    var sending = false
    var sendError = ""
    /// Set when the focused reply couldn't be found.
    var note = ""

    init(threadId: UUID, focus: UUID?) {
        self.threadId = threadId
        self.focus = focus
    }

    /// Adds rows for this thread only, replacing any with the same id, in time order.
    mutating func merge(_ rows: [SideThreadMessage]) {
        var byId = Dictionary(messages.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for row in rows where row.threadId == threadId {
            byId[row.id] = row
        }
        messages = byId.values.sorted { lhs, rhs in
            if lhs.sentAt != rhs.sentAt { return lhs.sentAt < rhs.sentAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    var focusLoaded: Bool {
        guard let focus else { return false }
        return messages.contains { $0.id == focus }
    }

    var trimmedDraft: String {
        draft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSend: Bool {
        load == .ready && !sending && !trimmedDraft.isEmpty && trimmedDraft.count <= SideThreadCopy.maxLength
    }

    /// The row a send writes. Nil when there's nothing to send or the thread isn't loaded.
    func outgoing(id: UUID, senderId: UUID, now: Date) -> SideThreadMessage? {
        guard canSend, let info else { return nil }
        return SideThreadMessage(
            id: id,
            threadId: threadId,
            squadId: info.squadId,
            senderId: senderId,
            body: trimmedDraft,
            sentAt: now
        )
    }

    /// The newest `sentAt` among loaded rows, for "anything newer" reads.
    var newest: Date? { messages.last?.sentAt }
}

enum SideThreadIdentifiers {
    static let panel = "side-thread"
    static let title = "side-thread-title"
    static let context = "side-thread-context"
    static let close = "side-thread-close"
    static let composer = "side-thread-composer"
    static let send = "side-thread-send"
    static let note = "side-thread-note"
    static let list = "side-thread-list"

    static func row(_ id: UUID) -> String {
        "side-thread-message-\(id.uuidString.lowercased())"
    }
}

final class SupabaseSideThreadService: SideThreadServing {
    private let http: SupabaseHTTP

    init(
        config: BackendConfig,
        accessToken: String,
        refresher: TokenRefreshing? = nil,
        transport: HTTPTransport = URLSessionTransport.shared
    ) {
        self.http = SupabaseHTTP(config: config, accessToken: accessToken, transport: transport, refresher: refresher)
    }

    static let messageColumns = "id,thread_id,squad_id,sender_id,body,sent_at"

    func thread(id: UUID) async throws -> SideThreadInfo? {
        let data = try await http.send(
            path: "rest/v1/sq8_threads",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "select", value: "id,squad_id,kind,title"),
                URLQueryItem(name: "limit", value: "1")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([SideThreadInfo].self, from: data).first
    }

    private struct MemberRow: Decodable {
        let userId: UUID
        enum CodingKeys: String, CodingKey { case userId = "user_id" }
    }

    func members(threadId: UUID) async throws -> [UUID] {
        let data = try await http.send(
            path: "rest/v1/sq8_thread_members",
            method: "GET",
            query: [
                URLQueryItem(name: "thread_id", value: "eq.\(threadId.uuidString)"),
                URLQueryItem(name: "select", value: "user_id"),
                URLQueryItem(name: "order", value: "added_at.asc")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([MemberRow].self, from: data).map(\.userId)
    }

    func messages(threadId: UUID, limit: Int) async throws -> [SideThreadMessage] {
        let data = try await http.send(
            path: "rest/v1/sq8_thread_messages",
            method: "GET",
            query: [
                URLQueryItem(name: "thread_id", value: "eq.\(threadId.uuidString)"),
                URLQueryItem(name: "select", value: Self.messageColumns),
                URLQueryItem(name: "order", value: "sent_at.desc,id.desc"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([SideThreadMessage].self, from: data).reversed()
    }

    func message(threadId: UUID, id: UUID) async throws -> SideThreadMessage? {
        let data = try await http.send(
            path: "rest/v1/sq8_thread_messages",
            method: "GET",
            query: [
                URLQueryItem(name: "id", value: "eq.\(id.uuidString)"),
                URLQueryItem(name: "thread_id", value: "eq.\(threadId.uuidString)"),
                URLQueryItem(name: "select", value: Self.messageColumns),
                URLQueryItem(name: "limit", value: "1")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([SideThreadMessage].self, from: data).first
    }

    /// The id is the client's, so a retried send can't post twice.
    func send(_ message: SideThreadMessage) async throws {
        let body = try BackendJSON.encoder.encode(message)
        _ = try await http.send(
            path: "rest/v1/sq8_thread_messages",
            method: "POST",
            body: body,
            prefer: "return=minimal,resolution=ignore-duplicates",
            feature: .messages
        )
    }
}

/// Mock server: one side group, "Ranked", in the seeded squad, with a few replies.
@MainActor
final class MockSideThreadService: SideThreadServing {
    static let threadId = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    /// The newest seeded reply: the one the UI test's push opens.
    static let replyId = UUID(uuidString: "00000000-0000-0000-0000-00000000B103")!

    private var threads: [UUID: SideThreadInfo] = [:]
    private var memberIds: [UUID: [UUID]] = [:]
    private var stored: [SideThreadMessage] = []
    private(set) var sent: [SideThreadMessage] = []
    var failsReads = false

    func seed(viewerId: UUID, otherId: UUID, squadId: UUID) {
        let thread = Self.threadId
        threads[thread] = SideThreadInfo(id: thread, squadId: squadId, kind: "side_group", title: "Ranked")
        memberIds[thread] = [viewerId, otherId]
        let base = Date(timeIntervalSince1970: 1_700_000_500)
        let lines: [(String, UUID, String)] = [
            ("00000000-0000-0000-0000-00000000B101", otherId, "Ranked tonight?"),
            ("00000000-0000-0000-0000-00000000B102", viewerId, "Maybe after 9"),
            (Self.replyId.uuidString, otherId, "On in 5, bring the mic")
        ]
        for (index, line) in lines.enumerated() {
            stored.append(SideThreadMessage(
                id: UUID(uuidString: line.0)!,
                threadId: thread,
                squadId: squadId,
                senderId: line.1,
                body: line.2,
                sentAt: base.addingTimeInterval(Double(index) * 60)
            ))
        }
    }

    func thread(id: UUID) async throws -> SideThreadInfo? {
        if failsReads { throw BackendFailure.reconnecting }
        return threads[id]
    }

    func members(threadId: UUID) async throws -> [UUID] {
        if failsReads { throw BackendFailure.reconnecting }
        return memberIds[threadId] ?? []
    }

    func messages(threadId: UUID, limit: Int) async throws -> [SideThreadMessage] {
        if failsReads { throw BackendFailure.reconnecting }
        let rows = stored.filter { $0.threadId == threadId }.sorted { $0.sentAt < $1.sentAt }
        return Array(rows.suffix(limit))
    }

    func message(threadId: UUID, id: UUID) async throws -> SideThreadMessage? {
        if failsReads { throw BackendFailure.reconnecting }
        return stored.first { $0.threadId == threadId && $0.id == id }
    }

    func send(_ message: SideThreadMessage) async throws {
        guard threads[message.threadId] != nil else { throw BackendFailure.rejected("No such thread.") }
        sent.append(message)
        if !stored.contains(where: { $0.id == message.id }) { stored.append(message) }
    }
}
