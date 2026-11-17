import XCTest
@testable import SquadSync

@MainActor
final class SquadHomeTests: XCTestCase {
    private let viewer = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let riley = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let alex = UUID(uuidString: "00000000-0000-0000-0000-00000000B011")!
    private let jordan = UUID(uuidString: "00000000-0000-0000-0000-00000000B012")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-00000000B013")!
    private let squadId = UUID(uuidString: "00000000-0000-0000-0000-000000000010")!
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func member(_ id: UUID, _ name: String, game: String = "", owner: Bool = false) -> SquadMemberRecord {
        SquadMemberRecord(id: id, displayName: name, defaultGame: game, isOwner: owner)
    }

    private func spot(
        status: SpotCallStatus = .open,
        joinUntil: Date? = nil,
        seats: [SpotRsvp]
    ) -> SpotCall {
        SpotCall(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!,
            squadId: squadId,
            callerId: alex,
            game: "Warzone",
            calledAt: now.addingTimeInterval(-60),
            joinUntil: joinUntil ?? now.addingTimeInterval(240),
            lockedAt: status == .locked ? now.addingTimeInterval(-10) : nil,
            closedAt: nil,
            status: status,
            rsvps: seats
        )
    }

    private func seat(_ id: UUID, _ name: String, response: String = "in", ready: Bool = false) -> SpotRsvp {
        SpotRsvp(userId: id, name: name, response: response, starter: false, ready: ready)
    }

    // MARK: Status mapping

    func testStatusWithNoSpotIsYouForTheViewerAndUnknownForEveryoneElse() {
        XCTAssertEqual(SquadPresence.status(memberId: viewer, viewerId: viewer, spot: nil, now: now), .you)
        XCTAssertEqual(SquadPresence.status(memberId: riley, viewerId: viewer, spot: nil, now: now), .unknown)
        XCTAssertEqual(SquadPresence.status(memberId: riley, viewerId: nil, spot: nil, now: now), .unknown)
    }

    func testOpenSpotSeatsMapToReadyAndInSpot() {
        let call = spot(seats: [seat(alex, "Alex", ready: true), seat(jordan, "Jordan"), seat(sam, "Sam", response: "out")])
        XCTAssertEqual(SquadPresence.status(memberId: alex, viewerId: viewer, spot: call, now: now), .ready)
        XCTAssertEqual(SquadPresence.status(memberId: jordan, viewerId: viewer, spot: call, now: now), .inSpot)
        XCTAssertEqual(SquadPresence.status(memberId: sam, viewerId: viewer, spot: call, now: now), .unknown, "An out RSVP is not a seat")
    }

    func testSeatedViewerShowsTheSeatNotYou() {
        let call = spot(seats: [seat(viewer, "You", ready: true)])
        XCTAssertEqual(SquadPresence.status(memberId: viewer, viewerId: viewer, spot: call, now: now), .ready)
    }

    func testExpiredOrClosedSpotNoLongerCountsAsPresence() {
        let past = spot(joinUntil: now.addingTimeInterval(-1), seats: [seat(alex, "Alex", ready: true)])
        XCTAssertEqual(SquadPresence.status(memberId: alex, viewerId: viewer, spot: past, now: now), .unknown)
        let expired = spot(status: .expired, seats: [seat(alex, "Alex")])
        XCTAssertEqual(SquadPresence.status(memberId: alex, viewerId: viewer, spot: expired, now: now), .unknown)
        let ended = spot(status: .ended, seats: [seat(alex, "Alex")])
        XCTAssertEqual(SquadPresence.status(memberId: alex, viewerId: viewer, spot: ended, now: now), .unknown)
        let cancelled = spot(status: .cancelled, seats: [seat(viewer, "You")])
        XCTAssertEqual(SquadPresence.status(memberId: viewer, viewerId: viewer, spot: cancelled, now: now), .you)
    }

    func testLockedSpotSeatsAreLockedIn() {
        let call = spot(status: .locked, joinUntil: now.addingTimeInterval(-30), seats: [seat(alex, "Alex", ready: true), seat(jordan, "Jordan")])
        XCTAssertEqual(SquadPresence.status(memberId: alex, viewerId: viewer, spot: call, now: now), .locked)
        XCTAssertEqual(SquadPresence.status(memberId: jordan, viewerId: viewer, spot: call, now: now), .locked)
    }

    func testUnknownNeverReadsAsOnline() {
        XCTAssertEqual(SquadPresenceStatus.unknown.shortLabel, "")
        XCTAssertEqual(SquadPresenceStatus.unknown.spoken, "presence isn't tracked yet")
        for status in SquadPresenceStatus.allCases {
            XCTAssertFalse(status.shortLabel.lowercased().contains("online"), "\(status) claims online")
            XCTAssertFalse(status.spoken.lowercased().contains("online"), "\(status) claims online")
        }
    }

    // MARK: Ordering

    func testStripOrdersByStatusThenOwnerThenName() {
        let members = [
            member(riley, "riley"),
            member(sam, "Sam"),
            member(viewer, "You", game: "Call of Duty", owner: true),
            member(jordan, "Jordan"),
            member(alex, "Alex", game: "Warzone")
        ]
        let call = spot(seats: [seat(jordan, "Jordan"), seat(alex, "Alex", ready: true)])
        let entries = SquadPresence.entries(members: members, ownerId: viewer, viewerId: viewer, spot: call, now: now)
        XCTAssertEqual(entries.map(\.name), ["Alex", "Jordan", "You", "riley", "Sam"])
        XCTAssertEqual(entries.map(\.status), [.ready, .inSpot, .you, .unknown, .unknown])
    }

    func testOwnerSortsFirstWithinTheSameStatus() {
        let members = [
            member(alex, "Alex"),
            member(riley, "Zed", owner: true),
            member(sam, "Bea")
        ]
        let entries = SquadPresence.entries(members: members, ownerId: riley, viewerId: nil, spot: nil, now: now)
        XCTAssertEqual(entries.map(\.name), ["Zed", "Alex", "Bea"])
        XCTAssertTrue(entries[0].isOwner)
    }

    func testOwnerIdMarksTheOwnerEvenWhenTheRowFlagIsMissing() {
        let entries = SquadPresence.entries(members: [member(alex, "Alex"), member(riley, "Riley")], ownerId: riley, viewerId: nil, spot: nil, now: now)
        XCTAssertEqual(entries.first?.name, "Riley")
        XCTAssertEqual(entries.first?.isOwner, true)
    }

    func testEqualNamesFallBackToIdSoTheOrderIsStable() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!
        let entries = SquadPresence.entries(
            members: [member(second, "Sam"), member(first, "sam")],
            ownerId: nil,
            viewerId: nil,
            spot: nil,
            now: now
        )
        XCTAssertEqual(entries.map(\.id), [first, second])
    }

    func testEmptySquadHasNoEntries() {
        XCTAssertTrue(SquadPresence.entries(members: [], ownerId: nil, viewerId: viewer, spot: nil, now: now).isEmpty)
    }

    // MARK: Game line

    func testGameComesFromTheSpotWhenSeatedAndFromTheProfileOtherwise() {
        let members = [member(alex, "Alex", game: "Apex"), member(riley, "Riley", game: "  Halo  "), member(sam, "Sam")]
        let call = spot(seats: [seat(alex, "Alex")])
        let entries = SquadPresence.entries(members: members, ownerId: nil, viewerId: nil, spot: call, now: now)
        let byName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })
        XCTAssertEqual(byName["Alex"]?.game, "Warzone")
        XCTAssertEqual(byName["Alex"]?.gameSource, .spot)
        XCTAssertEqual(byName["Alex"]?.gameCaption, "Warzone")
        XCTAssertEqual(byName["Riley"]?.game, "Halo")
        XCTAssertEqual(byName["Riley"]?.gameSource, .profileDefault)
        XCTAssertEqual(byName["Riley"]?.gameCaption, "Usually Halo")
        XCTAssertNil(byName["Sam"]?.game)
        XCTAssertNil(byName["Sam"]?.gameCaption)
    }

    func testBlankNameShowsPlayerAndAnInitial() {
        let entries = SquadPresence.entries(members: [member(alex, "   ")], ownerId: nil, viewerId: nil, spot: nil, now: now)
        XCTAssertEqual(entries.first?.name, "Player")
        XCTAssertEqual(entries.first?.initial, "P")
        let lower = SquadPresenceEntry(id: alex, name: "riley", status: .unknown, game: nil, gameSource: nil, isOwner: false, isViewer: false)
        XCTAssertEqual(lower.initial, "R")
    }

    func testSpokenLabelSaysPresenceIsNotTracked() {
        let entries = SquadPresence.entries(members: [member(riley, "Riley", game: "Halo")], ownerId: nil, viewerId: viewer, spot: nil, now: now)
        XCTAssertEqual(entries.first?.spokenLabel, "Riley, presence isn't tracked yet, usually plays Halo")
        XCTAssertTrue(SquadPresence.hasUntracked(entries))
        let mine = SquadPresence.entries(members: [member(viewer, "You", owner: true)], ownerId: viewer, viewerId: viewer, spot: nil, now: now)
        XCTAssertEqual(mine.first?.spokenLabel, "You, owner")
        XCTAssertFalse(SquadPresence.hasUntracked(mine))
    }

    // MARK: Header title

    func testHeaderTitleFallsBackWhenTheNameIsNullOrBlank() {
        XCTAssertEqual(SquadHeader.title(name: nil), "Your squad")
        XCTAssertEqual(SquadHeader.title(name: ""), "Your squad")
        XCTAssertEqual(SquadHeader.title(name: "   \n"), "Your squad")
        XCTAssertEqual(SquadHeader.title(name: "  Friday "), "Friday")
    }

    func testHeaderTitleForSquadsAndNoSquad() {
        XCTAssertEqual(SquadHeader.title(squad: nil), "SquadSync")
        let unnamed = SquadRecord(id: squadId, ownerId: viewer, name: "", members: [member(viewer, "You", owner: true)])
        XCTAssertEqual(SquadHeader.title(squad: unnamed), "Your squad")
        XCTAssertEqual(SquadHeader.detail(squad: unnamed), "1 of 8")
        XCTAssertEqual(SquadHeader.spoken(squad: unnamed), "Your squad · 1 of 8")
        let named = SquadRecord(id: squadId, ownerId: viewer, name: "Friday", members: [member(viewer, "You", owner: true), member(riley, "Riley")])
        XCTAssertEqual(SquadHeader.title(squad: named), "Friday")
        XCTAssertEqual(SquadHeader.spoken(squad: named), "Friday · 2 of 8", "The squad-title identifier keeps the old label the UI tests read")
        XCTAssertNil(SquadHeader.spoken(squad: nil))
        XCTAssertEqual(SquadHeader.detail(squad: nil), "Not in a squad yet")
    }

    // MARK: Voice pill (mock)

    func testVoicePillSaysItIsAMock() {
        var pill = VoicePillState()
        XCTAssertEqual(pill.title, "Voice")
        XCTAssertTrue(pill.spoken.contains("mock"))
        XCTAssertTrue(pill.spoken.contains("Nobody is in it."))
        pill.joined = true
        pill.count = 1
        pill.connection = .connected
        XCTAssertEqual(pill.title, "In voice · 1")
        XCTAssertTrue(pill.spoken.contains("1 person is in it."))
        pill.connection = .failed("x")
        XCTAssertEqual(pill.title, "Voice · failed")
    }

    func testMockModelVoiceToggleUsesTheInMemoryRoom() async {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .invite
        )
        XCTAssertFalse(model.voicePill.joined)
        await model.toggleVoice()
        let joined = model.voicePill.joined
        let count = model.voicePill.count
        XCTAssertTrue(joined)
        XCTAssertEqual(count, 1)
        await model.toggleVoice()
        let left = model.voicePill.joined
        XCTAssertFalse(left)
        XCTAssertEqual(model.voicePill.connection, .idle)
    }

    func testMockModelPresenceEntriesComeFromTheSquad() {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .invite
        )
        let entries = model.presenceEntries(now: now)
        XCTAssertEqual(entries.map(\.name), ["You", "Riley"])
        XCTAssertEqual(entries.map(\.status), [.you, .unknown])
    }

    // MARK: Haptics

    func testHapticsAreANoOpUnderTests() {
        XCTAssertFalse(SQHaptics.isEnabled)
        XCTAssertFalse(SQHaptics.play(.tap))
        XCTAssertFalse(SQHaptics.play(.success))
        XCTAssertTrue(SQHaptics.isEnabled(environment: [:]))
        XCTAssertFalse(SQHaptics.isEnabled(environment: ["XCTestConfigurationFilePath": "/tmp/x"]))
    }
}
