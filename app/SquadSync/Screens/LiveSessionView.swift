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
    var presenceNote = ""
    var followSend: UUID?
    var selectedMessage: UUID?
    var reacting = false
    var viewerId: UUID?
    var spot: SpotCall?
    var spotGame = "Warzone"
    var spotBusy = false
    var spotNote = ""
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
    private let mockSpots: SpotServing?
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
            let chat = MockChatService()
            self.sessionStore = store
            self.auth = MockAuthService(store: store)
            self.mockProfiles = MockProfileService()
            self.mockSquads = squads
            self.mockChat = chat
            self.mockInvites = MockInviteService(squads: squads)
            self.phase = .ready
            self.email = session.email
            self.viewerId = session.userId
            if scenario == .spotCall {
                let seeded = squads.seedSpotSquad(ownerId: session.userId)
                self.squad = seeded
                let card = SpotSeed.halfFilled(ownerId: session.userId, squadId: seeded.id, now: Date())
                self.spot = card
                self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: card)
            } else {
                self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: nil)
                if scenario == .invite {
                    let seeded = squads.seed(ownerId: session.userId, name: "Friday")
                    self.squad = seeded
                    let message = RemoteMessage(
                        id: ChatSeed.messageId,
                        squadId: seeded.id,
                        senderId: ChatSeed.otherId,
                        body: "From Riley",
                        sentAt: Date(timeIntervalSince1970: 1_700_000_000)
                    )
                    chat.seed(message)
                    log.ingest([message.entry()])
                }
            }
        } else {
            let store = sessionStore ?? KeychainSessionStore()
            self.sessionStore = store
            self.auth = SupabaseAuthService(config: config, store: store)
            self.mockProfiles = nil
            self.mockSquads = nil
            self.mockChat = nil
            self.mockInvites = nil
            self.mockSpots = nil
        }
    }

    private func inviteService(_ session: AuthSession) -> InviteServing {
        mockInvites ?? SupabaseInviteService(config: config, accessToken: session.accessToken)
    }

    private func spotService(_ session: AuthSession) -> SpotServing {
        mockSpots ?? SupabaseSpotService(config: config, accessToken: session.accessToken)
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
        } catch {
            report(error)
            if let marks = try? await chatService(session).reactions(squadId: squad.id) {
                board.replace(with: marks)
            }
        }
    }

    func loadSpot(_ session: AuthSession) async {
        guard let squad else { return }
        do {
            let loaded = try await spotService(session).current(squadId: squad.id)
            if var loaded {
                loaded.rsvps = loaded.rsvps.map { seat in
                    var copy = seat
                    if copy.name == "Player" {
                        copy.name = squad.members.first { $0.id == seat.userId }?.displayName ?? "Player"
                    }
                    if let previous = spot?.seat(for: seat.userId), mockSpots != nil {
                        copy.ready = previous.ready
                    }
                    return copy
                }
                spot = loaded
            } else if mockSpots == nil {
                spot = nil
            }
        } catch {
            report(error)
        }
    }

    func callSpots() async {
        let game = spotGame.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !game.isEmpty else {
            spotNote = SpotProblem.gameBlank.message
            return
        }
        spotBusy = true
        defer { spotBusy = false }
        do {
            let session = try requiredSession()
            guard let squad else { return }
            _ = try await spotService(session).call(squadId: squad.id, game: game, startsAt: Date())
            await loadSpot(session)
            spotNote = "Calling spots: \(game), 8 seats."
        } catch {
            spotNote = (error as? SpotProblem)?.message ?? error.localizedDescription
        }
    }

    func joinSpot() async {
        await changeSpot { session, call in
            try await spotService(session).rsvp(callId: call.id, response: "in")
            spotNote = "You're in."
        }
    }

    func toggleReady() async {
        guard let call = spot, let user = viewerId ?? profile?.id else { return }
        let next = !(call.seat(for: user)?.ready ?? false)
        spotBusy = true
        defer { spotBusy = false }
        do {
            let session = try requiredSession()
            try await spotService(session).setReady(callId: call.id, userId: user, ready: next)
            await loadSpot(session)
            if var call = spot, let index = call.rsvps.firstIndex(where: { $0.userId == user }) {
                call.rsvps[index].ready = next
                spot = call
            }
        } catch let problem as SpotProblem {
            spotNote = problem.message
        } catch {
            report(error)
        }
    }

    func lockSpot() async {
        await changeSpot { session, call in
            try await spotService(session).lock(callId: call.id)
            spotNote = "Locked. Open in another app is only a launcher."
        }
    }

    func cancelSpot() async {
        await changeSpot { session, call in
            try await spotService(session).cancel(callId: call.id)
            spotNote = "Cancelled."
        }
    }

    private func changeSpot(_ work: (AuthSession, SpotCall) async throws -> Void) async {
        guard let call = spot else { return }
        spotBusy = true
        defer { spotBusy = false }
        do {
            let session = try requiredSession()
            try await work(session, call)
            await loadSpot(session)
        } catch let problem as SpotProblem {
            spotNote = problem.message
        } catch {
            report(error)
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
        followSend = id
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
        let chat = chatService(session)
        var error: Error?
        do {
            try await chat.send(message)
        } catch let first {
            if RequestNoise.isCancellation(first) {
                do { try await chat.send(message) } catch let second { error = second }
            } else {
                error = first
            }
        }
        switch OutboundSend.result(error: error) {
        case .sent:
            log.markSent(id: message.id)
        case .staySending:
            break
        case .failed:
            log.markFailed(id: message.id)
            if let error { report(error) }
        }
    }

    func becameActive() async {
        guard usesLiveSocket, phase == .ready, let session = try? requiredSession(), let squad else { return }
        presenceNote = "Reconnecting…"
        realtime?.start(config: config, accessToken: session.accessToken, squadId: squad.id)
        await loadChat(session)
        presenceNote = "Back online"
        try? await Task.sleep(nanoseconds: 1_600_000_000)
        if presenceNote == "Back online" { presenceNote = "" }
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
            await loadSpot(session)
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
        } catch {
            report(error)
        }
    }

    var usesLiveSocket: Bool { mockChat == nil }
    var readyIsLocalOnly: Bool { mockSpots == nil }

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
        case .spots:
            await loadSpot(session)
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
            await loadSpot(session)
        } catch {
            if RequestNoise.isCancellation(error) { return }
            report(error)
            if let failure = error as? BackendFailure, case .notSetUp(.messages) = failure { poll?.cancel() }
        }
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true
        defer { busy = false }
        do {
            try await work()
        } catch {
            report(error)
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

    private func report(_ error: Error) {
        if RequestNoise.isCancellation(error) { return }
        if let failure = error as? BackendFailure {
            note(failure)
        } else if let problem = error as? InviteProblem {
            status = problem.message
        } else {
            status = error.localizedDescription
        }
    }

    private func note(_ failure: BackendFailure) {
        if RequestNoise.isCancellation(failure) { return }
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
    @State private var pinnedToBottom = true
    @State private var showNewMessages = false
    @State private var wentToBackground = false
    @Environment(\.scenePhase) private var scenePhase

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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { wentToBackground = true }
            guard phase == .active, wentToBackground else { return }
            wentToBackground = false
            Task { await model.becameActive() }
        }
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
            ScrollView {
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
                        if let notice = liveNotice {
                            Text(notice).font(.caption).foregroundStyle(SQColor.muted)
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
            if model.squad != nil {
                chatList
                    .safeAreaInset(edge: .bottom, spacing: SQSpace.s) {
                        VStack(alignment: .leading, spacing: SQSpace.xs) {
                            Text("Unread \(model.log.unreadCount(viewerId: model.profile?.id ?? UUID()))")
                                .font(.caption)
                            composer
                        }
                        .padding(.top, SQSpace.s)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(SQColor.canvas)
                    }
                    .frame(minHeight: 180, maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(model.notes, id: \.self) { note in
                Text(note).font(.caption).foregroundStyle(SQColor.muted)
            }
        }
    }

    private var liveNotice: String? {
        guard model.usesLiveSocket else { return nil }
        if !model.presenceNote.isEmpty { return model.presenceNote }
        return model.link.notice
    }

    private var chatList: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottom) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        if model.spot == nil {
                            callSpotForm
                        }
                        if let spot = model.spot {
                            spotCard(spot)
                        }
                        ForEach(model.log.ordered) { entry in
                            messageRow(entry).id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ChatContentFrame())
                }
                .coordinateSpace(name: "chat")
                .scrollDismissesKeyboard(.interactively)
                .modifier(ChatPinModifier(pinned: $pinnedToBottom))
                if showNewMessages {
                    Button("New messages") {
                        showNewMessages = false
                        pinnedToBottom = true
                        if let id = model.log.ordered.last?.id {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("new-messages")
                }
            }
            .onChange(of: model.log.ordered.last?.id) { _, id in
                guard let id else { return }
                let own = model.followSend == id
                if ChatFollow.scrolls(pinned: pinnedToBottom, ownSend: own) {
                    withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                    showNewMessages = false
                    if own { model.followSend = nil }
                } else {
                    showNewMessages = true
                }
            }
        }
    }

    private var callSpotForm: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            TextField("Game", text: Binding(get: { model.spotGame }, set: { model.spotGame = $0 }))
                .textFieldStyle(.roundedBorder)
            Button("Call spots") { Task { await model.callSpots() } }
                .disabled(model.spotBusy)
            Text("Seats are capped at 8. This server does not store a smaller target.")
                .font(.caption)
                .foregroundStyle(SQColor.muted)
        }
        .padding(SQSpace.s)
        .background(SQColor.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func spotCard(_ spot: SpotCall) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let expired = SpotCallRules.showsExpired(spot, now: context.date)
            let viewer = model.viewerId ?? model.profile?.id
            let mine = viewer.flatMap { spot.seat(for: $0) }
            VStack(alignment: .leading, spacing: SQSpace.s) {
                Text("Calling spots: \(spot.game), \(spot.filled) of \(SpotCallRules.cap) seats")
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                Text(statusLine(spot, expired: expired, now: context.date))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(SQColor.warning)
                    .accessibilityIdentifier("spot-countdown")
                ForEach(spot.rsvps.filter(\.isIn)) { seat in
                    Text(seatLine(seat))
                        .font(.caption)
                        .lineLimit(2)
                }
                Text("Check-in starters can join after the timer. 0013 does not know who is in a game.")
                    .font(.caption2)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if model.readyIsLocalOnly {
                    Text("Ready is not stored. 0013 only records in or out, and lock does not wait for it.")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !model.spotNote.isEmpty {
                    Text(model.spotNote)
                        .font(.caption)
                        .foregroundStyle(SQColor.muted)
                }
                if spot.status == .open && !expired {
                    Button("Join") { Task { await model.joinSpot() } }
                        .disabled(model.spotBusy || viewer == nil || !SpotCallRules.canJoin(spot, userId: viewer!, now: context.date))
                        .accessibilityIdentifier("spot-join")
                        .accessibilityLabel("Join the spot call")
                    if mine?.isIn == true {
                        Button(mine?.ready == true ? "Ready" : "Ready") { Task { await model.toggleReady() } }
                            .disabled(model.spotBusy || model.readyIsLocalOnly)
                            .accessibilityIdentifier("spot-ready")
                            .accessibilityLabel(mine?.ready == true ? "Ready, on" : "Ready, off")
                    }
                }
                if let viewer, SpotCallRules.canLock(spot, actorId: viewer, ownerId: model.squad?.ownerId ?? viewer) {
                    Button("Lock") { Task { await model.lockSpot() } }
                        .disabled(model.spotBusy)
                        .accessibilityIdentifier("spot-lock")
                        .accessibilityLabel("Lock the spot call")
                }
                if let viewer, SpotCallRules.canCancel(spot, actorId: viewer) {
                    Button("Cancel") { Task { await model.cancelSpot() } }
                        .disabled(model.spotBusy)
                }
                if spot.status == .locked {
                    Text("Open in")
                        .font(.caption.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    ForEach(PartyLauncher.destinations) { destination in
                        Button {
                            openLauncher(destination)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Open in \(destination.title)")
                                    .font(.body)
                                    .lineLimit(2)
                                Text(destination.note)
                                    .font(.caption2)
                                    .foregroundStyle(SQColor.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .accessibilityIdentifier("spot-open-\(destination.title.lowercased())")
                        .accessibilityLabel("Open in \(destination.title). \(destination.note)")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(SQSpace.m)
            .background(SQColor.card, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("spot-card")
        }
    }

    private func statusLine(_ spot: SpotCall, expired: Bool, now: Date) -> String {
        if spot.status == .cancelled { return "Cancelled" }
        if spot.status == .ended { return "Ended" }
        if spot.status == .locked { return "Locked" }
        if expired { return "Expired" }
        if spot.filled >= SpotCallRules.cap { return "Full · \(SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now))" }
        return "\(SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now)) left"
    }

    private func seatLine(_ seat: SpotRsvp) -> String {
        var bits = [seat.name]
        if seat.starter { bits.append("starter") }
        if seat.ready { bits.append("Ready") }
        else { bits.append("In") }
        return bits.joined(separator: " · ")
    }

    private func openLauncher(_ destination: PartyLauncher.Destination) {
        let application = UIApplication.shared
        let url = application.canOpenURL(destination.scheme) ? destination.scheme : destination.web
        application.open(url)
    }

    private var composer: some View {
        HStack {
            TextField("Message", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                .textFieldStyle(.roundedBorder)
            Button("Send") { Task { await model.send() } }
                .accessibilityIdentifier("send-message")
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
            Button {
                model.selectedMessage = entry.id
            } label: {
                Text(entry.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(WideRowButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            Text(label(for: entry))
                .font(.caption)
                .foregroundStyle(SQColor.muted)
            chips(for: entry)
            if mine, entry.id == lastMine, !names.isEmpty {
                Text("Seen by \(names.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(SQColor.muted)
            }
            if model.selectedMessage == entry.id {
                Button("React") { model.reacting = true }
                    .accessibilityIdentifier("react")
            }
            if model.reacting, model.selectedMessage == entry.id {
                reactionChoices(entry.id)
            }
            if entry.delivery == .failed {
                Button("Retry") { Task { await model.retry(entry.id) } }
            }
        }
        .padding(.vertical, SQSpace.xs)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ChatSeed.rowIdentifier(for: entry.id))
        .onTapGesture(count: 2) {
            model.selectedMessage = entry.id
            model.reacting = true
        }
        .accessibilityAction(named: Text("React")) {
            model.selectedMessage = entry.id
            model.reacting = true
        }
        .contextMenu {
            ForEach(Tapback.allCases) { reaction in
                Button(reaction.spoken) { Task { await model.tap(reaction, on: entry.id) } }
            }
        }
    }

    private func reactionChoices(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(Tapback.allCases) { reaction in
                Button(reaction.spoken) { Task { await model.tap(reaction, on: id) } }
                    .accessibilityIdentifier("tapback-\(reaction.rawValue)")
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
                            .accessibilityIdentifier("reaction-count")
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

private struct WideRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

private struct ChatFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

private struct ChatViewportKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ChatContentFrame: View {
    var body: some View {
        GeometryReader { geo in
            Color.clear.preference(key: ChatFrameKey.self, value: geo.frame(in: .named("chat")))
        }
    }
}

private struct ChatPinModifier: ViewModifier {
    @Binding var pinned: Bool
    @State private var lastOffset: CGFloat = 0
    @State private var viewport: CGFloat = 0

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollSample.self, of: { geo in
                ScrollSample(
                    offset: geo.contentOffset.y,
                    content: geo.contentSize.height,
                    viewport: geo.containerSize.height
                )
            }, action: { _, sample in
                pinned = ChatFollow.pinned(previous: pinned, oldOffset: lastOffset, sample: sample)
                lastOffset = sample.offset
            })
        } else {
            content
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: ChatViewportKey.self, value: geo.size.height)
                    }
                }
                .onPreferenceChange(ChatViewportKey.self) { viewport = $0 }
                .onPreferenceChange(ChatFrameKey.self) { frame in
                    let sample = ScrollSample(offset: -frame.minY, content: frame.height, viewport: viewport)
                    pinned = ChatFollow.pinned(previous: pinned, oldOffset: lastOffset, sample: sample)
                    lastOffset = sample.offset
                }
        }
    }
}
