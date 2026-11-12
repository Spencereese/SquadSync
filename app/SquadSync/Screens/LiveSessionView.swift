import SwiftUI
import UIKit

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
    var inviteCode = ""
    var joinCode = ""
    var board = ReactionBoard()
    var reads: [MemberRead] = []
    var link: RealtimeLink = .down
    var viewerId: UUID?
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
    private let mockInvites: InviteServing?
    private var realtime: RealtimeClient?
    private var poll: Task<Void, Never>?

    enum Phase {
        case email
        case code
        case ready
    }

    init(config: BackendConfig, backend: BackendMode = .live, scenario: LaunchScenario = .seated, sessionStore: SessionStoring? = nil) {
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
            let squads = MockSquadService()
            self.sessionStore = store
            self.auth = MockAuthService(store: store)
            self.mockProfiles = MockProfileService()
            self.mockSquads = squads
            self.mockChat = MockChatService()
            self.mockInvites = MockInviteService(squads: squads)
            self.phase = .ready
            self.email = session.email
            self.viewerId = session.userId
            if scenario == .invite {
                self.squad = squads.seed(ownerId: session.userId, name: "Friday")
            }
        } else {
            let store = sessionStore ?? KeychainSessionStore()
            self.sessionStore = store
            self.auth = SupabaseAuthService(config: config, store: store)
            self.mockProfiles = nil
            self.mockSquads = nil
            self.mockChat = nil
            self.mockInvites = nil
        }
    }

    private func inviteService(_ session: AuthSession) -> InviteServing {
        mockInvites ?? SupabaseInviteService(config: config, accessToken: session.accessToken)
    }

    func restore() async {
        do {
            guard let session = try auth.restore() else { return }
            phase = .ready
            email = session.email
            viewerId = session.userId
            await refresh(session)
            startLive(session)
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
            startLive(session)
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
            startLive(session)
        }
    }

    func createInvite() async {
        await run {
            let session = try requiredSession()
            do {
                let ticket = try await inviteService(session).createInvite()
                inviteCode = ticket.code
                status = "Invite \(ticket.code) is ready."
            } catch let problem as InviteProblem {
                status = problem.message
            }
        }
    }

    func joinSquad() async {
        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = InviteProblem.revokedOrUnknown.message
            return
        }
        await run {
            let session = try requiredSession()
            let existing = squad?.id
            do {
                let joined = try await inviteService(session).join(code: trimmed)
                squad = try await squadService(session).currentSquad(userId: session.userId)
                status = existing == joined ? "You're already in this squad." : "Joined."
                await loadChat(session)
                startLive(session)
            } catch let problem as InviteProblem {
                status = problem.message
            }
        }
    }

    func tap(_ reaction: Tapback, on id: UUID) async {
        guard let squad, let session = try? requiredSession() else { return }
        let emoji = SquadReaction.emoji(for: reaction)
        let changes = board.toggle(messageId: id, userId: session.userId, emoji: emoji)
        do {
            let chat = chatService(session)
            for change in changes {
                switch change {
                case .insert(let symbol):
                    try await chat.setReaction(squadId: squad.id, messageId: id, userId: session.userId, emoji: symbol, active: true)
                case .remove(let symbol):
                    try await chat.setReaction(squadId: squad.id, messageId: id, userId: session.userId, emoji: symbol, active: false)
                }
            }
        } catch let failure as BackendFailure {
            note(failure)
            if let marks = try? await chatService(session).reactions(squadId: squad.id) {
                board.replace(with: marks)
            }
        } catch {
            status = error.localizedDescription
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
        realtime?.stop()
        realtime = nil
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
            if let cursor = try? await chat.ownReadAt(squadId: squad.id, userId: session.userId) {
                log.markRead(at: cursor)
            }
            let caughtUp = Date()
            log.markRead(at: caughtUp)
            try? await chat.markRead(squadId: squad.id, userId: session.userId, at: caughtUp, messageId: log.ordered.last?.id)
            if let marks = try? await chat.reactions(squadId: squad.id) {
                board.replace(with: marks)
            }
            if let remoteReads = try? await chat.reads(squadId: squad.id) {
                reads = remoteReads
            }
        } catch let failure as BackendFailure {
            note(failure)
        } catch {
            status = error.localizedDescription
        }
    }

    var usesLiveSocket: Bool { mockChat == nil }

    private var usesSocket: Bool { usesLiveSocket }

    private func startLive(_ session: AuthSession) {
        realtime?.stop()
        realtime = nil
        poll?.cancel()
        guard let squad else { return }
        guard usesSocket else {
            link = .down
            beginPoll(session)
            return
        }
        let client = RealtimeClient()
        client.onEvent = { [weak self] event in
            Task { await self?.handle(event, session: session) }
        }
        realtime = client
        client.start(config: config, accessToken: session.accessToken, squadId: squad.id)
        beginPoll(session)
    }

    private func handle(_ event: RealtimeClient.Event, session: AuthSession) async {
        switch event {
        case .phase(let next):
            let opened = next == .connected && link != .connected
            link = next
            if next.polls {
                beginPoll(session)
            } else {
                poll?.cancel()
                poll = nil
            }
            if opened { await loadChat(session) }
        case .message(let message):
            guard message.squadId == squad?.id else { return }
            log.ingest([message.entry()])
            if message.senderId != session.userId {
                let seenAt = max(Date(), message.sentAt)
                log.markRead(at: seenAt)
                try? await chatService(session).markRead(
                    squadId: message.squadId,
                    userId: session.userId,
                    at: seenAt,
                    messageId: message.id
                )
            }
        case .messageRemoved(let id):
            log.remove(id: id)
        case .roster:
            squad = try? await squadService(session).currentSquad(userId: session.userId)
        case .reaction(let mark, let removed):
            if removed { board.remove(mark) } else { board.add(mark) }
        case .read(let read):
            if let index = reads.firstIndex(where: { $0.userId == read.userId }) {
                reads[index] = read
            } else {
                reads.append(read)
            }
        }
    }

    private func beginPoll(_ session: AuthSession) {
        poll?.cancel()
        poll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await self?.pollOnce(session)
            }
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

    init(config: BackendConfig = .fromBundle(), backend: BackendMode = .live, scenario: LaunchScenario = .seated) {
        _model = State(initialValue: LiveSessionModel(config: config, backend: backend, scenario: scenario))
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
                if squad.ownerId == (model.profile?.id ?? model.viewerId) {
                    inviteControls
                }
                joinControls
                if let notice = model.link.notice, model.usesLiveSocket {
                    Text(notice).font(.caption).foregroundStyle(SQColor.muted)
                }
                ScrollView {
                    ForEach(model.log.ordered) { entry in
                        messageRow(entry)
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
                joinControls
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

    private var inviteControls: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Button("Create invite") { Task { await model.createInvite() } }
                .disabled(model.busy)
            if !model.inviteCode.isEmpty {
                Text(model.inviteCode)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("invite-code")
                ShareLink(item: model.inviteCode) {
                    Text("Share")
                }
                Button("Copy") {
                    UIPasteboard.general.string = model.inviteCode
                    model.status = "Copied."
                }
            }
        }
    }

    private var joinControls: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            TextField("Invite code", text: Binding(get: { model.joinCode }, set: { model.joinCode = $0 }))
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.characters)
                .accessibilityIdentifier("join-code")
            Button("Join") { Task { await model.joinSquad() } }
                .disabled(model.busy)
        }
    }

    private func messageRow(_ entry: ChatEntry) -> some View {
        let mine = entry.senderId == model.profile?.id
        let lastMine = model.log.ordered.last { $0.senderId == model.profile?.id && $0.delivery == .sent }?.id
        let names = seenNames(for: entry)
        return VStack(alignment: .leading, spacing: 2) {
            Text(entry.body).frame(maxWidth: .infinity, alignment: .leading)
            Text(label(for: entry))
                .font(.caption)
                .foregroundStyle(SQColor.muted)
            chips(for: entry)
            if mine, entry.id == lastMine, !names.isEmpty {
                Text("Seen by \(names.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(SQColor.muted)
            }
            if entry.delivery == .failed {
                Button("Retry") { Task { await model.retry(entry.id) } }
            }
        }
        .padding(.vertical, SQSpace.xs)
        .contextMenu {
            ForEach(Tapback.allCases) { reaction in
                Button(reaction.spoken) { Task { await model.tap(reaction, on: entry.id) } }
            }
        }
    }

    @ViewBuilder
    private func chips(for entry: ChatEntry) -> some View {
        let rows = Tapback.allCases.compactMap { reaction -> (Tapback, Int)? in
            let emoji = SquadReaction.emoji(for: reaction)
            let count = model.board.marks.filter { $0.messageId == entry.id && $0.emoji == emoji }.count
            guard count > 0 else { return nil }
            return (reaction, count)
        }
        if !rows.isEmpty {
            HStack(spacing: 4) {
                ForEach(rows, id: \.0.id) { reaction, count in
                    HStack(spacing: 3) {
                        Image(systemName: reaction.rawValue)
                        Text("\(count)")
                    }
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(SQColor.card, in: Capsule())
                }
            }
        }
    }

    private func seenNames(for entry: ChatEntry) -> [String] {
        let people = model.reads.map { read in
            let name = model.squad?.members.first { $0.id == read.userId }?.displayName ?? "Player"
            return (id: read.userId, name: name, at: read.lastReadAt)
        }
        return Receipts.seenNames(messageSentAt: entry.sentAt, reads: people, viewerId: model.profile?.id ?? UUID())
    }

    private func label(for entry: ChatEntry) -> String {
        switch entry.delivery {
        case .sending: "Sending"
        case .sent: "Sent"
        case .failed: "Failed"
        }
    }
}
