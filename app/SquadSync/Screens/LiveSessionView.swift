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
    var status = ""
    var notes: [String] = [
        "Voice, spots, presence, and push stay mock. Leave off -backend live to use that shell."
    ]
    var busy = false

    private let config: BackendConfig
    private let sessionStore: SessionStoring
    private var auth: AuthService
    private var poll: Task<Void, Never>?

    enum Phase {
        case email
        case code
        case ready
    }

    init(config: BackendConfig, sessionStore: SessionStoring = KeychainSessionStore()) {
        self.config = config
        self.sessionStore = sessionStore
        self.auth = SupabaseAuthService(config: config, store: sessionStore)
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
            status = "Check \(email) for a 6-digit code."
        }
    }

    func verify() async {
        await run {
            let session = try await auth.verify(email: email, code: code)
            phase = .ready
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
            try await SupabaseProfileService(config: config, accessToken: session.accessToken).save(profile)
            status = "Profile saved."
        }
    }

    func createSquad() async {
        await run {
            let session = try requiredSession()
            let service = SupabaseSquadService(config: config, accessToken: session.accessToken)
            squad = try await service.createSquad(ownerId: session.userId)
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
            status = "Signed out."
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Sign out failed. \(error)"
        }
        profile = nil
        squad = nil
        log = ChatLog()
        phase = .email
    }

    private func requiredSession() throws -> AuthSession {
        guard let session = try auth.restore() else { throw BackendFailure.notSignedIn }
        return session
    }

    private func deliver(_ message: RemoteMessage, session: AuthSession) async {
        do {
            try await SupabaseChatService(config: config, accessToken: session.accessToken).send(message)
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
            let profiles = SupabaseProfileService(config: config, accessToken: session.accessToken)
            let loaded = try await profiles.loadOrCreate(userId: session.userId, email: session.email)
            profile = loaded
            displayName = loaded.displayName
            defaultGame = loaded.defaultGame
            let squads = SupabaseSquadService(config: config, accessToken: session.accessToken)
            squad = try await squads.currentSquad(userId: session.userId)
            await loadChat(session)
        }
    }

    private func loadChat(_ session: AuthSession) async {
        guard let squad else { return }
        do {
            let rows = try await SupabaseChatService(config: config, accessToken: session.accessToken).history(squadId: squad.id)
            log.ingest(rows.map { $0.entry() })
            log.markRead(at: Date())
            try? await SupabaseChatService(config: config, accessToken: session.accessToken)
                .markRead(squadId: squad.id, userId: session.userId, at: Date(), messageId: log.ordered.last?.id)
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
            let rows = try await SupabaseChatService(config: config, accessToken: session.accessToken).history(squadId: squad.id)
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

    init(config: BackendConfig = .fromBundle()) {
        _model = State(initialValue: LiveSessionModel(config: config))
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
                TextField("6-digit code", text: Binding(get: { model.code }, set: { model.code = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
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
                Text("Squad · \(squad.members.count) of 8")
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
