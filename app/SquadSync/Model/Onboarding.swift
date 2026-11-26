import Foundation

// Onboarding (redesign S5): email code sign-in, a first profile, and a first squad.
// Foundation only, so the rules run in the Linux harness.

/// Where someone is in getting set up. The session screen shows one step at a time.
enum OnboardingStep: Equatable, CaseIterable {
    case email
    case code
    case profile
    case squad
    case home

    /// Signed out: the email or code step. Signed in: profile until it's confirmed
    /// once, then a squad. Someone already in a squad goes straight home.
    static func current(signedIn: Bool, codeSent: Bool, profileConfirmed: Bool, hasSquad: Bool) -> OnboardingStep {
        guard signedIn else { return codeSent ? .code : .email }
        if hasSquad { return .home }
        return profileConfirmed ? .squad : .profile
    }

    var title: String {
        switch self {
        case .email: "Sign in with email"
        case .code: "Enter your code"
        case .profile: "Set up your profile"
        case .squad: "Find your group"
        case .home: "SquadSync"
        }
    }

    /// "Step 2 of 4" for the four setup steps; nil at home.
    var progress: String? {
        switch self {
        case .email: "Step 1 of 4"
        case .code: "Step 2 of 4"
        case .profile: "Step 3 of 4"
        case .squad: "Step 4 of 4"
        case .home: nil
        }
    }

    /// The header as one VoiceOver stop, title first: "Enter your code, Step 2 of 4".
    /// Someone back at the squad step after leaving a squad gets no step count.
    func spokenHeader(showsProgress: Bool = true) -> String {
        [title, showsProgress ? progress : nil].compactMap { $0 }.joined(separator: ", ")
    }
}

enum SignInEmail {
    static let invalidMessage = "Enter an email like name@example.com."

    static func normalized(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// A light check so a typo is caught before a code is sent. The server decides the rest.
    static func isValid(_ raw: String) -> Bool {
        let email = normalized(raw)
        guard !email.isEmpty, email.count <= 254, !email.contains(where: \.isWhitespace) else { return false }
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2, !parts[0].isEmpty else { return false }
        let labels = parts[1].split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }) else { return false }
        return (labels.last?.count ?? 0) >= 2
    }
}

/// The code field. Supabase sends 6 digits by default; a project can send up to 10.
enum OTPEntry {
    static let length = 6
    static let maxLength = 10

    /// Digits only, so a pasted "123 456" or "Your code is 123456" still works.
    static func digits(_ raw: String) -> String {
        String(raw.filter { ("0"..."9").contains($0) }.prefix(maxLength))
    }

    static func isComplete(_ raw: String) -> Bool {
        SignInCode.isValid(digits(raw))
    }
}

enum SignInStage: Equatable {
    case send
    case verify
}

/// A failed send or verify, in plain words, with how long to wait when the server says.
struct SignInProblem: Equatable {
    enum Kind: Equatable {
        case offline
        case wrongCode
        case rateLimited
        case invalidEmail
        case signupsClosed
        case notConfigured
        case other
    }

    let kind: Kind
    let message: String
    /// Seconds the server asked us to wait before another code.
    let retryAfter: TimeInterval?

    static let offline = "You're offline. Check your connection, then try again."
    static let wrongCode = "That code didn't work. It may be mistyped or expired. Check the newest email, or send a new code."
    static let signupsClosed = "This email can't sign up here yet."
    static let notConfigured = "Sign-in isn't set up in this build."

    static func from(_ error: Error, stage: SignInStage) -> SignInProblem {
        if let failure = error as? BackendFailure {
            switch failure {
            case .reconnecting:
                return SignInProblem(kind: .offline, message: offline, retryAfter: nil)
            case .notConfigured:
                return SignInProblem(kind: .notConfigured, message: notConfigured, retryAfter: nil)
            case .rejected(let text):
                return from(serverText: text, stage: stage)
            case .notSetUp, .sessionEnded, .notSignedIn:
                break
            }
        }
        return generic(stage)
    }

    /// GoTrue's words: "For security purposes, you can only request this after 42 seconds.",
    /// "email rate limit exceeded", "Token has expired or is invalid", "Signups not allowed for otp".
    static func from(serverText: String, stage: SignInStage) -> SignInProblem {
        let text = serverText.lowercased()
        if text.contains("security purposes") || text.contains("rate limit") || text.contains("too many") {
            if let seconds = waitSeconds(in: text) {
                return SignInProblem(kind: .rateLimited, message: "Too many tries. Wait \(seconds) seconds, then send a new code.", retryAfter: TimeInterval(seconds))
            }
            return SignInProblem(kind: .rateLimited, message: "Too many codes sent. Wait a minute, then try again.", retryAfter: 60)
        }
        if text.contains("signup") && (text.contains("not allowed") || text.contains("disabled")) {
            return SignInProblem(kind: .signupsClosed, message: signupsClosed, retryAfter: nil)
        }
        if stage == .verify && (text.contains("expired") || text.contains("invalid") || text.contains("token")) {
            return SignInProblem(kind: .wrongCode, message: wrongCode, retryAfter: nil)
        }
        if stage == .send && text.contains("email") && (text.contains("invalid") || text.contains("validate")) {
            return SignInProblem(kind: .invalidEmail, message: SignInEmail.invalidMessage, retryAfter: nil)
        }
        return generic(stage)
    }

    private static func generic(_ stage: SignInStage) -> SignInProblem {
        switch stage {
        case .send: SignInProblem(kind: .other, message: "Couldn't send the code. Try again.", retryAfter: nil)
        case .verify: SignInProblem(kind: .other, message: "Couldn't check the code. Try again.", retryAfter: nil)
        }
    }

    /// The number before "second" in "after 42 seconds".
    private static func waitSeconds(in text: String) -> Int? {
        guard let range = text.range(of: "second") else { return nil }
        let before = text[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        let digits = before.reversed().prefix { $0.isNumber }
        guard !digits.isEmpty, let value = Int(String(digits.reversed())), value > 0 else { return nil }
        return min(value, 3600)
    }
}

/// When another code can be sent: after the cooldown, and never before the server's own wait.
struct ResendClock: Equatable {
    /// Supabase allows one email code a minute per address by default.
    static let liveCooldown: TimeInterval = 60

    var cooldown: TimeInterval = ResendClock.liveCooldown
    var sentAt: Date?
    var serverWaitUntil: Date?

    func secondsLeft(now: Date) -> Int {
        var until = Date.distantPast
        if let sentAt { until = max(until, sentAt.addingTimeInterval(cooldown)) }
        if let serverWaitUntil { until = max(until, serverWaitUntil) }
        let left = until.timeIntervalSince(now)
        return left > 0 ? Int(left.rounded(.up)) : 0
    }

    func canResend(now: Date) -> Bool { secondsLeft(now: now) == 0 }

    func label(now: Date) -> String {
        let left = secondsLeft(now: now)
        guard left > 0 else { return "Send a new code" }
        return "Send a new code in \(left / 60):\(String(format: "%02d", left % 60))"
    }

    func spoken(now: Date) -> String {
        let left = secondsLeft(now: now)
        guard left > 0 else { return "Send a new code" }
        return "Send a new code, available in \(left) second\(left == 1 ? "" : "s")"
    }
}

/// A read the onboarding screen waits on (the profile).
enum OnboardingLoad: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

/// The one onboarding request in flight, so its button can say what it's doing.
enum OnboardingAction: Equatable {
    case sending
    case resending
    case verifying
    case savingProfile
    case creating
    case joining
}

/// Where the games list is kept.
enum GamesHome: Equatable {
    /// The server has a `games` column (proposed 0023).
    case server
    /// It doesn't, so the list stays on this phone and the profile says so.
    case phone

    var note: String? {
        switch self {
        case .server: nil
        case .phone: "Your games list is saved on this phone only. The server keeps your name and default game."
        }
    }
}

/// The profile being set up or edited: name, default game, and the games you play.
struct ProfileDraft: Equatable {
    static let maxName = 40
    static let maxGame = 40
    static let maxGames = 12
    static let suggestions = [
        "Call of Duty", "Warzone", "Fortnite", "Apex Legends",
        "Valorant", "Rocket League", "Minecraft", "Halo Infinite"
    ]

    var name: String
    var defaultGame: String
    var games: [String]

    init(name: String, defaultGame: String, games: [String] = []) {
        self.name = name
        self.defaultGame = defaultGame
        self.games = []
        for game in games { _ = addGame(game) }
    }

    static func tidy(_ raw: String) -> String {
        raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    var nameError: String? {
        let name = Self.tidy(self.name)
        if name.isEmpty { return "Add the name your group will see." }
        if name.count > Self.maxName { return "Keep your name to \(Self.maxName) characters." }
        return nil
    }

    var gameError: String? {
        let game = Self.tidy(defaultGame)
        if game.isEmpty { return "Pick a default game." }
        if game.count > Self.maxGame { return "Keep the game to \(Self.maxGame) characters." }
        return nil
    }

    var isValid: Bool { nameError == nil && gameError == nil }

    func contains(_ game: String) -> Bool {
        let key = Self.tidy(game).lowercased()
        return games.contains { $0.lowercased() == key }
    }

    /// Adds a game. Returns why it wasn't added, or nil when it was.
    @discardableResult
    mutating func addGame(_ raw: String) -> String? {
        let game = Self.tidy(raw)
        if game.isEmpty { return "Type a game first." }
        if game.count > Self.maxGame { return "Keep the game to \(Self.maxGame) characters." }
        if contains(game) { return "\(game) is already in your list." }
        if games.count >= Self.maxGames { return "Your list holds \(Self.maxGames) games. Remove one first." }
        games.append(game)
        return nil
    }

    mutating func removeGame(_ game: String) {
        let key = game.lowercased()
        games.removeAll { $0.lowercased() == key }
    }

    /// Suggestions not already in the list, for the empty and short-list states.
    var openSuggestions: [String] {
        Self.suggestions.filter { !contains($0) }
    }

    /// What gets saved: tidy text, and the default game always in the list, first.
    var saved: (name: String, defaultGame: String, games: [String]) {
        let game = Self.tidy(defaultGame)
        var list = games.filter { $0.lowercased() != game.lowercased() }
        if !game.isEmpty { list.insert(game, at: 0) }
        return (Self.tidy(name), game, Array(list.prefix(Self.maxGames)))
    }
}

/// The games editor in the signed-in profile panel: add or remove games and pick
/// the default. The list is `sq8_profiles.games` (0023) through ProfileGames;
/// the default is `default_game`. Same rules as the profile step (ProfileDraft).
/// Games are saved only once the list has loaded, so a failed read never
/// overwrites the server's list with an empty one.
struct ProfileGamesEditor: Equatable {
    enum Load: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    static let emptyText = "No games yet. Add the ones you play."
    static let loadingText = "Loading your games…"
    static let loadFailedText = "Your games didn't load. Try again."
    static let offlineLoadText = "You're offline. Your games will load when you're back online."
    static let saveFailedText = "Your games didn't save. Try again."
    static let offlineSaveText = "You're offline. Your games weren't saved. Try again."

    var load: Load = .idle
    var games: [String] = []
    var entry = ""
    var error = ""
    var message = ""
    var saving = false
    var home: GamesHome?

    var canEdit: Bool { load == .loaded && !saving }
    var showsEmpty: Bool { load == .loaded && games.isEmpty }

    mutating func begin() {
        load = .loading
        error = ""
    }

    /// The read came back: the list, tidied and de-duplicated like the profile step.
    mutating func loaded(_ read: ProfileGames, defaultGame: String) {
        games = ProfileDraft(name: "", defaultGame: defaultGame, games: read.games).games
        home = read.home
        load = .loaded
    }

    mutating func failed(offline: Bool) {
        load = .failed(offline ? Self.offlineLoadText : Self.loadFailedText)
    }

    /// Adds the typed (or suggested) game. Returns true when it went in.
    @discardableResult
    mutating func add(_ raw: String) -> Bool {
        var draft = ProfileDraft(name: "", defaultGame: "", games: games)
        if let problem = draft.addGame(raw) {
            error = problem
            return false
        }
        games = draft.games
        error = ""
        message = ""
        if raw == entry { entry = "" }
        return true
    }

    mutating func remove(_ game: String) {
        var draft = ProfileDraft(name: "", defaultGame: "", games: games)
        draft.removeGame(game)
        games = draft.games
        error = ""
        message = ""
    }

    /// Suggestions not in the list yet, for the empty and short-list states.
    var suggestions: [String] {
        ProfileDraft(name: "", defaultGame: "", games: games).openSuggestions
    }

    static func isDefault(_ game: String, defaultGame: String) -> Bool {
        ProfileDraft.tidy(game).lowercased() == ProfileDraft.tidy(defaultGame).lowercased()
    }

    /// VoiceOver for one row: "Warzone, default game" or "Fortnite".
    static func rowLabel(_ game: String, defaultGame: String) -> String {
        isDefault(game, defaultGame: defaultGame) ? "\(game), default game" : game
    }

    /// The list shown: the default first (it's saved that way), then the rest.
    static func ordered(_ games: [String], defaultGame: String) -> [String] {
        games.filter { isDefault($0, defaultGame: defaultGame) } + games.filter { !isDefault($0, defaultGame: defaultGame) }
    }

    static func savedMessage(_ home: GamesHome?) -> String {
        home == .phone ? "Profile saved. Your games list is on this phone only." : "Profile saved."
    }
}

/// How much things move. Reduce Motion (or the `-reduceMotion` launch flag in tests)
/// swaps slides and springs for short fades, and scrolls jump instead of gliding.
enum MotionPolicy: Equatable {
    case full
    case reduced

    enum Kind: Equatable {
        /// One onboarding step replacing another.
        case stepChange
        /// A row, banner, or toast appearing.
        case appear
        /// Scrolling the chat to a message.
        case scroll
        /// A section opening or closing.
        case toggle
    }

    static func resolve(systemReduceMotion: Bool, launchOverride: Bool) -> MotionPolicy {
        systemReduceMotion || launchOverride ? .reduced : .full
    }

    /// Seconds for the animation, or nil to change without animating.
    func duration(_ kind: Kind) -> Double? {
        switch (self, kind) {
        case (.full, .stepChange): 0.28
        case (.full, .appear): 0.2
        case (.full, .scroll): 0.25
        case (.full, .toggle): 0.2
        case (.reduced, .stepChange), (.reduced, .appear): 0.15
        case (.reduced, .scroll), (.reduced, .toggle): nil
        }
    }

    /// Slides, scales, and springs only happen with full motion. Reduced keeps fades.
    var movesContent: Bool { self == .full }

    /// Read by UI tests from the onboarding container's accessibility value.
    var label: String {
        switch self {
        case .full: "Full motion"
        case .reduced: "Reduced motion"
        }
    }
}

/// Remembers, per account on this phone, that the profile step was finished.
/// Someone already in a squad never sees it.
struct OnboardingMarks {
    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private func key(_ userId: UUID) -> String { "sq8.onboarding.profile.\(userId.uuidString.lowercased())" }

    func profileConfirmed(_ userId: UUID) -> Bool { defaults.bool(forKey: key(userId)) }

    func confirmProfile(_ userId: UUID) { defaults.set(true, forKey: key(userId)) }
}
