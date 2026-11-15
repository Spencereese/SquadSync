import Foundation

final class MockAuthService: AuthService {
    private let store: SessionStoring
    private var pendingEmail: String?

    init(store: SessionStoring) {
        self.store = store
    }

    func sendCode(to email: String) async throws {
        pendingEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func verify(email: String, code: String) async throws -> AuthSession {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == pendingEmail, SignInCode.isValid(code) else {
            throw BackendFailure.rejected("Enter the code from your email.")
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

final class MockSquadService: SquadService {
    private var squad: SquadRecord?

    func currentSquad(userId: UUID) async throws -> SquadRecord? { squad }

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

    func leaveAvailable() async -> Bool { false }

    func leaveSquad(newOwner: UUID?) async throws {
        throw InviteProblem.notInSquad
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

    static let morgan = UUID(uuidString: "00000000-0000-0000-0000-00000000B015")!
    static let quinn = UUID(uuidString: "00000000-0000-0000-0000-00000000B016")!
    static let avery = UUID(uuidString: "00000000-0000-0000-0000-00000000B017")!
    static let bench: [(id: UUID, name: String)] = [
        (ChatSeed.otherId, "Riley"),
        (avery, "Avery"),
        (morgan, "Morgan"),
        (quinn, "Quinn")
    ]
}

final class MockChatService: ChatService {
    private var stored: [RemoteMessage] = []

    func seed(_ message: RemoteMessage) {
        if stored.contains(where: { $0.id == message.id }) { return }
        stored.append(message)
    }

    func history(squadId: UUID) async throws -> [RemoteMessage] {
        stored.filter { $0.squadId == squadId }
    }

    func send(_ message: RemoteMessage) async throws {
        if stored.contains(where: { $0.id == message.id }) { return }
        stored.append(message)
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

final class MockSpotService: SpotServing {
    private var call: SpotCall?
    private let viewerId: UUID
    private let ownerId: UUID

    init(viewerId: UUID, ownerId: UUID, call: SpotCall?) {
        self.viewerId = viewerId
        self.ownerId = ownerId
        self.call = call
    }

    func current(squadId: UUID) async throws -> SpotCall? {
        guard call?.squadId == squadId else { return nil }
        return call
    }

    func call(squadId: UUID, game: String, startsAt: Date) async throws -> UUID {
        let label = game.trimmingCharacters(in: .whitespacesAndNewlines)
        if label.isEmpty { throw SpotProblem.gameBlank }
        if let existing = call, existing.closedAt == nil, existing.status == .open || existing.status == .locked {
            throw SpotProblem.alreadyOpen
        }
        let created = SpotCall(
            id: UUID(),
            squadId: squadId,
            callerId: viewerId,
            game: label,
            calledAt: Date(),
            joinUntil: Date().addingTimeInterval(SpotCallRules.window),
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
        if answer == "in" && Date() >= call.joinUntil && !starter { throw SpotProblem.joinClosed }
        if answer == "in" && call.seat(for: viewerId)?.isIn != true && call.filled >= SpotCallRules.cap {
            throw SpotProblem.full
        }
        if let index = call.rsvps.firstIndex(where: { $0.userId == viewerId }) {
            call.rsvps[index].response = answer
            if answer == "out" { call.rsvps[index].ready = false }
        } else {
            call.rsvps.append(SpotRsvp(userId: viewerId, name: "You", response: answer, starter: false, ready: false))
        }
        self.call = call
    }

    func lock(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard SpotCallRules.canLock(call, actorId: viewerId, ownerId: ownerId, now: Date()) else {
            throw SpotProblem.notCaller
        }
        call.status = .locked
        call.lockedAt = Date()
        self.call = call
    }

    func cancel(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard SpotCallRules.canCancel(call, actorId: viewerId, now: Date()) else { throw SpotProblem.notCaller }
        call.status = .cancelled
        call.closedAt = Date()
        self.call = call
    }

    func end(callId: UUID) async throws {
        guard var call, call.id == callId else { throw SpotProblem.missing }
        guard call.status == .locked else { throw SpotProblem.notLocked }
        guard viewerId == call.callerId || viewerId == ownerId else { throw SpotProblem.notCaller }
        call.status = .ended
        call.closedAt = Date()
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
}

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
        guard let squad = try await squads.currentSquad(userId: UUID()) else { throw InviteProblem.revokedOrUnknown }
        if squad.members.count >= 8 { throw InviteProblem.full }
        guard let guest = squads.nextGuest() else { throw InviteProblem.full }
        squads.addMember(id: guest.id, name: guest.name)
        return squad.id
    }

    static func problem(for code: String) -> InviteProblem? {
        switch code.uppercased() {
        case "EXPIRED2": .expired
        case "REVOKED2": .revokedOrUnknown
        case "FULL2345": .full
        case "ALREADY2": .alreadyInASquad
        default: nil
        }
    }
}
