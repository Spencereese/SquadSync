import SwiftUI
import UIKit
import UserNotifications
import os

/// Opening a pushed message: each step, so a launch that doesn't open it can be read
/// back from the device log (subsystem com.spencereese.squadsync, category chat-open).
private let chatOpenLog = Logger(subsystem: "com.spencereese.squadsync", category: "chat-open")

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
    /// The row at the top of the thread that pages older messages.
    var olderPaging = ChatOlderPaging()
    /// Older pages that came back for the open squad: the layout generation the
    /// tracked rows report positions in, and the UI tests' paging probe.
    var olderPagesLoaded = 0
    /// The previous oldest message while an older page goes in above it; its row
    /// keeps reporting where it is so the list can hold it in place.
    var olderHoldAnchor: UUID?
    /// Bumped with where to scroll when an older page goes in, so the topmost row
    /// the reader could fully see stays where it was (see ChatPrependHold).
    private(set) var olderRestore: ChatPrependRestore?
    private(set) var olderRestoreSerial = 0
    /// The message list's scroll view: paging trigger and place-keeping geometry.
    let scrollHold = ChatScrollController()
    /// Bumped when the viewer calls spots, so the list brings the card into view.
    var spotCalledSerial = 0
    /// An older page has been added for the open squad, so a later full reload
    /// doesn't decide "start of chat" from the newest 200 alone.
    @ObservationIgnored private var olderPagedThisSquad = false
    /// A pushed message to open, held until the chat's first load has finished.
    @ObservationIgnored private var pendingOpen = ChatPendingOpen()
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
    // Who's in (S4): check-ins, what the server supports, and Steam when it's deployed.
    var checkIns: [CheckInRecord] = []
    var checkInCaps = CheckInCapabilities.unknown
    var steam = SteamRead.notChecked
    var whosInLoad = WhosInLoad.idle
    var whosInOpen = false
    /// The game and console typed into your own check-in. Only sent once the server has 0022's columns.
    var checkInGame = ""
    var checkInPlatform: CheckInPlatform?
    var checkInBusy = false
    /// Why the last check-in didn't save, in plain words. Cleared by the next success.
    var checkInError = ""
    // Onboarding (S5): sign-in, the first profile, and the first squad.
    /// Why the last send or verify failed, in plain words.
    var signInError = ""
    /// "We sent a new code to …" after a resend.
    var resentNote = ""
    var resend = ResendClock()
    var onboardingAction: OnboardingAction?
    /// False until the profile step is done once on this phone (or a squad exists).
    var profileConfirmed = true
    var profileDraft = ProfileDraft(name: "", defaultGame: "Call of Duty")
    var profileLoad = OnboardingLoad.idle
    var showProfileErrors = false
    var profileError = ""
    var gameEntry = ""
    var gamesError = ""
    var gamesHome: GamesHome?
    /// Set when the profile step was finished in this launch, so the squad step
    /// counts "Step 4 of 4". Someone who left a squad later sees no count.
    var onboardedThisSession = false

    /// Which onboarding step the screen shows.
    var onboardingStep: OnboardingStep {
        OnboardingStep.current(
            signedIn: phase == .ready,
            codeSent: phase == .code,
            profileConfirmed: profileConfirmed,
            hasSquad: squad != nil
        )
    }

    private let config: BackendConfig
    /// Unsent messages on disk, so a kill doesn't lose them.
    let outbox: ChatOutbox
    private let voiceRoom: VoiceRoomService = InMemoryVoiceRoomService()
    private let sessionStore: SessionStoring
    private var auth: AuthService
    private let mockProfiles: ProfileService?
    private let mockSquads: SquadService?
    private let mockChat: ChatService?
    private let mockInvites: InviteServing?
    private let mockSpots: SpotServing?
    /// Internal so model tests can change what the mock server holds.
    let mockCheckIns: MockCheckInService?
    /// Internal so model tests can read what the mock auth and games servers saw.
    let mockAuth: MockAuthService?
    let mockGames: MockProfileGames?
    /// Live only: remembers the finished profile step per account.
    private let marks: OnboardingMarks?
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

    init(config: BackendConfig, backend: BackendMode = .live, scenario: LaunchScenario = .seated, sessionStore: SessionStoring? = nil, outbox: ChatOutbox? = nil) {
        self.config = config
        if let outbox {
            self.outbox = outbox
        } else if backend == .mock {
            // Mock launches start with an empty outbox unless a UI test relaunches
            // with -keepOutbox to check that a failed send survived.
            let mockOutbox = ChatOutbox.standard(mock: true)
            if !ProcessInfo.processInfo.arguments.contains("-keepOutbox") { mockOutbox.clearAll() }
            self.outbox = mockOutbox
        } else {
            self.outbox = ChatOutbox.standard(mock: false)
        }
        if backend == .mock {
            let store = sessionStore ?? MemorySessionStore()
            let session = AuthSession(
                accessToken: "mock-access",
                refreshToken: "mock-refresh",
                userId: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                email: "spencer@squadsync.app"
            )
            // Onboarding scenarios start signed out (or, for the profile one, signed in
            // before the profile step), so the mock session is only saved for the rest.
            let signedOut = scenario.startsSignedOut
            if !signedOut { try? store.save(session) }
            let squads = MockSquadService()
            let chat = MockChatService(
                replies: scenario != .chatNoReplies,
                historyDown: scenario == .chatHistoryFailed,
                historyDelay: scenario == .chatHistorySlow ? 3 : 0
            )
            // UI tests: a slow older page, so "before" and "after" a page lands can
            // both be read with nothing else moving the list.
            if let delay = Self.debugOlderDelay() { chat.olderDelay = delay }
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-mock-older-gate") { chat.olderGated = true }
            #endif
            self.sessionStore = store
            let mockAuth = MockAuthService(
                store: store,
                acceptedCode: scenario.isOnboardingScenario ? MockAuthService.onboardingCode : nil,
                sendFailure: scenario == .onboardingOffline ? .reconnecting : nil,
                delay: scenario == .onboardingSlow ? 2 : 0
            )
            self.auth = mockAuth
            self.mockAuth = mockAuth
            self.mockGames = MockProfileGames(home: .phone)
            self.marks = nil
            if scenario.isOnboardingScenario {
                self.profileConfirmed = false
                self.resend = ResendClock(cooldown: 5)
            }
            self.mockCheckIns = Self.mockCheckIns(for: scenario, viewerId: session.userId)
            self.mockProfiles = MockProfileService()
            self.mockSquads = squads
            self.mockChat = chat
            self.mockInvites = MockInviteService(squads: squads)
            if !signedOut {
                self.phase = .ready
                self.email = session.email
                self.viewerId = session.userId
            }
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
                if scenario == .chatLongHistory {
                    let long = ChatLongSeed.messages(viewerId: session.userId, squadId: seeded.id, now: Date())
                    for message in long { chat.seed(message) }
                } else if scenario != .chatEmpty {
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
                } else if scenario == .whosInEmpty {
                    self.squad = squads.seed(ownerId: session.userId, name: "Friday")
                } else if scenario.isWhosInScenario {
                    self.squad = squads.seedSpotSquad(ownerId: session.userId)
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
            self.mockCheckIns = nil
            self.mockAuth = nil
            self.mockGames = nil
            self.marks = OnboardingMarks()
        }
        if let live = auth as? SupabaseAuthService {
            live.onRefresh = { [weak self] session in
                Task { @MainActor in self?.sessionRefreshed(session) }
            }
        }
    }

    /// Every token refresh hands the open socket the new JWT, so realtime doesn't
    /// drop into polling when the old one expires.
    func sessionRefreshed(_ session: AuthSession) {
        realtime?.updateAccessToken(session.accessToken)
    }

    /// Mock check-in servers. Every mock scenario has check-ins like live (0006) with
    /// no game or console columns and Steam not set up; the who's-in scenarios vary that.
    private static func mockCheckIns(for scenario: LaunchScenario, viewerId: UUID) -> MockCheckInService {
        let squad = ChatSeed.squadId
        let now = Date()
        switch scenario {
        case .whosIn:
            return MockCheckInService(
                caps: CheckInCapabilities(table: true, details: true),
                rows: WhosInSeed.rows(viewerId: viewerId, squadId: squad, now: now, details: true),
                steam: WhosInSeed.steam
            )
        case .whosInBasic:
            return MockCheckInService(rows: WhosInSeed.rows(viewerId: viewerId, squadId: squad, now: now, details: false))
        case .whosInFailed:
            return MockCheckInService(rows: WhosInSeed.rows(viewerId: viewerId, squadId: squad, now: now, details: false), readsDown: true)
        case .whosInSlow:
            return MockCheckInService(rows: WhosInSeed.rows(viewerId: viewerId, squadId: squad, now: now, details: false), readDelay: 9, waitsForSheet: true)
        case .whosInNoServer:
            return MockCheckInService(caps: .unknown)
        default:
            return MockCheckInService()
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
        guard SignInEmail.isValid(email) else {
            signInError = SignInEmail.invalidMessage
            return
        }
        let address = SignInEmail.normalized(email)
        signInError = ""
        status = ""
        onboardingAction = .sending
        defer { onboardingAction = nil }
        do {
            try await auth.sendCode(to: address)
            email = address
            code = ""
            resentNote = ""
            resend.sentAt = Date()
            resend.serverWaitUntil = nil
            phase = .code
        } catch {
            noteSignInFailure(error, stage: .send)
        }
    }

    /// "Send a new code", once the cooldown (and any server wait) is over.
    func resendCode() async {
        guard resend.canResend(now: Date()) else { return }
        signInError = ""
        resentNote = ""
        onboardingAction = .resending
        defer { onboardingAction = nil }
        do {
            try await auth.sendCode(to: email)
            code = ""
            resend.sentAt = Date()
            resend.serverWaitUntil = nil
            resentNote = "We sent a new code to \(email). Use the newest one."
        } catch {
            noteSignInFailure(error, stage: .send)
        }
    }

    /// Back to the email step, keeping what was typed.
    func changeEmail() {
        phase = .email
        code = ""
        signInError = ""
        resentNote = ""
        resend = ResendClock(cooldown: resend.cooldown)
    }

    /// The code field keeps digits only. The sixth digit checks the code on its own.
    func codeChanged(_ raw: String) {
        let digits = OTPEntry.digits(raw)
        let before = code.count
        guard digits != code else { return }
        code = digits
        if !digits.isEmpty { signInError = "" }
        if digits.count == OTPEntry.length, before < OTPEntry.length, onboardingAction == nil {
            Task { await verify() }
        }
    }

    func verify() async {
        let digits = OTPEntry.digits(code)
        guard OTPEntry.isComplete(digits) else {
            signInError = "Enter the 6-digit code from your email."
            return
        }
        code = digits
        signInError = ""
        onboardingAction = .verifying
        defer { onboardingAction = nil }
        do {
            let session = try await auth.verify(email: email, code: digits)
            viewerId = session.userId
            status = ""
            resentNote = ""
            // Load the profile and squad before leaving the code step, so the next
            // step is the right one instead of flashing the squad form first.
            await refresh(session)
            // A refresh that ended the session already moved back to the email step.
            if phase == .email { return }
            phase = .ready
            startLive(session)
        } catch {
            noteSignInFailure(error, stage: .verify)
            if case .wrongCode = SignInProblem.from(error, stage: .verify).kind { code = "" }
        }
    }

    private func noteSignInFailure(_ error: Error, stage: SignInStage) {
        if RequestNoise.isCancellation(error) { return }
        let problem = SignInProblem.from(error, stage: stage)
        signInError = problem.message
        if let wait = problem.retryAfter {
            resend.serverWaitUntil = Date().addingTimeInterval(wait)
        }
    }

    /// The offline panel's Try again.
    func retryConnection() async {
        await restore()
    }

    // MARK: Onboarding profile

    /// Seeds the profile step from the server: name, default game, and the games list
    /// (from the server once 0023 is applied, from this phone until then).
    func loadOnboardingProfile() async {
        guard let session = try? requiredSession() else { return }
        profileLoad = .loading
        do {
            let loaded: UserProfile
            if let profile {
                loaded = profile
            } else {
                loaded = try await profileService(session).loadOrCreate(userId: session.userId, email: session.email)
                profile = loaded
            }
            let games = try await gamesService(session).load(userId: session.userId)
            profileDraft = ProfileDraft(name: loaded.displayName, defaultGame: loaded.defaultGame, games: games.games)
            gamesHome = games.home
            profileLoad = .loaded
        } catch {
            if RequestNoise.isCancellation(error) { return }
            profileLoad = .failed(Self.offline(error)
                ? "You're offline. Your profile will load when you're back online."
                : "Your profile didn't load. Try again.")
        }
    }

    func addGameFromEntry() {
        if let problem = profileDraft.addGame(gameEntry) {
            gamesError = problem
        } else {
            gamesError = ""
            gameEntry = ""
        }
    }

    func addSuggestedGame(_ game: String) {
        gamesError = profileDraft.addGame(game) ?? ""
    }

    func removeGame(_ game: String) {
        profileDraft.removeGame(game)
        gamesError = ""
    }

    /// Continue on the profile step: saves name and default game to the server, then
    /// the games list wherever it lives, then moves on to the squad step.
    func saveOnboardingProfile() async {
        showProfileErrors = true
        profileError = ""
        guard profileDraft.isValid, var current = profile, let session = try? requiredSession() else { return }
        let saved = profileDraft.saved
        onboardingAction = .savingProfile
        defer { onboardingAction = nil }
        do {
            current.displayName = saved.name
            current.defaultGame = saved.defaultGame
            try await profileService(session).save(current)
            profile = current
            displayName = saved.name
            defaultGame = saved.defaultGame
            gamesHome = try await gamesService(session).save(userId: session.userId, games: saved.games)
            profileDraft.games = saved.games
            marks?.confirmProfile(session.userId)
            showProfileErrors = false
            onboardedThisSession = true
            profileConfirmed = true
        } catch {
            if RequestNoise.isCancellation(error) { return }
            if let failure = error as? BackendFailure, case .signIn = SessionFailurePolicy.surface(failure) {
                handleSessionError(error)
                return
            }
            profileError = Self.offline(error)
                ? "You're offline. Your profile wasn't saved. Try again."
                : "Your profile didn't save. Try again."
        }
    }

    private static func offline(_ error: Error) -> Bool {
        if case .reconnecting = error as? BackendFailure { return true }
        return false
    }

    private func gamesService(_ session: AuthSession) -> ProfileGamesServing {
        mockGames ?? SupabaseProfileGames(config: config, accessToken: session.accessToken, refresher: tokenRefresher)
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
        onboardingAction = .creating
        defer { onboardingAction = nil }
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
        onboardingAction = .joining
        defer { onboardingAction = nil }
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
            spotCalledSerial += 1
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
        let message = RemoteMessage(id: id, squadId: squad.id, senderId: session.userId, body: text, sentAt: now, replyToId: reply)
        log.beginSend(id: id, senderId: session.userId, body: text, now: now, replyToId: reply)
        // On disk before the network, so a kill mid-send still has it.
        outbox.add(OutboxItem(message))
        followSend = id
        draft = ""
        replyingTo = nil
        unreadMarker.clear()
        await deliver(message, session: session)
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
            // Long enough to outlast the context menu closing and still be read.
            try? await Task.sleep(nanoseconds: 3_000_000_000)
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
        // Same id as the first try, so the server's ignore-duplicates keeps one row.
        outbox.add(OutboxItem(message))
        await deliver(message, session: session)
    }

    /// Presence strip rows for the home header. Only real signals: spot seats,
    /// check-ins once the server is known to have them, and the viewer.
    func presenceEntries(now: Date) -> [SquadPresenceEntry] {
        guard let squad else { return [] }
        return SquadPresence.entries(
            members: squad.members,
            ownerId: squad.ownerId,
            viewerId: viewerId ?? profile?.id,
            spot: spot,
            now: now,
            availability: WhosIn.availabilityByMember(checkIns: checkIns, squadId: squad.id, caps: checkInCaps, now: now)
        )
    }

    /// Rows for the who's-in sheet.
    func whosInEntries(now: Date) -> [WhosInEntry] {
        guard let squad else { return [] }
        return WhosIn.entries(
            members: squad.members,
            squadId: squad.id,
            ownerId: squad.ownerId,
            viewerId: viewerId ?? profile?.id,
            spot: spot,
            checkIns: checkIns,
            caps: checkInCaps,
            steam: steam,
            now: now
        )
    }

    /// Your own check-in as it reads now.
    func myAvailability(now: Date) -> WhosInAvailability {
        guard checkInCaps.table else { return .untracked }
        guard let me = viewerId ?? profile?.id else { return .notCheckedIn }
        return CheckInRules.availability(WhosIn.newest(checkIns, squadId: squad?.id)[me], now: now)
    }

    func openWhosIn() {
        whosInOpen = true
        checkInError = ""
        Task { await loadWhosIn(includeSteam: true) }
    }

    /// Reads capabilities (once), the squad's check-ins, and, when asked, Steam.
    /// A failure keeps earlier rows and says so instead of emptying the sheet.
    func loadWhosIn(includeSteam: Bool = false) async {
        guard let squad, let session = try? requiredSession() else { return }
        let service = checkInService(session)
        await readCheckIns(service, squadId: squad.id)
        // Steam is its own source: it's read even when check-ins aren't on the server.
        if includeSteam {
            steam = await service.steam()
        }
    }

    private func readCheckIns(_ service: CheckInServing, squadId requested: UUID) async {
        whosInLoad = .loading
        do {
            if !checkInCaps.table {
                checkInCaps = try await service.capabilities()
            }
            guard checkInCaps.table else {
                checkIns = []
                whosInLoad = .loaded
                return
            }
            let rows = try await service.checkIns(squadId: requested)
            guard squad?.id == requested else { return }
            checkIns = rows
            whosInLoad = .loaded
            seedCheckInDraft()
        } catch CheckInProblem.unavailable {
            checkInCaps = .unknown
            checkIns = []
            whosInLoad = .loaded
        } catch {
            if RequestNoise.isCancellation(error) { return }
            whosInLoad = WhosInLoad.failure(error)
        }
    }

    /// A realtime check-in delete. Every squad's deletes arrive, so this rereads
    /// only when the delete could be someone this squad shows.
    func checkInRemoved(userId: UUID?) async {
        guard let squad else { return }
        let members = Set(squad.members.map(\.id))
        guard CheckInChange.rereads(afterRemoving: userId, memberIds: members, loaded: checkIns) else { return }
        await loadWhosIn()
    }

    /// Retry from the sheet's error row. The mock server comes back so both states can be seen.
    func retryWhosIn() async {
        mockCheckIns?.recover()
        await loadWhosIn(includeSteam: steam == .notChecked || steam == .failed)
    }

    /// Fills the game and console fields from your saved check-in, once.
    private func seedCheckInDraft() {
        guard checkInGame.isEmpty, checkInPlatform == nil,
              let me = viewerId ?? profile?.id,
              let mine = WhosIn.newest(checkIns, squadId: squad?.id)[me] else { return }
        checkInGame = mine.game ?? ""
        checkInPlatform = mine.platform
    }

    /// Saves your check-in. "On now" gets its 60 minutes from the server clock.
    func checkIn(_ kind: CheckInKind, laterAt: Date? = nil) async {
        guard checkInCaps.table, let squad, let session = try? requiredSession() else { return }
        if kind == .availableLater, laterAt == nil { return }
        checkInBusy = true
        defer { checkInBusy = false }
        let write = CheckInWrite(
            userId: session.userId,
            squadId: squad.id,
            kind: kind,
            untilAt: laterAt,
            game: CheckInRules.normalizedGame(checkInGame),
            platform: checkInPlatform,
            includesDetails: checkInCaps.details
        )
        do {
            if let saved = try await checkInService(session).save(write) {
                checkIns.removeAll { $0.userId == saved.userId }
                checkIns.append(saved)
            } else {
                await loadWhosIn()
            }
            checkInError = ""
            SQHaptics.play(.success)
        } catch let problem as CheckInProblem {
            checkInError = problem.message
            if problem == .unavailable { checkInCaps = .unknown }
        } catch {
            if RequestNoise.isCancellation(error) { return }
            checkInError = CheckInRules.message(for: "")
            report(error)
        }
    }

    /// Removes your check-in, so you read as not checked in.
    func clearCheckIn() async {
        guard checkInCaps.table, let squad, let session = try? requiredSession() else { return }
        checkInBusy = true
        defer { checkInBusy = false }
        do {
            try await checkInService(session).clear(userId: session.userId, squadId: squad.id)
            checkIns.removeAll { $0.userId == session.userId }
            checkInError = ""
        } catch let problem as CheckInProblem {
            checkInError = problem.message
        } catch {
            if RequestNoise.isCancellation(error) { return }
            checkInError = "Couldn't clear your check-in. Try again."
        }
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
        // Unsent messages belong to this account; the next person doesn't get them.
        if let user = viewerId ?? profile?.id { outbox.clear(userId: user) }
        olderPaging = ChatOlderPaging()
        olderPagesLoaded = 0
        olderPagedThisSquad = false
        olderHoldAnchor = nil
        pendingOpen.clear()
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
        code = ""
        signInError = ""
        resentNote = ""
        resend = ResendClock(cooldown: resend.cooldown)
        profileLoad = .idle
        profileError = ""
        showProfileErrors = false
        gamesHome = nil
        if marks != nil { profileConfirmed = true }
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
            outbox.remove(id: message.id, squadId: message.squadId, userId: message.senderId)
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
            if let marks {
                // Someone already in a squad never sees the profile step.
                if squad != nil { marks.confirmProfile(session.userId) }
                profileConfirmed = squad != nil || marks.profileConfirmed(session.userId)
            }
            if !profileConfirmed && squad == nil { await loadOnboardingProfile() }
            await loadChat(session)
            await loadSpot(session)
            // The slow mock skips this so the sheet's own read is the one that loads.
            if mockCheckIns?.waitsForSheet != true { await loadWhosIn() }
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
            requestOpen(messageId: message)
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

    // MARK: Older history, unsent messages, pushed messages

    /// The top-of-thread row came into view: add one older page and keep the place.
    func loadOlder() async {
        _ = try? await fetchOlderPage(waitForRunning: false)
    }

    /// `-mock-older-delay <seconds>` (Debug only).
    private static func debugOlderDelay() -> TimeInterval? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-mock-older-delay"),
              arguments.index(after: index) < arguments.endIndex,
              let seconds = TimeInterval(arguments[arguments.index(after: index)]),
              seconds > 0 else { return nil }
        return seconds
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// UI tests: older pages are held until released (`-mock-older-gate`, mock only).
    var debugOlderGate: Bool { mockChatService?.olderGated ?? false }

    /// UI tests: let one held older page through.
    func debugReleaseOlderPage() { mockChatService?.releaseOlder() }
    #endif

    /// Tests: the mock chat server, to slow or fail its reads.
    var mockChatService: MockChatService? { mockChat as? MockChatService }

    /// Retry on the older-page error row.
    func retryOlder() async {
        // The mock server comes back on Retry, so the UI test can see both states.
        if let mock = mockChat as? MockChatService, mock.olderDown { mock.olderDown = false }
        await loadOlder()
    }

    /// One older page, merged by id. Returns false once the start of the chat is
    /// reached. Throws when the read fails (the row then offers Retry).
    private func fetchOlderPage(waitForRunning: Bool = true) async throws -> Bool {
        guard let squad, let session = try? requiredSession() else { return false }
        // The row asking twice while a page runs is one page, not two.
        if !waitForRunning, olderPaging.state == .loading { return true }
        // Opening a pushed message waits for a page the row started, rather than skip.
        var waits = 0
        while olderPaging.state == .loading, waits < 200 {
            try await Task.sleep(nanoseconds: 50_000_000)
            waits += 1
        }
        guard let cursor = ChatOlderPaging.cursor(log) else {
            olderPaging.finish(rowCount: 0)
            return false
        }
        guard olderPaging.begin() else { return olderPaging.state != .reachedStart }
        let requested = squad.id
        do {
            let rows = try await chatService(session).older(squadId: requested, before: cursor, limit: ChatOlderPaging.pageSize)
            guard HistoryMerge.accepts(requestSquad: requested, loadedSquad: loadedSquad) else { return false }
            // Hold the reader's place: record it right before the rows go in (only
            // when something new is going in, so the hold always sees the growth).
            let known = Set(log.entries.map(\.id))
            if rows.contains(where: { !known.contains($0.id) }) {
                let restore = scrollHold.prepareForPrepend(oldest: cursor.id, generation: olderPagesLoaded + 1)
                olderHoldAnchor = restore?.id ?? cursor.id
                olderRestore = restore
            } else {
                olderRestore = nil
            }
            log.ingest(rows.map { $0.entry() })
            if olderRestore != nil { olderRestoreSerial += 1 }
            olderPagedThisSquad = true
            olderPagesLoaded += 1
            olderPaging.finish(rowCount: rows.count)
            return olderPaging.state != .reachedStart
        } catch {
            if RequestNoise.isCancellation(error) {
                olderPaging.reset()
            } else {
                olderPaging.fail()
            }
            throw error
        }
    }

    /// Unsent messages from before a relaunch go back in the thread as failed, with
    /// their original ids. Any the server already has leave the outbox.
    private func restoreOutbox(squadId: UUID, userId: UUID) {
        let items = outbox.load(squadId: squadId, userId: userId)
        guard !items.isEmpty else { return }
        let delivered = OutboxRestore.apply(items, to: &log)
        for id in delivered { outbox.remove(id: id, squadId: squadId, userId: userId) }
    }

    /// A push asked to open `messageId`. It opens once the chat's first load has
    /// finished: now if it already has, otherwise from the end of that load.
    func requestOpen(messageId: UUID) {
        let ready = pendingOpen.chatReady
        chatOpenLog.info("target set \(messageId.uuidString, privacy: .public) chatReady=\(ready, privacy: .public)")
        if let id = pendingOpen.request(messageId) {
            openTask = Task { await openMessage(id) }
        }
    }

    /// The open started by `requestOpen` (tests await it).
    @ObservationIgnored private(set) var openTask: Task<Void, Never>?

    /// The chat's load finished: open a held target, if any.
    private func chatLoadFinished() async {
        let held = pendingOpen.target
        chatOpenLog.info("chat load done, held=\(held?.uuidString ?? "none", privacy: .public)")
        if let id = pendingOpen.chatLoaded() {
            await openMessage(id)
        }
    }

    /// Opens a message: scrolls to it when it's loaded, pages back for it (up to
    /// `ChatReveal.maxPages`) when it isn't, and says so when it can't.
    private func openMessage(_ id: UUID) async {
        guard let squad, let session = try? requiredSession() else {
            chatOpenLog.error("open \(id.uuidString, privacy: .public): no squad or session")
            return
        }
        let chat = chatService(session)
        let squadId = squad.id
        var pages = 0
        let outcome = await ChatReveal.run(
            loaded: { [self] in log.entries.contains { $0.id == id } },
            exists: {
                let found = try await chat.message(squadId: squadId, id: id) != nil
                chatOpenLog.info("lookup \(id.uuidString, privacy: .public): \(found ? "on server" : "not on server", privacy: .public)")
                return found
            },
            loadOlderPage: { [self] in
                pages += 1
                let more = try await fetchOlderPage()
                let count = log.entries.count
                chatOpenLog.info("page fetch \(pages, privacy: .public): \(count, privacy: .public) loaded, more=\(more, privacy: .public)")
                return more
            }
        )
        switch outcome {
        case .found:
            chatOpenLog.info("found \(id.uuidString, privacy: .public) after \(pages, privacy: .public) pages")
            scrollHold.endHold()
            followSend = id
        case .notInChat, .tooFarBack, .failed:
            chatOpenLog.info("not found \(id.uuidString, privacy: .public): \(String(describing: outcome), privacy: .public)")
            if let text = ChatReveal.text(outcome) { showToast(text) }
        }
    }

    /// Tests: open a message directly, as if the chat were ready.
    func reveal(messageId: UUID) async {
        await openMessage(messageId)
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
            olderPaging = ChatOlderPaging()
            olderPagesLoaded = 0
            olderPagedThisSquad = false
            olderHoldAnchor = nil
            scrollHold.reset()
            pendingOpen.chatReset()
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
            if !olderPagedThisSquad {
                olderPaging.settleFirstRead(rowCount: rows.count, limit: SupabaseChatService.historyLimit)
            }
            restoreOutbox(squadId: requested, userId: session.userId)
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
            await chatLoadFinished()
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
        case .checkIns:
            await loadWhosIn()
        case .checkInRemoved(let user):
            await checkInRemoved(userId: user)
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
            // Without the socket, check-ins only refresh while someone is looking at them.
            if whosInOpen { await loadWhosIn() }
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

    private func checkInService(_ session: AuthSession) -> CheckInServing {
        mockCheckIns ?? SupabaseCheckInService(
            config: config,
            accessToken: session.accessToken,
            refresher: tokenRefresher,
            knownDetails: checkInCaps.table ? checkInCaps.details : nil
        )
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
    /// The thread's rows, rebuilt only when what they're made of changes.
    @State private var rowMemo = ChatRowMemo()
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
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
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
                    if showsOnboarding {
                        OnboardingView(model: model, step: model.onboardingStep)
                    } else {
                        ready
                    }
                }
                .padding(.horizontal, showsOnboarding ? SQSpace.l : SQSpace.m)
                .padding(.vertical, showsOnboarding ? 0 : SQSpace.s)
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
            // Onboarding draws its own step title, so the bar stays hidden there too.
            .toolbar(.hidden, for: .navigationBar)
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
        .sheet(isPresented: Binding(get: { model.whosInOpen }, set: { model.whosInOpen = $0 })) {
            // The launch Dynamic Type override sits outside, so the sheet reads AX5 for its detents.
            WhosInSheet(model: model)
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
            guard phase == .active else { return }
            let wasInBackground = wentToBackground
            wentToBackground = false
            guard RealtimeResume.reconnects(
                wentToBackground: wasInBackground,
                link: model.link,
                signedInWithSquad: model.phase == .ready && model.squad != nil
            ) else { return }
            // becameActive refreshes the session, reloads (the backfill), and restarts
            // the socket with the fresh token; catchUp then reads anything newer.
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

    /// Email, code, and profile take the whole screen. The squad step sits under
    /// the home header (for the account menu); offline always shows the reconnect panel.
    private var showsOnboarding: Bool {
        switch model.onboardingStep {
        case .email, .code: true
        case .profile: !model.reconnecting
        case .squad, .home: false
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
                OnboardingSquadStep(model: model)
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
                onOpenWhosIn: { model.openWhosIn() },
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
                onOpenWhosIn: {
                    rosterOpen = false
                    model.openWhosIn()
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

    private var historyFailedWithoutMessages: Bool {
        if case .failed = model.chatLoad.display(hasMessages: !model.log.entries.isEmpty) { return true }
        return false
    }

    private var liveNotice: String? {
        guard model.usesLiveSocket else { return nil }
        if !model.presenceNote.isEmpty { return model.presenceNote }
        return model.link.notice
    }

    private var chatList: some View {
        let _ = ChatScrollTrace.counted(.listBody)
        return ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        // Ticks only while there's a call whose countdown it shows: with
                        // no call the slot is the call form, which doesn't change with
                        // time, and a once-a-second update inside the lazy stack is work
                        // on a settled thread for nothing.
                        TimelineView(ChatSlotSchedule(ticks: model.spot != nil)) { context in
                            let now = SpotClock.now(timeline: context.date, resumedAt: model.resumedAt)
                            spotSlot(now: now)
                        }
                        .id(ChatAnchor.spot)
                        if !model.spotHistoryNote.isEmpty {
                            SpotStatusRow(text: model.spotHistoryNote, identifier: "spot-history-note")
                        }
                        if let display = model.chatLoad.display(hasMessages: !model.log.entries.isEmpty) {
                            ChatHistoryRow(display: display) {
                                Task { await model.retryChatLoad() }
                            }
                        }
                        if model.chatLoad == .loaded, !model.log.entries.isEmpty {
                            // Shows the paging state only. Whether to load is decided
                            // from scroll geometry (olderCheck), not this row appearing.
                            ChatOlderRow(state: model.olderPaging.state) {
                                Task { await model.retryOlder() }
                            }
                        }
                        let tracked = scrollTrackedIds
                        let failed = failedEndRow
                        ForEach(chatRowItems) { item in
                            let _ = ChatScrollTrace.counted(.rowBody)
                            switch item.row {
                            case .day(_, let label):
                                ChatDaySeparator(label: label)
                            case .unread(let count):
                                ChatUnreadDivider(count: count)
                            case .message(let bubble):
                                messageRow(bubble)
                                    .id(bubble.entry.id)
                                    // Only tracked rows get a geometry observer, in the
                                    // row's background, so tracking never changes the
                                    // row's own identity (see ChatRowGeometry).
                                    .modifier(ChatRowGeometry(
                                        id: bubble.entry.id,
                                        tracksPosition: tracked.contains(bubble.entry.id),
                                        tracksFit: failed == bubble.entry.id,
                                        controller: model.scrollHold
                                    ))
                            case .spot(let call):
                                if let outcome = SpotThread.outcome(call, viewerId: spotViewer, now: Date()) {
                                    SpotHistoryCard(call: call, outcome: outcome)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .coordinateSpace(name: ChatRowGeometry.contentSpace)
                    .background {
                        // iOS 17 only: newer systems read scroll geometry directly
                        // (ChatPinModifier), so no per-frame preference there.
                        if #available(iOS 18.0, *) {
                            EmptyView()
                        } else {
                            ChatContentFrame()
                        }
                    }
                    .background(ChatScrollBridge(controller: model.scrollHold))
                    // The end of the thread: the scroll-to-bottom anchor, and "End of
                    // messages" for VoiceOver. A real line of (clear) text, as in
                    // d6921b9, never a 1 pt synthesized element: 6f41b07/6617367's
                    // `Color.clear.frame(height: 1).accessibilityElement()` here hung
                    // the main thread under the LazyVStack whenever XCUI snapshotted
                    // the tree (thread-groups bisect: that switch alone, 8/8). Its type
                    // size is capped so it doesn't grow to ~51 pt at AX5, and with the
                    // keyboard up at AX sizes it's the smallest size and no minimum
                    // height, so "Not delivered" and Retry keep their room.
                    Text("End of messages")
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .dynamicTypeSize(...(endRowCompact ? DynamicTypeSize.xSmall : .large))
                        .frame(maxWidth: .infinity, minHeight: endRowCompact ? 0 : SQSpace.l)
                        .id(ChatAnchor.end)
                        .accessibilityIdentifier(ChatAnchor.end)
                }
                .contentMargins(.bottom, listBottomMargin, for: .scrollContent)
                .coordinateSpace(name: ChatRowGeometry.listSpace)
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
                #if DEBUG
                .overlay(alignment: .bottomLeading) {
                    if model.debugOlderGate {
                        ChatOlderDebugProbe(state: model.olderPaging.state, pages: model.olderPagesLoaded) {
                            model.debugReleaseOlderPage()
                        }
                    }
                }
                #endif
                composerBar(proxy)
            }
            .onAppear {
                if let id = model.followSend {
                    model.scrollHold.jumped(toBottom: false)
                    proxy.scrollTo(id, anchor: .center)
                    return
                }
                guard model.log.ordered.last != nil else { return }
                Task { @MainActor in
                    // A pushed message may have been opened in the meantime.
                    if let id = model.followSend, id != model.log.ordered.last?.id {
                        model.scrollHold.jumped(toBottom: false)
                        proxy.scrollTo(id, anchor: .center)
                        return
                    }
                    scrollChatToBottom(proxy)
                    await model.catchUp(pinned: pinnedToBottom)
                }
            }
            // At AX5 the history error can land below the fold; bring its Retry into view.
            .onChange(of: historyFailedWithoutMessages, initial: true) { _, failed in
                guard failed else { return }
                Task { @MainActor in
                    withMotion(.current(systemReduceMotion: systemReduceMotion), .scroll) {
                        proxy.scrollTo(ChatHistoryRow.anchor, anchor: .bottom)
                    }
                }
            }
            .onChange(of: model.followSend) { _, id in
                guard let id else { return }
                model.scrollHold.endHold()
                // Your own send is the newest row and pins; an opened message unpins.
                model.scrollHold.jumped(toBottom: id == model.log.ordered.last?.id)
                proxy.scrollTo(id, anchor: .center)
            }
            .onChange(of: pinnedToBottom) { wasPinned, isPinned in
                if ChatCatchUp.requests(becamePinned: isPinned && !wasPinned, tappedNewMessages: false) {
                    Task { await model.catchUp(pinned: true) }
                }
            }
            // Paging is decided from the scroll view's geometry: on every offset and
            // content-size change (the controller calls back), and whenever the paging
            // state changes. While a page's rows aren't laid out yet the check waits
            // for the content-size change instead of reading stale geometry.
            .onAppear {
                model.scrollHold.onGeometry = { metrics in olderCheck(metrics) }
                // A drag means the person has taken over: an opened message no
                // longer holds the list (so new messages can be followed again).
                model.scrollHold.onUserDrag = {
                    if let id = model.followSend, id != model.log.ordered.last?.id { model.followSend = nil }
                }
            }
            .onChange(of: model.olderPaging.state) { _, _ in
                if let metrics = model.scrollHold.metrics { olderCheck(metrics) }
            }
            // An older page went in: put the topmost row the reader could fully see
            // back where it was. The framework lays that row out exactly, so the
            // lazy stack's estimated heights for the new rows don't move it.
            .onChange(of: model.olderRestoreSerial) { _, _ in
                guard let restore = model.olderRestore else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    proxy.scrollTo(restore.id, anchor: UnitPoint(x: 0.5, y: restore.unitY))
                }
            }
            // The viewer called spots: the card is at the top of the thread.
            .onChange(of: model.spotCalledSerial) { _, _ in
                model.scrollHold.endHold()
                model.scrollHold.jumped(toBottom: false)
                proxy.scrollTo(ChatAnchor.spot, anchor: .top)
            }
            // A pinned list follows the end: a new row, or the last one sending,
            // failing (its "Not delivered" and Retry stay above the composer), sent.
            .onChange(of: chatEndSignature) { _, _ in
                model.scrollHold.watchFailedRow(failedEndRow)
                model.scrollHold.endChanged()
            }
            // A row expanding in place where the person tapped stays put.
            .onChange(of: model.selectedMessage) { _, id in
                if id != nil { model.scrollHold.expanded() }
            }
            .onChange(of: model.reacting) { _, on in
                if on { model.scrollHold.expanded() }
            }
            .onChange(of: model.log.ordered.last?.id) { _, id in
                guard let id else { return }
                // A pushed message is being opened: it wins over following the newest,
                // even when the history and the open land in the same update.
                if let target = model.followSend, target != id, model.log.entries.contains(where: { $0.id == target }) {
                    model.scrollHold.jumped(toBottom: false)
                    proxy.scrollTo(target, anchor: .center)
                    return
                }
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

    /// Room under the last message. At accessibility sizes with the keyboard up
    /// the list is only a few rows tall, so it keeps just a sliver.
    private var listBottomMargin: CGFloat {
        typeSize.isAccessibilitySize && composerFocused ? SQSpace.xs : SQSpace.l
    }

    /// AX sizes with the keyboard up: the list is only a few rows tall, so the
    /// end row takes as little height as a line of text can.
    private var endRowCompact: Bool {
        typeSize.isAccessibilitySize && composerFocused
    }

    /// Rows whose position the scroll controller needs: the oldest loaded message
    /// (the paging trigger and the next hold's anchor) and the current hold's anchor.
    ///
    /// Only while older pages can still come (idle or loading): then the first
    /// `trackedWindow` messages, which covers what's on screen whenever a page is
    /// asked for (it's asked for once the oldest is laid out near the screen), so
    /// the hold can anchor on a row the reader sees. Rows report only while laid
    /// out, and only on layout changes. A whole chat (Start of chat) tracks
    /// nothing, so a settled list does no reporting work.
    private var scrollTrackedIds: Set<UUID> {
        var ids = Set<UUID>()
        if let anchor = model.olderHoldAnchor { ids.insert(anchor) }
        // Before the first read is in, there's no paging to track for.
        guard model.chatLoad == .loaded else { return ids }
        switch model.olderPaging.state {
        case .idle, .loading:
            for entry in model.log.ordered.prefix(Self.trackedWindow) { ids.insert(entry.id) }
        case .failed, .reachedStart:
            break
        }
        return ids
    }

    private static let trackedWindow = 40

    /// The thread's end: the last row and its send state. A change means a new
    /// row at the end, or the last one sending, failing, or sent.
    private var chatEndSignature: String? {
        model.log.ordered.last.map { "\($0.id)|\($0.delivery)" }
    }

    /// The thread's last row when it's a message that failed to send (only your
    /// own can): its frame is measured so Retry stays inside the list.
    private var failedEndRow: UUID? {
        guard let last = model.log.ordered.last, last.delivery == .failed else { return nil }
        return last.id
    }

    private func olderCheck(_ metrics: ChatScrollMetrics) {
        let hold = model.scrollHold
        guard !hold.requestInFlight else { return }
        let oldestY = ChatOlderPaging.cursor(model.log).flatMap { hold.screenY(of: $0.id) }
        guard ChatOlderTrigger.isDue(
            metrics: metrics,
            oldestRowY: oldestY,
            userHasScrolled: hold.userHasScrolled,
            settlingPrepend: hold.isSettlingPrepend,
            paging: model.olderPaging,
            hasMessages: model.chatLoad == .loaded && !model.log.entries.isEmpty
        ) else { return }
        hold.requestInFlight = true
        Task {
            await model.loadOlder()
            hold.requestInFlight = false
        }
    }

    private func scrollChatToBottom(_ proxy: ScrollViewProxy) {
        model.scrollHold.jumped(toBottom: true)
        proxy.scrollTo(ChatAnchor.end, anchor: .bottom)
    }

    private var spotViewer: UUID? { model.viewerId ?? model.profile?.id }

    private var unreadForViewer: Int {
        model.log.unreadCount(viewerId: model.profile?.id ?? model.viewerId ?? UUID())
    }

    /// Thread rows with day separators, the unread divider, and message groups.
    /// Built once per change of the thread's inputs (ChatRowMemo), not per render.
    private var chatRowItems: [ChatRowItem] {
        #if DEBUG
        let builds = rowMemo.builds
        defer { if rowMemo.builds != builds { ChatScrollTrace.count(.memoBuild) } }
        #endif
        return rowMemo.rows(
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
                        Button("Lock") {
                            model.scrollHold.expanded()
                            Task { await model.lockSpot() }
                        }
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
            Button {
                SQHaptics.play(.tap)
                model.openWhosIn()
            } label: {
                Text("Who's in")
            }
            .accessibilityIdentifier("composer-whos-in")
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title2.weight(.semibold))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .foregroundStyle(SQColor.signal)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More")
        .accessibilityHint("Call spots, or see who's in")
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
            // Not spoken; lets UI tests read sender grouping without measuring gaps.
            .accessibilityIdentifier(ChatSeed.bubbleIdentifier(startsGroup: bubble.startsGroup))
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
                Button { model.reacting = true } label: {
                    Text("React")
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("react")
            }
            if model.reacting, model.selectedMessage == entry.id {
                reactionChoices(entry.id)
            }
            if entry.delivery == .failed {
                // The frame sits on the label, not the Button, so the hit target and
                // the accessibility frame are both at least 44 pt tall.
                Button { Task { await model.retry(entry.id) } } label: {
                    Text("Retry")
                        .font(SQType.label)
                        .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
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
    static let spot = "message-list-spot"
}

/// Feeds a message row's geometry to the scroll controller with
/// `onGeometryChange`, which calls back per row after layout (and once when it
/// appears), only when the value changes. It replaced a PreferenceKey: with an
/// `onPreferenceChange` on the list, SwiftUI recomputed that preference over the
/// whole lazy stack on every update, walking every row (copying it and reading
/// its id) and merging the reports.
///
/// The observer sits in the row's background, behind an `if`, and the row itself
/// is always the same view. 1c7fe9f put the `if` around the row (`content` vs
/// `content.onGeometryChange…`): when an older page went in, the tracked window
/// (the first 40 messages) moved up the thread, every visible row stopped being
/// tracked, and SwiftUI swapped each one for a new view, mid-insert. The lazy
/// stack lost their measured heights and the hold's neighbours, and every visible
/// row left the tree. A row's failed send flipped it the same way. Now tracking
/// on or off only adds or removes the clear background.
///
/// Tracked rows report:
/// - `tracksPosition`: the frame in the message stack's own space (doesn't move
///   while the list scrolls), for paging and the prepend hold (the controller
///   stamps the layout generation on receipt);
/// - `tracksFit`: the frame in the list's visible space, for the failed-send fit.
/// The callbacks write no SwiftUI state.
private struct ChatRowGeometry: ViewModifier {
    static let contentSpace = "chat-content"
    static let listSpace = "chat"

    let id: UUID
    let tracksPosition: Bool
    let tracksFit: Bool
    let controller: ChatScrollController

    func body(content: Content) -> some View {
        content.background {
            if tracksPosition || tracksFit {
                ChatRowGeometryProbe(id: id, tracksPosition: tracksPosition, tracksFit: tracksFit, controller: controller)
            }
        }
    }
}

/// Clear, the row's size (it's the row's background), and hidden from VoiceOver.
private struct ChatRowGeometryProbe: View {
    let id: UUID
    let tracksPosition: Bool
    let tracksFit: Bool
    let controller: ChatScrollController

    var body: some View {
        let id = self.id
        let tracksPosition = self.tracksPosition
        let tracksFit = self.tracksFit
        let controller = self.controller
        Color.clear
            .onGeometryChange(for: ChatRowSample.self) { proxy in
                let inContent = proxy.frame(in: .named(ChatRowGeometry.contentSpace))
                let inList = proxy.frame(in: .named(ChatRowGeometry.listSpace))
                return ChatRowSample(
                    content: tracksPosition ? ChatRowFrame(minY: inContent.minY, height: inContent.height) : nil,
                    list: tracksFit ? ChatRowFrame(minY: inList.minY, height: inList.height) : nil
                )
            } action: { sample in
                if let frame = sample.content {
                    controller.rowMoved(id, frame: frame)
                }
                if let frame = sample.list {
                    controller.failedRowMoved(id, frame: frame)
                }
            }
            .onDisappear {
                controller.rowGone(id)
            }
            .accessibilityHidden(true)
    }
}

private struct ChatRowSample: Equatable, Sendable {
    var content: ChatRowFrame?
    var list: ChatRowFrame?
}

/// The spot slot's clock: once a second while `ticks`, else a single entry (the
/// view renders once and only re-renders when its inputs change).
private struct ChatSlotSchedule: TimelineSchedule {
    let ticks: Bool

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next: Date? = startDate
        let ticks = self.ticks
        return AnyIterator {
            guard let current = next else { return nil }
            next = ticks ? current.addingTimeInterval(1) : nil
            return current
        }
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
            Color.clear.preference(key: ChatFrameKey.self, value: geo.frame(in: .named(ChatRowGeometry.listSpace)))
        }
    }
}

private struct ChatPinModifier: ViewModifier {
    @Binding var pinned: Bool
    /// iOS 17 only. Plain references, not state: written on every scroll frame,
    /// and a state write there would render this modifier again each frame.
    @State private var last = ChatPinLast()

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollSample.self, of: { geo in
                ScrollSample(
                    offset: geo.contentOffset.y,
                    content: geo.contentSize.height,
                    viewport: geo.containerSize.height
                )
            }, action: { old, sample in
                update(ChatFollow.pinned(previous: pinned, oldOffset: old.offset, sample: sample))
            })
        } else {
            content
                .background {
                    GeometryReader { geo in
                        Color.clear.preference(key: ChatViewportKey.self, value: geo.size.height)
                    }
                }
                .onPreferenceChange(ChatViewportKey.self) { last.viewport = $0 }
                .onPreferenceChange(ChatFrameKey.self) { frame in
                    let sample = ScrollSample(offset: -frame.minY, content: frame.height, viewport: last.viewport)
                    let next = ChatFollow.pinned(previous: pinned, oldOffset: last.offset, sample: sample)
                    last.offset = sample.offset
                    update(next)
                }
        }
    }

    /// Writes only a change, so a scroll that doesn't flip it renders nothing.
    private func update(_ next: Bool) {
        if next != pinned { pinned = next }
    }
}

private final class ChatPinLast {
    var offset: CGFloat = 0
    var viewport: CGFloat = 0
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

#if DEBUG
/// UI tests only (mock backend with `-mock-older-gate`): invisible. One element
/// reports the paging state ("loading pages=0"), the other lets one held older
/// page through when tapped.
private struct ChatOlderDebugProbe: View {
    let state: ChatOlderPaging.State
    let pages: Int
    let release: () -> Void

    private var value: String {
        let name: String
        switch state {
        case .idle: name = "idle"
        case .loading: name = "loading"
        case .failed: name = "failed"
        case .reachedStart: name = "reachedStart"
        }
        return "\(name) pages=\(pages)"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Not Color.clear: a fully clear view can be left out of the
            // accessibility tree. Nearly clear still draws, so it stays in.
            Rectangle()
                .fill(Color.white.opacity(0.001))
                .frame(width: 44, height: 44)
                .accessibilityElement()
                .accessibilityIdentifier("debug-older-paging")
                .accessibilityValue(value)
            Button(action: release) {
                Rectangle()
                    .fill(Color.white.opacity(0.001))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityIdentifier("debug-older-release")
            .accessibilityLabel("Release older page")
        }
    }
}
#endif
