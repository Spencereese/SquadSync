import SwiftUI
import UIKit
import UserNotifications

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
    /// History read for the open squad: loading, loaded, or why it failed.
    var chatLoad = ChatHistoryState.idle
    /// Where the unread divider sits. Settled on the squad's first load, cleared when you send.
    var unreadMarker = ChatUnreadMarker()
    /// What the server lets the chat do. Replies stay off until `reply_to_id` is found.
    var chatCaps = ChatCapabilities.unknown
    /// The message the composer is replying to.
    var replyingTo: UUID?
    /// A short confirmation, like "Copied".
    var chatToast = ""
    /// Copies text to the clipboard. Tests swap it out.
    @ObservationIgnored var copyText: (String) -> Void = { UIPasteboard.general.string = $0 }
    var viewerId: UUID?
    var spot: SpotCall?
    var spotGame = "Warzone"
    var spotGate = SpotActionGate()
    var resumedAt = Date.distantPast
    var leaveAvailable = false
    var renameAvailable = false
    var renameDraft = ""
    var transferTo: UUID?
    var spotNote = ""
    /// How many times the spot card was read. A failed call increments it.
    var spotLoads = 0
    var spotServer = SpotServerCapabilities.unavailable
    /// Finished calls from the server, shown as compact cards in the thread.
    var spotHistory: [SpotCall] = []
    /// Set when the history read fails. The thread says so instead of looking empty.
    var spotHistoryNote = ""
    var spotLoad = SpotLoadState.idle
    /// The call sheet opened from the composer's + menu or a bare `/spots`.
    var spotSheetOpen = false
    var spotSheet = SpotSheetState.editing
    var status = ""
    var reconnecting = false
    var notes: [String] = [
        LiveShellCopy.footer
    ]
    var busy = false
    /// Voice is a mock on the home header. The pill drives the in-memory room only.
    var voicePill = VoicePillState()
    /// The status line the last failed send wrote, so a later success can clear exactly that.
    var sendFailureStatus: String?

    private let config: BackendConfig
    private let voiceRoom: VoiceRoomService = InMemoryVoiceRoomService()
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
            let chat = MockChatService(
                replies: scenario != .chatNoReplies,
                historyDown: scenario == .chatHistoryFailed,
                historyDelay: scenario == .chatHistorySlow ? 3 : 0
            )
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
            } else if scenario.isChatScenario {
                // History comes from the mock server on the first load, so the
                // loading, empty, error, and unread states run like they do live.
                let seeded = squads.seedSpotSquad(ownerId: session.userId)
                self.squad = seeded
                self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: nil)
                if scenario != .chatEmpty {
                    let thread = ChatPolishSeed.thread(
                        viewerId: session.userId,
                        squadId: seeded.id,
                        now: Date(),
                        replies: scenario != .chatNoReplies
                    )
                    for message in thread.messages { chat.seed(message) }
                    for read in thread.reads { chat.seedRead(userId: read.userId, at: read.lastReadAt) }
                    for mark in thread.reactions { chat.seedReaction(mark) }
                }
            } else if scenario == .spotHistory || scenario == .spotServerMissing {
                let seeded = squads.seedSpotSquad(ownerId: session.userId)
                self.squad = seeded
                let now = Date()
                if scenario == .spotHistory {
                    let past = SpotSeed.history(ownerId: session.userId, squadId: seeded.id, now: now)
                    self.spotHistory = past
                    self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: nil, past: past)
                    let lines: [(String, TimeInterval, UUID)] = [
                        ("Who's on tonight?", -55 * 60, SpotSeed.alex),
                        ("Apex was fun", -20 * 60, SpotSeed.jordan),
                        ("Again later?", -5 * 60, session.userId)
                    ]
                    for (index, line) in lines.enumerated() {
                        let message = RemoteMessage(
                            id: UUID(uuidString: "00000000-0000-0000-0000-00000000020\(index + 1)")!,
                            squadId: seeded.id,
                            senderId: line.2,
                            body: line.0,
                            sentAt: now.addingTimeInterval(line.1)
                        )
                        chat.seed(message)
                        log.ingest([message.entry()])
                    }
                } else {
                    self.mockSpots = MockSpotService(viewerId: session.userId, ownerId: session.userId, call: nil, serverMissing: true)
                }
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
            settlePush(signedIn: true)
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
                settlePush(signedIn: true)
            } catch let problem as InviteProblem {
                membershipIsError = true
                status = problem.message
            }
        }
    }

    func probeRename() async {
        let me = profile?.id ?? viewerId
        guard let session = try? requiredSession(), squad?.ownerId == me else {
            renameAvailable = false
            return
        }
        renameAvailable = await squadService(session).renameAvailable()
    }

    func renameSquad() async {
        let trimmed = SquadName.normalized(renameDraft)
        if let error = SquadName.renameError(trimmed) {
            membershipIsError = true
            status = error
            return
        }
        guard let session = try? requiredSession(), let current = squad else { return }
        membershipIsError = false
        busy = true
        defer {
            busy = false
            settlePush(signedIn: (try? requiredSession()) != nil)
        }
        do {
            try await squadService(session).renameSquad(
                squadId: current.id,
                name: trimmed.isEmpty ? nil : trimmed
            )
            squad = try await squadService(session).currentSquad(userId: session.userId)
            renameDraft = squad?.name ?? ""
            status = "Renamed."
        } catch let failure as BackendFailure {
            membershipIsError = true
            if case .rejected(let message) = failure {
                status = message
            } else {
                status = "Could not rename the squad."
            }
        } catch {
            membershipIsError = true
            status = error.localizedDescription
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
        spotLoads += 1
        defer { scheduleExpiryRead(session) }
        spotLoad = SpotLoadState.beginning(spotLoad, hasCard: spot != nil)
        let service = spotService(session)
        spotServer = await service.serverCapabilities()
        await loadSpotHistory(service, squad: squad)
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
            spotLoad = SpotLoadState.finished(failure: nil)
        } catch {
            spotLoad = SpotLoadState.finished(failure: SpotThread.loadFailed)
            report(error)
        }
    }

    /// Read-only. A failure keeps the cards already shown and adds an honest note.
    private func loadSpotHistory(_ service: SpotServing, squad: SquadRecord) async {
        do {
            let past = try await service.history(squadId: squad.id, limit: SpotThread.historyLimit)
            spotHistory = past
            spotHistoryNote = ""
        } catch {
            spotHistoryNote = SpotThread.historyUnavailable
        }
    }

    func retrySpotLoad() async {
        await reloadSpotAfterFailure()
    }

    /// The composer's + menu and a bare `/spots`. An active call keeps its card and
    /// says why instead of opening a second call.
    func openSpotCall(now: Date = Date()) {
        guard SpotThread.canCallNow(spot, now: now) else {
            spotNote = SpotProblem.alreadyOpen.message
            return
        }
        if spotGame.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let fallback = defaultGame.trimmingCharacters(in: .whitespacesAndNewlines)
            spotGame = fallback.isEmpty ? "Warzone" : fallback
        }
        spotSheet = .editing
        spotSheetOpen = true
    }

    func callSpotsFromSheet() async {
        spotSheet = .calling
        let called = await callSpots()
        spotSheet = SpotSheetState.after(success: called, message: spotNote)
        if called { spotSheetOpen = false }
    }

    /// `/spots` opens the sheet. `/spots Apex` calls right away.
    func runSpotCommand(_ command: SpotCommand, now: Date = Date()) async {
        switch command {
        case .call(let game):
            guard SpotThread.canCallNow(spot, now: now) else {
                spotNote = SpotProblem.alreadyOpen.message
                return
            }
            if let game {
                spotGame = game
                await callSpots()
            } else {
                openSpotCall(now: now)
            }
        }
    }

    /// True when the call went through.
    @discardableResult
    func callSpots() async -> Bool {
        let game = spotGame.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !game.isEmpty else {
            spotNote = SpotProblem.gameBlank.message
            return false
        }
        guard spotGate.begin() else { return false }
        defer { spotGate.finish() }
        do {
            let session = try requiredSession()
            guard let squad else { return false }
            _ = try await spotService(session).call(squadId: squad.id, game: game, startsAt: Date())
            await loadSpot(session)
            spotNote = "Calling spots: \(game), 8 seats."
            return true
        } catch let problem as SpotProblem {
            spotNote = problem.message
            await reloadSpotAfterFailure()
            return false
        } catch {
            report(error)
            spotNote = status.isEmpty ? SpotThread.loadFailed : status
            await reloadSpotAfterFailure()
            return false
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

    func endSpot() async {
        // sq8_end_spot updates the call row. The other client's sq8_spot_calls
        // subscription turns that into .spots, which reloads their card.
        await changeSpot(reloadAfterFailure: true) { session, call in
            try await spotService(session).end(callId: call.id)
            spotNote = "Ended."
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
        if let command = SpotCommand.parse(text) {
            draft = ""
            await runSpotCommand(command)
            return
        }
        let session: AuthSession
        do {
            session = try requiredSession()
        } catch {
            status = (error as? SessionStoreError)?.message ?? "Session restore failed. \(error)"
            return
        }
        let id = UUID()
        let now = Date()
        let reply = chatCaps.replies ? replyingTo : nil
        log.beginSend(id: id, senderId: session.userId, body: text, now: now, replyToId: reply)
        followSend = id
        draft = ""
        replyingTo = nil
        unreadMarker.clear()
        await deliver(
            RemoteMessage(id: id, squadId: squad.id, senderId: session.userId, body: text, sentAt: now, replyToId: reply),
            session: session
        )
    }

    /// Long-press Copy. Says so for a moment, since the clipboard shows nothing.
    func copy(_ id: UUID) {
        guard let entry = log.entries.first(where: { $0.id == id }) else { return }
        copyText(entry.body)
        showToast("Copied")
    }

    /// Long-press Reply. Only when the server has `reply_to_id`; otherwise it says why.
    func startReply(_ id: UUID) {
        guard chatCaps.replies else {
            showToast(ChatCapabilities.repliesUnavailable)
            return
        }
        guard log.entries.contains(where: { $0.id == id && $0.delivery == .sent }) else { return }
        replyingTo = id
    }

    func cancelReply() {
        replyingTo = nil
    }

    /// The quote for the reply banner, from the loaded thread.
    var replyQuote: ChatReplyQuote? {
        guard let replyingTo else { return nil }
        let original = log.entries.first { $0.id == replyingTo }
        return ChatReplyQuote(
            id: replyingTo,
            sender: original.map { senderName($0.senderId) },
            body: original?.body
        )
    }

    func senderName(_ id: UUID) -> String {
        if id == (profile?.id ?? viewerId) { return ChatThread.you }
        return squad?.members.first { $0.id == id }?.displayName ?? ChatThread.unknownSender
    }

    /// Display names by user id for the thread rows.
    var memberNames: [UUID: String] {
        Dictionary((squad?.members ?? []).map { ($0.id, $0.displayName) }, uniquingKeysWith: { first, _ in first })
    }

    @ObservationIgnored private var toastTask: Task<Void, Never>?

    func showToast(_ text: String) {
        chatToast = text
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            if self?.chatToast == text { self?.chatToast = "" }
        }
    }

    /// Retry on the history error row.
    func retryChatLoad() async {
        // The mock server comes back on Retry, so the UI test can see both states.
        if let mock = mockChat as? MockChatService, mock.historyDown { mock.historyDown = false }
        await reloadChat()
    }

    /// Reads the open squad's history, reactions, and receipts again.
    func reloadChat() async {
        guard let session = try? requiredSession() else { return }
        await loadChat(session)
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
        let message = RemoteMessage(
            id: id,
            squadId: squad.id,
            senderId: entry.senderId,
            body: entry.body,
            sentAt: entry.sentAt,
            replyToId: entry.replyToId
        )
        await deliver(message, session: session)
    }

    /// Presence strip rows for the home header. Only real signals: spot seats and the viewer.
    func presenceEntries(now: Date) -> [SquadPresenceEntry] {
        guard let squad else { return [] }
        return SquadPresence.entries(
            members: squad.members,
            ownerId: squad.ownerId,
            viewerId: viewerId ?? profile?.id,
            spot: spot,
            now: now
        )
    }

    /// Joins or leaves the in-memory voice room. Nothing goes over the network.
    func toggleVoice() async {
        let user = (viewerId ?? profile?.id)?.uuidString ?? "viewer"
        if voicePill.joined {
            await voiceRoom.leave(userId: user)
        } else {
            voicePill.connection = .connecting
            await voiceRoom.join(userId: user)
        }
        voicePill.joined = voiceRoom.participants.contains { $0.id == user }
        voicePill.count = voiceRoom.participants.count
        voicePill.connection = voiceRoom.connection
    }

    func signOut() async {
        if voicePill.joined { await toggleVoice() }
        realtime?.stop()
        realtime = nil
        poll?.cancel()
        poll = nil
        do {
            if case .unregister(let token) = PushCoordinator.shared.signOutAction(),
               let session = try? requiredSession() {
                do {
                    try await squadService(session).unregisterPushToken(token)
                } catch {
                    PushCoordinator.shared.noteStoreFailure(PushStoreFailure.reason(error))
                }
            }
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
        settlePush(signedIn: false)
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
            recoverAfterSend()
        case .staySending:
            break
        case .failed:
            log.markFailed(id: message.id)
            if let error {
                report(error)
                sendFailureStatus = status
            }
        }
    }

    /// A delivered message clears "Reconnecting…" and the failed-send line it replaced.
    func recoverAfterSend() {
        status = SendRecovery.status(afterSuccess: status, sendFailure: sendFailureStatus)
        sendFailureStatus = nil
        reconnecting = false
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
            settlePush(signedIn: true)
        } catch {
            handleSessionError(error)
        }
    }

    func settlePush(signedIn: Bool) {
        PushCoordinator.shared.settle(
            signedIn: signedIn,
            squadId: squad?.id,
            membershipKnown: signedIn
        )
        if let message = PushCoordinator.shared.focusMessage {
            followSend = message
        }
        guard signedIn else { return }
        PushCoordinator.shared.askIfReady(signedIn: true, hasSquad: squad != nil)
        registerForPushTokensIfAllowed()
    }

    /// Every signed-in launch and foreground. Permission was already decided; this only refreshes the token.
    func registerForPushTokensIfAllowed() {
        if let seen = PushCoordinator.shared.seenToken,
           PushCoordinator.shared.plan(seen) != .none {
            let token = seen
            Task { await syncPushToken(token) }
        }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let state = PushAuthState(status: settings.authorizationStatus)
            DispatchQueue.main.async {
                PushCoordinator.shared.performRegistration(status: state) {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func syncPushToken(_ token: String) async {
        guard let session = try? requiredSession() else {
            PushCoordinator.shared.noteSeen(token)
            PushCoordinator.shared.noteStoreFailure(PushStoreFailure.signedOut)
            return
        }
        await PushTokenSync.apply(token: token, service: squadService(session), coordinator: .shared)
    }

    func settleIncomingPush() async {
        guard let session = try? requiredSession() else {
            settlePush(signedIn: false)
            return
        }
        if busy { return }
        await refresh(session)
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
            unreadMarker.reset()
            replyingTo = nil
            chatCaps = .unknown
            loadedSquad = requested
        }
        chatLoad = .loading
        do {
            let chat = chatService(session)
            chatCaps = ChatCapabilities(replies: await chat.repliesAvailable())
            // The cursor is read first, so nothing marks the chat read between the
            // history landing and the unread divider settling.
            let cursor = try? await chat.ownReadAt(squadId: requested, userId: session.userId)
            let rows = try await chat.history(squadId: requested)
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return }
            log.adopt(replacingSquad: false, history: rows.map { $0.entry() })
            chatLoad = .loaded
            if let cursor { log.markRead(at: cursor) }
            unreadMarker.settle(log: log, viewerId: session.userId)
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return }
            if let marks = try? await chat.reactions(squadId: squad.id) {
                board.replace(with: marks)
            }
            if let remoteReads = try? await chat.reads(squadId: squad.id) {
                reads = remoteReads
            }
        } catch {
            if !RequestNoise.isCancellation(error) {
                chatLoad = ChatHistoryState.failure(error)
            }
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
            chatLoad = .loaded
            await loadSpot(session)
        } catch {
            if RequestNoise.isCancellation(error) { return }
            report(error)
            if let failure = error as? BackendFailure, case .notSetUp(.messages) = failure { poll?.cancel() }
        }
    }

    private func run(_ work: () async throws -> Void) async {
        busy = true
        defer {
            busy = false
            settlePush(signedIn: (try? requiredSession()) != nil)
        }
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
        mockChat ?? SupabaseChatService(
            config: config,
            accessToken: session.accessToken,
            refresher: tokenRefresher,
            knownReplies: chatCaps.replies ? true : nil
        )
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
    @State private var wentToBackground = false
    @State private var confirmSignOut = false
    @State private var confirmEndSpot = false
    @State private var showMembers = false
    /// Large-text presence roster, floated over the chat instead of pushing it down.
    @State private var rosterOpen = false
    @State private var confirmLeave = false
    @ScaledMetric(relativeTo: .body) private var composerLine: CGFloat = 22
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @FocusState private var composerFocused: Bool

    init(config: BackendConfig = .fromBundle(), backend: BackendMode = .live, scenario: LaunchScenario = .seated) {
        _model = State(initialValue: LiveSessionModel(config: config, backend: backend, scenario: scenario))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SQColor.surface0
                    .ignoresSafeArea()
                Group {
                    if model.phase == .ready {
                        ready
                    } else {
                        signIn
                    }
                }
                .padding(.horizontal, model.phase == .ready ? SQSpace.m : SQSpace.l)
                .padding(.vertical, model.phase == .ready ? SQSpace.s : SQSpace.l)
                .safeAreaInset(edge: .top, spacing: 0) {
                    if pushToastText != nil {
                        pushToast
                            .padding(.top, SQSpace.s)
                            .padding(.bottom, SQSpace.xs)
                    }
                }
            }
            .navigationTitle(squadTitle ?? "SquadSync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            // Chat-first: once signed in, the squad header replaces the navigation bar.
            // Sign-in keeps the system bar and its "SquadSync" title.
            .toolbar(model.phase == .ready ? .hidden : .visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $confirmSignOut) {
            signOutSheet
                .adoptingLaunchDynamicType()
        }
        .sheet(isPresented: Binding(get: { model.spotSheetOpen }, set: { model.spotSheetOpen = $0 })) {
            spotCallSheet
        }
        .sheet(isPresented: $showMembers) {
            membershipSheet
                .adoptingLaunchDynamicType()
        }
        .task { await model.restore() }
        .onReceive(NotificationCenter.default.publisher(for: .sq8PushToken)) { note in
            guard let token = note.object as? String else { return }
            Task { await model.syncPushToken(token) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sq8PushRoute)) { _ in
            Task { await model.settleIncomingPush() }
        }
        .task(id: pushToastText) {
            guard let message = pushToastText else { return }
            UIAccessibility.post(notification: .announcement, argument: message)
            try? await Task.sleep(nanoseconds: UInt64(PushToast.lifetime * 1_000_000_000))
            guard !Task.isCancelled else { return }
            guard pushToastText == message else { return }
            PushCoordinator.shared.dismissToast()
        }
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

    private var pushToastText: String? {
        PushToast.text(
            notice: PushCoordinator.shared.notice,
            openedChat: PushCoordinator.shared.openedChat,
            openedSquad: PushCoordinator.shared.openedSquad
        )
    }

    private var pushToast: some View {
        Group {
            if let message = pushToastText,
               let identifier = PushToast.identifier(
                notice: PushCoordinator.shared.notice,
                openedChat: PushCoordinator.shared.openedChat,
                openedSquad: PushCoordinator.shared.openedSquad
               ) {
                Button {
                    PushCoordinator.shared.dismissToast()
                } label: {
                    Text(message)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(SQColor.ink)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, SQSpace.m)
                        .padding(.vertical, SQSpace.s)
                        .background(SQColor.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12).stroke(SQColor.line, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, SQSpace.s)
                .contentShape(Rectangle())
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(message)
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    private var squadTitle: String? {
        guard model.phase == .ready, let squad = model.squad else { return nil }
        return SquadTitle.line(name: squad.name, memberCount: squad.members.count)
    }

    /// Chat-first home: header, pinned spot bar, then the chat fills the rest.
    /// Profile, members, rename, invite, and leave live in the squad panel.
    private var ready: some View {
        VStack(alignment: .leading, spacing: rowGap) {
            homeHeader
            readyBody
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    /// Accessibility sizes trim the gaps between header, status, bar, and chat.
    private var rowGap: CGFloat {
        typeSize.isAccessibilitySize ? SQSpace.xs : SQSpace.s
    }

    private var readyBody: some View {
        VStack(alignment: .leading, spacing: rowGap) {
            if model.squad != nil, !model.status.isEmpty {
                Text(model.status)
                    .font(SQType.caption)
                    .foregroundStyle(SQColor.subtle)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, SQSpace.xs)
                    .accessibilityIdentifier("home-status")
            }
            if let spot = model.spot {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
                    if SpotCallRules.showsPinnedBar(spot, now: now) {
                        activeCallBar(spot, now: now)
                    }
                }
            }
            if model.squad != nil {
                chatList
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .layoutPriority(1)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: SQSpace.m) {
                        if model.reconnecting {
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
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var homeHeader: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
            SquadHomeHeader(
                squad: model.squad,
                entries: model.presenceEntries(now: now),
                compact: typeSize.isAccessibilitySize && composerFocused,
                voice: model.voicePill,
                linkNote: model.squad == nil ? nil : liveNotice,
                onOpenPanel: { showMembers = true },
                onAccount: { confirmSignOut = true },
                onVoice: { Task { await model.toggleVoice() } },
                rosterOpen: $rosterOpen
            )
        }
    }

    private var showsRoster: Bool {
        rosterOpen && typeSize.isAccessibilitySize && !composerFocused && model.squad != nil
    }

    /// Floats over the top of the message list. It is offered the list's height and
    /// picks the longest roster that fits, so its last row is always fully visible.
    private var presenceRoster: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
            SquadPresenceRoster(
                entries: model.presenceEntries(now: now),
                voice: model.voicePill,
                onOpenPanel: {
                    rosterOpen = false
                    showMembers = true
                },
                onVoice: { Task { await model.toggleVoice() } }
            )
        }
        .frame(maxHeight: .infinity, alignment: .top)
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
                            spotSlot(now: now)
                        }
                        if !model.spotHistoryNote.isEmpty {
                            SpotStatusRow(text: model.spotHistoryNote, identifier: "spot-history-note")
                        }
                        if let display = model.chatLoad.display(hasMessages: !model.log.entries.isEmpty) {
                            ChatHistoryRow(display: display) {
                                Task { await model.retryChatLoad() }
                            }
                        }
                        ForEach(chatRows) { row in
                            switch row {
                            case .day(_, let label):
                                ChatDaySeparator(label: label)
                            case .unread(let count):
                                ChatUnreadDivider(count: count)
                            case .message(let bubble):
                                messageRow(bubble).id(bubble.entry.id)
                            case .spot(let call):
                                if let outcome = SpotThread.outcome(call, viewerId: spotViewer, now: Date()) {
                                    SpotHistoryCard(call: call, outcome: outcome)
                                }
                            }
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
                .overlay(alignment: .top) {
                    // Floats over the message list only: the pinned spot bar above and
                    // the composer below stay uncovered, and the list keeps its height.
                    if showsRoster {
                        presenceRoster
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if ChatJump.shows(pinned: pinnedToBottom, hasMessages: !model.log.entries.isEmpty), !showsRoster {
                        ChatJumpButton(newCount: unreadForViewer) {
                            pinnedToBottom = true
                            scrollChatToBottom(proxy)
                            if ChatCatchUp.requests(becamePinned: false, tappedNewMessages: true) {
                                Task { await model.catchUp(pinned: true) }
                            }
                        }
                        .padding(SQSpace.s)
                    }
                }
                composerBar(proxy)
            }
            .onAppear {
                if let id = model.followSend {
                    proxy.scrollTo(id, anchor: .center)
                    return
                }
                guard model.log.ordered.last != nil else { return }
                Task { @MainActor in
                    scrollChatToBottom(proxy)
                    await model.catchUp(pinned: pinnedToBottom)
                }
            }
            .onChange(of: model.followSend) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
            }
            .onChange(of: pinnedToBottom) { wasPinned, isPinned in
                if ChatCatchUp.requests(becamePinned: isPinned && !wasPinned, tappedNewMessages: false) {
                    Task { await model.catchUp(pinned: true) }
                }
            }
            .onChange(of: model.log.ordered.last?.id) { _, id in
                guard let id else { return }
                let own = model.followSend == id
                if ChatFollow.scrolls(pinned: pinnedToBottom, ownSend: own) {
                    scrollChatToBottom(proxy)
                    if own { model.followSend = nil }
                    Task { await model.catchUp(pinned: true) }
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
                if !model.chatToast.isEmpty {
                    Text(model.chatToast)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.subtle)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("chat-toast")
                }
                if let quote = model.replyQuote {
                    ChatReplyBanner(quote: quote) { model.cancelReply() }
                }
                composer
            }
            .padding(.top, typeSize.isAccessibilitySize ? SQSpace.s : SQSpace.m)
            .padding(.bottom, typeSize.isAccessibilitySize ? SQSpace.xs : SQSpace.s)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SQColor.surface0)
    }

    private func scrollChatToBottom(_ proxy: ScrollViewProxy) {
        proxy.scrollTo(ChatAnchor.end, anchor: .bottom)
    }

    private var spotViewer: UUID? { model.viewerId ?? model.profile?.id }

    private var unreadForViewer: Int {
        model.log.unreadCount(viewerId: model.profile?.id ?? model.viewerId ?? UUID())
    }

    /// Thread rows with day separators, the unread divider, and message groups.
    private var chatRows: [ChatRow] {
        ChatThread.rows(
            items: threadItems,
            context: ChatThread.Context(
                viewerId: model.profile?.id ?? model.viewerId,
                names: model.memberNames,
                reads: model.reads,
                unreadAnchor: model.unreadMarker.anchor,
                clock: .current,
                now: Date()
            )
        )
    }

    /// Messages with finished calls from the server between them. The current call
    /// stays out: it sits in the top slot, pinned or as history, until the next read.
    private var threadItems: [SpotThreadItem] {
        let history = SpotThread.history(
            past: model.spotHistory,
            excluding: model.spot?.id,
            viewerId: spotViewer,
            now: Date()
        )
        return SpotThread.items(entries: model.log.ordered, history: history)
    }

    /// Top of the thread. An active call keeps its full card here (with the pinned bar
    /// above the chat); once it ends, cancels, or expires the same slot turns into a
    /// compact history card. Loading and failed reads say so.
    @ViewBuilder
    private func spotSlot(now: Date) -> some View {
        if SpotThread.canCallNow(model.spot, now: now) {
            callSpotForm
        }
        if let spot = model.spot {
            switch SpotThread.phase(spot, viewerId: spotViewer, now: now) {
            case .active:
                spotCard(spot)
            case .history(let outcome):
                SpotHistoryCard(call: spot, outcome: outcome)
                if !model.spotNote.isEmpty {
                    Text(model.spotNote)
                        .font(.caption)
                        .foregroundStyle(SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, SQSpace.m)
                        .accessibilityIdentifier("spot-note")
                }
            }
        } else if model.spotLoad.showsLoadingRow {
            SpotStatusRow(text: "Loading the spot call…", loading: true, identifier: "spot-loading")
        } else if let failure = model.spotLoad.failure {
            SpotStatusRow(text: failure, identifier: "spot-load-failed") {
                Task { await model.retrySpotLoad() }
            }
        }
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
            if model.spot == nil, !model.spotNote.isEmpty {
                Text(model.spotNote)
                    .font(.caption)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("spot-note")
            }
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
                    if let viewer, SpotCallRules.canEnd(spot, actorId: viewer, ownerId: model.squad?.ownerId ?? viewer) {
                        Button { confirmEndSpot = true } label: {
                            Text("End spot")
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .disabled(model.spotGate.busy)
                        .accessibilityIdentifier("spot-end")
                        .accessibilityLabel("End the spot call")
                    }
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
            .sheet(isPresented: $confirmEndSpot) {
                endSpotConfirm
            }
        }
    }

    private var endSpotConfirm: some View {
        VStack(alignment: .leading, spacing: SQSpace.l) {
            Text("End this spot?")
                .font(.title2.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text("People can call a new spot after this one ends.")
                .foregroundStyle(SQColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button("End spot", role: .destructive) {
                confirmEndSpot = false
                Task { await model.endSpot() }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("spot-end-confirm")
            Button("Cancel", role: .cancel) { confirmEndSpot = false }
                .accessibilityIdentifier("spot-end-cancel")
        }
        .padding(SQSpace.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .adoptingLaunchDynamicType()
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

    /// Pinned spot bar. One row when it fits: game, countdown, and seats beside the
    /// action. At large text it drops the game (the card and VoiceOver still name it)
    /// and caps its text at AX1, so it stays one thin row and the chat keeps the screen.
    private func activeCallBar(_ spot: SpotCall, now: Date) -> some View {
        let viewer = model.viewerId ?? model.profile?.id
        let action = viewer.flatMap {
            SpotCallRules.barAction(spot, viewerId: $0, ownerId: model.squad?.ownerId ?? $0, now: now)
        }
        let countdown = SpotCallRules.countdown(joinUntil: spot.joinUntil, now: now)
        let seats = "\(spot.filled)/\(spot.seatTotal)"
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: SQSpace.s) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(spot.game)
                        .font(SQType.section)
                        .lineLimit(1)
                    HStack(spacing: SQSpace.s) {
                        barCountdown(countdown)
                        barSeats(seats)
                    }
                }
                .fixedSize()
                Spacer(minLength: SQSpace.s)
                if let action { barButton(action).fixedSize() }
            }
            HStack(alignment: .center, spacing: SQSpace.s) {
                barCountdown(countdown)
                barSeats(seats)
                Spacer(minLength: SQSpace.s)
                if let action { barButton(action).fixedSize() }
            }
            VStack(alignment: .leading, spacing: SQSpace.xs) {
                HStack(spacing: SQSpace.s) {
                    barCountdown(countdown)
                    barSeats(seats)
                }
                if let action { barButton(action) }
            }
        }
        // The bar is a thin pinned strip: its text stops growing at AX1 so the
        // countdown, seats, and action stay on one row at AX5 and the chat keeps
        // its room. The card in the chat shows the same call at full size, and
        // the bar's VoiceOver label still reads the whole call.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .padding(.horizontal, SQSpace.m)
        .padding(.vertical, typeSize.isAccessibilitySize ? SQSpace.xs : SQSpace.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sqSurface(.card, radius: SQRadius.m)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(spot.game), \(spot.filled) of \(spot.seatTotal), \(countdown) left")
        .accessibilityIdentifier("active-call-bar")
    }

    private func barCountdown(_ text: String) -> some View {
        Text(text)
            .sqTimerStyle(compact: true)
            .accessibilityIdentifier("active-call-countdown")
    }

    private func barSeats(_ text: String) -> some View {
        Text(text)
            .font(SQType.timerSmall)
            .foregroundStyle(SQColor.subtle)
            .lineLimit(1)
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
            composerPlus
            TextField("Message", text: Binding(get: { model.draft }, set: { model.draft = $0 }))
                .textFieldStyle(.roundedBorder)
                .focused($composerFocused)
            Button("Send") {
                SQHaptics.play(.tap)
                Task { await model.send() }
            }
            .accessibilityIdentifier("send-message")
        }
        .frame(maxHeight: composerLine * 3)
    }

    /// The + menu. Calling spots is the first thing it does; `/spots` does the same.
    private var composerPlus: some View {
        Menu {
            Button {
                SQHaptics.play(.tap)
                model.openSpotCall()
            } label: {
                Text("Call spots")
            }
            .accessibilityIdentifier("composer-call-spots")
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(SQColor.signal)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityHint("Call spots for the squad")
        .accessibilityIdentifier("composer-plus")
    }

    /// Opened from the + menu or a bare `/spots`.
    private var spotCallSheet: some View {
        SpotCallSheet(model: model)
            .adoptingLaunchDynamicType()
    }

    private var membershipSheet: some View {
        let ownerId = model.profile?.id ?? model.viewerId
        let isOwner = model.squad?.ownerId == ownerId
        return ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.m) {
                VStack(alignment: .leading, spacing: SQSpace.xs) {
                    Text("Members")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(SQColor.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(model.squad.map { SquadTitle.line(name: $0.name, memberCount: $0.members.count) } ?? "You're not in a squad yet.")
                        .font(SQType.detail)
                        .foregroundStyle(SQColor.subtle)
                        .accessibilityIdentifier("squad-count")
                }
                if !model.status.isEmpty {
                    Text(model.status)
                        .font(.footnote)
                        .foregroundStyle(model.membershipIsError ? SQColor.danger : SQColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("membership-status")
                }
                SQCardSurface {
                    VStack(alignment: .leading, spacing: SQSpace.s) {
                        panelHeading("Join with a code")
                        joinControls
                    }
                }
                if let squad = model.squad {
                    SQCardSurface {
                        VStack(alignment: .leading, spacing: SQSpace.s) {
                            panelHeading("In this squad")
                            if squad.members.isEmpty {
                                Text("No members yet.")
                                    .accessibilityIdentifier("members-empty")
                            }
                            ForEach(squad.members) { member in
                                memberRow(member, isOwner: isOwner)
                                    .padding(.vertical, SQSpace.xs)
                            }
                            if model.leaveAvailable {
                                Divider()
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
                    }
                }
                if isOwner {
                    SQCardSurface {
                        VStack(alignment: .leading, spacing: SQSpace.s) {
                            panelHeading("Rename")
                            renameControls
                        }
                    }
                    SQCardSurface {
                        VStack(alignment: .leading, spacing: SQSpace.s) {
                            panelHeading("Invite")
                            inviteControls
                            if model.inviteCode.isEmpty {
                                Text("No invite yet.")
                                    .font(.footnote)
                                    .foregroundStyle(SQColor.muted)
                                    .accessibilityIdentifier("invite-empty")
                            }
                        }
                    }
                }
                profileSection
                if !model.notes.isEmpty {
                    notes
                        .padding(.horizontal, SQSpace.xs)
                        .accessibilityIdentifier("panel-notes")
                }
            }
            .padding(SQSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(SQColor.surface0)
        .presentationBackground(SQColor.surface0)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .adoptingLaunchDynamicType()
        .onAppear {
            model.renameDraft = model.squad?.name ?? ""
            Task {
                await model.probeLeave()
                if isOwner {
                    await model.probeRename()
                }
            }
        }
    }

    @ViewBuilder
    private func memberRow(_ member: SquadMemberRecord, isOwner: Bool) -> some View {
        let title = member.isOwner ? "\(member.displayName) · Owner" : member.displayName
        let nameLabel = member.isOwner ? "\(member.displayName), owner" : member.displayName
        if isOwner && !member.isOwner {
            ViewThatFits(in: .horizontal) {
                memberLine(title: title, label: nameLabel, member: member, stacked: false)
                memberLine(title: title, label: nameLabel, member: member, stacked: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(title)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel(nameLabel)
        }
    }

    private func memberLine(title: String, label: String, member: SquadMemberRecord, stacked: Bool) -> some View {
        let name = Text(title)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel(label)
        let remove = removeButton(member)
        return Group {
            if stacked {
                VStack(alignment: .leading, spacing: SQSpace.xs) {
                    name
                    remove.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .firstTextBaseline) {
                    name.layoutPriority(1)
                    Spacer(minLength: SQSpace.s)
                    remove.fixedSize(horizontal: true, vertical: false)
                }
            }
        }
    }

    private func removeButton(_ member: SquadMemberRecord) -> some View {
        Button {
            Task { await model.removeMember(member) }
        } label: {
            Text("Remove \(member.displayName)")
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .disabled(model.busy)
        .accessibilityIdentifier("remove-\(member.displayName)")
        .accessibilityLabel("Remove \(member.displayName)")
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

    /// Profile moved off the home screen into the squad panel.
    @ViewBuilder
    private var profileSection: some View {
        if model.profile != nil {
            SQCardSurface {
                VStack(alignment: .leading, spacing: SQSpace.s) {
                    Text("Your profile")
                        .font(SQType.section)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("profile-heading")
                    TextField("Display name", text: Binding(get: { model.displayName }, set: { model.displayName = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("profile-name")
                    TextField("Default game", text: Binding(get: { model.defaultGame }, set: { model.defaultGame = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("profile-game")
                    Button("Save profile") { Task { await model.saveProfile() } }
                        .disabled(model.busy)
                        .accessibilityIdentifier("save-profile")
                }
            }
        }
    }

    private func panelHeading(_ title: String) -> some View {
        Text(title)
            .font(SQType.section)
            .foregroundStyle(SQColor.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var renameControls: some View {
        VStack(alignment: .leading, spacing: SQSpace.s) {
            if RenameAccess.showsControl(isOwner: true, available: model.renameAvailable) {
                TextField("Squad name", text: Binding(get: { model.renameDraft }, set: { model.renameDraft = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("rename-field")
                Button("Rename") { Task { await model.renameSquad() } }
                    .disabled(model.busy)
                    .accessibilityIdentifier("rename-squad")
                    .accessibilityLabel("Rename the squad")
            }
            if RenameAccess.showsUnavailable(isOwner: true, available: model.renameAvailable) {
                Text(RenameAccess.unavailable)
                    .font(.footnote)
                    .foregroundStyle(SQColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("rename-unavailable")
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

    private var viewerForChat: UUID? { model.profile?.id ?? model.viewerId }

    /// One message: group header, reply quote, bubble, reaction chips, then the
    /// delivery caption or seen line. Long-press for React, Reply, Copy, and Retry.
    private func messageRow(_ bubble: ChatBubble) -> some View {
        let entry = bubble.entry
        let chipsForRow = ChatReactions.chips(marks: model.board.marks, messageId: entry.id, viewerId: viewerForChat)
        let actions = ChatAction.available(for: entry, repliesAvailable: model.chatCaps.replies)
        return VStack(alignment: .leading, spacing: 2) {
            if bubble.startsGroup {
                ChatGroupHeader(name: bubble.senderName, time: bubble.time, mine: bubble.mine)
            }
            if let reply = bubble.reply {
                ChatReplyQuoteView(quote: reply)
            }
            Button {
                model.selectedMessage = entry.id
            } label: {
                Text(entry.body)
                    .font(SQType.body)
                    .foregroundStyle(entry.delivery == .failed ? SQColor.muted : SQColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(ChatSpeech.bubble(bubble))
            .accessibilityActions {
                ForEach(actions, id: \.title) { action in
                    Button(action.title) { run(action, on: entry.id) }
                }
            }
            .buttonStyle(WideRowButtonStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            if !chipsForRow.isEmpty {
                ChipFlow(spacing: SQSpace.xs) {
                    ForEach(chipsForRow) { chip in
                        ChatReactionChipButton(chip: chip) {
                            Task { await model.tap(chip.tapback, on: entry.id) }
                        }
                    }
                }
                .padding(.top, 2)
            }
            if let caption = bubble.caption {
                Text(caption)
                    .font(SQType.micro)
                    .foregroundStyle(entry.delivery == .failed ? SQColor.danger : SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("delivery-caption")
            }
            if let seen = bubble.seen {
                Text(seen)
                    .font(SQType.micro)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("seen-by")
            }
            if model.selectedMessage == entry.id, actions.contains(.react) {
                Button("React") { model.reacting = true }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("react")
            }
            if model.reacting, model.selectedMessage == entry.id {
                reactionChoices(entry.id)
            }
            if entry.delivery == .failed {
                Button("Retry") { Task { await model.retry(entry.id) } }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("retry-send")
                    .accessibilityLabel("Retry sending")
            }
        }
        .padding(.top, bubble.startsGroup ? SQSpace.s : 0)
        .padding(.bottom, bubble.endsGroup ? SQSpace.xs : 0)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(ChatSeed.rowIdentifier(for: entry.id))
        .onTapGesture(count: 2) {
            guard actions.contains(.react) else { return }
            model.selectedMessage = entry.id
            model.reacting = true
        }
        .contextMenu {
            if actions.contains(.react) {
                Section {
                    ForEach(Tapback.allCases) { reaction in
                        Button(reaction.spoken) { Task { await model.tap(reaction, on: entry.id) } }
                    }
                }
            }
            Section {
                if actions.contains(.reply) {
                    Button { run(.reply, on: entry.id) } label: { Label("Reply", systemImage: "arrowshape.turn.up.left") }
                }
                Button { run(.copy, on: entry.id) } label: { Label("Copy", systemImage: "doc.on.doc") }
                if actions.contains(.retry) {
                    Button { run(.retry, on: entry.id) } label: { Label("Retry sending", systemImage: "arrow.clockwise") }
                }
            }
        }
    }

    private func run(_ action: ChatAction, on id: UUID) {
        switch action {
        case .react:
            model.selectedMessage = id
            model.reacting = true
        case .reply:
            model.startReply(id)
            composerFocused = true
        case .copy:
            model.copy(id)
        case .retry:
            Task { await model.retry(id) }
        }
    }

    private func reactionChoices(_ id: UUID) -> some View {
        VStack(alignment: .leading, spacing: SQSpace.xs) {
            ForEach(ChatReactions.order) { reaction in
                Button { Task { await model.tap(reaction, on: id) } } label: {
                    Text("\(SquadReaction.emoji(for: reaction))  \(reaction.spoken)")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(reaction.spoken)
                .accessibilityIdentifier("tapback-\(reaction.rawValue)")
            }
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

/// The call sheet, opened from the + menu or a bare `/spots`. Its own view so its
/// focus and detent state live with it. Says what it is doing while it calls, and
/// keeps the sheet open with the reason when the call fails.
private struct SpotCallSheet: View {
    let model: LiveSessionModel
    @FocusState private var spotGameFocused: Bool
    @State private var spotSheetDetent: PresentationDetent = .medium
    // Read here, inside the launch Dynamic Type override applied at the call site.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SQSpace.m) {
                Text("Call spots")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(SQColor.ink)
                    .accessibilityAddTraits(.isHeader)
                Text("The squad gets 5 minutes to join. Starters already in a game can join late. Seats cap at 8.")
                    .font(SQType.detail)
                    .foregroundStyle(SQColor.subtle)
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Game", text: Binding(get: { model.spotGame }, set: { model.spotGame = $0 }))
                    .textFieldStyle(.roundedBorder)
                    .focused($spotGameFocused)
                    .submitLabel(.go)
                    .onSubmit {
                        Task { await model.callSpotsFromSheet() }
                    }
                    .accessibilityLabel("Game")
                    .accessibilityIdentifier("spot-sheet-game")
                switch model.spotSheet {
                case .calling:
                    HStack(spacing: SQSpace.s) {
                        ProgressView()
                            .accessibilityHidden(true)
                        Text("Calling spots…")
                            .font(SQType.caption)
                            .foregroundStyle(SQColor.subtle)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("spot-sheet-calling")
                case .failed(let reason):
                    Text(reason)
                        .font(SQType.caption)
                        .foregroundStyle(SQColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("spot-sheet-error")
                case .editing:
                    EmptyView()
                }
            }
            .padding(SQSpace.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // The actions ride in the bottom safe-area inset, so they sit above the
        // whole keyboard, including the QuickType bar, at every text size.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: SQSpace.s) {
                Button {
                    SQHaptics.play(.success)
                    Task { await model.callSpotsFromSheet() }
                } label: {
                    Text("Call spots")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.spotGate.busy)
                .accessibilityIdentifier("spot-sheet-call")
                Button("Not now", role: .cancel) { model.spotSheetOpen = false }
                    .accessibilityIdentifier("spot-sheet-cancel")
            }
            .padding(.horizontal, SQSpace.xl)
            .padding(.top, SQSpace.s)
            .padding(.bottom, SQSpace.m)
            .frame(maxWidth: .infinity)
            .background(SQColor.surface0)
        }
        // Typing gets the whole screen, so the field and the actions both stay in view.
        .onChange(of: spotGameFocused) { _, focused in
            if focused { spotSheetDetent = .large }
        }
        // At accessibility text sizes the medium detent pushes the field below the fold,
        // so those sizes open (and stay) large.
        .onAppear { spotSheetDetent = Self.openingDetent(for: dynamicTypeSize) }
        .onChange(of: dynamicTypeSize) { _, size in
            if size.isAccessibilitySize { spotSheetDetent = .large }
        }
        .presentationDetents([.medium, .large], selection: $spotSheetDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(SQColor.surface0)
    }

    static func openingDetent(for size: DynamicTypeSize) -> PresentationDetent {
        size.isAccessibilitySize ? .large : .medium
    }
}
