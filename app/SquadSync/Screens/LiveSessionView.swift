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
    var membershipIsError = false
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
    var spotGate = SpotActionGate()
    var resumedAt = Date.distantPast
    var leaveAvailable = false
    var transferTo: UUID?
    var spotNote = ""
    var spotServer = SpotServerCapabilities.unavailable
    var status = ""
    var reconnecting = false
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
    private var liveSpotService: SupabaseSpotService?
    private var liveSpotToken: String?
    private var realtime: RealtimeClient?
    private var poll: Task<Void, Never>?
    private var expiryRead: Task<Void, Never>?
    private var loadedSquad: UUID?

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
            if scenario == .spotCall || scenario == .spotCallMine || scenario == .spotCallNearlyFull || scenario == .spotCallExpired {
                let seeded = squads.seedSpotSquad(ownerId: session.userId)
                self.squad = seeded
                let card: SpotCall
                if scenario == .spotCallMine {
                    card = SpotSeed.calledByViewer(ownerId: session.userId, squadId: seeded.id, now: Date())
                } else if scenario == .spotCallNearlyFull {
                    card = SpotSeed.nearlyFull(ownerId: session.userId, squadId: seeded.id, now: Date())
                } else if scenario == .spotCallExpired {
                    card = SpotSeed.staleExpired(ownerId: session.userId, squadId: seeded.id, now: Date())
                } else {
                    card = SpotSeed.halfFilled(ownerId: session.userId, squadId: seeded.id, now: Date())
                }
                self.spot = card
                self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: card)
            } else {
                self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: nil)
                if scenario == .almostFull {
                    self.squad = squads.seedAlmostFull(ownerId: session.userId)
                } else if scenario == .invite {
                    var seeded = squads.seed(ownerId: session.userId, name: "Friday")
                    squads.addMember(id: ChatSeed.otherId, name: "Riley")
                    seeded.members.append(SquadMemberRecord(id: ChatSeed.otherId, displayName: "Riley", defaultGame: "", isOwner: false))
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
                    for index in 1...8 {
                        let extra = RemoteMessage(
                            id: UUID(uuidString: "00000000-0000-0000-0000-00000000010\(index)")!,
                            squadId: seeded.id,
                            senderId: session.userId,
                            body: "Line \(index)",
                            sentAt: Date(timeIntervalSince1970: 1_700_000_000 + Double(index))
                        )
                        chat.seed(extra)
                        log.ingest([extra.entry()])
                    }
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
        mockInvites ?? SupabaseInviteService(config: config, accessToken: session.accessToken, refresher: tokenRefresher)
    }

    private func spotService(_ session: AuthSession) -> SpotServing {
        if let mockSpots { return mockSpots }
        if let liveSpotService, liveSpotToken == session.accessToken {
            return liveSpotService
        }
        let created = SupabaseSpotService(
            config: config,
            accessToken: session.accessToken,
            refresher: tokenRefresher
        )
        liveSpotService = created
        liveSpotToken = session.accessToken
        return created
    }

    func restore() async {
        expireStoredTokenIfRequested()
        do {
            guard let session = try await auth.prepareSession(now: Date()) else { return }
            phase = .ready
            email = session.email
            viewerId = session.userId
            reconnecting = false
            await refresh(session)
            if squad != nil { startLive(session) }
        } catch {
            handleSessionError(error)
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
        membershipIsError = false
        status = "Creating invite…"
        await run {
            let session = try requiredSession()
            do {
                let ticket = try await inviteService(session).createInvite()
                inviteCode = ticket.code
                membershipIsError = false
                status = "Invite \(ticket.code) is ready."
            } catch let problem as InviteProblem {
                membershipIsError = true
                status = problem.message
            }
        }
    }

    func joinSquad() async {
        let trimmed = joinCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            membershipIsError = true
            status = "Enter an invite code."
            return
        }
        membershipIsError = false
        status = "Joining…"
        await run {
            let session = try requiredSession()
            let beforeId = squad?.id
            let beforeCount = squad?.members.count ?? 0
            do {
                _ = try await inviteService(session).join(code: trimmed)
                squad = try await squadService(session).currentSquad(userId: session.userId)
                membershipIsError = false
                status = MembershipChange.note(
                    beforeId: beforeId,
                    beforeCount: beforeCount,
                    afterId: squad?.id,
                    afterCount: squad?.members.count ?? 0
                )
                await loadChat(session)
                startLive(session)
            } catch let problem as InviteProblem {
                membershipIsError = true
                status = problem.message
            }
        }
    }

    func probeLeave() async {
        guard let session = try? requiredSession() else {
            leaveAvailable = false
            return
        }
        leaveAvailable = await squadService(session).leaveAvailable()
    }

    func leaveSquad() async {
        guard leaveAvailable, let squad else { return }
        let me = profile?.id ?? viewerId
        if squad.ownerId == me, squad.members.count > 1, transferTo == nil {
            membershipIsError = true
            status = InviteProblem.ownerMustTransfer.message
            return
        }
        membershipIsError = false
        status = "Leaving…"
        await run {
            let session = try requiredSession()
            do {
                try await squadService(session).leaveSquad(newOwner: squad.ownerId == me ? transferTo : nil)
                realtime?.stop()
                realtime = nil
                poll?.cancel()
                poll = nil
                self.squad = nil
                self.spot = nil
                self.log = ChatLog()
                self.inviteCode = ""
                self.transferTo = nil
                self.loadedSquad = nil
                membershipIsError = false
                status = "You left the squad."
            } catch let problem as InviteProblem {
                membershipIsError = true
                status = problem.message
            }
        }
    }

    func removeMember(_ member: SquadMemberRecord) async {
        guard let squad else { return }
        membershipIsError = false
        status = "Removing \(member.displayName)…"
        await run {
            let session = try requiredSession()
            do {
                try await squadService(session).removeMember(squadId: squad.id, userId: member.id)
                self.squad = try await squadService(session).currentSquad(userId: session.userId)
                membershipIsError = false
                status = "Removed \(member.displayName)."
            } catch let problem as InviteProblem {
                membershipIsError = true
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
        defer { scheduleExpiryRead(session) }
        let service = spotService(session)
        spotServer = await service.serverCapabilities()
        do {
            let loaded = try await service.current(squadId: squad.id)
            if var loaded {
                loaded.rsvps = loaded.rsvps.map { seat in
                    var copy = seat
                    if copy.name == "Player" {
                        copy.name = squad.members.first { $0.id == seat.userId }?.displayName ?? "Player"
                    }
                    if let previous = spot?.seat(for: seat.userId), mockSpots != nil, previous.response == copy.response {
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
        guard spotGate.begin() else { return }
        defer { spotGate.finish() }
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

    func leaveSpot() async {
        await changeSpot { session, call in
            try await spotService(session).rsvp(callId: call.id, response: "out")
            spotNote = "You left."
        }
    }

    func toggleReady() async {
        guard let call = spot, let user = viewerId ?? profile?.id else { return }
        let next = !(call.seat(for: user)?.ready ?? false)
        guard spotGate.begin() else { return }
        defer { spotGate.finish() }
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
            await reloadSpotAfterFailure()
        } catch {
            report(error)
            await reloadSpotAfterFailure()
        }
    }

    func lockSpot() async {
        await changeSpot(reloadAfterFailure: true) { session, call in
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

    private func changeSpot(
        reloadAfterFailure: Bool = false,
        _ work: (AuthSession, SpotCall) async throws -> Void
    ) async {
        guard let call = spot, spotGate.begin() else { return }
        defer { spotGate.finish() }
        do {
            let session = try requiredSession()
            try await work(session, call)
            await loadSpot(session)
        } catch let problem as SpotProblem {
            spotNote = problem.message
            if reloadAfterFailure { await reloadSpotAfterFailure() }
        } catch {
            report(error)
            if reloadAfterFailure { await reloadSpotAfterFailure() }
        }
    }

    private func reloadSpotAfterFailure() async {
        guard let session = try? requiredSession() else { return }
        await loadSpot(session)
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
        await deliver(
            RemoteMessage(id: id, squadId: squad.id, senderId: session.userId, body: text, sentAt: now),
            session: session
        )
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

    /// `-debug-expire-token` rewrites the stored access token's `exp` into the past so a launch exercises refresh.
    private func expireStoredTokenIfRequested() {
        #if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-debug-expire-token") else { return }
        guard var session = try? sessionStore.load() else { return }
        session.accessToken = AccessTokenClock.replacingExpiry(
            session.accessToken,
            exp: Date().addingTimeInterval(-120)
        )
        try? sessionStore.save(session)
        SquadLog.http.notice("auth -debug-expire-token marked the stored access token expired")
        #endif
    }

    private func requiredSession() throws -> AuthSession {
        guard let session = try auth.restore() else { throw BackendFailure.notSignedIn }
        return session
    }

    private func deliver(_ message: RemoteMessage, session: AuthSession) async {
        let chat = chatService(session)
        var error: Error?
        var receipt: SendReceipt?
        do {
            receipt = try await chat.send(message)
        } catch let first {
            if RequestNoise.isCancellation(first) {
                do { receipt = try await chat.send(message) } catch let second { error = second }
            } else {
                error = first
            }
        }
        switch OutboundSend.result(receipt: receipt, error: error) {
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
        resumedAt = Date()
        liveSpotService = nil
        liveSpotToken = nil
        guard usesLiveSocket else { return }
        poll?.cancel()
        poll = nil
        expireStoredTokenIfRequested()
        do {
            guard let session = try await auth.prepareSession(now: Date()) else { return }
            phase = .ready
            email = session.email
            viewerId = session.userId
            presenceNote = "Reconnecting…"
            await refresh(session)
            if squad != nil { startLive(session) }
            if !reconnecting {
                presenceNote = "Back online"
                try? await Task.sleep(nanoseconds: 1_600_000_000)
                if presenceNote == "Back online" { presenceNote = "" }
            }
        } catch {
            handleSessionError(error)
        }
    }

    private func refresh(_ session: AuthSession) async {
        busy = true
        defer { busy = false }
        do {
            let profiles = profileService(session)
            let loaded = try await profiles.loadOrCreate(userId: session.userId, email: session.email)
            profile = loaded
            displayName = loaded.displayName
            defaultGame = loaded.defaultGame
            let squads = squadService(session)
            squad = try await squads.currentSquad(userId: session.userId)
            reconnecting = false
            await loadChat(session)
            await loadSpot(session)
        } catch {
            handleSessionError(error)
        }
    }

    func catchUp(pinned: Bool) async {
        guard ReadAdvance.catchesUp(pinned: pinned), let squad, let session = try? requiredSession() else { return }
        let seenAt = max(Date(), log.ordered.last?.sentAt ?? .distantPast)
        do {
            try await chatService(session).markRead(
                squadId: squad.id,
                userId: session.userId,
                at: seenAt,
                messageId: log.ordered.last?.id
            )
            log.markRead(at: seenAt)
        } catch {
            return
        }
    }

    private func loadChat(_ session: AuthSession) async {
        guard let squad else { return }
        let requested = squad.id
        if loadedSquad != requested {
            log = ChatLog()
            reads = []
            board = ReactionBoard()
            loadedSquad = requested
        }
        do {
            let chat = chatService(session)
            let rows = try await chat.history(squadId: requested)
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return }
            log.adopt(replacingSquad: false, history: rows.map { $0.entry() })
            if let cursor = try? await chat.ownReadAt(squadId: requested, userId: session.userId) {
                log.markRead(at: cursor)
            }
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return }
            if let marks = try? await chat.reactions(squadId: squad.id) {
                board.replace(with: marks)
            }
            if let remoteReads = try? await chat.reads(squadId: squad.id) {
                reads = remoteReads
            }
        } catch {
            handleSessionError(error)
        }
    }

    var usesLiveSocket: Bool { mockChat == nil }
    var showsLiveGaps: Bool { mockSpots == nil }
    var readyIsLocalOnly: Bool { showsLiveGaps && !spotServer.ready }

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
    }

    private func handle(_ event: RealtimeClient.Event, session: AuthSession) async {
        switch event {
        case .phase(let next):
            let opened = next == .connected && link != .connected
            link = next
            if next.polls {
                beginPoll(session)
                await loadChat(session)
            } else {
                poll?.cancel()
                poll = nil
            }
            if opened { await loadChat(session) }
        case .message(let message):
            guard message.squadId == squad?.id else { return }
            log.ingest([message.entry()])
        case .messageRemoved(let id):
            log.remove(id: id)
        case .roster:
            squad = try? await squadService(session).currentSquad(userId: session.userId)
        case .reaction(let mark, let removed):
            if removed { board.remove(mark) } else { board.add(mark) }
        case .spots:
            await loadSpot(session)
        case .read(let read):
            var book = ReceiptBook(reads: reads)
            book.apply(read)
            reads = book.reads
        }
    }

    private func scheduleExpiryRead(_ session: AuthSession) {
        expiryRead?.cancel()
        expiryRead = nil
        guard let spot, spot.status == .open, spot.closedAt == nil, spot.lockedAt == nil else { return }
        guard let delay = SpotExpiryRead.delay(joinUntil: spot.joinUntil, now: Date()) else { return }
        let nanos = UInt64(delay * 1_000_000_000)
        expiryRead = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            await self?.loadSpot(session)
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
        guard let squad, HistoryMerge.accepts(requestSquad: squad.id, loadedSquad: loadedSquad) else { return }
        let requested = squad.id
        do {
            let rows = try await chatService(session).history(squadId: requested)
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return }
            log.adopt(replacingSquad: false, history: rows.map { $0.entry() })
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
        mockProfiles ?? SupabaseProfileService(config: config, accessToken: session.accessToken, refresher: tokenRefresher)
    }

    private func squadService(_ session: AuthSession) -> SquadService {
        mockSquads ?? SupabaseSquadService(config: config, accessToken: session.accessToken, refresher: tokenRefresher)
    }

    private func chatService(_ session: AuthSession) -> ChatService {
        mockChat ?? SupabaseChatService(config: config, accessToken: session.accessToken, refresher: tokenRefresher)
    }

    private var tokenRefresher: TokenRefreshing? { auth as? TokenRefreshing }

    private func handleSessionError(_ error: Error) {
        if RequestNoise.isCancellation(error) { return }
        guard let failure = error as? BackendFailure else {
            if let storeError = error as? SessionStoreError {
                status = storeError.message
            } else {
                status = error.localizedDescription
            }
            return
        }
        switch SessionFailurePolicy.surface(failure) {
        case .signIn(let message):
            realtime?.stop()
            realtime = nil
            poll?.cancel()
            poll = nil
            squad = nil
            spot = nil
            profile = nil
            phase = .email
            reconnecting = false
            status = message
        case .reconnecting:
            reconnecting = true
            status = SessionFailurePolicy.reconnecting
            if phase != .ready, let session = try? auth.restore() {
                phase = .ready
                email = session.email
                viewerId = session.userId
            }
        case .message:
            if let failure = error as? BackendFailure {
                note(failure)
            } else {
                status = error.localizedDescription
            }
        }
    }

    private func report(_ error: Error) {
        if RequestNoise.isCancellation(error) { return }
        if let failure = error as? BackendFailure {
            switch SessionFailurePolicy.surface(failure) {
            case .signIn, .reconnecting:
                handleSessionError(error)
            case .message:
                note(failure)
            }
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
        case .notSignedIn, .sessionEnded:
            status = SessionFailurePolicy.ended
        case .reconnecting:
            status = SessionFailurePolicy.reconnecting
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
    @State private var confirmSignOut = false
    @State private var showMembers = false
    @State private var confirmLeave = false
    @ScaledMetric(relativeTo: .body) private var composerLine: CGFloat = 22
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
            .navigationTitle(squadTitle ?? "SquadSync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if model.phase == .ready {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showMembers = true
                        } label: {
                            Image(systemName: "person.3")
                        }
                        .accessibilityLabel("Members")
                        .accessibilityHint("Opens invite, join, and remove")
                        .accessibilityIdentifier("members")
                    }
                }
                if let squadTitle {
                    ToolbarItem(placement: .principal) {
                        Text(squadTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .accessibilityIdentifier("squad-title")
                            .accessibilityLabel(squadTitle)
                            .accessibilityAddTraits(.isHeader)
                    }
                }
                if model.phase == .ready {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            confirmSignOut = true
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Account")
                    }
                }
            }
        }
        .sheet(isPresented: $confirmSignOut) {
            signOutSheet
                .adoptingLaunchDynamicType()
        }
        .sheet(isPresented: $showMembers) {
            membershipSheet
                .adoptingLaunchDynamicType()
        }
        .task { await model.restore() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { wentToBackground = true }
            guard phase == .active, wentToBackground else { return }
            wentToBackground = false
            Task {
                await model.becameActive()
                await model.catchUp(pinned: pinnedToBottom)
            }
        }
    }

    /// Swiping the sheet away only clears `confirmSignOut`. It does not sign out.
    private var signOutSheet: some View {
        VStack(alignment: .leading, spacing: SQSpace.l) {
            Text("Sign out?")
                .font(.title2.weight(.semibold))
            Text("You can sign in again with the same email.")
                .foregroundStyle(SQColor.muted)
            Button("Sign out", role: .destructive) {
                confirmSignOut = false
                Task { await model.signOut() }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel", role: .cancel) { confirmSignOut = false }
        }
        .padding(SQSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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

    private var squadTitle: String? {
        guard model.phase == .ready, let squad = model.squad else { return nil }
        return SquadTitle.line(name: squad.name, memberCount: squad.members.count)
    }

    private var ready: some View {
        VStack(alignment: .leading, spacing: SQSpace.m) {
            if let spot = model.spot {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
                    if SpotCallRules.showsPinnedBar(spot, now: now) {
                        activeCallBar(spot, now: now)
                    }
                }
            }
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
                    if model.squad != nil {
                        if let notice = liveNotice {
                            Text(notice).font(.caption).foregroundStyle(SQColor.muted)
                        }
                    } else if model.reconnecting {
                        Text("Reconnecting…")
                            .accessibilityIdentifier("reconnecting")
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
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
                            if SpotCallRules.showsCallForm(model.spot, now: now) {
                                callSpotForm
                            }
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
                    Text("End of messages")
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .frame(maxWidth: .infinity, minHeight: SQSpace.l)
                        .id(ChatAnchor.end)
                        .accessibilityIdentifier(ChatAnchor.end)
                }
                .contentMargins(.bottom, SQSpace.l, for: .scrollContent)
                .coordinateSpace(name: "chat")
                .scrollDismissesKeyboard(.interactively)
                .modifier(ChatPinModifier(pinned: $pinnedToBottom))
                .accessibilityIdentifier("message-list")
                composerBar(proxy)
            }
            .onAppear {
                guard model.log.ordered.last != nil else { return }
                Task { @MainActor in
                    scrollChatToBottom(proxy)
                    await model.catchUp(pinned: pinnedToBottom)
                }
            }
            .onChange(of: pinnedToBottom) { wasPinned, isPinned in
                if ChatCatchUp.hidesNewMessages(pinned: isPinned) {
                    showNewMessages = false
                }
                if ChatCatchUp.requests(becamePinned: isPinned && !wasPinned, tappedNewMessages: false) {
                    Task { await model.catchUp(pinned: true) }
                }
            }
            .onChange(of: model.log.ordered.last?.id) { _, id in
                guard let id else { return }
                let own = model.followSend == id
                if ChatFollow.scrolls(pinned: pinnedToBottom, ownSend: own) {
                    scrollChatToBottom(proxy)
                    showNewMessages = false
                    if own { model.followSend = nil }
                    Task { await model.catchUp(pinned: true) }
                } else {
                    showNewMessages = true
                }
            }
        }
    }

    /// The composer is a sibling under the list, so the scroll view's frame ends above it.
    /// Its identifier is its own element and is not an ancestor of Message or Send.
    private func composerBar(_ proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Composer")
                .font(.system(size: 1))
                .foregroundStyle(.clear)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 1)
                .accessibilityIdentifier("composer")
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                if showNewMessages {
                    Button("New messages") {
                        showNewMessages = false
                        pinnedToBottom = true
                        scrollChatToBottom(proxy)
                        if ChatCatchUp.requests(becamePinned: false, tappedNewMessages: true) {
                            Task { await model.catchUp(pinned: true) }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("new-messages")
                }
                let unread = model.log.unreadCount(viewerId: model.profile?.id ?? model.viewerId ?? UUID())
                if unread > 0 {
                    Text("Unread \(unread)")
                    .accessibilityLabel("\(unread) unread")
                        .font(.caption)
                        .accessibilityIdentifier("unread-count")
                }
                composer
            }
            .padding(.top, SQSpace.m)
            .padding(.bottom, SQSpace.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.canvas)
    }

    private func scrollChatToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(ChatAnchor.end, anchor: .bottom)
    }

    private var callSpotForm: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            TextField("Game", text: Binding(get: { model.spotGame }, set: { model.spotGame = $0 }))
                .textFieldStyle(.roundedBorder)
            Button("Call spots") { Task { await model.callSpots() } }
                .disabled(model.spotGate.busy)
                .accessibilityIdentifier("call-spots")
            Text(model.spotServer.seatTarget
                ? "The server stores a seat target of 8."
                : "Seats are capped at 8. This server does not store a smaller target.")
                .font(.caption)
                .foregroundStyle(SQColor.muted)
        }
        .padding(SQSpace.s)
        .background(SQColor.card, in: RoundedRectangle(cornerRadius: 12))
    }

    private func spotCard(_ spot: SpotCall) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
            let expired = SpotCallRules.showsExpired(spot, now: now)
            let viewer = model.viewerId ?? model.profile?.id
            let mine = viewer.flatMap { spot.seat(for: $0) }
            VStack(alignment: .leading, spacing: SQSpace.s) {
                Text("Calling spots: \(spot.game), \(spot.filled) of \(spot.seatTotal) seats")
                    .font(.headline)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("spot-title")
                Text(statusLine(spot, expired: expired, now: now))
                    .accessibilityLabel(statusLine(spot, expired: expired, now: now))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(SQColor.warning)
                    .accessibilityIdentifier("spot-countdown")
                ForEach(spot.rsvps.filter(\.isIn)) { seat in
                    seatChips(seat)
                }
                Text("Check-in starters can join after the timer. 0013 does not know who is in a game.")
                    .font(.caption2)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                if model.showsLiveGaps && !model.spotServer.ready {
                    Text("Ready isn't stored on the server yet.")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("spot-gap-ready")
                }
                if model.showsLiveGaps && !model.spotServer.gatedLock {
                    Text("Lock doesn't wait for Ready yet.")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("spot-gap-lock")
                }
                if model.showsLiveGaps && !model.spotServer.expiry {
                    Text("This phone decides when the window ends. The server doesn't mark the call expired yet.")
                        .font(.caption2)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("spot-gap-expiry")
                }
                if !model.spotNote.isEmpty {
                    Text(model.spotNote)
                        .font(.caption)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("spot-note")
                }
                if spot.status == .open && !expired {
                    Button("Join") { Task { await model.joinSpot() } }
                        .disabled(model.spotGate.busy || viewer == nil || !SpotCallRules.canJoin(spot, userId: viewer!, now: now))
                        .accessibilityIdentifier("spot-join")
                        .accessibilityLabel("Join the spot call")
                    if mine?.isIn == true && now < spot.joinUntil {
                        Button(mine?.ready == true ? "Ready" : "Ready") { Task { await model.toggleReady() } }
                            .disabled(model.spotGate.busy || model.readyIsLocalOnly)
                            .accessibilityIdentifier("spot-ready")
                            .accessibilityLabel(mine?.ready == true ? "Ready, on" : "Ready, off")
                    }
                    if let viewer, SpotCallRules.canLock(spot, actorId: viewer, ownerId: model.squad?.ownerId ?? viewer, now: now) {
                        Button("Lock") { Task { await model.lockSpot() } }
                            .disabled(model.spotGate.busy)
                            .accessibilityIdentifier("spot-lock")
                            .accessibilityLabel("Lock the spot call")
                    }
                }
                if let viewer, SpotCallRules.canCancel(spot, actorId: viewer, now: now) {
                    Button("Cancel") { Task { await model.cancelSpot() } }
                        .disabled(model.spotGate.busy)
                        .accessibilityIdentifier("spot-cancel")
                        .accessibilityLabel("Cancel the spot call")
                }
                if expired, let viewer, SpotCallRules.canJoin(spot, userId: viewer, now: now) {
                    Button("Join") { Task { await model.joinSpot() } }
                        .disabled(model.spotGate.busy)
                        .accessibilityIdentifier("spot-join")
                        .accessibilityLabel("Join the spot call")
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
            .background(SQColor.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SQColor.line, lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("spot-card")
        }
    }

    private func statusLine(_ spot: SpotCall, expired: Bool, now: Date) -> String {
        if spot.status == .cancelled { return "Cancelled" }
        if spot.status == .ended { return "Ended" }
        if spot.status == .locked { return "Locked" }
        if spot.status == .expired || expired { return "Expired" }
        if spot.filled >= SpotCallRules.cap { return "Full · \(SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now))" }
        return "\(SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now)) left"
    }

    private func seatChips(_ seat: SpotRsvp) -> some View {
        let parts = seatParts(seat)
        return ChipFlow(spacing: SQSpace.xs) {
            ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                Text(part)
                    .font(.caption)
                    .lineLimit(1)
                    .padding(.horizontal, SQSpace.s)
                    .padding(.vertical, SQSpace.xs)
                    .background(SQColor.theirs, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(parts.joined(separator: ", "))
    }

    private func seatParts(_ seat: SpotRsvp) -> [String] {
        var parts = [seat.name]
        if seat.starter { parts.append("starter") }
        parts.append(seat.ready ? "Ready" : "In")
        return parts
    }

    private func openLauncher(_ destination: PartyLauncher.Destination) {
        let application = UIApplication.shared
        let url = application.canOpenURL(destination.scheme) ? destination.scheme : destination.web
        application.open(url)
    }

    private func activeCallBar(_ spot: SpotCall, now: Date) -> some View {
        let viewer = model.viewerId ?? model.profile?.id
        let action = viewer.flatMap {
            SpotCallRules.barAction(spot, viewerId: $0, ownerId: model.squad?.ownerId ?? $0, now: now)
        }
        return VStack(alignment: .leading, spacing: SQSpace.xs) {
            Text(spot.game)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(spot.filled) of \(spot.seatTotal)")
                .font(.subheadline)
                .lineLimit(1)
            Text(SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now))
                .font(.subheadline.monospacedDigit())
                .lineLimit(1)
                .accessibilityIdentifier("active-call-countdown")
            if let action { barButton(action) }
        }
        .padding(SQSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.card, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(SQColor.line, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("active-call-bar")
    }

    private func barButton(_ action: SpotBarAction) -> some View {
        Button(action.title) { Task { await runBar(action) } }
            .disabled(model.spotGate.busy || (action == .ready && model.readyIsLocalOnly))
            .accessibilityIdentifier(action.identifier)
            .accessibilityLabel(barLabel(action))
    }

    private func barLabel(_ action: SpotBarAction) -> String {
        switch action {
        case .join: return "Join the spot call"
        case .leave: return "Leave the spot call"
        case .ready:
            let viewer = model.viewerId ?? model.profile?.id
            let on = viewer.flatMap { model.spot?.seat(for: $0)?.ready } == true
            return on ? "Ready, on" : "Ready, off"
        case .lock: return "Lock the spot call"
        case .cancel: return "Cancel the spot call"
        }
    }

    private func runBar(_ action: SpotBarAction) async {
        switch action {
        case .join: await model.joinSpot()
        case .leave: await model.leaveSpot()
        case .ready: await model.toggleReady()
        case .lock: await model.lockSpot()
        case .cancel: await model.cancelSpot()
        }
    }

    private var composer: some View {
        HStack(alignment: .center) {
            TextField("Message", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                .textFieldStyle(.roundedBorder)
            Button("Send") { Task { await model.send() } }
                .accessibilityIdentifier("send-message")
        }
        .frame(maxHeight: composerLine * 3)
    }

    private var membershipSheet: some View {
        let ownerId = model.profile?.id ?? model.viewerId
        let isOwner = model.squad?.ownerId == ownerId
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.m) {
                Text("Members")
                    .font(.title2.weight(.semibold))
                Text(model.squad.map { SquadTitle.line(name: $0.name, memberCount: $0.members.count) } ?? "You're not in a squad yet.")
                    .accessibilityIdentifier("squad-count")
                if !model.status.isEmpty {
                    Text(model.status)
                        .font(.footnote)
                        .foregroundStyle(model.membershipIsError ? SQColor.danger : SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("membership-status")
                }
                joinControls
                if model.squad?.members.isEmpty != false && model.squad != nil {
                    Text("No members yet.")
                        .accessibilityIdentifier("members-empty")
                }
                if let squad = model.squad {
                    ForEach(squad.members) { member in
                        HStack {
                            Text(member.isOwner ? "\(member.displayName) · Owner" : member.displayName)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                                .accessibilityLabel(member.isOwner ? "\(member.displayName), owner" : member.displayName)
                            Spacer()
                            if isOwner && !member.isOwner {
                                Button("Remove \(member.displayName)") {
                                    Task { await model.removeMember(member) }
                                }
                                .disabled(model.busy)
                                .accessibilityIdentifier("remove-\(member.displayName)")
                                .accessibilityLabel("Remove \(member.displayName)")
                            }
                        }
                    }
                    if model.leaveAvailable {
                        leaveControls(squad: squad, isOwner: isOwner)
                    }
                    if let line = LeaveAvailabilityCopy.line(isOwner: isOwner, leaveShown: model.leaveAvailable) {
                        Text(line)
                            .font(.footnote)
                            .foregroundStyle(SQColor.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("leave-unavailable")
                    }
                }
                if isOwner {
                    inviteControls
                    if model.inviteCode.isEmpty {
                        Text("No invite yet.")
                            .font(.footnote)
                            .foregroundStyle(SQColor.muted)
                            .accessibilityIdentifier("invite-empty")
                    }
                }
            }
            .padding(SQSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .adoptingLaunchDynamicType()
        .onAppear { Task { await model.probeLeave() } }
    }

    private func leaveControls(squad: SquadRecord, isOwner: Bool) -> some View {
        let me = model.profile?.id ?? model.viewerId
        let others = squad.members.filter { !$0.isOwner }
        return VStack(alignment: .leading, spacing: SQSpace.s) {
            if me != nil {
                Button("Leave") { confirmLeave = true }
                    .disabled(model.busy)
                    .accessibilityIdentifier("leave-squad")
                    .accessibilityLabel(isOwner && squad.members.count > 1 ? "Leave and transfer ownership" : "Leave the squad")
                if confirmLeave {
                    if isOwner && squad.members.count > 1 {
                        if MembershipPrompt.shows(selected: model.transferTo) {
                            Text(MembershipPrompt.transfer)
                                .font(.footnote)
                                .foregroundStyle(SQColor.muted)
                                .accessibilityIdentifier("transfer-prompt")
                        }
                        ForEach(others) { member in
                            Button(model.transferTo == member.id ? "Next owner \(member.displayName)" : "Transfer to \(member.displayName)") {
                                model.transferTo = member.id
                                model.status = MembershipPrompt.status(afterSelecting: model.status)
                                if model.status.isEmpty { model.membershipIsError = false }
                            }
                            .disabled(model.busy)
                            .accessibilityIdentifier("transfer-\(member.displayName)")
                            .accessibilityLabel(model.transferTo == member.id ? "Next owner \(member.displayName), selected" : "Transfer to \(member.displayName)")
                        }
                    }
                    Text("Leave the squad?")
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("confirm-leave-title")
                    Text("You can join again with a code.")
                        .font(.footnote)
                        .foregroundStyle(SQColor.muted)
                    Button(model.busy ? "Leaving…" : "Leave squad") {
                        Task {
                            await model.leaveSquad()
                            if model.squad == nil {
                                confirmLeave = false
                                showMembers = false
                            }
                        }
                    }
                    .disabled(model.busy)
                    .accessibilityIdentifier("confirm-leave")
                    .accessibilityLabel("Confirm leaving the squad")
                    Button("Stay") { confirmLeave = false }
                        .disabled(model.busy)
                        .accessibilityIdentifier("cancel-leave")
                }
            }
        }
    }

    private var inviteControls: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            Button("Create invite") { Task { await model.createInvite() } }
                .disabled(model.busy)
                .accessibilityIdentifier("create-invite")
            if !model.inviteCode.isEmpty {
                Text(model.inviteCode)
                    .font(.body.monospaced())
                    .accessibilityIdentifier("invite-code")
                ShareLink(item: model.inviteCode) {
                    Text("Share")
                }
                Button("Copy") {
                    UIPasteboard.general.string = model.inviteCode
                    model.membershipIsError = false
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
                .accessibilityIdentifier("join-squad")
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
            .accessibilityLabel(MessageSpeech.row(body: entry.body, delivery: entry.delivery))
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
                    .accessibilityIdentifier("retry-send")
                    .accessibilityLabel("Retry sending")
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

private struct ChipFlow: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        guard width > 0 else {
            let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
            let height = sizes.map(\.height).max() ?? 0
            let total = sizes.map(\.width).reduce(0, +) + spacing * CGFloat(max(sizes.count - 1, 0))
            return CGSize(width: total, height: height)
        }
        let rows = rows(width: width, subviews: subviews)
        let height = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +)
            + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = rows(width: bounds.width, subviews: subviews)
        var y = bounds.minY
        var index = 0
        for row in rows {
            let rowHeight = row.map(\.height).max() ?? 0
            var x = bounds.minX
            for size in row {
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
                index += 1
            }
            y += rowHeight + spacing
        }
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var used: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let next = used == 0 ? size.width : used + spacing + size.width
            if used > 0, next > width {
                rows.append([size])
                used = size.width
            } else {
                rows[rows.count - 1].append(size)
                used = next
            }
        }
        return rows
    }
}

private struct WideRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }
}

private enum ChatAnchor {
    static let end = "message-list-end"
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
