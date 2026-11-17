import XCTest
@testable import SquadSync

/// Who's in (redesign S4): check-in rules, sources, the strip's statuses, and the
/// check-in service against scripted HTTP. Foundation only; runs in the Linux harness.
final class WhosInTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
    private let viewer = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let alex = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let jordan = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-0000000000A3")!
    private let utc = TimeZone(identifier: "UTC")!

    private func record(
        _ user: UUID,
        _ kind: CheckInKind,
        checked: TimeInterval = -60,
        until: TimeInterval? = nil,
        game: String? = nil,
        platform: CheckInPlatform? = nil,
        squad squadId: UUID? = nil
    ) -> CheckInRecord {
        CheckInRecord(
            userId: user,
            squadId: squadId ?? squad,
            kind: kind,
            checkedAt: now.addingTimeInterval(checked),
            untilAt: until.map { now.addingTimeInterval($0) },
            game: game,
            platform: platform
        )
    }

    private func member(_ id: UUID, _ name: String, game: String = "", owner: Bool = false) -> SquadMemberRecord {
        SquadMemberRecord(id: id, displayName: name, defaultGame: game, isOwner: owner)
    }

    private var members: [SquadMemberRecord] {
        [member(viewer, "Spencer", game: "Call of Duty", owner: true), member(alex, "Alex", game: "Warzone"), member(jordan, "Jordan"), member(sam, "Sam")]
    }

    private let full = CheckInCapabilities(table: true, details: true)
    private let basic = CheckInCapabilities(table: true, details: false)

    private func entries(
        _ checkIns: [CheckInRecord],
        caps: CheckInCapabilities? = nil,
        steam: SteamRead = .notSetUp,
        spot: SpotCall? = nil
    ) -> [WhosInEntry] {
        WhosIn.entries(
            members: members, squadId: squad, ownerId: viewer, viewerId: viewer, spot: spot,
            checkIns: checkIns, caps: caps ?? full, steam: steam, now: now
        )
    }

    private func entry(_ id: UUID, in list: [WhosInEntry]) -> WhosInEntry? {
        list.first { $0.id == id }
    }

    // MARK: Availability

    func testOnNowLastsUntilTheServerWindowEnds() {
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableNow, until: 30 * 60), now: now), .now(until: now.addingTimeInterval(30 * 60)))
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableNow, checked: -3700, until: -100), now: now), .notCheckedIn, "An expired on-now is not on")
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableNow, until: nil), now: now), .notCheckedIn, "On now without a window isn't trusted")
        XCTAssertEqual(CheckInRules.availability(nil, now: now), .notCheckedIn)
    }

    func testLaterStaysListedForAnHourAfterItsTime() {
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableLater, until: 7200), now: now), .later(at: now.addingTimeInterval(7200)))
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableLater, checked: -9000, until: -1800), now: now), .later(at: now.addingTimeInterval(-1800)), "Inside the grace hour it still reads 'said around'")
        XCTAssertEqual(CheckInRules.availability(record(alex, .availableLater, checked: -9000, until: -3700), now: now), .notCheckedIn)
    }

    func testCantPlayFadesAfterTwelveHours() {
        XCTAssertEqual(CheckInRules.availability(record(alex, .unavailable, checked: -3600), now: now), .cantPlay)
        XCTAssertEqual(CheckInRules.availability(record(alex, .unavailable, checked: -13 * 3600), now: now), .notCheckedIn)
    }

    func testLaterTimesMatchTheDatabaseWindow() {
        XCTAssertFalse(CheckInRules.acceptsLater(now.addingTimeInterval(60), now: now), "0006 wants more than a minute")
        XCTAssertTrue(CheckInRules.acceptsLater(now.addingTimeInterval(5 * 60), now: now))
        XCTAssertTrue(CheckInRules.acceptsLater(now.addingTimeInterval(7 * 24 * 3600), now: now))
        XCTAssertFalse(CheckInRules.acceptsLater(now.addingTimeInterval(7 * 24 * 3600 + 1), now: now))
    }

    func testLaterOptionsOfferTonightOrTomorrowAt8() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let afternoon = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 14))!
        let options = CheckInRules.laterOptions(now: afternoon, calendar: calendar)
        XCTAssertEqual(options.map(\.label), ["In 30 min", "In 1 hour", "In 2 hours", "Tonight 8 PM"])
        XCTAssertEqual(options.last?.at, calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 20)))
        let evening = calendar.date(from: DateComponents(year: 2026, month: 11, day: 17, hour: 19, minute: 30))!
        let late = CheckInRules.laterOptions(now: evening, calendar: calendar)
        XCTAssertEqual(late.last?.label, "Tomorrow 8 PM")
        XCTAssertEqual(late.last?.at, calendar.date(from: DateComponents(year: 2026, month: 11, day: 18, hour: 20)))
        XCTAssertTrue(late.allSatisfy { CheckInRules.acceptsLater($0.at, now: evening) })
    }

    func testGameIsTrimmedCappedAndNilWhenBlank() {
        XCTAssertNil(CheckInRules.normalizedGame("   "))
        XCTAssertEqual(CheckInRules.normalizedGame("  Halo "), "Halo")
        XCTAssertEqual(CheckInRules.normalizedGame(String(repeating: "x", count: 60))?.count, 40)
    }

    func testServerRefusalsReadAsPlainWords() {
        XCTAssertEqual(CheckInRules.message(for: "sq8_check_in_later_invalid"), "Pick a time between a few minutes and 7 days from now.")
        XCTAssertEqual(CheckInRules.message(for: "new row violates row-level security policy"), "You can only check in for your own squad.")
        XCTAssertEqual(CheckInRules.message(for: "boom"), "Check-in didn't save. Try again.")
    }

    // MARK: Rows and writes

    func testRowsDecodeWithAndWithoutTheProposedColumns() throws {
        let json = """
        [
          {"user_id":"\(alex.uuidString)","squad_id":"\(squad.uuidString)","kind":"available_now","checked_at":"2027-01-15T08:00:00Z","until_at":"2027-01-15T09:00:00Z","game":"  Halo  ","platform":"xbox"},
          {"user_id":"\(jordan.uuidString)","squad_id":"\(squad.uuidString)","kind":"unavailable","checked_at":"2027-01-15T08:00:00.123Z","until_at":null},
          {"user_id":"\(sam.uuidString)","squad_id":"\(squad.uuidString)","kind":"maybe","checked_at":"2027-01-15T08:00:00Z"},
          {"user_id":"\(viewer.uuidString)","squad_id":"\(squad.uuidString)","kind":"available_later","checked_at":"2027-01-15T08:00:00Z","until_at":"2027-01-15T10:00:00Z","platform":"dreamcast"}
        ]
        """
        let rows = try CheckInRows.decode(Data(json.utf8), decoder: BackendJSON.decoder)
        XCTAssertEqual(rows.map(\.userId), [alex, jordan, viewer], "An unknown kind is dropped, not read as can't play")
        XCTAssertEqual(rows[0].game, "Halo")
        XCTAssertEqual(rows[0].platform, .xbox)
        XCTAssertNil(rows[1].untilAt)
        XCTAssertNil(rows[1].game)
        XCTAssertNil(rows[2].platform, "An unknown console is left out")
    }

    private func json(_ write: CheckInWrite) throws -> [String: Any] {
        let data = try BackendJSON.encoder.encode(write)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testWriteLeavesTheWindowToTheServerAndOnlyNamesColumnsItHas() throws {
        let basicNow = try json(CheckInWrite(userId: viewer, squadId: squad, kind: .availableNow, untilAt: now, game: "Halo", platform: .pc, includesDetails: false))
        XCTAssertEqual(Set(basicNow.keys), ["user_id", "squad_id", "kind", "until_at"], "Without 0022 the game and console aren't named")
        XCTAssertTrue(basicNow["until_at"] is NSNull, "The trigger stamps the 60-minute window")
        XCTAssertEqual(basicNow["kind"] as? String, "available_now")

        let detailed = try json(CheckInWrite(userId: viewer, squadId: squad, kind: .availableLater, untilAt: now, game: "Halo", platform: .nintendoSwitch, includesDetails: true))
        XCTAssertEqual(detailed["game"] as? String, "Halo")
        XCTAssertEqual(detailed["platform"] as? String, "switch")
        XCTAssertNotNil(detailed["until_at"] as? String)

        let cant = try json(CheckInWrite(userId: viewer, squadId: squad, kind: .unavailable, untilAt: now, game: "Halo", platform: .pc, includesDetails: true))
        XCTAssertTrue(cant["game"] is NSNull, "Can't play clears the old game")
        XCTAssertTrue(cant["platform"] is NSNull)
        XCTAssertTrue(cant["until_at"] is NSNull)
    }

    // MARK: Steam

    func testSteamParsesEachStateAndNeverGuessesAGame() {
        XCTAssertEqual(SteamRead.parse(Data(#"{"status":"not_set_up"}"#.utf8)), .notSetUp)
        XCTAssertEqual(SteamRead.parse(Data("nope".utf8)), .failed)
        XCTAssertEqual(SteamRead.parse(Data(#"{"error":"not_a_member"}"#.utf8)), .failed)
        let body = """
        {"status":"ok","members":[
          {"user_id":"\(alex.uuidString)","state":"playing","game":"Counter-Strike 2"},
          {"user_id":"\(jordan.uuidString)","state":"private"},
          {"user_id":"\(sam.uuidString)","state":"playing","game":"  "},
          {"user_id":"\(viewer.uuidString)","state":"not_linked"},
          {"user_id":"bad","state":"playing","game":"x"}
        ]}
        """
        let read = SteamRead.parse(Data(body.utf8))
        XCTAssertEqual(read.presence(for: alex), .playing("Counter-Strike 2"))
        XCTAssertEqual(read.presence(for: jordan), .privateProfile)
        XCTAssertEqual(read.presence(for: sam), .notInGame, "A blank game isn't a game")
        XCTAssertEqual(read.presence(for: viewer), .notLinked)
    }

    func testAnUndeployedFunctionIsNotSetUp() {
        XCTAssertTrue(SteamFunction.isMissing(.notSetUp(.checkIns)))
        XCTAssertTrue(SteamFunction.isMissing(.rejected("Requested function was not found")))
        XCTAssertFalse(SteamFunction.isMissing(.rejected("signed_out")))
        XCTAssertFalse(SteamFunction.isMissing(.reconnecting))
    }

    // MARK: Entries and sources

    func testGameSourcesRankSpotThenSteamThenCheckInThenProfile() {
        let checkIns = [
            record(alex, .availableNow, until: 1800, game: "Halo", platform: .xbox),
            record(jordan, .availableNow, until: 1800, game: "Apex", platform: .playstation)
        ]
        let steam = SteamRead.members([jordan: .playing("Counter-Strike 2")])
        let list = entries(checkIns, steam: steam)
        XCTAssertEqual(entry(alex, in: list)?.gameSource, .checkIn(.xbox))
        XCTAssertEqual(entry(alex, in: list)?.gameLine, "Halo · Xbox")
        XCTAssertEqual(entry(jordan, in: list)?.gameSource, .steam, "Steam is checked; a typed console isn't")
        XCTAssertEqual(entry(jordan, in: list)?.game, "Counter-Strike 2")
        XCTAssertEqual(entry(viewer, in: list)?.gameSource, .profile)
        XCTAssertEqual(entry(viewer, in: list)?.gameLine, "Usually plays Call of Duty")
        XCTAssertNil(entry(sam, in: list)?.game)

        let call = SpotSeed.halfFilled(ownerId: viewer, squadId: squad, now: now)
        let seatedIds = call.rsvps.filter(\.isIn).map(\.userId)
        let spotMembers = members + seatedIds.filter { id in !members.contains { $0.id == id } }.map { member($0, "Seat") }
        let seated = WhosIn.entries(members: spotMembers, squadId: squad, ownerId: viewer, viewerId: viewer, spot: call, checkIns: checkIns, caps: full, steam: steam, now: now)
        XCTAssertFalse(seatedIds.isEmpty)
        for id in seatedIds {
            XCTAssertEqual(entry(id, in: seated)?.gameSource, .spot, "A seat on the open call wins")
            XCTAssertEqual(entry(id, in: seated)?.game, call.game)
        }
    }

    func testCheckInGameNeedsTheColumnsAndAnOnOrLaterCheckIn() {
        let typed = [record(alex, .availableNow, until: 1800, game: "Halo", platform: .xbox), record(sam, .unavailable, game: "Apex")]
        XCTAssertEqual(entry(alex, in: entries(typed, caps: basic))?.gameSource, .profile, "Without 0022 a typed game isn't shown")
        XCTAssertEqual(entry(sam, in: entries(typed))?.game, nil, "Can't play doesn't advertise a game")
    }

    func testSectionsAndOrder() {
        let list = entries([
            record(sam, .availableLater, until: 3600),
            record(jordan, .unavailable),
            record(alex, .availableNow, until: 600),
            record(viewer, .availableNow, until: 900)
        ])
        XCTAssertEqual(list.map(\.id), [viewer, alex, sam, jordan], "On now (you first), later, can't play")
        let sections = WhosIn.sections(list.filter { !$0.isViewer })
        XCTAssertEqual(sections.map(\.section), [.now, .later, .cantPlay])
        XCTAssertEqual(WhosIn.summary(list.filter { !$0.isViewer }), "1 on now · 1 later")
        XCTAssertEqual(WhosIn.summary([]), "Nobody's checked in")
    }

    func testNewestRowWinsAndOtherSquadsAreIgnored() {
        let other = UUID()
        let list = entries([
            record(alex, .unavailable, checked: -600),
            record(alex, .availableNow, checked: -60, until: 1800),
            record(jordan, .availableNow, until: 1800, squad: other)
        ])
        XCTAssertEqual(entry(alex, in: list)?.availability, .now(until: now.addingTimeInterval(1800)))
        XCTAssertEqual(entry(jordan, in: list)?.availability, .notCheckedIn)
    }

    func testWithoutTheTableEveryoneIsUntrackedAndNothingIsClaimed() {
        let list = entries([record(alex, .availableNow, until: 1800)], caps: .unknown)
        XCTAssertTrue(list.allSatisfy { $0.availability == .untracked })
        XCTAssertEqual(WhosIn.sections(list).map(\.section), [.notCheckedIn])
        XCTAssertEqual(entry(alex, in: list)?.statusLine(now: now, timeZone: utc), "Check-ins aren't on this server")
        XCTAssertNil(WhosIn.availabilityByMember(checkIns: [], squadId: squad, caps: .unknown, now: now))
    }

    func testStatusLinesAndSpokenLabelsSayWhereThingsCameFrom() {
        let list = entries(
            [
                record(alex, .availableNow, until: 1800, game: "Halo", platform: .xbox),
                record(sam, .availableLater, until: 7200)
            ],
            steam: .members([jordan: .privateProfile])
        )
        let a = entry(alex, in: list)!
        XCTAssertEqual(a.statusLine(now: now, timeZone: utc), "On now · until \(WhosIn.time(now.addingTimeInterval(1800), timeZone: utc))")
        XCTAssertEqual(
            a.spokenLabel(now: now, timeZone: utc),
            "Alex, on now until \(WhosIn.time(now.addingTimeInterval(1800), timeZone: utc)), says Halo on Xbox, from their check-in"
        )
        XCTAssertTrue(entry(sam, in: list)!.statusLine(now: now, timeZone: utc).hasPrefix("Later · around "))
        XCTAssertEqual(entry(jordan, in: list)?.steamNote, "Steam profile private")
        XCTAssertTrue(entry(jordan, in: list)!.spokenLabel(now: now).hasSuffix("Steam profile private"))
        XCTAssertEqual(entry(viewer, in: entries([]))?.statusLine(now: now), "You haven't checked in")
        for item in list {
            XCTAssertFalse(item.spokenLabel(now: now).lowercased().contains("online"), item.spokenLabel(now: now))
        }
    }

    func testTimeReadsTheSameEverywhere() {
        XCTAssertEqual(WhosIn.time(Date(timeIntervalSince1970: 0), timeZone: utc), "12:00 AM")
        XCTAssertEqual(WhosIn.time(Date(timeIntervalSince1970: 21 * 3600 + 40 * 60), timeZone: utc), "9:40 PM")
    }

    func testSourcesFooterIsHonestAboutEachSource() {
        XCTAssertEqual(WhosIn.checkInSource(.unknown), "Check-ins: not set up on this server.")
        XCTAssertTrue(WhosIn.checkInSource(basic).contains("Honor system"))
        XCTAssertTrue(WhosIn.checkInSource(full).contains("game and console"))
        XCTAssertEqual(WhosIn.steamSource(.notSetUp), "Steam: not set up on this server yet.")
        XCTAssertTrue(WhosIn.steamSource(.members([:])).contains("PC only"))
        XCTAssertTrue(WhosIn.xboxSource.contains("no presence"))
    }

    func testLoadStatesKeepEarlierRows() {
        XCTAssertEqual(WhosInLoad.loading.display(hasData: false), .loading)
        XCTAssertNil(WhosInLoad.loading.display(hasData: true))
        XCTAssertEqual(WhosInLoad.failed("x").display(hasData: true), .stale)
        XCTAssertEqual(WhosInLoad.failed("x").display(hasData: false), .failed("x"))
        XCTAssertNil(WhosInLoad.loaded.display(hasData: false))
        XCTAssertEqual(WhosInLoad.failure(BackendFailure.reconnecting), .failed("Who's in couldn't load. Check your connection."))
    }

    // MARK: The header strip

    func testStripStatusesComeFromCheckInsOnceTheServerHasThem() {
        let map = WhosIn.availabilityByMember(
            checkIns: [record(alex, .availableNow, until: 600), record(jordan, .availableLater, until: 3600), record(sam, .unavailable)],
            squadId: squad, caps: basic, now: now
        )
        let strip = SquadPresence.entries(members: members, ownerId: viewer, viewerId: viewer, spot: nil, now: now, availability: map)
        XCTAssertEqual(strip.map(\.status), [.availableNow, .later, .you, .cantPlay], "Sam's can't play sorts last")
        XCTAssertEqual(strip.first?.spokenLabel, "Alex, on now, from their check-in, usually plays Warzone")
        XCTAssertEqual(SquadPresence.whosInPill(strip), "Who's in · 1")
        XCTAssertEqual(SquadPresence.whosInSpoken(strip), "Who's in, 1 on")
        XCTAssertFalse(SquadPresence.hasUntracked(strip))

        let empty = SquadPresence.entries(members: members, ownerId: viewer, viewerId: viewer, spot: nil, now: now, availability: [:])
        XCTAssertEqual(Set(empty.filter { !$0.isViewer }.map(\.status)), [.notCheckedIn])
        XCTAssertEqual(SquadPresence.whosInPill(empty), "Who's in")

        let untracked = SquadPresence.entries(members: members, ownerId: viewer, viewerId: viewer, spot: nil, now: now, availability: nil)
        XCTAssertTrue(SquadPresence.hasUntracked(untracked), "No check-ins on the server keeps the old honest line")
    }

    func testEveryStripStatusAvoidsOnline() {
        for status in SquadPresenceStatus.allCases {
            XCTAssertFalse(status.spoken.lowercased().contains("online"), "\(status)")
        }
        XCTAssertEqual(SquadPresenceStatus.notCheckedIn.spoken, "hasn't checked in")
        XCTAssertEqual(SquadPresence.moreLabel(2), "2 more in Who's in")
    }

    // MARK: Mock server

    func testMockServerStampsTheWindowAndDropsDetailsItDoesntHave() async throws {
        let mock = await MockCheckInService(caps: basic)
        await MainActor.run { mock.clock = { self.now } }
        let saved = try await mock.save(CheckInWrite(userId: viewer, squadId: squad, kind: .availableNow, untilAt: nil, game: "Halo", platform: .pc, includesDetails: false))
        XCTAssertEqual(saved?.untilAt, now.addingTimeInterval(3600))
        XCTAssertNil(saved?.game)
        do {
            _ = try await mock.save(CheckInWrite(userId: viewer, squadId: squad, kind: .availableLater, untilAt: now.addingTimeInterval(30), game: nil, platform: nil, includesDetails: false))
            XCTFail("A later time under a minute out should be refused")
        } catch let problem as CheckInProblem {
            XCTAssertEqual(problem, .rejected("Pick a time between a few minutes and 7 days from now."))
        }
        try await mock.clear(userId: viewer, squadId: squad)
        let rows = try await mock.checkIns(squadId: squad)
        XCTAssertTrue(rows.isEmpty)
    }

    func testMockReadsFailUntilRecovered() async throws {
        let mock = await MockCheckInService(rows: [record(alex, .availableNow, until: 600)], readsDown: true)
        do {
            _ = try await mock.checkIns(squadId: squad)
            XCTFail("Reads should fail while down")
        } catch {}
        await mock.recover()
        let rows = try await mock.checkIns(squadId: squad)
        XCTAssertEqual(rows.count, 1)
    }

    // MARK: Live service, scripted HTTP

    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")

    func testCapabilitiesSayNotSetUpOnlyWhenTheTableIsMissing() async throws {
        let missing = ScriptedTransport(responses: [(404, Data(#"{"code":"PGRST205","message":"Could not find the table 'public.sq8_check_ins' in the schema cache"}"#.utf8))])
        let none = try await SupabaseCheckInService(config: config, accessToken: "t", transport: missing).capabilities()
        XCTAssertEqual(none, .unknown)

        let live = ScriptedTransport(responses: [
            (200, Data("[]".utf8)),
            (400, Data(#"{"code":"42703","message":"column sq8_check_ins.game does not exist"}"#.utf8))
        ])
        let today = try await SupabaseCheckInService(config: config, accessToken: "t", transport: live).capabilities()
        XCTAssertEqual(today, CheckInCapabilities(table: true, details: false), "Live today: 0006 without proposed 0022")
        XCTAssertEqual(live.requests.count, 2)
        XCTAssertTrue(live.requests.allSatisfy { $0.httpMethod == "GET" }, "Probes are read-only")

        let down = FailingTransport()
        do {
            _ = try await SupabaseCheckInService(config: config, accessToken: "t", transport: down).capabilities()
            XCTFail("A network failure must not read as not set up")
        } catch let failure as BackendFailure {
            XCTAssertEqual(failure, .reconnecting)
        }
    }

    func testReadSelectsOnlyColumnsTheServerHas() async throws {
        let transport = ScriptedTransport(responses: [(200, Data("[]".utf8))])
        let service = SupabaseCheckInService(config: config, accessToken: "t", transport: transport, knownDetails: false)
        let rows = try await service.checkIns(squadId: squad)
        XCTAssertTrue(rows.isEmpty)
        let query = URLComponents(url: try XCTUnwrap(transport.requests.first?.url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertEqual(query.first { $0.name == "select" }?.value, "user_id,squad_id,kind,checked_at,until_at")
        XCTAssertEqual(query.first { $0.name == "squad_id" }?.value, "eq.\(squad.uuidString)")
    }

    func testSaveUpsertsYourOwnRowAndExplainsRefusals() async throws {
        let stored = """
        [{"user_id":"\(viewer.uuidString)","squad_id":"\(squad.uuidString)","kind":"available_now","checked_at":"2027-01-15T08:00:00Z","until_at":"2027-01-15T09:00:00Z"}]
        """
        let transport = ScriptedTransport(responses: [(201, Data(stored.utf8))])
        let service = SupabaseCheckInService(config: config, accessToken: "t", transport: transport, knownDetails: false)
        let saved = try await service.save(CheckInWrite(userId: viewer, squadId: squad, kind: .availableNow, untilAt: nil, game: nil, platform: nil, includesDetails: false))
        XCTAssertEqual(saved?.kind, .availableNow)
        let request = try XCTUnwrap(transport.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Prefer"), "resolution=merge-duplicates,return=representation")
        XCTAssertTrue(request.url?.absoluteString.contains("on_conflict=user_id") ?? false)

        let refusing = ScriptedTransport(responses: [(400, Data(#"{"code":"23514","message":"sq8_check_in_later_invalid"}"#.utf8))])
        do {
            _ = try await SupabaseCheckInService(config: config, accessToken: "t", transport: refusing)
                .save(CheckInWrite(userId: viewer, squadId: squad, kind: .availableLater, untilAt: now, game: nil, platform: nil, includesDetails: false))
            XCTFail("The refusal should surface")
        } catch let problem as CheckInProblem {
            XCTAssertEqual(problem, .rejected("Pick a time between a few minutes and 7 days from now."))
        }
    }

    func testSteamReadIsNotSetUpWhenTheFunctionIsntDeployed() async {
        let transport = ScriptedTransport(responses: [(404, Data(#"{"code":"NOT_FOUND","message":"Requested function was not found"}"#.utf8))])
        let read = await SupabaseCheckInService(config: config, accessToken: "t", transport: transport).steam()
        XCTAssertEqual(read, .notSetUp)
        XCTAssertEqual(transport.requests.first?.url?.path, "/functions/v1/sq8-steam-presence")
        let broken = ScriptedTransport(responses: [(500, Data(#"{"message":"boom"}"#.utf8))])
        let failed = await SupabaseCheckInService(config: config, accessToken: "t", transport: broken).steam()
        XCTAssertEqual(failed, .failed)
    }
}

/// Every request fails as if offline.
final class FailingTransport: HTTPTransport, @unchecked Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        throw URLError(.notConnectedToInternet)
    }
}

/// Who's in through the session model on the mock backend: each scenario's
/// sources, checking in and clearing, the failed read and Retry, and a server
/// without check-ins.
@MainActor
final class WhosInModelTests: XCTestCase {
    private func model(_ scenario: LaunchScenario) -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: scenario
        )
    }

    func testFullScenarioShowsEverySourceWithItsLabel() async {
        let model = model(.whosIn)
        await model.loadWhosIn(includeSteam: true)
        XCTAssertEqual(model.whosInLoad, .loaded)
        XCTAssertEqual(model.checkInCaps, CheckInCapabilities(table: true, details: true))
        let entries = model.whosInEntries(now: Date())
        let alex = entries.first { $0.id == SpotSeed.alex }
        XCTAssertEqual(alex?.gameSource, .checkIn(.xbox))
        XCTAssertEqual(alex?.gameLine, "Halo Infinite · Xbox")
        let jordan = entries.first { $0.id == SpotSeed.jordan }
        XCTAssertEqual(jordan?.gameSource, .steam)
        XCTAssertEqual(jordan?.game, "Counter-Strike 2")
        let casey = entries.first { $0.id == SpotSeed.casey }
        XCTAssertEqual(casey?.availability, .cantPlay)
        XCTAssertEqual(casey?.steamNote, "Steam profile private")
        let strip = model.presenceEntries(now: Date())
        XCTAssertEqual(strip.first { $0.id == SpotSeed.alex }?.status, .availableNow)
    }

    func testBasicScenarioChecksInWithoutGameOrConsole() async {
        let model = model(.whosInBasic)
        await model.loadWhosIn(includeSteam: true)
        XCTAssertEqual(model.checkInCaps, CheckInCapabilities(table: true, details: false))
        XCTAssertEqual(model.steam, .notSetUp)
        XCTAssertEqual(model.myAvailability(now: Date()), .notCheckedIn)
        model.checkInGame = "Halo"
        await model.checkIn(.availableNow)
        guard case .now = model.myAvailability(now: Date()) else {
            return XCTFail("On now didn't take: \(model.myAvailability(now: Date()))")
        }
        let mine = model.whosInEntries(now: Date()).first { $0.isViewer }
        XCTAssertEqual(mine?.gameSource, .profile, "This server doesn't keep the typed game")
        XCTAssertEqual(model.checkInError, "")
        await model.clearCheckIn()
        XCTAssertEqual(model.myAvailability(now: Date()), .notCheckedIn)
    }

    func testLaterNeedsATimeAndTheServerKeepsIt() async {
        let model = model(.whosIn)
        await model.loadWhosIn()
        await model.checkIn(.availableLater)
        XCTAssertEqual(model.myAvailability(now: Date()), .notCheckedIn, "Later without a time sends nothing")
        let at = Date().addingTimeInterval(3600)
        model.checkInGame = " Rocket League "
        model.checkInPlatform = .pc
        await model.checkIn(.availableLater, laterAt: at)
        XCTAssertEqual(model.myAvailability(now: Date()), .later(at: at))
        let mine = model.whosInEntries(now: Date()).first { $0.isViewer }
        XCTAssertEqual(mine?.gameLine, "Rocket League · PC")
    }

    func testFailedReadSaysSoAndRetryLoads() async {
        let model = model(.whosInFailed)
        await model.loadWhosIn()
        XCTAssertEqual(model.whosInLoad.display(hasData: !model.checkIns.isEmpty), .failed("Who's in couldn't load. The server didn't answer."))
        await model.retryWhosIn()
        XCTAssertEqual(model.whosInLoad, .loaded)
        XCTAssertFalse(model.checkIns.isEmpty)
    }

    func testServerWithoutCheckInsStaysUntracked() async {
        let model = model(.whosInNoServer)
        await model.loadWhosIn(includeSteam: true)
        XCTAssertFalse(model.checkInCaps.table)
        XCTAssertEqual(model.myAvailability(now: Date()), .untracked)
        XCTAssertTrue(SquadPresence.hasUntracked(model.presenceEntries(now: Date())))
        await model.checkIn(.availableNow)
        XCTAssertTrue(model.checkIns.isEmpty, "Nothing is written to a server without the table")
    }

    func testOtherScenariosLookLikeLiveToday() async {
        let model = model(.invite)
        XCTAssertEqual(model.presenceEntries(now: Date()).map(\.status), [.you, .unknown], "Before the probe nothing is claimed")
        await model.loadWhosIn()
        XCTAssertEqual(model.presenceEntries(now: Date()).map(\.status), [.you, .notCheckedIn])
        let empty = self.model(.whosInEmpty)
        await empty.loadWhosIn()
        XCTAssertTrue(empty.whosInEntries(now: Date()).allSatisfy(\.isViewer))
    }
}
