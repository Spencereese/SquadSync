import SwiftUI

@MainActor
@Observable
final class LiveSessionModel {
    var email = ""
    var code = ""
    var phase: Phase = .email
    var profile: UserProfile?
    var displayName = ""
    var defaultGame = "Call of Duty"
    var squad: SquadRecord?
    var log = ChatLog()
    var draft = ""
    var squadName = ""
    var squadNameError = ""
    var status = ""
    var notes: [String] = [
        "Voice, spots, presence, and push stay mock. Leave off -backend live to use that shell."
    ]
    var busy = false

    private let config: BackendConfig
    private let sessionStore: SessionStoring
    private var auth: AuthService
    private let mockProfiles: ProfileService?
    private let mockSquads: SquadService?
    private let mockChat: ChatService?
    private var poll: Task<Void, Never>?

    enum Phase {
        case email
        case code
        case ready
    }

    init(config: BackendConfig, backend: BackendMode = .live, sessionStore: SessionStoring? = nil) {
        self.config = config
        if backend == .mock {
            let store = sessionStore ?? MemorySessionStore()
            let session = AuthSession(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                email: "spencer@squadsync.app"
            )
            try? store.save(session)
            self.sessionStore = store
            self.auth = MockAuthService(store: store)
            self.mockProfiles = MockProfileService()
            self.mockSquads = MockSquadService()
            self.mockChat = MockChatService()
            self.phase = .ready
            self.email = session.email
        } else {
            let store = sessionStore ?? KeychainSessionStore()
            self.sessionStore = store
            self.auth = SupabaseAuthService(config: config, store: store)
            self.mockProfiles = nil
            self.mockSquads = nil
            self.mockChat = nil
        }
    }

    func restore() async {
        do {
            guard let session = try auth.restore() else { return }
            phase = .ready
            email = session.email
            await refresh(session)
            startPolling(session)
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Session restore failed. \(error)"
        }
    }

    func sendCode() async {
        await run {
            try await auth.sendCode(to: email)
            phase = .code
            status = "Check \(email). Enter the code from your email."
        }
    }

    func verify() async {
        let trimmed = SignInCode.normalized(code)
        guard SignInCode.isValid(trimmed) else {
            status = "Enter the code from your email."
            return
        }
        code = trimmed
        await run {
            let session = try await auth.verify(email: email, code: code)
            phase = .ready
            status = ""
            await refresh(session)
            startPolling(session)
        }
    }

    func saveProfile() async {
        guard var profile else { return }
        profile.displayName = displayName
        profile.defaultGame = defaultGame
        self.profile = profile
        await run {
            let session = try requiredSession()
            try await profileService(session).save(profile)
            status = "Profile saved."
        }
    }

    func createSquad() async {
        if let error = SquadName.validationError(squadName) {
            squadNameError = error
            return
        }
        squadNameError = ""
        let name = SquadName.normalized(squadName)
        await run {
            let session = try requiredSession()
            let service = squadService(session)
            squad = try await service.createSquad(ownerId: session.userId, name: name)
            status = "Squad created."
            await loadChat(session)
        }
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let squad else { return }
        let session: AuthSession
        do {
            session = try requiredSession()
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Session restore failed. \(error)"
            return
        }
        let id = UUID()
        let now = Date()
        log.beginSend(id: id, senderId: session.userId, body: text, now: now)
        draft = ""
        await deliver(RemoteMessage(id: id, squadId: squad.id, senderId: session.userId, body: text, sentAt: now), session: session)
    }

    func retry(_ id: UUID) async {
        guard let squad, let entry = log.entries.first(where: { $0.id == id }) else { return }
        let session: AuthSession
        do {
            session = try requiredSession()
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Session restore failed. \(error)"
            return
        }
        log.retry(id: id)
        let message = RemoteMessage(id: id, squadId: squad.id, senderId: entry.senderId, body: entry.body, sentAt: entry.sentAt)
        await deliver(message, session: session)
    }

    func signOut() async {
        poll?.cancel()
        poll = nil
        do {
            try await auth.signOut()
            status = ""
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Sign out failed. \(error)"
        }
        profile = nil
        squad = nil
        squadName = ""
        squadNameError = ""
        log = ChatLog()
        phase = .email
    }

    private func requiredSession() throws -> AuthSession {
        guard let session = try auth.restore() else { throw BackendFailure.notSignedIn }
        return session
    }

    private func deliver(_ message: RemoteMessage, session: AuthSession) async {
        do {
            try await chatService(session).send(message)
            log.markSent(id: message.id)
        } catch let failure as BackendFailure {
            log.markFailed(id: message.id)
            note(failure)
        } catch {
            log.markFailed(id: message.id)
            status = error.localizedDescription
        }
    }

    private func refresh(_ session: AuthSession) async {
        await run {
            let profiles = profileService(session)
            let loaded = try await profiles.loadOrCreate(userId: session.userId, email: session.email)
            profile = loaded
            displayName = loaded.displayName
            defaultGame = loaded.defaultGame
            let squads = squadService(session)
            squad = try await squads.currentSquad(userId: session.userId)
            await loadChat(session)
        }
    }

    private func loadChat(_ session: AuthSession) async {
        guard let squad else { return }
        do {
            let chat = chatService(session)
            let rows = try await chat.history(squadId: squad.id)
            log.ingest(rows.map { $0.entry() })
            log.markRead(at: Date())
            try? await chat.markRead(squadId: squad.id, userId: session.userId, at: Date(), messageId: log.ordered.last?.id)
        } catch let failure as BackendFailure {
            note(failure)
        } catch {
            status = error.localizedDescription
        }
    }

    private func startPolling(_ session: AuthSession) {
        poll?.cancel()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.pollOnce(session)
            }
        }
        if !notes.contains(where: { $0.contains("every few seconds") }) {
            notes.append("New messages are checked every few seconds. A live realtime publication for chat is not confirmed on this project.")
        }
    }

    private func pollOnce(_ session: AuthSession) async {
        guard let squad else { return }
        do {
            let rows = try await chatService(session).history(squadId: squad.id)
            log.ingest(rows.map { $0.entry() })
        } catch let failure as BackendFailure {
            note(failure)
            if case .notSetUp(.messages) = failure { poll?.cancel() }
        } catch {
            status = error.localizedDescription
        }
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do {
            try await work()
        } catch let failure as BackendFailure {
            note(failure)
        } catch {
            status = error.localizedDescription
        }
    }

    private func profileService(_ session: AuthSession) -> ProfileService {
        mockProfiles ?? SupabaseProfileService(config: config, accessToken: session.accessToken)
    }

    private func squadService(_ session: AuthSession) -> SquadService {
        mockSquads ?? SupabaseSquadService(config: config, accessToken: session.accessToken)
    }

    private func chatService(_ session: AuthSession) -> ChatService {
        mockChat ?? SupabaseChatService(config: config, accessToken: session.accessToken)
    }

    private func note(_ failure: BackendFailure) {
        switch failure {
        case .notConfigured:
            status = config.configurationError
                ?? "Supabase is not configured. Copy Config.example.xcconfig to Config.xcconfig and paste the anon key."
        case .notSignedIn:
            status = "Sign in again."
        case .notSetUp(let feature):
            let line = "\(feature.rawValue) are not set up yet."
            status = line
            if !notes.contains(line) { notes.append(line) }
        case .rejected(let message):
            status = message
        }
    }
}

struct LiveSessionView: View {
    @State private var model: LiveSessionModel

    init(config: BackendConfig = .fromBundle(), backend: BackendMode = .live) {
        _model = State(initialValue: LiveSessionModel(config: config, backend: backend))
    }

    var body: some View {
        NavigationStack {
            Group {
                if model.phase == .ready {
                    ready
                } else {
                    signIn
                }
            }
            .padding(SQSpace.l)
            .navigationTitle("SquadSync")
            .toolbar {
                if model.phase == .ready {
                    Button("Sign out") { Task { await model.signOut() } }
                }
            }
        }
        .task { await model.restore() }
    }

    private var signIn: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            Text("Email code")
                .font(.title2.weight(.semibold))
            TextField("Email", text: Binding(get: { model.email }, set: { model.email = $0 }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            if model.phase == .code {
                TextField("Code", text: Binding(get: { model.code }, set: { model.code = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                Text("Enter the code from your email.")
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                Button("Verify") { Task { await model.verify() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.busy)
            } else {
                Button("Send code") { Task { await model.sendCode() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.busy)
            }
            if !model.status.isEmpty {
                Text(model.status).font(.footnote).foregroundStyle(SQColor.muted)
            }
            notes
        }
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            if model.profile != nil {
                TextField("Display name", text: Binding(get: { model.displayName }, set: { model.displayName = $0 }))
                    .textFieldStyle(.roundedBorder)
                TextField("Default game", text: Binding(get: { model.defaultGame }, set: { model.defaultGame = $0 }))
                    .textFieldStyle(.roundedBorder)
                Button("Save profile") { Task { await model.saveProfile() } }
                    .disabled(model.busy)
            }
            if let squad = model.squad {
                Text(SquadTitle.line(name: squad.name, memberCount: squad.members.count))
                    .font(.headline)
                ForEach(squad.members) { member in
                    Text(member.isOwner ? "\(member.displayName) · Owner" : member.displayName)
                }
                ScrollView {
                    ForEach(model.log.ordered) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.body).frame(maxWidth: .infinity, alignment: .leading)
                            Text(label(for: entry))
                                .font(.caption)
                                .foregroundStyle(SQColor.muted)
                            if entry.delivery == .failed {
                                Button("Retry") { Task { await model.retry(entry.id) } }
                            }
                        }
                        .padding(.vertical, SQSpace.xs)
                    }
                }
                Text("Unread \(model.log.unreadCount(viewerId: model.profile?.id ?? UUID()))")
                    .font(.caption)
                HStack {
                    TextField("Message", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                        .textFieldStyle(.roundedBorder)
                    Button("Send") { Task { await model.send() } }
                }
            } else {
                Text("You're not in a squad yet.")
                TextField("Squad name", text: Binding(get: { model.squadName }, set: { model.squadName = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("squad-name")
                if !model.squadNameError.isEmpty {
                    Text(model.squadNameError)
                        .font(.footnote)
                        .foregroundStyle(SQColor.danger)
                }
                Button("Create squad") { Task { await model.createSquad() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.busy)
            }
            if !model.status.isEmpty {
                Text(model.status).font(.footnote).foregroundStyle(SQColor.muted)
            }
            notes
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(model.notes, id: \.self) { note in
                Text(note).font(.caption).foregroundStyle(SQColor.muted)
            }
        }
    }

    private func label(for entry: ChatEntry) -> String {
        switch entry.delivery {
        case .sending: "Sending"
        case .sent: "Sent"
        case .failed: "Failed"
        }
    }
}
