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
    /// Only the list read selects it; a push open doesn't.
    var createdAt: Date? = nil

    var isDirect: Bool { kind == "dm" }

    enum CodingKeys: String, CodingKey {
        case id
        case squadId = "squad_id"
        case kind
        case title
        case createdAt = "created_at"
    }
}

struct SideThreadMembership: Equatable, Decodable {
    let threadId: UUID
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case userId = "user_id"
    }
}

/// What a new side thread is made of. `memberIds` are the other people; the
/// creator is added too. One other person is a DM, more is a side group.
struct NewSideThread: Equatable {
    let id: UUID
    let squadId: UUID
    let createdBy: UUID
    let memberIds: [UUID]
    let title: String?

    var kind: String { memberIds.count == 1 ? "dm" : "side_group" }
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
    /// Every side thread of this squad the signed-in person is in (RLS shows no others).
    func threads(squadId: UUID) async throws -> [SideThreadInfo]
    /// Who is in each of these threads.
    func memberships(threadIds: [UUID]) async throws -> [SideThreadMembership]
    /// The newest message of each thread that has one.
    func lastMessages(threadIds: [UUID]) async throws -> [UUID: SideThreadMessage]
    /// Makes the thread and seats its creator and the others. Safe to repeat with the same id.
    func create(_ thread: NewSideThread) async throws
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

    // The list and the new-thread form.
    static let listPanel = "side-threads"
    static let listClose = "side-threads-close"
    static let listNew = "side-threads-new"
    static let listLoading = "side-threads-loading"
    static let listEmpty = "side-threads-empty"
    static let listError = "side-threads-error"
    static let listRetry = "side-threads-retry"
    static let listNote = "side-threads-note"
    static let listScroll = "side-threads-list"
    static let formCancel = "side-thread-cancel"
    static let formName = "side-thread-name"
    static let formStart = "side-thread-start"
    static let formError = "side-thread-create-error"
    static let formEmpty = "side-thread-pick-empty"

    static func listRow(_ id: UUID) -> String {
        "side-threads-row-\(id.uuidString.lowercased())"
    }

    /// Named like the Remove buttons: by the person's display name.
    static func pick(_ name: String) -> String {
        "side-thread-pick-\(name)"
    }
}

// MARK: The list of side threads

/// One line of the list: a thread, who is in it, and its newest reply.
struct SideThreadRow: Equatable, Identifiable {
    let info: SideThreadInfo
    let memberIds: [UUID]
    let last: SideThreadMessage?

    var id: UUID { info.id }
    var isDirect: Bool { info.isDirect }
    /// Newest reply, else when the thread was made, else nothing.
    var activity: Date? { last?.sentAt ?? info.createdAt }
}

enum SideThreadList {
    /// Newest activity first; a thread with no date sorts last, ties by id so the order is stable.
    static func rows(
        threads: [SideThreadInfo],
        memberships: [SideThreadMembership],
        last: [UUID: SideThreadMessage],
        squadId: UUID?
    ) -> [SideThreadRow] {
        var members: [UUID: [UUID]] = [:]
        for membership in memberships where !(members[membership.threadId] ?? []).contains(membership.userId) {
            members[membership.threadId, default: []].append(membership.userId)
        }
        let rows = threads
            .filter { squadId == nil || $0.squadId == squadId }
            .map { SideThreadRow(info: $0, memberIds: members[$0.id] ?? [], last: last[$0.id]) }
        return rows.sorted { lhs, rhs in
            switch (lhs.activity, rhs.activity) {
            case let (a?, b?) where a != b: return a > b
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }

    /// The existing DM between exactly these two people, if there is one.
    static func directThread(in rows: [SideThreadRow], between a: UUID, and b: UUID) -> SideThreadRow? {
        rows.first { $0.isDirect && Set($0.memberIds) == Set([a, b]) }
    }
}

/// What the list shows. Unread dots are not here: side threads have no read state
/// (`sq8_chat_read_state` is one row per squad), and a local guess would lie.
struct SideThreadListState: Equatable {
    enum Load: Equatable {
        case idle
        case loading
        case ready
        case failed
    }

    var load: Load = .idle
    var rows: [SideThreadRow] = []

    var isEmpty: Bool { load == .ready && rows.isEmpty }
}

/// The "new side thread" form: who, and a name when it's a group.
struct SideThreadDraft: Equatable {
    static let titleLimit = 40

    /// Chosen in tap order.
    private(set) var selected: [UUID] = []
    var title = ""
    var creating = false
    var error = ""
    /// Fixed for the draft, so a retry after a lost response reuses the same thread.
    let threadId: UUID

    init(threadId: UUID = UUID()) {
        self.threadId = threadId
    }

    mutating func toggle(_ id: UUID) {
        if let index = selected.firstIndex(of: id) {
            selected.remove(at: index)
        } else {
            selected.append(id)
        }
        error = ""
    }

    func isSelected(_ id: UUID) -> Bool { selected.contains(id) }

    /// One person is a DM; two or more is a side group.
    var isDirect: Bool { selected.count == 1 }
    var isGroup: Bool { selected.count >= 2 }

    var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    var titleTooLong: Bool { trimmedTitle.count > Self.titleLimit }

    var canCreate: Bool { !selected.isEmpty && !creating && !(isGroup && titleTooLong) }

    /// A group with no typed name is called by its members ("Riley, Sam, Jordan").
    func resolvedTitle(names: [UUID: String]) -> String? {
        guard isGroup else { return nil }
        if !trimmedTitle.isEmpty { return trimmedTitle }
        let joined = selected.map { SideThreadCopy.displayName($0, names: names) }.joined(separator: ", ")
        return joined.count <= Self.titleLimit ? joined : String(joined.prefix(Self.titleLimit - 1)) + "…"
    }

    func newThread(squadId: UUID, creator: UUID, names: [UUID: String]) -> NewSideThread? {
        guard canCreate else { return nil }
        return NewSideThread(
            id: threadId,
            squadId: squadId,
            createdBy: creator,
            memberIds: selected.filter { $0 != creator },
            title: resolvedTitle(names: names)
        )
    }
}

extension SideThreadCopy {
    static let listTitle = "Side threads"
    static let listLoading = "Loading side threads…"
    static let listFailed = "Couldn't load your side threads."
    static let listEmpty = "No side threads yet. Start one to talk with part of the squad."
    static let noUnread = "Unread dots aren't shown yet."
    static let newThread = "New"
    static let newTitle = "New side thread"
    static let pickPrompt = "Who's in it?"
    static let noOneToPick = "Invite someone to your squad first. A side thread needs at least one other person."
    static let directHint = "One person starts a direct message."
    static let groupHint = "Two or more people start a side group."
    static let namePlaceholder = "Group name (optional)"
    static let start = "Start"
    static let createFailed = "Couldn't start the side thread. Check your connection and try again."
    static let back = "Back"

    static func displayName(_ id: UUID, names: [UUID: String]) -> String {
        guard let name = names[id], !name.isEmpty else { return "Player" }
        return name
    }

    /// The row's second line: who said it, then what. Your own reply says "You".
    /// A DM leaves the other person's name out because the title is their name.
    static func preview(_ row: SideThreadRow, viewerId: UUID?, names: [UUID: String]) -> String {
        guard let last = row.last else { return "No messages yet" }
        let text = last.body.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if last.senderId == viewerId { return "You: \(text)" }
        if row.isDirect { return text }
        return "\(displayName(last.senderId, names: names)): \(text)"
    }

    /// "9:02 AM" today, "Wed" within the last week, else "Nov 20".
    static func when(_ date: Date, now: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        if calendar.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
        } else if let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day,
                  days > 0, days < 7 {
            formatter.setLocalizedDateFormatFromTemplate("EEE")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("MMM d")
        }
        return formatter.string(from: date)
    }

    /// One spoken line for the row.
    static func spoken(_ row: SideThreadRow, title: String, viewerId: UUID?, names: [UUID: String], now: Date) -> String {
        var parts = [row.isDirect ? "Direct message with \(title)" : "Side group \(title)"]
        parts.append(preview(row, viewerId: viewerId, names: names))
        if let date = row.last?.sentAt { parts.append(when(date, now: now)) }
        return parts.joined(separator: ". ")
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

    static let listLimit = 100
    static let lastBatch = 300
    /// A thread whose newest message is older than the batch is read on its own, up to this many.
    static let lastFallbacks = 20

    func threads(squadId: UUID) async throws -> [SideThreadInfo] {
        let data = try await http.send(
            path: "rest/v1/sq8_threads",
            method: "GET",
            query: [
                URLQueryItem(name: "squad_id", value: "eq.\(squadId.uuidString)"),
                URLQueryItem(name: "select", value: "id,squad_id,kind,title,created_at"),
                URLQueryItem(name: "order", value: "created_at.desc"),
                URLQueryItem(name: "limit", value: "\(Self.listLimit)")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([SideThreadInfo].self, from: data)
    }

    private static func inList(_ ids: [UUID]) -> String {
        "in.(\(ids.map { $0.uuidString.lowercased() }.joined(separator: ",")))"
    }

    func memberships(threadIds: [UUID]) async throws -> [SideThreadMembership] {
        guard !threadIds.isEmpty else { return [] }
        let data = try await http.send(
            path: "rest/v1/sq8_thread_members",
            method: "GET",
            query: [
                URLQueryItem(name: "thread_id", value: Self.inList(threadIds)),
                URLQueryItem(name: "select", value: "thread_id,user_id"),
                URLQueryItem(name: "order", value: "added_at.asc")
            ],
            feature: .messages
        )
        return try BackendJSON.decoder.decode([SideThreadMembership].self, from: data)
    }

    func lastMessages(threadIds: [UUID]) async throws -> [UUID: SideThreadMessage] {
        guard !threadIds.isEmpty else { return [:] }
        let data = try await http.send(
            path: "rest/v1/sq8_thread_messages",
            method: "GET",
            query: [
                URLQueryItem(name: "thread_id", value: Self.inList(threadIds)),
                URLQueryItem(name: "select", value: Self.messageColumns),
                URLQueryItem(name: "order", value: "sent_at.desc,id.desc"),
                URLQueryItem(name: "limit", value: "\(Self.lastBatch)")
            ],
            feature: .messages
        )
        let rows = try BackendJSON.decoder.decode([SideThreadMessage].self, from: data)
        var last: [UUID: SideThreadMessage] = [:]
        for row in rows where last[row.threadId] == nil { last[row.threadId] = row }
        // A full batch may have crowded out a quiet thread's only message.
        if rows.count >= Self.lastBatch {
            for id in threadIds.filter({ last[$0] == nil }).prefix(Self.lastFallbacks) {
                if let newest = try await messages(threadId: id, limit: 1).last { last[id] = newest }
            }
        }
        return last
    }

    private struct ThreadWrite: Encodable {
        let id: UUID
        let squadId: UUID
        let kind: String
        let title: String?
        let createdBy: UUID

        enum CodingKeys: String, CodingKey {
            case id
            case squadId = "squad_id"
            case kind
            case title
            case createdBy = "created_by"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(squadId, forKey: .squadId)
            try container.encode(kind, forKey: .kind)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encode(createdBy, forKey: .createdBy)
        }
    }

    private struct MemberWrite: Encodable {
        let threadId: UUID
        let userId: UUID
        let addedBy: UUID

        enum CodingKeys: String, CodingKey {
            case threadId = "thread_id"
            case userId = "user_id"
            case addedBy = "added_by"
        }
    }

    /// 0017/0024 have no create function. The creator may insert the thread row (they
    /// can't read it back until they're a member, so `return=minimal`), then seats
    /// everyone in one statement: the creator first among them. Both inserts ignore a
    /// duplicate, so repeating the same id after a lost response is safe.
    func create(_ thread: NewSideThread) async throws {
        let row = ThreadWrite(
            id: thread.id,
            squadId: thread.squadId,
            kind: thread.kind,
            title: thread.kind == "dm" ? nil : thread.title,
            createdBy: thread.createdBy
        )
        _ = try await http.send(
            path: "rest/v1/sq8_threads",
            method: "POST",
            body: try BackendJSON.encoder.encode(row),
            prefer: "return=minimal,resolution=ignore-duplicates",
            feature: .messages
        )
        let seated = ([thread.createdBy] + thread.memberIds.filter { $0 != thread.createdBy }).map {
            MemberWrite(threadId: thread.id, userId: $0, addedBy: thread.createdBy)
        }
        _ = try await http.send(
            path: "rest/v1/sq8_thread_members",
            method: "POST",
            body: try BackendJSON.encoder.encode(seated),
            prefer: "return=minimal,resolution=ignore-duplicates",
            feature: .messages
        )
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

    private var byId: [UUID: SideThreadInfo] = [:]
    private var memberIds: [UUID: [UUID]] = [:]
    private var stored: [SideThreadMessage] = []
    private(set) var sent: [SideThreadMessage] = []
    private(set) var created: [NewSideThread] = []
    var failsReads = false
    var failsCreate = false

    /// Tests: an empty server.
    func removeAll() {
        byId = [:]
        memberIds = [:]
        stored = []
    }

    func seed(viewerId: UUID, otherId: UUID, squadId: UUID) {
        let thread = Self.threadId
        byId[thread] = SideThreadInfo(id: thread, squadId: squadId, kind: "side_group", title: "Ranked")
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
        return byId[id]
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

    func threads(squadId: UUID) async throws -> [SideThreadInfo] {
        if failsReads { throw BackendFailure.reconnecting }
        return byId.values.filter { $0.squadId == squadId }.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func memberships(threadIds: [UUID]) async throws -> [SideThreadMembership] {
        if failsReads { throw BackendFailure.reconnecting }
        return threadIds.flatMap { id in (memberIds[id] ?? []).map { SideThreadMembership(threadId: id, userId: $0) } }
    }

    func lastMessages(threadIds: [UUID]) async throws -> [UUID: SideThreadMessage] {
        if failsReads { throw BackendFailure.reconnecting }
        var last: [UUID: SideThreadMessage] = [:]
        for id in threadIds {
            if let newest = stored.filter({ $0.threadId == id }).max(by: { $0.sentAt < $1.sentAt }) { last[id] = newest }
        }
        return last
    }

    func create(_ thread: NewSideThread) async throws {
        if failsCreate { throw BackendFailure.reconnecting }
        created.append(thread)
        byId[thread.id] = SideThreadInfo(
            id: thread.id,
            squadId: thread.squadId,
            kind: thread.kind,
            title: thread.kind == "dm" ? nil : thread.title,
            createdAt: Date()
        )
        memberIds[thread.id] = [thread.createdBy] + thread.memberIds.filter { $0 != thread.createdBy }
    }

    func send(_ message: SideThreadMessage) async throws {
        guard byId[message.threadId] != nil else { throw BackendFailure.rejected("No such thread.") }
        sent.append(message)
        if !stored.contains(where: { $0.id == message.id }) { stored.append(message) }
    }
}
