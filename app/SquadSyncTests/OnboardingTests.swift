import XCTest
@testable import SquadSync

/// Onboarding (redesign S5): steps, email and code entry, sign-in errors, resend,
/// the profile draft, where games are kept, motion, and color contrast.
/// Foundation only; runs in the Linux harness.
final class OnboardingTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let user = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")

    private func json(_ text: String) -> Data { Data(text.utf8) }

    // MARK: Steps

    func testStepsRunEmailCodeProfileSquadThenHome() {
        XCTAssertEqual(OnboardingStep.current(signedIn: false, codeSent: false, profileConfirmed: false, hasSquad: false), .email)
        XCTAssertEqual(OnboardingStep.current(signedIn: false, codeSent: true, profileConfirmed: false, hasSquad: false), .code)
        XCTAssertEqual(OnboardingStep.current(signedIn: true, codeSent: false, profileConfirmed: false, hasSquad: false), .profile)
        XCTAssertEqual(OnboardingStep.current(signedIn: true, codeSent: false, profileConfirmed: true, hasSquad: false), .squad)
        XCTAssertEqual(OnboardingStep.current(signedIn: true, codeSent: false, profileConfirmed: false, hasSquad: true), .home, "Already in a squad skips the profile step")
    }

    func testEveryStepHasATitleAndSetupStepsCount() {
        for step in OnboardingStep.allCases {
            XCTAssertFalse(step.title.isEmpty)
        }
        XCTAssertEqual(OnboardingStep.email.progress, "Step 1 of 4")
        XCTAssertEqual(OnboardingStep.squad.progress, "Step 4 of 4")
        XCTAssertNil(OnboardingStep.home.progress)
        XCTAssertEqual(OnboardingStep.code.spokenHeader(), "Enter your code, Step 2 of 4")
        XCTAssertEqual(OnboardingStep.squad.spokenHeader(showsProgress: false), "Find your squad")
        XCTAssertEqual(OnboardingStep.home.spokenHeader(), "SquadSync")
    }

    // MARK: Email and code

    func testEmailCheckCatchesTyposButNotRealAddresses() {
        for good in ["a@b.co", " Spencer@Example.com ", "first.last+tag@mail.example.org"] {
            XCTAssertTrue(SignInEmail.isValid(good), good)
        }
        for bad in ["", "spencer", "spencer@", "@example.com", "a@b", "a@b.c", "a b@example.com", "a@@b.com", "a@b..com"] {
            XCTAssertFalse(SignInEmail.isValid(bad), bad)
        }
        XCTAssertEqual(SignInEmail.normalized(" Spencer@Example.COM "), "spencer@example.com")
    }

    func testCodeFieldKeepsDigitsFromAPaste() {
        XCTAssertEqual(OTPEntry.digits("Your code is 123 456"), "123456")
        XCTAssertEqual(OTPEntry.digits("12-34-56-78-90-12"), "1234567890", "Capped at 10 digits")
        XCTAssertEqual(OTPEntry.digits("١٢٣"), "", "Only ASCII digits; the server wants 0-9")
        XCTAssertTrue(OTPEntry.isComplete("123456"))
        XCTAssertFalse(OTPEntry.isComplete("12345"))
    }

    // MARK: Sign-in problems

    func testOfflineSaysOffline() {
        let problem = SignInProblem.from(BackendFailure.reconnecting, stage: .send)
        XCTAssertEqual(problem.kind, .offline)
        XCTAssertEqual(problem.message, SignInProblem.offline)
    }

    func testWrongOrExpiredCodeSaysWhatToDo() {
        let problem = SignInProblem.from(BackendFailure.rejected("Token has expired or is invalid"), stage: .verify)
        XCTAssertEqual(problem.kind, .wrongCode)
        XCTAssertTrue(problem.message.contains("send a new code"), problem.message)
        XCTAssertEqual(SignInProblem.from(BackendFailure.rejected(MockAuthService.wrongCodeText), stage: .verify).kind, .wrongCode)
    }

    func testRateLimitReadsTheServersWait() {
        let problem = SignInProblem.from(
            BackendFailure.rejected("For security purposes, you can only request this after 42 seconds."),
            stage: .send
        )
        XCTAssertEqual(problem.kind, .rateLimited)
        XCTAssertEqual(problem.retryAfter, 42)
        XCTAssertEqual(problem.message, "Too many tries. Wait 42 seconds, then send a new code.")
        let vague = SignInProblem.from(BackendFailure.rejected("email rate limit exceeded"), stage: .send)
        XCTAssertEqual(vague.kind, .rateLimited)
        XCTAssertEqual(vague.retryAfter, 60)
    }

    func testOtherProblemsStayPlain() {
        XCTAssertEqual(SignInProblem.from(BackendFailure.rejected("Signups not allowed for otp"), stage: .send).kind, .signupsClosed)
        XCTAssertEqual(SignInProblem.from(BackendFailure.rejected("Unable to validate email address: invalid format"), stage: .send).kind, .invalidEmail)
        XCTAssertEqual(SignInProblem.from(BackendFailure.notConfigured, stage: .send).message, SignInProblem.notConfigured)
        XCTAssertEqual(SignInProblem.from(BackendFailure.rejected("Request failed (500)."), stage: .send).message, "Couldn't send the code. Try again.")
        XCTAssertEqual(SignInProblem.from(BackendFailure.rejected("Request failed (500)."), stage: .verify).message, "Couldn't check the code. Try again.")
        XCTAssertEqual(SignInProblem.from(URLError(.badURL), stage: .verify).kind, .other)
    }

    func testLiveAuthErrorsMapThroughTheService() async {
        let tooSoon = ScriptedTransport(responses: [
            (429, json(#"{"code":429,"error_code":"over_email_send_rate_limit","msg":"For security purposes, you can only request this after 17 seconds."}"#))
        ])
        let sender = SupabaseAuthService(config: config, store: OnboardingTestStore(), transport: tooSoon)
        do {
            try await sender.sendCode(to: "a@b.co")
            XCTFail("A 429 should throw")
        } catch {
            let problem = SignInProblem.from(error, stage: .send)
            XCTAssertEqual(problem.kind, .rateLimited)
            XCTAssertEqual(problem.retryAfter, 17)
        }
        let wrong = ScriptedTransport(responses: [
            (403, json(#"{"code":403,"error_code":"otp_expired","msg":"Token has expired or is invalid"}"#))
        ])
        let verifier = SupabaseAuthService(config: config, store: OnboardingTestStore(), transport: wrong)
        do {
            _ = try await verifier.verify(email: "a@b.co", code: "123456")
            XCTFail("A 403 should throw")
        } catch {
            XCTAssertEqual(SignInProblem.from(error, stage: .verify).kind, .wrongCode, "\(error)")
        }
        let offline = SupabaseAuthService(config: config, store: OnboardingTestStore(), transport: FailingTransport())
        do {
            try await offline.sendCode(to: "a@b.co")
            XCTFail("Offline should throw")
        } catch {
            XCTAssertEqual(SignInProblem.from(error, stage: .send).kind, .offline)
        }
    }

    func testMockAuthAcceptsOnlyItsCode() async throws {
        let auth = MockAuthService(store: OnboardingTestStore(), acceptedCode: MockAuthService.onboardingCode)
        try await auth.sendCode(to: "a@b.co")
        XCTAssertEqual(auth.sendCount, 1)
        do {
            _ = try await auth.verify(email: "a@b.co", code: "000000")
            XCTFail("Wrong code accepted")
        } catch {
            XCTAssertEqual(SignInProblem.from(error, stage: .verify).kind, .wrongCode)
        }
        let session = try await auth.verify(email: "a@b.co", code: "123456")
        XCTAssertEqual(session.email, "a@b.co")
        let offline = MockAuthService(store: OnboardingTestStore(), sendFailure: .reconnecting)
        do {
            try await offline.sendCode(to: "a@b.co")
            XCTFail("Offline mock sent")
        } catch {
            XCTAssertEqual(SignInProblem.from(error, stage: .send).kind, .offline)
        }
    }

    // MARK: Resend

    func testResendWaitsForTheCooldownAndTheServer() {
        var clock = ResendClock(cooldown: 60, sentAt: now)
        XCTAssertFalse(clock.canResend(now: now))
        XCTAssertEqual(clock.secondsLeft(now: now.addingTimeInterval(18)), 42)
        XCTAssertEqual(clock.label(now: now.addingTimeInterval(18)), "Send a new code in 0:42")
        XCTAssertEqual(clock.spoken(now: now.addingTimeInterval(59.2)), "Send a new code, available in 1 second")
        XCTAssertTrue(clock.canResend(now: now.addingTimeInterval(60)))
        XCTAssertEqual(clock.label(now: now.addingTimeInterval(61)), "Send a new code")
        clock.serverWaitUntil = now.addingTimeInterval(90)
        XCTAssertEqual(clock.secondsLeft(now: now.addingTimeInterval(61)), 29, "The server's longer wait wins")
        XCTAssertTrue(ResendClock().canResend(now: now), "Nothing sent yet")
        XCTAssertEqual(ResendClock(cooldown: 600, sentAt: now).label(now: now), "Send a new code in 10:00")
    }

    // MARK: Profile draft

    func testProfileNeedsANameAndAGame() {
        var draft = ProfileDraft(name: "  ", defaultGame: "")
        XCTAssertEqual(draft.nameError, "Add the name your squad will see.")
        XCTAssertEqual(draft.gameError, "Pick a default game.")
        XCTAssertFalse(draft.isValid)
        draft.name = String(repeating: "x", count: 41)
        XCTAssertEqual(draft.nameError, "Keep your name to 40 characters.")
        draft.name = "  Spencer   R "
        draft.defaultGame = "Warzone"
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.saved.name, "Spencer R")
    }

    func testGamesListAddsTidiesAndRefusesDuplicates() {
        var draft = ProfileDraft(name: "S", defaultGame: "Warzone")
        XCTAssertNil(draft.addGame("  Apex   Legends "))
        XCTAssertEqual(draft.games, ["Apex Legends"])
        XCTAssertEqual(draft.addGame("apex legends"), "apex legends is already in your list.")
        XCTAssertEqual(draft.addGame("   "), "Type a game first.")
        XCTAssertEqual(draft.addGame(String(repeating: "g", count: 41)), "Keep the game to 40 characters.")
        draft.removeGame("APEX LEGENDS")
        XCTAssertTrue(draft.games.isEmpty)
    }

    func testGamesListHoldsTwelve() {
        var draft = ProfileDraft(name: "S", defaultGame: "Warzone")
        for index in 1...12 { XCTAssertNil(draft.addGame("Game \(index)")) }
        XCTAssertEqual(draft.addGame("Game 13"), "Your list holds 12 games. Remove one first.")
        XCTAssertEqual(draft.games.count, 12)
    }

    func testSuggestionsSkipWhatYouHave() {
        var draft = ProfileDraft(name: "S", defaultGame: "Warzone", games: ["fortnite"])
        XCTAssertFalse(draft.openSuggestions.contains("Fortnite"))
        XCTAssertEqual(draft.openSuggestions.count, ProfileDraft.suggestions.count - 1)
        draft.removeGame("Fortnite")
        XCTAssertTrue(draft.openSuggestions.contains("Fortnite"))
    }

    func testSavedListPutsTheDefaultGameFirst() {
        let draft = ProfileDraft(name: "S", defaultGame: " warzone ", games: ["Apex Legends", "Warzone"])
        XCTAssertEqual(draft.saved.defaultGame, "warzone")
        XCTAssertEqual(draft.saved.games, ["warzone", "Apex Legends"])
        let none = ProfileDraft(name: "S", defaultGame: "Halo", games: [])
        XCTAssertEqual(none.saved.games, ["Halo"])
    }

    // MARK: Where games are kept

    func testServerWithoutTheGamesColumnKeepsThemOnThePhone() async throws {
        let suite = "onboarding-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let local = LocalGamesStore(defaults: defaults)
        let missing = ScriptedTransport(responses: [
            (400, json(#"{"code":"42703","message":"column sq8_profiles.games does not exist"}"#))
        ])
        let service = SupabaseProfileGames(config: config, accessToken: "token", transport: missing, local: local)
        let loaded = try await service.load(userId: user)
        XCTAssertEqual(loaded.home, .phone)
        let home = try await service.save(userId: user, games: ["Halo", "Apex Legends"])
        XCTAssertEqual(home, .phone)
        XCTAssertEqual(local.load(user), ["Halo", "Apex Legends"])
        XCTAssertEqual(missing.requests.count, 1, "Saving on the phone sends nothing")
        XCTAssertNotNil(GamesHome.phone.note)
        XCTAssertNil(GamesHome.server.note)
    }

    func testServerWithTheColumnReadsAndPatchesIt() async throws {
        let present = ScriptedTransport(responses: [
            (200, json(#"[{"games":["Halo"]}]"#)),
            (204, Data())
        ])
        let service = SupabaseProfileGames(config: config, accessToken: "token", transport: present)
        let loaded = try await service.load(userId: user)
        XCTAssertEqual(loaded, ProfileGames(games: ["Halo"], home: .server))
        let home = try await service.save(userId: user, games: ["Halo", "Valorant"])
        XCTAssertEqual(home, .server)
        XCTAssertEqual(present.requests.last?.httpMethod, "PATCH")
        let body = present.requests.last?.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(body.contains("Valorant"), body)
        XCTAssertEqual(present.requests.first?.url?.query?.contains("select=games"), true)
    }

    func testOfflineGamesReadThrowsInsteadOfGuessing() async {
        let service = SupabaseProfileGames(config: config, accessToken: "token", transport: FailingTransport())
        do {
            _ = try await service.load(userId: user)
            XCTFail("Offline read should throw")
        } catch {
            XCTAssertEqual(error as? BackendFailure, .reconnecting)
        }
        XCTAssertFalse(SupabaseProfileGames.columnMissing(.rejected("permission denied for table sq8_profiles")))
        XCTAssertTrue(SupabaseProfileGames.columnMissing(.rejected("Could not find the 'games' column of 'sq8_profiles' in the schema cache")))
    }

    func testOnboardingMarksArePerAccount() {
        let suite = "onboarding-marks-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let marks = OnboardingMarks(defaults: defaults)
        XCTAssertFalse(marks.profileConfirmed(user))
        marks.confirmProfile(user)
        XCTAssertTrue(marks.profileConfirmed(user))
        XCTAssertFalse(marks.profileConfirmed(UUID()))
    }

    // MARK: Motion

    func testReduceMotionTurnsSlidesIntoFadesAndScrollsIntoJumps() {
        XCTAssertEqual(MotionPolicy.resolve(systemReduceMotion: false, launchOverride: false), .full)
        XCTAssertEqual(MotionPolicy.resolve(systemReduceMotion: true, launchOverride: false), .reduced)
        XCTAssertEqual(MotionPolicy.resolve(systemReduceMotion: false, launchOverride: true), .reduced)
        XCTAssertTrue(MotionPolicy.full.movesContent)
        XCTAssertFalse(MotionPolicy.reduced.movesContent)
        XCTAssertNil(MotionPolicy.reduced.duration(.scroll))
        XCTAssertNil(MotionPolicy.reduced.duration(.toggle))
        XCTAssertNotNil(MotionPolicy.reduced.duration(.stepChange), "A short fade still marks the change")
        for kind in [MotionPolicy.Kind.stepChange, .appear, .scroll, .toggle] {
            let seconds = MotionPolicy.full.duration(kind) ?? 0
            XCTAssertGreaterThan(seconds, 0)
            XCTAssertLessThanOrEqual(seconds, 0.3, "Subtle: nothing runs longer than 0.3s")
        }
        XCTAssertEqual(MotionPolicy.reduced.label, "Reduced motion")
    }

    // MARK: Contrast

    func testContrastMathMatchesWCAG() {
        XCTAssertEqual(Contrast.ratio(0xFFFFFF, 0x000000), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio(0x777777, 0x777777), 1, accuracy: 0.001)
        XCTAssertEqual(Contrast.ratio(0x767676, 0xFFFFFF), 4.54, accuracy: 0.01)
    }

    func testEveryTextTokenPassesAAOnEverySurfaceInBothModes() {
        var failures: [String] = []
        for (textName, text) in SQPalette.textTokens {
            for (surfaceName, surface) in SQPalette.surfaces {
                let light = Contrast.ratio(text.light, surface.light)
                let dark = Contrast.ratio(text.dark, surface.dark)
                if light < Contrast.text { failures.append("light \(textName) on \(surfaceName): \(String(format: "%.2f", light))") }
                if dark < Contrast.text { failures.append("dark \(textName) on \(surfaceName): \(String(format: "%.2f", dark))") }
            }
        }
        XCTAssertEqual(failures, [])
    }

    func testTextOnFilledColorsPasses() {
        XCTAssertGreaterThanOrEqual(Contrast.ratio(SQPalette.onSignal.light, SQPalette.signal.light), Contrast.text)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(SQPalette.onSignal.dark, SQPalette.signal.dark), Contrast.text)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(0xFFFFFF, SQPalette.mine.light), Contrast.text)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(SQPalette.ink.dark, SQPalette.mine.dark), Contrast.text)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(SQPalette.ink.light, SQPalette.theirs.light), Contrast.text)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(SQPalette.ink.dark, SQPalette.theirs.dark), Contrast.text)
    }
}

/// A session store for the Foundation tests (the app's in-memory one lives with the keychain code).
final class OnboardingTestStore: SessionStoring {
    private var session: AuthSession?
    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() throws { session = nil }
}

/// Onboarding through the session model on the mock backend (Mac only: the model
/// lives with the session screen and is main-actor).
@MainActor
final class OnboardingModelTests: XCTestCase {
    private func model(_ scenario: LaunchScenario) -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: scenario
        )
    }

    func testOnboardingRunsFromEmailToHome() async {
        let model = model(.onboarding)
        await model.restore()
        XCTAssertEqual(model.onboardingStep, .email)
        model.email = "nope"
        await model.sendCode()
        XCTAssertEqual(model.signInError, SignInEmail.invalidMessage)
        XCTAssertEqual(model.onboardingStep, .email)
        model.email = " New.Player@Example.com "
        await model.sendCode()
        XCTAssertEqual(model.onboardingStep, .code)
        XCTAssertEqual(model.email, "new.player@example.com")
        XCTAssertEqual(model.signInError, "")
        model.code = "123456"
        await model.verify()
        XCTAssertEqual(model.onboardingStep, .profile)
        XCTAssertEqual(model.profileLoad, .loaded)
        XCTAssertEqual(model.profileDraft.name, "new.player", "The trigger's default name comes in")
        XCTAssertEqual(model.gamesHome, .phone, "Like live: no games column yet")
        model.profileDraft.name = "New Player"
        model.addSuggestedGame("Fortnite")
        await model.saveOnboardingProfile()
        XCTAssertEqual(model.profileError, "")
        XCTAssertEqual(model.onboardingStep, .squad)
        XCTAssertEqual(model.displayName, "New Player")
        XCTAssertEqual(model.mockGames?.stored.values.first, ["Call of Duty", "Fortnite"])
        model.squadName = "Friday"
        await model.createSquad()
        XCTAssertEqual(model.onboardingStep, .home)
    }

    func testWrongCodeClearsTheFieldAndSaysWhy() async {
        let model = model(.onboarding)
        model.email = "a@b.co"
        await model.sendCode()
        model.code = "000000"
        await model.verify()
        XCTAssertEqual(model.onboardingStep, .code)
        XCTAssertEqual(model.signInError, SignInProblem.wrongCode)
        XCTAssertEqual(model.code, "", "A wrong code is cleared for the next try")
        model.codeChanged("1")
        XCTAssertEqual(model.signInError, "", "Typing again clears the error")
    }

    func testResendWaitsThenSendsANewCode() async {
        let model = model(.onboarding)
        model.email = "a@b.co"
        await model.sendCode()
        XCTAssertFalse(model.resend.canResend(now: Date()))
        await model.resendCode()
        XCTAssertEqual(model.mockAuth?.sendCount, 1, "Resend does nothing during the cooldown")
        model.resend.sentAt = Date().addingTimeInterval(-10)
        await model.resendCode()
        XCTAssertEqual(model.mockAuth?.sendCount, 2)
        XCTAssertTrue(model.resentNote.hasPrefix("We sent a new code"))
        model.changeEmail()
        XCTAssertEqual(model.onboardingStep, .email)
        XCTAssertEqual(model.email, "a@b.co", "Changing email keeps what was typed")
    }

    func testOfflineSendSaysOfflineAndStays() async {
        let model = model(.onboardingOffline)
        model.email = "a@b.co"
        await model.sendCode()
        XCTAssertEqual(model.signInError, SignInProblem.offline)
        XCTAssertEqual(model.onboardingStep, .email)
        XCTAssertNil(model.onboardingAction)
    }

    func testProfileValidationAndOfflineSave() async {
        let model = model(.onboardingProfile)
        await model.restore()
        XCTAssertEqual(model.onboardingStep, .profile)
        model.profileDraft.name = " "
        await model.saveOnboardingProfile()
        XCTAssertTrue(model.showProfileErrors)
        XCTAssertEqual(model.onboardingStep, .profile, "An empty name doesn't move on")
        model.profileDraft.name = "Spencer"
        model.mockGames?.savesDown = true
        await model.saveOnboardingProfile()
        XCTAssertEqual(model.profileError, "You're offline. Your profile wasn't saved. Try again.")
        XCTAssertEqual(model.onboardingStep, .profile)
        model.mockGames?.savesDown = false
        await model.saveOnboardingProfile()
        XCTAssertEqual(model.onboardingStep, .squad)
    }

    func testProfileLoadFailureOffersRetry() async {
        let model = model(.onboardingProfile)
        model.mockGames?.loadsDown = true
        await model.restore()
        XCTAssertEqual(model.profileLoad, .failed("You're offline. Your profile will load when you're back online."))
        model.mockGames?.loadsDown = false
        await model.loadOnboardingProfile()
        XCTAssertEqual(model.profileLoad, .loaded)
    }

    func testOtherScenariosSkipOnboarding() async {
        let model = model(.invite)
        await model.restore()
        XCTAssertEqual(model.onboardingStep, .home)
        let empty = self.model(.noSquad)
        await empty.restore()
        XCTAssertEqual(empty.onboardingStep, .squad, "No squad but already set up: the squad step, not the profile")
    }
}
