import Foundation

// The mock services keep plain dictionaries and arrays. Their only app caller is
// the main-actor LiveSessionModel, but its async calls used to run on the global
// executor, so loadChat's reads(squadId:) could race markRead's write and crash
// (Mac pass c165577). Isolating each mock with state to the main actor serializes
// every access, matching how the model already uses them.

/// Stays nonisolated because `restore()` is a synchronous requirement. Its one
/// piece of mutable state sits behind a lock.
final class MockAuthService: AuthService {
    /// GoTrue's words for a wrong or expired code, so the app maps it the same way.
    static let wrongCodeText = "Token has expired or is invalid"
    /// The mock onboarding code. Any other code is wrong when `acceptedCode` is set.
    static let onboardingCode = "123456"

    private let store: SessionStoring
    private let lock = NSLock()
    private var pendingEmail: String?
    /// nil accepts any well-formed code (the older mock behavior).
    private let acceptedCode: String?
    /// Thrown by every send, e.g. `.reconnecting` for offline.
    private let sendFailure: BackendFailure?
    private let delay: TimeInterval
    private var sends = 0
    /// How many codes went out. Read under the lock.
    var sendCount: Int { lock.withLock { sends } }

    init(store: SessionStoring, acceptedCode: String? = nil, sendFailure: BackendFailure? = nil, delay: TimeInterval = 0) {
        self.store = store
        self.acceptedCode = acceptedCode
        self.sendFailure = sendFailure
        self.delay = delay
    }

    private func pause() async throws {
        if delay > 0 { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
    }

    func sendCode(to email: String) async throws {
        try await pause()
        if let sendFailure { throw sendFailure }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        lock.withLock {
            pendingEmail = trimmed
            sends += 1
        }
    }

    func verify(email: String, code: String) async throws -> AuthSession {
        try await pause()
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let expected = lock.withLock { pendingEmail }
        guard trimmed == expected, SignInCode.isValid(code), acceptedCode == nil || code == acceptedCode else {
            throw BackendFailure.rejected(Self.wrongCodeText)
        }
        let session = AuthSession(
            accessToken: "mock-access",
            refreshToken: "mock-refresh",
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: trimmed
        )
        try store.save(session)
        return session
    }

    func restore() throws -> AuthSession? { try store.load() }

    func prepareSession(now: Date) async throws -> AuthSession? { try store.load() }

    func signOut() async throws { try store.clear() }
}

@MainActor
final class MockProfileService: ProfileService {
    private var profiles: [UUID: UserProfile] = [:]

    func loadOrCreate(userId: UUID, email: String) async throws -> UserProfile {
        if let existing = profiles[userId] { return existing }
        let name = email.split(separator: "@").first.map(String.init) ?? "Player"
        let created = UserProfile(id: userId, displayName: name, defaultGame: "Call of Duty")
        profiles[userId] = created
        return created
    }

    func save(_ profile: UserProfile) async throws {
        profiles[profile.id] = profile
    }
}

@MainActor
final class MockSquadService: SquadService {
    private var squad: SquadRecord?
    private var viewerJoined = true
    private var leftUser: (id: UUID, name: String)?

    func currentSquad(userId: UUID) async throws -> SquadRecord? {
        guard viewerJoined else { return nil }
        return squad
    }

    func seed(ownerId: UUID, name: String) -> SquadRecord {
        let created = SquadRecord(
            id: ChatSeed.squadId,
            ownerId: ownerId,
            name: name,
            members: [SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true)]
        )
        squad = created
        return created
    }

    func seedSpotSquad(ownerId: UUID) -> SquadRecord {
        let created = SquadRecord(
            id: ChatSeed.squadId,
            ownerId: ownerId,
            name: "Friday",
            members: [
                SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true),
                SquadMemberRecord(id: SpotSeed.alex, displayName: "Alex", defaultGame: "Warzone", isOwner: false),
                SquadMemberRecord(id: SpotSeed.jordan, displayName: "Jordan", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: SpotSeed.sam, displayName: "Sam", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: SpotSeed.casey, displayName: "Casey", defaultGame: "", isOwner: false)
            ]
        )
        squad = created
        return created
    }

    func addMember(id: UUID, name: String) {
        guard var squad else { return }
        guard !squad.members.contains(where: { $0.id == id }) else { return }
        squad.members.append(SquadMemberRecord(id: id, displayName: name, defaultGame: "", isOwner: false))
        self.squad = squad
    }

    func createSquad(ownerId: UUID, name: String) async throws -> SquadRecord {
        let trimmed = SquadName.normalized(name)
        if let error = SquadName.validationError(trimmed) {
            throw BackendFailure.rejected(error)
        }
        let created = SquadRecord(
            id: UUID(),
            ownerId: ownerId,
            name: trimmed,
            members: [SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true)]
        )
        squad = created
        return created
    }

    func seedAlmostFull(ownerId: UUID) -> SquadRecord {
        let created = SquadRecord(
            id: ChatSeed.squadId,
            ownerId: ownerId,
            name: "Friday",
            members: [
                SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true),
                SquadMemberRecord(id: SpotSeed.alex, displayName: "Alex", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: SpotSeed.jordan, displayName: "Jordan", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: SpotSeed.sam, displayName: "Sam", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: SpotSeed.casey, displayName: "Casey", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: MockSquadService.morgan, displayName: "Morgan", defaultGame: "", isOwner: false),
                SquadMemberRecord(id: MockSquadService.quinn, displayName: "Quinn", defaultGame: "", isOwner: false)
            ]
        )
        squad = created
        return created
    }

    func leaveAvailable() async -> Bool { true }

    func renameAvailable() async -> Bool { true }

    func pushTokenRPCAvailable() async -> Bool { false }

    func registerPushToken(_ token: String) async throws {}

    func unregisterPushToken(_ token: String) async throws {}

    func renameSquad(squadId: UUID, name: String?) async throws {
        guard var squad, squad.id == squadId else { throw BackendFailure.rejected(RenameFailure.message("missing")) }
        let trimmed = SquadName.normalized(name ?? "")
        if let error = SquadName.renameError(trimmed) { throw BackendFailure.rejected(error) }
        squad.name = trimmed
        self.squad = squad
    }

    func leaveSquad(newOwner: UUID?) async throws {
        guard viewerJoined, let squad else { throw InviteProblem.alreadyLeft }
        guard let owner = squad.members.first(where: { $0.isOwner }) else { throw InviteProblem.alreadyLeft }
        if squad.members.count > 1 {
            guard let newOwner,
                  newOwner != owner.id,
                  squad.members.contains(where: { $0.id == newOwner })
            else { throw InviteProblem.ownerMustTransfer }
            var members = squad.members.filter { $0.id != owner.id }
            if let index = members.firstIndex(where: { $0.id == newOwner }) {
                members[index].isOwner = true
            }
            leftUser = (owner.id, owner.displayName)
            viewerJoined = false
            self.squad = SquadRecord(id: squad.id, ownerId: newOwner, name: squad.name, members: members)
            return
        }
        leftUser = (owner.id, owner.displayName)
        viewerJoined = false
        self.squad = nil
    }

    func rejoinLeftViewer() -> UUID? {
        guard !viewerJoined, var squad, let leftUser else { return nil }
        guard squad.members.count < 8 else { return nil }
        squad.members.append(SquadMemberRecord(id: leftUser.id, displayName: leftUser.name, defaultGame: "", isOwner: false))
        self.squad = squad
        viewerJoined = true
        self.leftUser = nil
        return squad.id
    }

    func removeMember(squadId: UUID, userId: UUID) async throws {
        guard var squad, squad.id == squadId else { throw InviteProblem.other("You can't remove that person.") }
        guard let member = squad.members.first(where: { $0.id == userId }) else {
            throw InviteProblem.other("You can't remove that person.")
        }
        guard !member.isOwner else { throw InviteProblem.other("The owner stays in the squad.") }
        squad.members.removeAll { $0.id == userId }
        self.squad = squad
    }

    func nextGuest() -> (id: UUID, name: String)? {
        guard let squad else { return nil }
        return Self.bench.first { guest in !squad.members.contains { $0.id == guest.id } }
    }

    nonisolated static let morgan = UUID(uuidString: "00000000-0000-0000-0000-00000000B015")!
    nonisolated static let quinn = UUID(uuidString: "00000000-0000-0000-0000-00000000B016")!
    nonisolated static let avery = UUID(uuidString: "00000000-0000-0000-0000-00000000B017")!
    nonisolated static let bench: [(id: UUID, name: String)] = [
        (ChatSeed.otherId, "Riley"),
        (avery, "Avery"),
        (morgan, "Morgan"),
        (quinn, "Quinn")
    ]
}

@MainActor
final class MockChatService: ChatService {
    private var stored: [RemoteMessage] = []
    /// Mock of a server without 0014's `reply_to_id`.
    var replies: Bool
    /// Mock of a history read that keeps failing until Retry brings the server back.
    var historyDown: Bool
    /// Mock of a slow history read, so the loading row can be seen.
    var historyDelay: TimeInterval

    init(replies: Bool = true, historyDown: Bool = false, historyDelay: TimeInterval = 0) {
        self.replies = replies
        self.historyDown = historyDown
        self.historyDelay = historyDelay
    }

    func repliesAvailable() async -> Bool { replies }

    func seedRead(userId: UUID, at date: Date) {
        reads[userId] = date
    }

    func seedReaction(_ mark: ReactionMark) {
        guard !reactionMarks.contains(mark) else { return }
        reactionMarks.append(mark)
    }

    func seed(_ message: RemoteMessage) {
        if stored.contains(where: { $0.id == message.id }) { return }
        stored.append(message)
    }

    func history(squadId: UUID) async throws -> [RemoteMessage] {
        if historyDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(historyDelay * 1_000_000_000))
        }
        if historyDown { throw BackendFailure.rejected(ChatHistoryState.failedText) }
        // Like live: the newest `historyLimit` rows, oldest first.
        return Array(ordered(squadId).suffix(SupabaseChatService.historyLimit))
    }

    /// Mock of an older-page read that fails until Retry brings it back.
    var olderDown = false
    /// Mock of a slow older-page read, so the loading row can be seen.
    var olderDelay: TimeInterval = 0
    /// How many older pages were asked for (tests).
    private(set) var olderReads = 0
    /// UI tests (`-mock-older-gate`): each older-page read waits here until the
    /// test releases it, one read per release.
    var olderGated = false
    private(set) var olderReleases = 0
    private var olderTickets = 0

    func releaseOlder() { olderReleases += 1 }

    func older(squadId: UUID, before: ChatPageCursor, limit: Int) async throws -> [RemoteMessage] {
        olderReads += 1
        if olderGated {
            olderTickets += 1
            let ticket = olderTickets
            while olderReleases < ticket {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        if olderDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(olderDelay * 1_000_000_000))
        }
        if olderDown { throw BackendFailure.reconnecting }
        let earlier = ordered(squadId).filter { before.precedes(sentAt: $0.sentAt, id: $0.id) }
        return Array(earlier.suffix(limit))
    }

    func message(squadId: UUID, id: UUID) async throws -> RemoteMessage? {
        stored.first { $0.squadId == squadId && $0.id == id }
    }

    /// Same order as the server's paging index: time, then id.
    private func ordered(_ squadId: UUID) -> [RemoteMessage] {
        stored.filter { $0.squadId == squadId }.sorted { lhs, rhs in
            if lhs.sentAt != rhs.sentAt { return lhs.sentAt < rhs.sentAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    func send(_ message: RemoteMessage) async throws -> SendReceipt {
        var probe = URLRequest(url: URL(string: "https://example.supabase.co/rest/v1/sq8_messages")!)
        probe.httpMethod = "POST"
        if DebugSendFailures.failIfNeeded(probe) {
            throw BackendFailure.rejected("Debug send failed.")
        }
        if let existing = stored.first(where: { $0.id == message.id }) {
            let matches = existing.squadId == message.squadId
                && existing.senderId == message.senderId
                && existing.body == message.body
            return matches ? .stored : .missing
        }
        if message.replyToId != nil, !replies {
            throw BackendFailure.rejected("Could not find the 'reply_to_id' column of 'sq8_messages'")
        }
        stored.append(message)
        return .stored
    }

    func newer(squadId: UUID, after: Date) async throws -> [RemoteMessage] {
        stored.filter { $0.squadId == squadId && $0.sentAt > after }
    }

    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws {
        reads[userId] = at
    }

    func reactions(squadId: UUID) async throws -> [ReactionMark] { reactionMarks }

    func setReaction(squadId: UUID, messageId: UUID, userId: UUID, emoji: String, active: Bool) async throws {
        if active {
            reactionMarks.removeAll { $0.messageId == messageId && $0.userId == userId }
            reactionMarks.append(ReactionMark(messageId: messageId, userId: userId, emoji: emoji))
        } else {
            reactionMarks.removeAll { $0.messageId == messageId && $0.userId == userId && $0.emoji == emoji }
        }
    }

    func reads(squadId: UUID) async throws -> [MemberRead] {
        reads.map { MemberRead(userId: $0.key, lastReadAt: $0.value) }
    }

    func ownReadAt(squadId: UUID, userId: UUID) async throws -> Date? { reads[userId] }

    private var reactionMarks: [ReactionMark] = []
    private var reads: [UUID: Date] = [:]
}

@MainActor
final class MockSpotService: SpotServing {
    private var call: SpotCall?
    private let viewerId: UUID
    private let ownerId: UUID
    private let now: () -> Date

    /// Finished calls, newest last. A new call archives the one it replaces.
    private var past: [SpotCall]
    /// Mock of a server without the spot RPCs or the history read, for the honest-degrade UI.
    private let serverMissing: Bool

    init(
        viewerId: UUID,
        ownerId: UUID,
        call: SpotCall?,
        past: [SpotCall] = [],
        serverMissing: Bool = false,
        now: @escaping () -> Date = { Date() }
    ) {
        self.viewerId = viewerId
        self.ownerId = ownerId
        self.call = call
        self.past = past
        self.serverMissing = serverMissing
        self.now = now
    }

    func history(squadId: UUID, limit: Int) async throws -> [SpotCall] {
        if serverMissing { throw BackendFailure.notSetUp(.squad) }
        var finished = past.filter { $0.squadId == squadId }
        if let call, call.squadId == squadId, call.closedAt != nil {
            finished.append(call)
        }
        return Array(finished.sorted { $0.calledAt > $1.calledAt }.prefix(max(1, limit)))
    }

    func current(squadId: UUID) async throws -> SpotCall? {
        guard call?.squadId == squadId else { return nil }
        return call
    }

    func call(squadId: UUID, game: String, startsAt: Date) async throws -> UUID {
        if serverMissing { throw SpotProblem.unavailable }
        let label = game.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty { throw SpotProblem.gameBlank }
        if let existing = call, blocksAnotherCall(existing) {
            throw SpotProblem.alreadyOpen
        }
        if var replaced = call {
            // 0013 closes the old unlocked row when the next call starts.
            if replaced.closedAt == nil {
                replaced.closedAt = now()
                replaced.status = now() >= replaced.joinUntil ? .expired : .ended
            }
            past.removeAll { $0.id == replaced.id }
            past.append(replaced)
        }
        let created = SpotCall(
            id: UUID(),
            squadId: squadId,
            callerId: viewerId,
            game: label,
            calledAt: now(),
            joinUntil: now().addingTimeInterval(SpotCallRules.window),
            lockedAt: nil,
            closedAt: nil,
            status: .open,
            rsvps: [SpotRsvp(userId: viewerId, name: "You", response: "in", starter: false, ready: false)]
        )
        call = created
        return created.id
    }

    func rsvp(callId: UUID, response: String) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        let answer = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard answer == "in" || answer == "out" else { throw SpotProblem.badResponse }
        if call.status != .open || call.closedAt != nil { throw SpotProblem.closed }
        if call.lockedAt != nil { throw SpotProblem.locked }
        let starter = call.seat(for: viewerId)?.starter == true
        if answer == "in" && now() >= call.joinUntil && !starter { throw SpotProblem.joinClosed }
        if answer == "in" && call.seat(for: viewerId)?.isIn != true && call.filled >= SpotCallRules.cap {
            throw SpotProblem.full
        }
        if let index = call.rsvps.firstIndex(where: { $0.userId == viewerId }) {
            if call.rsvps[index].response != answer {
                call.rsvps[index].ready = false
            }
            call.rsvps[index].response = answer
        } else {
            call.rsvps.append(SpotRsvp(userId: viewerId, name: "You", response: answer, starter: false, ready: false))
        }
        self.call = call
    }

    func lock(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        let allowed = viewerId == call.callerId || viewerId == ownerId
        if call.serverOwnsLock && allowed && !SpotLockRule.allows(call) {
            throw SpotProblem.notReady
        }
        guard SpotCallRules.canLock(call, actorId: viewerId, ownerId: ownerId, now: now()) else {
            throw SpotProblem.notCaller
        }
        call.status = .locked
        call.lockedAt = now()
        self.call = call
    }

    /// 0013 closes an unlocked call once `join_until` has passed, and a lock older than six hours.
    private func blocksAnotherCall(_ existing: SpotCall) -> Bool {
        guard existing.closedAt == nil else { return false }
        if existing.lockedAt != nil || existing.status == .locked {
            guard let lockedAt = existing.lockedAt else { return true }
            return now().timeIntervalSince(lockedAt) < 6 * 60 * 60
        }
        if existing.status == .expired { return false }
        return now() < existing.joinUntil
    }

    func cancel(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard SpotCallRules.canCancel(call, actorId: viewerId, now: now()) else { throw SpotProblem.notCaller }
        call.status = .cancelled
        call.closedAt = now()
        self.call = call
    }

    func end(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard call.status == .locked else { throw SpotProblem.notLocked }
        guard viewerId == call.callerId || viewerId == ownerId else { throw SpotProblem.notCaller }
        call.status = .ended
        call.closedAt = now()
        self.call = call
    }

    func setReady(callId: UUID, userId: UUID, ready: Bool) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard call.status == .open else { throw SpotProblem.locked }
        guard let index = call.rsvps.firstIndex(where: { $0.userId == userId && $0.isIn }) else {
            throw SpotProblem.badResponse
        }
        call.rsvps[index].ready = ready
        self.call = call
    }

    func serverCapabilities() async -> SpotServerCapabilities {
        return .unavailable
    }
}

@MainActor
final class MockInviteService: InviteServing {
    private let squads: MockSquadService

    init(squads: MockSquadService) {
        self.squads = squads
    }

    func createInvite() async throws -> InviteTicket {
        guard let squad = try await squads.currentSquad(userId: UUID()) else { throw InviteProblem.notOwner }
        if squad.members.count >= 8 { throw InviteProblem.full }
        return InviteTicket(code: "ABCD2345", squadId: squad.id)
    }

    func join(code: String) async throws -> UUID {
        if let problem = Self.problem(for: code) { throw problem }
        if try await squads.currentSquad(userId: UUID()) == nil {
            if let rejoined = squads.rejoinLeftViewer() { return rejoined }
            throw InviteProblem.revokedOrUnknown
        }
        guard let squad = try await squads.currentSquad(userId: UUID()) else { throw InviteProblem.revokedOrUnknown }
        if squad.members.count >= 8 { throw InviteProblem.full }
        guard let guest = squads.nextGuest() else { throw InviteProblem.full }
        squads.addMember(id: guest.id, name: guest.name)
        return squad.id
    }

    nonisolated static func problem(for code: String) -> InviteProblem? {
        switch code.uppercased() {
        case "EXPIRED2": .expired
        case "REVOKED2": .revokedOrUnknown
        case "FULL2345": .full
        case "ALREADY2": .alreadyInASquad
        default: nil
        }
    }
}

/// Mock thread for the message polish scenarios: two days, groups, reactions,
/// a reply, an unread run, and read receipts on the latest message.
enum ChatPolishSeed {
    static func id(_ suffix: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", 0x300 + suffix))!
    }

    /// Alex's "Who's on tonight?", with reactions and the reply's original.
    static let question = id(0x21)
    static let longMessage = id(0x24)
    /// Jordan's "Lobby's up", the first message you haven't read.
    static let firstUnread = id(0x25)
    /// Sam's reply, the latest message.
    static let reply = id(0x26)
    static let warmUps = 10

    struct Thread {
        var messages: [RemoteMessage]
        var reads: [MemberRead]
        var reactions: [ReactionMark]
    }

    static func thread(viewerId: UUID, squadId: UUID, now: Date, calendar: Calendar = .current, replies: Bool = true) -> Thread {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86_400)
        let evening = yesterday.addingTimeInterval(20 * 3600)
        var messages: [RemoteMessage] = []
        func add(_ suffix: Int, _ sender: UUID, _ body: String, _ at: Date, replyTo: UUID? = nil) {
            messages.append(RemoteMessage(id: id(suffix), squadId: squadId, senderId: sender, body: body, sentAt: at, replyToId: replyTo))
        }
        let cycle = [SpotSeed.alex, SpotSeed.jordan, viewerId, SpotSeed.sam]
        for index in 0..<warmUps {
            add(index, cycle[index % cycle.count], "Warm-up \(index + 1)", evening.addingTimeInterval(Double(index) * 7 * 60))
        }
        add(0x11, SpotSeed.jordan, "GG last night", evening.addingTimeInterval(90 * 60))
        add(0x12, SpotSeed.jordan, "Same time tomorrow?", evening.addingTimeInterval(91 * 60))
        add(0x13, viewerId, "I'm in", evening.addingTimeInterval(100 * 60))

        // Today's run fits between midnight and now, even just after midnight.
        let start = max(now.addingTimeInterval(-30 * 60), today.addingTimeInterval(30))
        let scale = max(now.addingTimeInterval(-30).timeIntervalSince(start), 0) / (30 * 60)
        func at(_ minutes: Double) -> Date { start.addingTimeInterval(minutes * 60 * scale) }
        add(0x21, SpotSeed.alex, "Who's on tonight?", at(0))
        add(0x22, SpotSeed.alex, "I can do 9", at(1))
        add(0x23, viewerId, "Count me in", at(10))
        add(0x24, viewerId, "Bringing Jordan too, and this one is long on purpose so it has to wrap at large text instead of getting cut off", at(11))
        add(0x25, SpotSeed.jordan, "Lobby's up", at(20))
        add(0x26, SpotSeed.sam, "Me", at(21), replyTo: replies ? question : nil)

        let reads = [
            MemberRead(userId: viewerId, lastReadAt: at(12)),
            MemberRead(userId: SpotSeed.alex, lastReadAt: at(21.5)),
            MemberRead(userId: SpotSeed.jordan, lastReadAt: at(21.5)),
            MemberRead(userId: SpotSeed.casey, lastReadAt: at(10))
        ]
        let reactions = [
            ReactionMark(messageId: question, userId: viewerId, emoji: "👍"),
            ReactionMark(messageId: question, userId: SpotSeed.jordan, emoji: "👍"),
            ReactionMark(messageId: question, userId: SpotSeed.alex, emoji: "🔥")
        ]
        return Thread(messages: messages, reads: reads, reactions: reactions)
    }
}
