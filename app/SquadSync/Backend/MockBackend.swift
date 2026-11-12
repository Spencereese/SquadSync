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
        guard trimmed == pendingEmail, code.count == 6, code.allSatisfy(\.isNumber) else {
            throw BackendFailure.rejected("Enter the 6-digit code for that email.")
        }
        let session = AuthSession(
            accessToken: "mock-access",
            refreshToken: "mock-refresh",
            userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            email: trimmed
        )
        store.save(session)
        return session
    }

    func restore() -> AuthSession? { store.load() }

    func signOut() async { store.clear() }
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

    func createSquad(ownerId: UUID) async throws -> SquadRecord {
        let created = SquadRecord(
            id: UUID(),
            ownerId: ownerId,
            members: [SquadMemberRecord(id: ownerId, displayName: "You", defaultGame: "Call of Duty", isOwner: true)]
        )
        squad = created
        return created
    }
}

final class MockChatService: ChatService {
    private var stored: [RemoteMessage] = []

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

    func markRead(squadId: UUID, userId: UUID, at: Date, messageId: UUID?) async throws {}
}
