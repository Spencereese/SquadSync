import XCTest
@testable import SquadSync

/// Play sessions: times in the viewer's zone, RSVP state, cancel, past
/// filtering, the chat cards, the honest errors, and both services (the mock
/// and the live one against scripted HTTP). Foundation only; runs in the Linux harness.
final class PlaySessionTests: XCTestCase {
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private let viewer = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let alex = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let jordan = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
    private let gone = UUID(uuidString: "00000000-0000-0000-0000-0000000000A9")!

    /// Thursday, Nov 26, 2026, 3:00 PM in the clock's zone.
    private func at(_ zone: String = "UTC", day: Int = 26, month: Int = 11, year: Int = 2026, hour: Int = 15, minute: Int = 0, second: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
    }

    private func clock(_ zone: String = "UTC") -> ChatClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        return ChatClock(calendar: calendar, locale: Locale(identifier: "en_US"))
    }

    private var now: Date { at() }

    private func session(
        _ id: Int = 1,
        creator: UUID? = nil,
        starts: Date? = nil,
        minutes: Int? = nil,
        cancelled: Date? = nil,
        created: Date? = nil,
        rsvps: [PlaySessionRSVP] = []
    ) -> PlaySession {
        PlaySession(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!,
            squadId: squad,
            creatorId: creator ?? alex,
            game: "Warzone",
            startsAt: starts ?? now.addingTimeInterval(5 * 3600),
            durationMinutes: minutes,
            note: nil,
            cancelledAt: cancelled,
            createdAt: created ?? now.addingTimeInterval(-600),
            rsvps: rsvps
        )
    }

    private var members: [SquadMemberRecord] {
        [
            SquadMemberRecord(id: viewer, displayName: "Spencer", defaultGame: "Call of Duty", isOwner: true),
            SquadMemberRecord(id: alex, displayName: "Alex", defaultGame: "Warzone", isOwner: false),
            SquadMemberRecord(id: jordan, displayName: "Jordan", defaultGame: "", isOwner: false),
            SquadMemberRecord(id: sam, displayName: "sam", defaultGame: "", isOwner: false)
        ]
    }

    // MARK: Times

    func testTimeLabelsSayTonightTomorrowAndTheDay() {
        let utc = clock()
        XCTAssertEqual(PlaySessionTime.label(at(hour: 20), now: now, clock: utc), "Tonight 8:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(hour: 17), now: now, clock: utc), "Tonight 5:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(hour: 16, minute: 30), now: now, clock: utc), "Today 4:30 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 27, hour: 19, minute: 30), now: now, clock: utc), "Tomorrow 7:30 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 25, hour: 20), now: now, clock: utc), "Yesterday 8:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 28, hour: 20), now: now, clock: utc), "Saturday 8:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 2, month: 12, hour: 21), now: now, clock: utc), "Wednesday 9:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 6, month: 12, hour: 20), now: now, clock: utc), "Sun, Dec 6, 8:00 PM")
        XCTAssertEqual(PlaySessionTime.label(at(day: 5, month: 1, year: 2027, hour: 20), now: now, clock: utc), "Jan 5, 2027, 8:00 PM")
    }

    func testTimeLabelsUseTheViewersOwnZone() {
        // 2:00 AM UTC on Friday is 8:00 PM Thursday in Chicago (UTC-6).
        let instant = at(day: 27, hour: 2)
        let chicagoNow = at("America/Chicago", hour: 15)
        XCTAssertEqual(PlaySessionTime.label(instant, now: chicagoNow, clock: clock("America/Chicago")), "Tonight 8:00 PM")
        XCTAssertEqual(PlaySessionTime.label(instant, now: chicagoNow, clock: clock()), "Tomorrow 2:00 AM")
    }

    func testRelativeLineCountsDownThenSaysLiveEndedOrCancelled() {
        func line(_ seconds: TimeInterval, minutes: Int? = nil, cancelled: Bool = false) -> String? {
            PlaySessionTime.relative(session(starts: now.addingTimeInterval(seconds), minutes: minutes, cancelled: cancelled ? now : nil), now: now)
        }
        XCTAssertEqual(line(30), "Starting now")
        XCTAssertEqual(line(25 * 60), "Starts in 25 min")
        XCTAssertEqual(line(24 * 60 + 10), "Starts in 25 min")
        XCTAssertEqual(line(60 * 60), "Starts in 1 hr")
        XCTAssertEqual(line(90 * 60), "Starts in 1 hr 30 min")
        XCTAssertEqual(line(120 * 60), "Starts in 2 hr")
        XCTAssertEqual(line(5 * 3600 + 20 * 60), "Starts in 5 hr")
        XCTAssertNil(line(13 * 3600))
        XCTAssertEqual(line(-60), "Happening now")
        XCTAssertEqual(line(-119 * 60), "Happening now")
        XCTAssertEqual(line(-120 * 60), "Ended")
        XCTAssertEqual(line(-40 * 60, minutes: 30), "Ended")
        XCTAssertEqual(line(3600, cancelled: true), "Cancelled")
    }

    func testSuggestedStartIsTonightAtEightOrSoonOnAQuarterHour() {
        let calendar = clock().calendar
        XCTAssertEqual(PlaySessionTime.suggestedStart(now: at(hour: 15), calendar: calendar), at(hour: 20))
        XCTAssertEqual(PlaySessionTime.suggestedStart(now: at(hour: 19, minute: 30), calendar: calendar), at(hour: 20))
        XCTAssertEqual(PlaySessionTime.suggestedStart(now: at(hour: 19, minute: 45), calendar: calendar), at(hour: 20, minute: 15))
        XCTAssertEqual(PlaySessionTime.suggestedStart(now: at(hour: 19, minute: 50, second: 10), calendar: calendar), at(hour: 20, minute: 30))
        XCTAssertEqual(PlaySessionTime.suggestedStart(now: at(hour: 23, minute: 40), calendar: calendar), at(day: 27, hour: 0, minute: 15))
    }

    func testQuickPicksOfferSoonTonightAndTomorrow() {
        let afternoon = PlaySessionTime.quickPicks(now: at(hour: 15), clock: clock())
        XCTAssertEqual(afternoon.map(\.id), ["soon", "tonight", "tomorrow"])
        XCTAssertEqual(afternoon.map(\.title), ["In 30 min", "Tonight 8:00 PM", "Tomorrow 8:00 PM"])
        XCTAssertEqual(afternoon.map(\.date), [at(hour: 15, minute: 30), at(hour: 20), at(day: 27, hour: 20)])
        // Ten minutes before eight, tonight at eight is too close to offer.
        let late = PlaySessionTime.quickPicks(now: at(hour: 19, minute: 50), clock: clock())
        XCTAssertEqual(late.map(\.id), ["soon", "tomorrow"])
        XCTAssertEqual(late.first?.date, at(hour: 20, minute: 30))
    }

    // MARK: Phases and filtering

    func testPhasesUseTwoHoursWhenThereIsNoDuration() {
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(60)), now: now), .upcoming)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now), now: now), .live)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(-7199)), now: now), .live)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(-7200)), now: now), .over)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(-20 * 60), minutes: 15), now: now), .over)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(-3 * 3600), minutes: 240), now: now), .live)
        XCTAssertEqual(PlaySessionRules.phase(session(starts: now.addingTimeInterval(3600), cancelled: now), now: now), .cancelled)
    }

    func testUpcomingDropsPastAndCancelledAndSortsSoonestFirst() {
        let later = session(1, starts: now.addingTimeInterval(86_400))
        let soon = session(2, starts: now.addingTimeInterval(1800))
        let live = session(3, starts: now.addingTimeInterval(-1800))
        let past = session(4, starts: now.addingTimeInterval(-3 * 3600))
        let cancelled = session(5, starts: now.addingTimeInterval(3600), cancelled: now.addingTimeInterval(-60))
        let upcoming = PlaySessionRules.upcoming([later, past, soon, cancelled, live], now: now)
        XCTAssertEqual(upcoming.map(\.id), [live.id, soon.id, later.id])
        XCTAssertTrue(PlaySessionRules.isDone(past, now: now))
        XCTAssertTrue(PlaySessionRules.isDone(cancelled, now: now))
        XCTAssertFalse(PlaySessionRules.isDone(live, now: now))
        XCTAssertFalse(PlaySessionRules.canRespond(past, now: now))
        XCTAssertTrue(PlaySessionRules.canRespond(live, now: now))
    }

    // MARK: RSVP state

    func testAnsweringReplacesYourAnswerInsteadOfAddingOne() {
        var current = session()
        current = PlaySessionRules.setting(.going, for: viewer, in: current, at: now)
        XCTAssertEqual(current.response(of: viewer), .going)
        current = PlaySessionRules.setting(.out, for: viewer, in: current, at: now.addingTimeInterval(5))
        XCTAssertEqual(current.response(of: viewer), .out)
        XCTAssertEqual(current.rsvps.filter { $0.userId == viewer }.count, 1)
        XCTAssertEqual(current.rsvps.first?.updatedAt, now.addingTimeInterval(5))
        XCTAssertNil(current.response(of: alex))
        XCTAssertNil(current.response(of: nil))
    }

    func testRosterPutsYouFirstAndDropsPeopleWhoLeft() {
        let current = session(rsvps: [
            PlaySessionRSVP(userId: jordan, response: .going),
            PlaySessionRSVP(userId: gone, response: .going),
            PlaySessionRSVP(userId: viewer, response: .going),
            PlaySessionRSVP(userId: alex, response: .going),
            PlaySessionRSVP(userId: sam, response: .out)
        ])
        let roster = PlaySessionRoster.make(current, members: members, viewerId: viewer)
        XCTAssertEqual(roster.going, ["You", "Alex", "Jordan"])
        XCTAssertEqual(roster.out, ["sam"])
        XCTAssertEqual(roster.viewerResponse, .going)
        XCTAssertEqual(roster.summary, "3 in · 1 out")
        XCTAssertEqual(PlaySessionRoster.list(roster.going), "You, Alex and Jordan")
        XCTAssertEqual(PlaySessionRoster.list(["Alex", "Sam"]), "Alex and Sam")
        XCTAssertEqual(PlaySessionRoster.list(["Alex"]), "Alex")
    }

    func testRosterSummaryAndMaybeCountAsNoAnswer() {
        let empty = PlaySessionRoster.make(session(), members: members, viewerId: viewer)
        XCTAssertEqual(empty.summary, "No answers yet")
        XCTAssertNil(empty.viewerResponse)
        let maybe = PlaySessionRoster.make(session(rsvps: [PlaySessionRSVP(userId: viewer, response: .maybe)]), members: members, viewerId: viewer)
        XCTAssertNil(maybe.viewerResponse)
        XCTAssertEqual(maybe.summary, "No answers yet")
        let outOnly = PlaySessionRoster.make(session(rsvps: [PlaySessionRSVP(userId: alex, response: .out)]), members: members, viewerId: viewer)
        XCTAssertEqual(outOnly.summary, "1 out")
        XCTAssertEqual(PlaySessionCopy.yourAnswer(.going), "You're in")
        XCTAssertEqual(PlaySessionCopy.yourAnswer(.out), "You're out")
        XCTAssertEqual(PlaySessionCopy.yourAnswer(nil), "You haven't answered")
    }

    func testSpokenLabelReadsTheWholeCardInOrder() {
        var current = session(rsvps: [
            PlaySessionRSVP(userId: viewer, response: .going),
            PlaySessionRSVP(userId: alex, response: .going),
            PlaySessionRSVP(userId: sam, response: .out)
        ])
        current.note = "Bring mics."
        let roster = PlaySessionRoster.make(current, members: members, viewerId: viewer)
        let spoken = PlaySessionCopy.spoken(current, roster: roster, time: "Tonight 8:00 PM", relative: "Starts in 5 hr")
        XCTAssertEqual(spoken, "Play session: Warzone, Tonight 8:00 PM. Starts in 5 hr. In: You and Alex. Out: sam. Note: Bring mics.")
        let bare = PlaySessionCopy.spoken(session(), roster: PlaySessionRoster.make(session(), members: members, viewerId: viewer), time: "Saturday 8:00 PM", relative: nil)
        XCTAssertEqual(bare, "Play session: Warzone, Saturday 8:00 PM. No answers yet.")
        XCTAssertEqual(PlaySessionCopy.nextLine(current, roster: roster, others: 2, time: "Tonight 8:00 PM"), "Tonight 8:00 PM · Warzone · 2 in · 1 out · +2 more")
        XCTAssertEqual(PlaySessionCopy.nextLine(current, roster: roster, others: 0, time: "Tonight 8:00 PM"), "Tonight 8:00 PM · Warzone · 2 in · 1 out")
    }

    // MARK: Cancel

    func testOnlyTheCreatorCanCancelAndOnlyWhileItIsOn() {
        let mine = session(creator: viewer)
        XCTAssertTrue(PlaySessionRules.canCancel(mine, viewerId: viewer, now: now))
        XCTAssertFalse(PlaySessionRules.canCancel(mine, viewerId: alex, now: now))
        XCTAssertFalse(PlaySessionRules.canCancel(mine, viewerId: nil, now: now))
        XCTAssertFalse(PlaySessionRules.canCancel(session(creator: viewer, cancelled: now), viewerId: viewer, now: now))
        XCTAssertFalse(PlaySessionRules.canCancel(session(creator: viewer, starts: now.addingTimeInterval(-3 * 3600)), viewerId: viewer, now: now))
        XCTAssertTrue(PlaySessionRules.canCancel(session(creator: viewer, starts: now.addingTimeInterval(-600)), viewerId: viewer, now: now))
    }

    func testReplacingKeepsTheListSortedAndUnique() {
        let first = session(1, starts: now.addingTimeInterval(7200))
        let second = session(2, starts: now.addingTimeInterval(3600))
        var list = PlaySessionRules.replacing(first, in: [])
        list = PlaySessionRules.replacing(second, in: list)
        XCTAssertEqual(list.map(\.id), [second.id, first.id])
        var cancelled = first
        cancelled.cancelledAt = now
        list = PlaySessionRules.replacing(cancelled, in: list)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list.last?.cancelledAt, now)
    }

    // MARK: The form

    func testDraftFallsBackToTheDefaultGameAndChecksTheRest() {
        var draft = PlaySessionDraft(startsAt: now.addingTimeInterval(3600), game: "  ", note: " ")
        XCTAssertEqual(draft.resolvedGame(defaultGame: "Call of Duty "), "Call of Duty")
        XCTAssertNil(draft.resolvedNote)
        XCTAssertNil(draft.problem(now: now, defaultGame: "Call of Duty"))
        XCTAssertEqual(draft.problem(now: now, defaultGame: " "), .gameBlank)
        draft.game = " Apex "
        XCTAssertEqual(draft.resolvedGame(defaultGame: "Call of Duty"), "Apex")
        draft.game = String(repeating: "x", count: 61)
        XCTAssertEqual(draft.problem(now: now, defaultGame: ""), .gameLong)
        draft.game = "Apex"
        draft.note = String(repeating: "n", count: 281)
        XCTAssertEqual(draft.problem(now: now, defaultGame: ""), .noteLong)
        draft.note = "ok"
        draft.startsAt = now.addingTimeInterval(-4 * 60)
        XCTAssertNil(draft.problem(now: now, defaultGame: ""), "A few minutes ago is still fine")
        draft.startsAt = now.addingTimeInterval(-6 * 60)
        XCTAssertEqual(draft.problem(now: now, defaultGame: ""), .timePast)
        draft.startsAt = now.addingTimeInterval(61 * 86_400)
        XCTAssertEqual(draft.problem(now: now, defaultGame: ""), .timeFar)
        XCTAssertEqual(PlaySessionProblem.gameBlank.message, "Add a game so the squad knows what you're playing.")
    }

    // MARK: Errors and load states

    func testServerAnswersBecomePlainWords() {
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.notSetUp(.sessions)), .unavailable)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.reconnecting), .offline)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("session_full")), .full)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("session_cancelled")), .cancelled)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("session_over")), .over)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("not_in_squad")), .notInSquad)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("session_time_past")), .timePast)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("new row violates row-level security policy for table \"sq8_session_rsvps\"")), .notAllowed)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("new row for relation \"sq8_sessions\" violates check constraint \"sq8_sessions_game_not_blank\"")), .gameBlank)
        XCTAssertEqual(PlaySessionProblem.from(BackendFailure.rejected("boom")), .failed)
        XCTAssertEqual(PlaySessionProblem.from(PlaySessionProblem.full), .full)
        XCTAssertEqual(PlaySessionProblem.from(URLError(.badURL)), .failed)
        XCTAssertTrue(PlaySessionProblem.isSessionFailure(BackendFailure.sessionEnded))
        XCTAssertTrue(PlaySessionProblem.isSessionFailure(BackendFailure.rejected("JWT expired")))
        XCTAssertFalse(PlaySessionProblem.isSessionFailure(BackendFailure.rejected("session_full")))
        XCTAssertEqual(PlaySessionProblem.unavailable.message, "Play sessions aren't set up on this server yet.")
    }

    func testLoadStatesNeverPretendThereIsNothing() {
        XCTAssertEqual(PlaySessionLoad.idle.display(hasData: false), .loading)
        XCTAssertEqual(PlaySessionLoad.loading.display(hasData: false), .loading)
        XCTAssertNil(PlaySessionLoad.loading.display(hasData: true))
        XCTAssertNil(PlaySessionLoad.loaded.display(hasData: false))
        XCTAssertEqual(PlaySessionLoad.failed("x").display(hasData: false), .failed("x"))
        XCTAssertEqual(PlaySessionLoad.failed("x").display(hasData: true), .stale)
        XCTAssertEqual(PlaySessionLoad.unavailable.display(hasData: false), .unavailable)
        XCTAssertEqual(PlaySessionLoad.beginning(.idle), .loading)
        XCTAssertEqual(PlaySessionLoad.beginning(.failed("x")), .loading)
        XCTAssertEqual(PlaySessionLoad.beginning(.loaded), .loaded, "A refresh keeps what's on screen")
        XCTAssertEqual(PlaySessionLoad.beginning(.unavailable), .unavailable)
    }

    // MARK: Chat cards

    private func entry(_ n: Int, at offset: TimeInterval, sender: UUID? = nil) -> ChatEntry {
        ChatEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 900 + n))!,
            senderId: sender ?? alex,
            body: "m\(n)",
            sentAt: now.addingTimeInterval(offset),
            delivery: .sent
        )
    }

    func testCardsSitWhereTheyWereScheduledBetweenMessages() {
        let first = entry(1, at: -900)
        let second = entry(2, at: -300)
        let card = session(7, created: now.addingTimeInterval(-600))
        let early = session(8, created: now.addingTimeInterval(-2000))
        let newest = session(9, created: now.addingTimeInterval(-10))
        let base: [SpotThreadItem] = [.message(first), .message(second)]
        let merged = PlaySessionThread.items(base, sessions: [newest, card, early], earliest: nil)
        XCTAssertEqual(merged.map(\.id), [
            "session-\(early.id.uuidString)",
            "message-\(first.id.uuidString)",
            "session-\(card.id.uuidString)",
            "message-\(second.id.uuidString)",
            "session-\(newest.id.uuidString)"
        ])
        // While older pages are still unread, cards from before the oldest loaded message wait.
        let partial = PlaySessionThread.items(base, sessions: [newest, card, early], earliest: first.sentAt)
        XCTAssertFalse(partial.contains { $0.id == "session-\(early.id.uuidString)" })
        XCTAssertEqual(partial.count, 4)
        XCTAssertEqual(PlaySessionThread.items(base, sessions: [], earliest: nil), base)
    }

    func testACardInTheThreadBreaksTheMessageGroup() {
        let first = entry(1, at: -120)
        let second = entry(2, at: -60)
        let card = session(7, created: now.addingTimeInterval(-90))
        let items = PlaySessionThread.items([.message(first), .message(second)], sessions: [card], earliest: nil)
        let rows = ChatThread.rows(items: items, context: ChatThread.Context(
            viewerId: viewer, names: [alex: "Alex"], reads: [], unreadAnchor: nil, clock: clock(), now: now
        ))
        let kinds: [String] = rows.map { row in
            switch row {
            case .day: return "day"
            case .unread: return "unread"
            case .message(let bubble): return bubble.startsGroup ? "start" : "more"
            case .spot: return "spot"
            case .session: return "session"
            case .gameOn: return "gameOn"
            }
        }
        XCTAssertEqual(kinds, ["day", "start", "session", "start"])
        XCTAssertEqual(rows[2].identity, "session-\(card.id.uuidString)")
    }

    // MARK: Mock server

    func testMockScheduleAnswerAndCancelFollowTheServerRules() async throws {
        let mock = MockPlaySessionService(memberIds: [viewer, alex], now: { self.now })
        let created = try await mock.schedule(PlaySessionRequest(squadId: squad, creatorId: viewer, game: " Apex ", startsAt: now.addingTimeInterval(3600), note: "hi"))
        XCTAssertEqual(created.game, "Apex")
        XCTAssertEqual(created.createdAt, now)
        try await mock.respond(sessionId: created.id, userId: viewer, response: .going)
        try await mock.respond(sessionId: created.id, userId: alex, response: .out)
        try await mock.respond(sessionId: created.id, userId: alex, response: .going)
        let read = try await mock.sessions(squadId: squad, since: now.addingTimeInterval(-86_400))
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read.first?.rsvps.count, 2)
        XCTAssertEqual(read.first?.response(of: alex), .going)

        do {
            try await mock.respond(sessionId: created.id, userId: gone, response: .going)
            XCTFail("Someone outside the squad answered")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .notInSquad)
        }

        let cancelled = try await mock.cancel(sessionId: created.id)
        XCTAssertEqual(cancelled.cancelledAt, now)
        do {
            try await mock.respond(sessionId: created.id, userId: viewer, response: .out)
            XCTFail("Answered a cancelled session")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .cancelled)
        }
    }

    func testMockCapsAtEightAndRefusesPastTimes() async throws {
        let people = (1...9).map { UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 700 + $0))! }
        let mock = MockPlaySessionService(memberIds: Set(people), now: { self.now })
        let created = try await mock.schedule(PlaySessionRequest(squadId: squad, creatorId: people[0], game: "Apex", startsAt: now.addingTimeInterval(3600), note: nil))
        for person in people.prefix(8) {
            try await mock.respond(sessionId: created.id, userId: person, response: .going)
        }
        do {
            try await mock.respond(sessionId: created.id, userId: people[8], response: .going)
            XCTFail("A ninth in was accepted")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .full)
        }
        // Someone already in can still say in again, and the ninth can say out.
        try await mock.respond(sessionId: created.id, userId: people[0], response: .going)
        try await mock.respond(sessionId: created.id, userId: people[8], response: .out)

        do {
            _ = try await mock.schedule(PlaySessionRequest(squadId: squad, creatorId: people[0], game: "Apex", startsAt: now.addingTimeInterval(-3600), note: nil))
            XCTFail("A past time was accepted")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .timePast)
        }
    }

    func testMockWithoutTablesOrWithReadsDownSaysSo() async throws {
        let missing = MockPlaySessionService(serverMissing: true, now: { self.now })
        do {
            _ = try await missing.sessions(squadId: squad, since: now)
            XCTFail("A server without tables returned sessions")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .unavailable)
        }
        let down = MockPlaySessionService(sessions: [session()], readsDown: true, now: { self.now })
        do {
            _ = try await down.sessions(squadId: squad, since: now.addingTimeInterval(-86_400))
            XCTFail("A down server returned sessions")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .failed)
        }
        down.recover()
        let read = try await down.sessions(squadId: squad, since: now.addingTimeInterval(-86_400))
        XCTAssertEqual(read.count, 1)
        let offline = MockPlaySessionService(writesDown: true, now: { self.now })
        do {
            _ = try await offline.schedule(PlaySessionRequest(squadId: squad, creatorId: viewer, game: "Apex", startsAt: now.addingTimeInterval(3600), note: nil))
            XCTFail("An offline write went through")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .offline)
        }
    }

    func testSeedHasOneOfEachKind() {
        let seeded = PlaySessionSeed.squad(viewerId: viewer, squadId: squad, alex: alex, jordan: jordan, sam: sam, now: now, calendar: clock().calendar)
        let upcoming = PlaySessionRules.upcoming(seeded, now: now)
        XCTAssertEqual(upcoming.map(\.id), [PlaySessionSeed.tonightId, PlaySessionSeed.laterId])
        XCTAssertEqual(seeded.first { $0.id == PlaySessionSeed.tonightId }?.response(of: viewer), nil)
        XCTAssertEqual(PlaySessionRules.phase(seeded.first { $0.id == PlaySessionSeed.pastId }!, now: now), .over)
        XCTAssertEqual(PlaySessionRules.phase(seeded.first { $0.id == PlaySessionSeed.cancelledId }!, now: now), .cancelled)
    }

    // MARK: Live service, scripted HTTP

    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon")

    private func query(_ request: URLRequest?) -> [String: String] {
        guard let url = request?.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        return Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
    }

    func testLiveReadAsksForOneSquadWithRSVPsEmbedded() async throws {
        let body = """
        [{"id":"00000000-0000-0000-0000-000000000001","squad_id":"00000000-0000-0000-0000-0000000000aa",
          "creator_id":"00000000-0000-0000-0000-0000000000a1","game":"Warzone",
          "starts_at":"2026-11-26T20:00:00+00:00","duration_minutes":null,"note":"mics",
          "cancelled_at":null,"created_at":"2026-11-26T14:50:00.123456+00:00",
          "sq8_session_rsvps":[{"user_id":"00000000-0000-0000-0000-0000000000a1","response":"in","updated_at":"2026-11-26T14:50:01.5+00:00"},
                               {"user_id":"00000000-0000-0000-0000-0000000000a2","response":"later","updated_at":null}]}]
        """
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabasePlaySessionService(config: config, accessToken: "token", transport: transport)
        let read = try await service.sessions(squadId: squad, since: now)
        XCTAssertEqual(read.count, 1)
        XCTAssertEqual(read.first?.startsAt, at(hour: 20))
        XCTAssertEqual(read.first?.note, "mics")
        XCTAssertEqual(read.first?.rsvps.map(\.userId), [alex], "An unknown answer is dropped, not guessed")
        let request = transport.requests.first
        XCTAssertEqual(request?.httpMethod, "GET")
        XCTAssertEqual(request?.url?.path, "/rest/v1/sq8_sessions")
        let items = query(request)
        XCTAssertEqual(items["squad_id"], "eq.\(squad.uuidString)")
        XCTAssertEqual(items["select"], SupabasePlaySessionService.select)
        XCTAssertTrue(items["select"]?.contains("sq8_session_rsvps(user_id,response,updated_at)") == true)
        XCTAssertTrue(items["starts_at"]?.hasPrefix("gte.2026-11-26T15:00:00") == true, "starts_at: \(items["starts_at"] ?? "")")
        XCTAssertEqual(items["order"], "starts_at.asc,id.asc")
    }

    func testLiveReadWithoutTheTableIsUnavailable() async {
        let missing = Data("{\"code\":\"PGRST205\",\"message\":\"Could not find the table 'public.sq8_sessions' in the schema cache\"}".utf8)
        let transport = ScriptedTransport(responses: [(404, missing)])
        let service = SupabasePlaySessionService(config: config, accessToken: "token", transport: transport)
        do {
            _ = try await service.sessions(squadId: squad, since: now)
            XCTFail("A missing table returned sessions")
        } catch {
            XCTAssertEqual(error as? BackendFailure, .notSetUp(.sessions))
            XCTAssertEqual(PlaySessionProblem.from(error), .unavailable)
        }
    }

    func testLiveScheduleAnswerAndCancelSendTheRightRequests() async throws {
        let row = """
        [{"id":"00000000-0000-0000-0000-000000000001","squad_id":"00000000-0000-0000-0000-0000000000aa",
          "creator_id":"00000000-0000-0000-0000-000000000001","game":"Apex","starts_at":"2026-11-26T20:00:00Z",
          "duration_minutes":null,"note":null,"cancelled_at":null,"created_at":"2026-11-26T15:00:00Z","sq8_session_rsvps":[]}]
        """
        let transport = ScriptedTransport(responses: [(201, Data(row.utf8)), (201, Data()), (200, Data("[]".utf8))])
        let service = SupabasePlaySessionService(config: config, accessToken: "token", transport: transport, clock: { self.now })
        let created = try await service.schedule(PlaySessionRequest(squadId: squad, creatorId: viewer, game: "Apex", startsAt: at(hour: 20), note: nil))
        XCTAssertEqual(created.game, "Apex")
        try await service.respond(sessionId: created.id, userId: viewer, response: .going)
        do {
            _ = try await service.cancel(sessionId: created.id)
            XCTFail("A cancel the server refused looked like it worked")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .notAllowed)
        }

        XCTAssertEqual(transport.requests.count, 3)
        let insert = transport.requests[0]
        XCTAssertEqual(insert.httpMethod, "POST")
        XCTAssertEqual(insert.value(forHTTPHeaderField: "Prefer"), "return=representation")
        let sent = try JSONSerialization.jsonObject(with: insert.httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(sent?["game"] as? String, "Apex")
        XCTAssertEqual(sent?["squad_id"] as? String, squad.uuidString)
        XCTAssertNil(sent?["note"], "A blank note isn't sent")

        let answer = transport.requests[1]
        XCTAssertEqual(answer.url?.path, "/rest/v1/sq8_session_rsvps")
        XCTAssertEqual(query(answer)["on_conflict"], "session_id,user_id")
        XCTAssertEqual(answer.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=minimal")
        let rsvp = try JSONSerialization.jsonObject(with: answer.httpBody ?? Data()) as? [String: Any]
        XCTAssertEqual(rsvp?["response"] as? String, "in")
        XCTAssertEqual(rsvp?["user_id"] as? String, viewer.uuidString)

        let cancel = transport.requests[2]
        XCTAssertEqual(cancel.httpMethod, "PATCH")
        XCTAssertEqual(query(cancel)["id"], "eq.\(created.id.uuidString)")
        let stamp = try JSONSerialization.jsonObject(with: cancel.httpBody ?? Data()) as? [String: Any]
        XCTAssertNotNil(stamp?["cancelled_at"] as? String)
    }

    func testLiveRefusalsComeBackAsPlainWords() async {
        let full = Data("{\"code\":\"P0001\",\"message\":\"session_full\"}".utf8)
        let rls = Data("{\"code\":\"42501\",\"message\":\"new row violates row-level security policy for table \\\"sq8_session_rsvps\\\"\"}".utf8)
        let transport = ScriptedTransport(responses: [(400, full), (403, rls)])
        let service = SupabasePlaySessionService(config: config, accessToken: "token", transport: transport)
        do {
            try await service.respond(sessionId: squad, userId: viewer, response: .going)
            XCTFail("A full session took a ninth")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .full)
        }
        do {
            try await service.respond(sessionId: squad, userId: viewer, response: .going)
            XCTFail("RLS refusal looked like success")
        } catch {
            XCTAssertEqual(PlaySessionProblem.from(error), .notAllowed)
        }
    }
}
