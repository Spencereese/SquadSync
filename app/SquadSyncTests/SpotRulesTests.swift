import XCTest
@testable import SquadSync

final class SpotRulesTests: XCTestCase {
    private func person(
        id: String = "p",
        role: Role = .member,
        inGame: Bool = false,
        starter: Bool = false
    ) -> Person {
        Person(
            id: id,
            name: id,
            role: role,
            availability: .upToPlay,
            game: inGame ? "Warzone" : nil,
            inVoice: false,
            isSpeaking: false,
            isStarter: starter
        )
    }

    private func party(calledAt: Date, seats: [Seat] = [], locked: Bool = false, size: Int = 4) -> Party {
        Party(
            id: "party",
            game: "Warzone",
            targetSize: size,
            callerId: "caller",
            calledAt: calledAt,
            seats: seats,
            locked: locked
        )
    }

    func testCountdownNeverExceedsFiveMinutes() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let skewed = party(calledAt: now.addingTimeInterval(207))
        XCTAssertEqual(SpotRules.remaining(skewed, now: now), SpotRules.joinWindow)
        XCTAssertEqual(SpotRules.countdownText(skewed, now: now), "5:00")
        let fresh = party(calledAt: now)
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now), "5:00")
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now.addingTimeInterval(90)), "3:30")
        XCTAssertEqual(SpotRules.countdownText(fresh, now: now.addingTimeInterval(301)), "0:00")
    }

    func testWindowClosesForEveryoneExceptInGameStarters() {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let open = party(calledAt: start)
        let later = start.addingTimeInterval(SpotRules.joinWindow + 1)
        let regular = person(id: "regular")
        let starter = person(id: "starter", inGame: true, starter: true)
        XCTAssertTrue(SpotRules.canJoin(party: open, person: regular, now: start.addingTimeInterval(10)))
        XCTAssertFalse(SpotRules.canJoin(party: open, person: regular, now: later))
        XCTAssertTrue(SpotRules.canJoin(party: open, person: starter, now: later))
        XCTAssertTrue(SpotRules.isStarterExempt(starter))
        XCTAssertFalse(SpotRules.isStarterExempt(person(id: "online-starter", starter: true)))
    }

    func testReadyThenLockRequiresTheCallerOrOwnerAndTheTarget() {
        var card = party(calledAt: Date(), seats: [
            Seat(userId: "a", status: .ready),
            Seat(userId: "b", status: .in)
        ], size: 2)
        let caller = person(id: "caller", role: .member)
        let owner = person(id: "owner", role: .owner)
        let member = person(id: "member")
        XCTAssertFalse(SpotRules.canLock(party: card, actor: caller))
        XCTAssertTrue(SpotRules.markReady(party: &card, personId: "b"))
        XCTAssertFalse(SpotRules.markReady(party: &card, personId: "missing"))
        XCTAssertFalse(SpotRules.canLock(party: card, actor: member))
        XCTAssertTrue(SpotRules.canLock(party: card, actor: caller))
        XCTAssertTrue(SpotRules.lock(party: &card, actor: owner))
        XCTAssertTrue(card.locked)
        XCTAssertFalse(SpotRules.canJoin(party: card, person: member, now: Date()))
    }

    func testCapOfEightBlocksANinthMemberButNotAGuest() {
        XCTAssertFalse(SpotRules.canAddToSquad(memberCount: 8, role: .member))
        XCTAssertTrue(SpotRules.canAddToSquad(memberCount: 7, role: .member))
        XCTAssertTrue(SpotRules.canAddToSquad(memberCount: 8, role: .guest))
        var full = party(
            calledAt: Date(),
            seats: (0..<8).map { Seat(userId: "s\($0)", status: .in) },
            size: 8
        )
        XCTAssertFalse(SpotRules.canJoin(party: full, person: person(id: "ninth"), now: Date()))
        XCTAssertEqual(SpotRules.filled(full), 8)
        _ = SpotRules.lock(party: &full, actor: person(id: "caller", role: .owner))
    }

    func testGuestsOnlySeeGroupsTheyWereAddedTo() {
        let guest = person(id: "riley", role: .guest)
        let member = person(id: "spencer", role: .owner)
        let threads = [
            Conversation(id: "space", title: "The Eight", kind: .squadSpace, parentId: nil, participantIds: ["spencer"], guestIds: [], unread: 0, folded: true),
            Conversation(id: "general", title: "#general", kind: .channel, parentId: "space", participantIds: ["spencer"], guestIds: [], unread: 0, folded: true),
            Conversation(id: "friday", title: "Friday crew", kind: .sideGroup, parentId: nil, participantIds: ["spencer", "riley"], guestIds: ["riley"], unread: 0, folded: false),
            Conversation(id: "dm", title: "Riley", kind: .dm, parentId: nil, participantIds: ["spencer", "riley"], guestIds: ["riley"], unread: 0, folded: false)
        ]
        let seen = SpotRules.visibleConversations(viewer: guest, conversations: threads).map(\.id)
        XCTAssertEqual(seen, ["friday", "dm"])
        XCTAssertEqual(SpotRules.visibleConversations(viewer: member, conversations: threads).count, 4)
    }
}

final class SpotCallRulesTests: XCTestCase {
    private let owner = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let caller = UUID(uuidString: "00000000-0000-0000-0000-00000000B011")!
    private let starter = UUID(uuidString: "00000000-0000-0000-0000-00000000B012")!
    private let member = UUID(uuidString: "00000000-0000-0000-0000-00000000B013")!
    private let start = Date(timeIntervalSince1970: 1_700_000_000)

    private func call(status: SpotCallStatus = .open, joinUntil: Date? = nil, rsvps: [SpotRsvp]? = nil) -> SpotCall {
        SpotCall(
            id: SpotSeed.callId,
            squadId: ChatSeed.squadId,
            callerId: caller,
            game: "Warzone",
            calledAt: start,
            joinUntil: joinUntil ?? start.addingTimeInterval(SpotCallRules.window),
            lockedAt: status == .locked ? start : nil,
            closedAt: status == .ended || status == .cancelled ? start : nil,
            status: status,
            rsvps: rsvps ?? [
                SpotRsvp(userId: caller, name: "Alex", response: "in", starter: false, ready: false)
            ]
        )
    }

    func testCountdownUsesTheServerDeadlineAndClampsAtFiveMinutes() {
        let fresh = start.addingTimeInterval(SpotCallRules.window)
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start), "5:00")
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start.addingTimeInterval(90)), "3:30")
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: fresh, now: start.addingTimeInterval(301)), "0:00")
        let skewed = start.addingTimeInterval(8 * 60)
        XCTAssertEqual(SpotCallRules.remaining(joinUntil: skewed, now: start), SpotCallRules.window)
    }

    func testStartersCanJoinAfterTheWindowAndOthersCannot() {
        let open = call()
        let later = start.addingTimeInterval(SpotCallRules.window + 1)
        var expired = open
        expired.joinUntil = start
        XCTAssertTrue(SpotCallRules.canJoin(open, userId: member, now: start.addingTimeInterval(10)))
        XCTAssertFalse(SpotCallRules.canJoin(expired, userId: member, now: later))
        var seated = expired
        seated.rsvps.append(SpotRsvp(userId: member, name: "Sam", response: "out", starter: true, ready: false))
        XCTAssertTrue(SpotCallRules.canJoin(seated, userId: member, now: later))
        XCTAssertTrue(SpotCallRules.showsExpired(expired, now: later))
        XCTAssertEqual(expired.status, .open)
    }

    func testLockIsCallerOrOwnerAndDoesNotRequireReady() {
        let open = call()
        XCTAssertTrue(SpotCallRules.canLock(open, actorId: caller, ownerId: owner, now: start))
        XCTAssertTrue(SpotCallRules.canLock(open, actorId: owner, ownerId: owner, now: start))
        XCTAssertFalse(SpotCallRules.canLock(open, actorId: member, ownerId: owner, now: start))
        XCTAssertFalse(SpotCallRules.canLock(call(status: .cancelled), actorId: caller, ownerId: owner, now: start))
        XCTAssertFalse(SpotCallRules.everyoneReady(open))
        var full = open
        full.rsvps = (0..<8).map { index in
            SpotRsvp(
                userId: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(index)")!,
                name: "P\(index)",
                response: "in",
                starter: false,
                ready: true
            )
        }
        XCTAssertTrue(SpotCallRules.everyoneReady(full))
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_full").message, "That spot call is full (8).")
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_join_closed"), .joinClosed)
    }

    func testExpiredOpenCallHidesJoinAndLock() {
        var card = call()
        card.joinUntil = start
        let now = start.addingTimeInterval(1)
        XCTAssertEqual(card.status, .open)
        XCTAssertNil(card.closedAt)
        XCTAssertTrue(SpotCallRules.showsExpired(card, now: now))
        XCTAssertEqual(SpotCallRules.countdown(joinUntil: card.joinUntil, now: now), "0:00")
        XCTAssertFalse(SpotCallRules.canJoin(card, userId: member, now: now))
        XCTAssertFalse(SpotCallRules.canLock(card, actorId: caller, ownerId: owner, now: now))
        XCTAssertFalse(SpotCallRules.canLock(card, actorId: owner, ownerId: owner, now: now))
        XCTAssertFalse(SpotCallRules.canCancel(card, actorId: caller, now: now))
        XCTAssertFalse(SpotCallRules.showsPinnedBar(card, now: now))
        XCTAssertNil(SpotCallRules.barAction(card, viewerId: caller, ownerId: owner, now: now))
        XCTAssertNil(SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: now))
        let open = call()
        XCTAssertTrue(SpotCallRules.canCancel(open, actorId: caller, now: start))
        XCTAssertEqual(SpotCallRules.barAction(open, viewerId: member, ownerId: owner, now: start), .join)
    }

    func testASecondSpotActionDoesNotStart() {
        var gate = SpotActionGate()
        XCTAssertTrue(gate.begin())
        XCTAssertFalse(gate.begin())
        gate.finish()
        XCTAssertTrue(gate.begin())
    }

    func testResumeAfterTheJoinWindowExpiresTheCall() {
        let card = call()
        let staleTimeline = card.joinUntil.addingTimeInterval(-30)
        let resumed = card.joinUntil.addingTimeInterval(5)
        let now = SpotClock.now(timeline: staleTimeline, resumedAt: resumed)
        XCTAssertTrue(SpotCallRules.showsExpired(card, now: now))
        XCTAssertFalse(SpotCallRules.showsPinnedBar(card, now: now))
        XCTAssertFalse(SpotCallRules.canLock(card, actorId: caller, ownerId: owner, now: now))
        XCTAssertFalse(SpotCallRules.canCancel(card, actorId: caller, now: now))
    }

    func testResumeTrustsAnExpiredStatusWhenThePhoneClockIsBehind() {
        var card = call()
        card.status = .expired
        card.serverOwnsExpiry = true
        let staleTimeline = card.joinUntil.addingTimeInterval(-120)
        let resumed = staleTimeline
        let now = SpotClock.now(timeline: staleTimeline, resumedAt: resumed)
        XCTAssertLessThan(now, card.joinUntil)
        XCTAssertTrue(SpotCallRules.showsExpired(card, now: now))
        XCTAssertFalse(SpotCallRules.canLock(card, actorId: caller, ownerId: owner, now: now))
        var stillOpen = call()
        stillOpen.serverOwnsExpiry = true
        let behind = stillOpen.joinUntil.addingTimeInterval(-10)
        XCTAssertFalse(SpotCallRules.showsExpired(stillOpen, now: behind))
        let ahead = stillOpen.joinUntil.addingTimeInterval(5)
        let localOnly = SpotClock.now(timeline: stillOpen.joinUntil.addingTimeInterval(-30), resumedAt: ahead)
        XCTAssertFalse(SpotCallRules.showsExpired(stillOpen, now: localOnly))
        stillOpen.serverOwnsExpiry = false
        XCTAssertTrue(SpotCallRules.showsExpired(stillOpen, now: localOnly))
    }

    func testStarterCanStillJoinAfterTheServerMarksTheCallExpired() {
        var card = call(status: .expired)
        card.serverOwnsExpiry = true
        card.rsvps.append(SpotRsvp(userId: member, name: "Sam", response: "out", starter: true, ready: false))
        XCTAssertTrue(SpotCallRules.canJoin(card, userId: member, now: start))
        XCTAssertFalse(SpotCallRules.canJoin(card, userId: owner, now: start))
        XCTAssertEqual(SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: start), .join)
        XCTAssertNil(SpotCallRules.barAction(card, viewerId: owner, ownerId: owner, now: start))
    }

    func testLockIsRejectedWhenNotReadyEvenIfTheSpotIsNotFull() {
        let now = start
        let card = SpotSeed.nearlyFull(ownerId: owner, squadId: ChatSeed.squadId, now: now)
        XCTAssertEqual(card.filled, 7)
        XCTAssertEqual(card.seatTarget, 8)
        XCTAssertFalse(SpotLockRule.allows(card))
        XCTAssertFalse(SpotCallRules.canLock(card, actorId: owner, ownerId: owner, now: now))
        var ready = card
        ready.rsvps = ready.rsvps.map { seat in
            var copy = seat
            copy.ready = true
            return copy
        }
        XCTAssertLessThan(ready.filled, ready.seatTotal)
        XCTAssertTrue(SpotLockRule.allows(ready))
        XCTAssertTrue(SpotCallRules.canLock(ready, actorId: owner, ownerId: owner, now: now))
        var full = ready
        full.seatTarget = 8
        full.rsvps.append(SpotRsvp(userId: member, name: "Extra", response: "in", starter: false, ready: false))
        XCTAssertEqual(full.filled, 8)
        XCTAssertFalse(SpotLockRule.allows(full))
        var nobody = card
        nobody.rsvps = []
        XCTAssertFalse(SpotLockRule.allows(nobody))
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_not_ready"), .notReady)
        XCTAssertEqual(SpotProblem.from(serverMessage: "spot_expired"), .expired)
    }

    func testReadyAndLeaveHideAfterThePhoneWindow() {
        var card = call()
        card.joinUntil = start
        card.rsvps = [SpotRsvp(userId: member, name: "Sam", response: "in", starter: true, ready: false)]
        let later = start.addingTimeInterval(1)
        XCTAssertNil(SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: later))
        card.rsvps[0].ready = true
        XCTAssertNil(SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: later))
        XCTAssertEqual(
            SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: start.addingTimeInterval(-10)),
            .leave
        )
        card.rsvps[0].ready = false
        XCTAssertEqual(
            SpotCallRules.barAction(card, viewerId: member, ownerId: owner, now: start.addingTimeInterval(-10)),
            .ready
        )
    }

    func testExpiryReadWaitsUntilJustAfterTheWindow() {
        let until = start.addingTimeInterval(60)
        let delay = SpotExpiryRead.delay(joinUntil: until, now: start)
        XCTAssertEqual(delay, 62)
        let almost = SpotExpiryRead.delay(joinUntil: until, now: until.addingTimeInterval(1))
        XCTAssertEqual(almost, 1)
        let due = SpotExpiryRead.delay(joinUntil: until, now: until.addingTimeInterval(2))
        XCTAssertNil(due)
    }

    func testDoubleTapSpotActionIsANoOp() {
        var gate = SpotActionGate()
        var ran = 0
        if gate.begin() { ran += 1 }
        if gate.begin() { ran += 1 }
        XCTAssertEqual(ran, 1)
        gate.finish()
        if gate.begin() { ran += 1 }
        XCTAssertEqual(ran, 2)
    }

    @MainActor
    func testReadyTogglePersistsAndASecondTapKeepsTheStoredValue() async throws {
        let squad = ChatSeed.squadId
        let card = SpotSeed.calledByViewer(ownerId: owner, squadId: squad, now: start)
        let service = MockSpotService(viewerId: owner, ownerId: owner, call: card)
        try await service.setReady(callId: card.id, userId: owner, ready: true)
        try await service.setReady(callId: card.id, userId: owner, ready: true)
        let stored = try await service.current(squadId: squad)
        let ready = stored?.seat(for: owner)?.ready
        XCTAssertEqual(ready, true)
        try await service.setReady(callId: card.id, userId: owner, ready: false)
        let cleared = try await service.current(squadId: squad)
        let again = cleared?.seat(for: owner)?.ready
        XCTAssertEqual(again, false)
    }

    @MainActor
    func testReadyResetsWhenOutIsFollowedByIn() async throws {
        let squad = ChatSeed.squadId
        let card = SpotSeed.calledByViewer(ownerId: owner, squadId: squad, now: start)
        let service = MockSpotService(viewerId: owner, ownerId: owner, call: card, now: { self.start })
        try await service.setReady(callId: card.id, userId: owner, ready: true)
        try await service.rsvp(callId: card.id, response: "in")
        let stillReady = try await service.current(squadId: squad)
        let kept = stillReady?.seat(for: owner)?.ready
        XCTAssertEqual(kept, true)
        try await service.rsvp(callId: card.id, response: "out")
        try await service.rsvp(callId: card.id, response: "in")
        let stored = try await service.current(squadId: squad)
        let ready = stored?.seat(for: owner)?.ready
        let response = stored?.seat(for: owner)?.response
        XCTAssertEqual(response, "in")
        XCTAssertEqual(ready, false)
    }

    @MainActor
    func testAnExpiredUnlockedSpotStillOffersAnotherCall() async throws {
        let now = start
        let squad = ChatSeed.squadId
        let stale = SpotSeed.staleExpired(ownerId: owner, squadId: squad, now: now)
        XCTAssertEqual(stale.status, .open)
        XCTAssertNil(stale.lockedAt)
        XCTAssertTrue(SpotCallRules.showsCallForm(stale, now: now))
        XCTAssertTrue(SpotCallRules.showsCallForm(nil, now: now))
        XCTAssertFalse(SpotCallRules.showsCallForm(call(), now: now))
        var stamped = call()
        stamped.status = .expired
        stamped.joinUntil = now.addingTimeInterval(60)
        XCTAssertTrue(SpotCallRules.showsCallForm(stamped, now: now))
        var locked = call()
        locked.status = .locked
        locked.lockedAt = now.addingTimeInterval(-60)
        locked.joinUntil = now.addingTimeInterval(-120)
        XCTAssertFalse(SpotCallRules.showsCallForm(locked, now: now))
        let service = MockSpotService(viewerId: owner, ownerId: owner, call: stale, now: { now })
        let created = try await service.call(squadId: squad, game: "Halo", startsAt: now)
        let loaded = try await service.current(squadId: squad)
        XCTAssertEqual(loaded?.id, created)
        XCTAssertEqual(loaded?.game, "Halo")
        XCTAssertFalse(SpotCallRules.showsCallForm(loaded, now: now))
        do {
            _ = try await service.call(squadId: squad, game: "Again", startsAt: now)
            XCTFail("A fresh call should stay up")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .alreadyOpen)
        }
    }

    @MainActor
    func testFailedCallSpotsReloadsTheCard() async {
        let model = LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: .spotCall
        )
        model.spotGame = "  "
        await model.callSpots()
        XCTAssertEqual(model.spotLoads, 0)
        let open = model.spot
        model.spotGame = "Halo"
        await model.callSpots()
        XCTAssertEqual(model.spotNote, SpotProblem.alreadyOpen.message)
        XCTAssertEqual(model.spotLoads, 1)
        XCTAssertEqual(model.spot?.id, open?.id)
    }

    @MainActor
    func testOnlyTheCallerOrOwnerCanEndALockedSpot() async throws {
        let locked = call(status: .locked)
        XCTAssertTrue(SpotCallRules.canEnd(locked, actorId: caller, ownerId: owner))
        XCTAssertTrue(SpotCallRules.canEnd(locked, actorId: owner, ownerId: owner))
        XCTAssertFalse(SpotCallRules.canEnd(locked, actorId: member, ownerId: owner))
        XCTAssertFalse(SpotCallRules.canEnd(call(), actorId: caller, ownerId: owner))
        let squad = ChatSeed.squadId
        let callerService = MockSpotService(viewerId: caller, ownerId: owner, call: locked)
        try await callerService.end(callId: locked.id)
        let ended = try await callerService.current(squadId: squad)
        XCTAssertEqual(ended?.status, .ended)
        XCTAssertNotNil(ended?.closedAt)
        let memberService = MockSpotService(viewerId: member, ownerId: owner, call: locked)
        do {
            try await memberService.end(callId: locked.id)
            XCTFail("A member should not end someone else's locked spot")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .notCaller)
        }
        let openService = MockSpotService(viewerId: caller, ownerId: owner, call: call())
        do {
            try await openService.end(callId: locked.id)
            XCTFail("An open spot should not end")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .notLocked)
        }
    }

    func testNearlyFullSpotLeavesOneSeat() {
        let card = SpotSeed.nearlyFull(ownerId: owner, squadId: ChatSeed.squadId, now: start)
        XCTAssertEqual(card.filled, 7)
        XCTAssertEqual(card.seatTotal, 8)
        XCTAssertEqual(card.seatTotal - card.filled, 1)
        XCTAssertNil(card.seat(for: owner))
        XCTAssertTrue(SpotCallRules.canJoin(card, userId: owner, now: start))
        XCTAssertFalse(card.rsvps.filter(\.isIn).allSatisfy(\.ready))
    }
}

final class SpotServerTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
    private let call = UUID(uuidString: "00000000-0000-0000-0000-0000000000C2")!
    private let caller = UUID(uuidString: "00000000-0000-0000-0000-0000000000C3")!
    private let member = UUID(uuidString: "00000000-0000-0000-0000-0000000000C4")!

    func testProbeTreatsMissingFunctionsAndColumnsAsUnavailable() {
        XCTAssertFalse(SpotProbe.functionPresent(status: 404, body: "{\"code\":\"PGRST202\"}"))
        XCTAssertFalse(SpotProbe.functionPresent(status: 400, body: "Could not find the function public.sq8_set_spot_ready"))
        XCTAssertTrue(SpotProbe.functionPresent(status: 405, body: "{\"message\":\"GET is not allowed\"}"))
        XCTAssertFalse(SpotProbe.columnPresent(status: 400, body: "{\"code\":\"42703\",\"message\":\"column sq8_spot_calls.seat_target does not exist\"}"))
        XCTAssertFalse(SpotProbe.columnPresent(status: 400, body: "Could not find the 'ready' column of 'sq8_spot_rsvps' in the schema cache"))
        XCTAssertTrue(SpotProbe.columnPresent(status: 200, body: "[]"))
    }

    func testCapabilityProbeIsReadOnlyAndReadyStaysOffWithoutTheRpc() async throws {
        let missingFunction = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function in the schema cache\"}".utf8)
        let missingColumn = Data("{\"code\":\"42703\",\"message\":\"column sq8_spot_rsvps.ready does not exist\"}".utf8)
        let transport = ScriptedTransport(responses: [
            (404, missingFunction),
            (404, missingFunction),
            (404, missingFunction),
            (400, missingColumn),
            (400, missingColumn)
        ])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        let caps = await spots.serverCapabilities()
        XCTAssertEqual(caps, .unavailable)
        for request in transport.requests {
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.httpBody)
        }
        let readyProbe = try XCTUnwrap(transport.requests.first)
        XCTAssertTrue(readyProbe.url?.path.hasSuffix("sq8_set_spot_ready") == true)
        XCTAssertTrue(readyProbe.url?.query?.contains("call_id=00000000-0000-0000-0000-000000000000") == true)
        XCTAssertTrue(readyProbe.url?.query?.contains("ready=false") == true)
        do {
            try await spots.setReady(callId: call, userId: member, ready: true)
            XCTFail("Ready should stay off until the server stores it")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .badResponse)
        }
        XCTAssertEqual(transport.requests.count, 5)
        XCTAssertTrue(transport.requests.allSatisfy { $0.httpMethod == "GET" })
    }

    func testReadyToggleRoundTripsWhenTheServerStoresIt() async throws {
        let joinUntil = Date(timeIntervalSince1970: 1_800_000_000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let called = formatter.string(from: joinUntil.addingTimeInterval(-60))
        let until = formatter.string(from: joinUntil)
        let payload = Data("""
        {"call":{"id":"\(call.uuidString)","squad_id":"\(squad.uuidString)","caller_id":"\(caller.uuidString)","game":"Warzone","called_at":"\(called)","join_until":"\(until)","locked_at":null,"closed_at":null,"status":"open","seat_target":8},"rsvps":[{"user_id":"\(member.uuidString)","response":"in","starter":false,"ready":true}]}
        """.utf8)
        let transport = ScriptedTransport(responses: presentProbes() + [
            (204, Data()),
            (200, payload)
        ])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        try await spots.setReady(callId: call, userId: member, ready: true)
        let loaded = try await spots.current(squadId: squad)
        let ready = loaded?.seat(for: member)?.ready
        XCTAssertEqual(ready, true)
        XCTAssertEqual(loaded?.seatTarget, 8)
        let post = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(post.count, 2)
        XCTAssertTrue(post.first?.url?.path.hasSuffix("sq8_set_spot_ready") == true)
        XCTAssertTrue(post.last?.url?.path.hasSuffix("sq8_read_open_spot") == true)
        let probes = transport.requests.filter { $0.httpMethod == "GET" }
        XCTAssertEqual(probes.count, 5)
        XCTAssertTrue(probes.allSatisfy { $0.httpBody == nil })
    }

    func testOldLockPathRejectsWhenNotReady() async throws {
        let transport = ScriptedTransport(responses: [
            (405, Data("{\"message\":\"GET is not allowed\"}".utf8)),
            (405, Data("{\"message\":\"GET is not allowed\"}".utf8)),
            (404, Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function public.sq8_read_open_spot(squad) in the schema cache\"}".utf8)),
            (400, Data("{\"code\":\"42703\",\"message\":\"column sq8_spot_calls.seat_target does not exist\"}".utf8)),
            (400, Data("{\"code\":\"42703\",\"message\":\"column sq8_spot_rsvps.ready does not exist\"}".utf8)),
            (400, Data("{\"code\":\"P0001\",\"message\":\"spot_not_ready\"}".utf8))
        ])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        do {
            try await spots.lock(callId: call)
            XCTFail("Lock should fail until every joiner is Ready")
        } catch let problem as SpotProblem {
            XCTAssertEqual(problem, .notReady)
            XCTAssertEqual(problem.message, "Everyone who is in has to be Ready before this locks.")
        }
        let post = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(post.httpMethod, "POST")
        let path = post.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("rpc/sq8_lock_spot"))
        XCTAssertFalse(path.contains("when_ready"))
        XCTAssertEqual(transport.requests.filter { $0.httpMethod == "POST" }.count, 1)
    }

    func testLockUsesTodaysRpcWhenTheReadyGateIsMissing() async throws {
        let missing = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function in the schema cache\"}".utf8)
        let column = Data("{\"code\":\"42703\",\"message\":\"column seat_target does not exist\"}".utf8)
        let transport = ScriptedTransport(responses: [
            (404, missing),
            (404, missing),
            (404, missing),
            (400, column),
            (400, column),
            (204, Data())
        ])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        try await spots.lock(callId: call)
        let post = try XCTUnwrap(transport.requests.last)
        XCTAssertEqual(post.httpMethod, "POST")
        let path = post.url?.path ?? ""
        XCTAssertTrue(path.hasSuffix("rpc/sq8_lock_spot"))
        XCTAssertFalse(path.contains("when_ready"))
    }

    func testExpiryComesFromTheServerClockWhenTheReadExists() async throws {
        let joinUntil = Date(timeIntervalSince1970: 1_800_000_000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let called = formatter.string(from: joinUntil.addingTimeInterval(-360))
        let until = formatter.string(from: joinUntil)
        let payload = Data("""
        {"call":{"id":"\(call.uuidString)","squad_id":"\(squad.uuidString)","caller_id":"\(caller.uuidString)","game":"Warzone","called_at":"\(called)","join_until":"\(until)","locked_at":null,"closed_at":null,"status":"expired","seat_target":8},"rsvps":[{"user_id":"\(caller.uuidString)","response":"in","starter":true,"ready":true}]}
        """.utf8)
        let transport = ScriptedTransport(responses: presentProbes() + [(200, payload)])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        let loaded = try await spots.current(squadId: squad)
        let card = try XCTUnwrap(loaded)
        let phoneIsBehind = joinUntil.addingTimeInterval(-30)
        XCTAssertLessThan(phoneIsBehind, card.joinUntil)
        XCTAssertEqual(card.status, .expired)
        XCTAssertTrue(card.serverOwnsExpiry)
        XCTAssertTrue(SpotCallRules.showsExpired(card, now: phoneIsBehind))
        let post = transport.requests.filter { $0.httpMethod == "POST" }
        XCTAssertEqual(post.count, 1)
        XCTAssertTrue(post.first?.url?.path.hasSuffix("sq8_read_open_spot") == true)
    }

    func testMissingExpiryKeepsThePhoneClock() async throws {
        let joinUntil = Date(timeIntervalSince1970: 1_800_000_000)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let called = formatter.string(from: joinUntil.addingTimeInterval(-60))
        let until = formatter.string(from: joinUntil)
        let row = Data("""
        [{"id":"\(call.uuidString)","squad_id":"\(squad.uuidString)","caller_id":"\(caller.uuidString)","game":"Warzone","called_at":"\(called)","join_until":"\(until)","locked_at":null,"closed_at":null,"status":"open"}]
        """.utf8)
        let seats = Data("""
        [{"user_id":"\(caller.uuidString)","response":"in","starter":true}]
        """.utf8)
        let missing = Data("{\"code\":\"PGRST202\",\"message\":\"Could not find the function in the schema cache\"}".utf8)
        let column = Data("{\"code\":\"42703\",\"message\":\"column ready does not exist\"}".utf8)
        let transport = ScriptedTransport(responses: [
            (404, missing),
            (404, missing),
            (404, missing),
            (400, column),
            (400, column),
            (200, row),
            (200, seats)
        ])
        let spots = SupabaseSpotService(config: config, accessToken: "access", transport: transport)
        let loaded = try await spots.current(squadId: squad)
        let card = try XCTUnwrap(loaded)
        XCTAssertEqual(card.status, .open)
        XCTAssertFalse(card.serverOwnsExpiry)
        XCTAssertNil(card.seatTarget)
        XCTAssertFalse(card.seat(for: caller)?.ready ?? true)
        let before = joinUntil.addingTimeInterval(-10)
        XCTAssertFalse(SpotCallRules.showsExpired(card, now: before))
        let resumed = SpotClock.now(timeline: joinUntil.addingTimeInterval(-20), resumedAt: joinUntil.addingTimeInterval(5))
        XCTAssertTrue(SpotCallRules.showsExpired(card, now: resumed))
        XCTAssertFalse(transport.requests.contains { $0.url?.path.contains("sq8_read_open_spot") == true && $0.httpMethod == "POST" })
    }

    private func presentProbes() -> [(Int, Data)] {
        let allowed = Data("{\"message\":\"GET is not allowed\"}".utf8)
        let rows = Data("[]".utf8)
        return [
            (405, allowed),
            (405, allowed),
            (405, allowed),
            (200, rows),
            (200, rows)
        ]
    }
}
