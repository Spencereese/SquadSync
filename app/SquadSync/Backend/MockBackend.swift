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
            members: [
                SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true),
                SquadMemberRecord(id: ChatSeed.otherId, displayName: "Riley", defaultGame: "", isOwner: false)
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

final class MockInviteService: InviteServing {
    private let squads: MockSquadService

    init(squads: MockSquadService) {
        self.squads = squads
    }

    func createInvite() async throws -> InviteTicket {
        guard let squad = try await squads.currentSquad(userId: UUID()) else { throw InviteProblem.notOwner }
        return InviteTicket(code: "ABCD2345", squadId: squad.id)
    }

    func join(code: String) async throws -> UUID {
        if let problem = Self.problem(for: code) { throw problem }
        guard let squad = try await squads.currentSquad(userId: UUID()) else { throw InviteProblem.revokedOrUnknown }
        squads.addMember(id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!, name: "Riley")
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
