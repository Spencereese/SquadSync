// Live two-simulator harness (Mac only). Not in any target: scripts/live/run-live.sh
// appends it to AccessibilityUITests.swift for the run and restores that file after.
// It signs in as the two test accounts already on the sims and talks to the live
// project only through the app, as that signed-in user. No SQL, no service role.
import XCTest

final class LiveTwoSim: XCTestCase {
    /// run-live.sh passes TEST_RUNNER_LIVE_DIR; xcodebuild forwards it as LIVE_DIR.
    var dir: String {
        let env = ProcessInfo.processInfo.environment
        return env["LIVE_DIR"] ?? env["PR37_DIR"] ?? NSTemporaryDirectory() + "squadsync-live"
    }
    var tag = "x"
    /// One id per run-live.sh pass (TEST_RUNNER_LIVE_RUN_ID, or the run-id file it
    /// writes), shared by A and B, so every body and game name is unique to the run
    /// and a bubble left by an earlier pass with the same text can't match.
    var run: String {
        let env = ProcessInfo.processInfo.environment
        if let id = env["LIVE_RUN_ID"], !id.isEmpty { return id }
        if let id = try? String(contentsOfFile: "\(dir)/run-id", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty { return id }
        return "norunid"
    }
    var gameName: String { "Apex \(run)" }
    var addedGame: String { "Zeta \(run)" }
    var aBody: String { "Side A \(run)" }
    var bBody: String { "Side B \(run)" }
    var offlineBody: String { "Offline \(run)" }

    override func setUp() {
        continueAfterFailure = true
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    }

    func shot(_ name: String) {
        try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
    }

    func note(_ s: String) {
        let f = DateFormatter(); f.dateFormat = "hh:mm:ss.SSS a"
        let line = "\(f.string(from: Date())) CT [\(tag)] \(s)\n"
        let path = "\(dir)/notes-\(tag).txt"
        if let h = FileHandle(forWritingAtPath: path) {
            h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
        } else {
            try? line.write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    func el(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    func lab(_ app: XCUIApplication, _ id: String) -> String {
        let e = el(app, id)
        return e.exists ? e.label : "<missing>"
    }

    func flag(_ n: String) {
        try? "\(Date().timeIntervalSince1970)".write(toFile: "\(dir)/flag-\(n)", atomically: true, encoding: .utf8)
        note("flag \(n)")
    }

    func flagTime(_ n: String, _ secs: Double) -> Double? {
        let end = Date().addingTimeInterval(secs)
        while Date() < end {
            if let s = try? String(contentsOfFile: "\(dir)/flag-\(n)", encoding: .utf8), let t = Double(s) { return t }
            usleep(200_000)
        }
        return nil
    }

    func live(_ extras: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "live"] + extras
        app.launch()
        let title = el(app, "squad-title")
        let signedOut = el(app, "signin-email")
        _ = title.waitForExistence(timeout: 30) || signedOut.waitForExistence(timeout: 1)
        note("launch: title='\(title.exists ? title.label : "<none>")' signin=\(signedOut.exists) value='\(title.exists ? ((title.value as? String) ?? "") : "")'")
        sleep(3)
        return app
    }

    func linkNote(_ app: XCUIApplication) -> String {
        let t = el(app, "squad-title")
        guard t.exists else { return "<no title>" }
        if let v = t.value as? String, !v.isEmpty { return v }
        return ""
    }

    /// The bubble element itself (`chat.bubble.<token>.start|continues`) whose label
    /// carries this run's text. Never a row, a quote, or a caption.
    func bubble(_ app: XCUIApplication, containing body: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'chat.bubble.' AND label CONTAINS %@", body)).firstMatch
    }

    /// "<token>" from "chat.bubble.<token>.start" (the same token the row and
    /// reactions identifiers use; see ChatSeed).
    func token(of bubble: XCUIElement) -> String? {
        let id = bubble.identifier
        guard id.hasPrefix("chat.bubble.") else { return nil }
        let rest = id.dropFirst("chat.bubble.".count)
        guard let dot = rest.lastIndex(of: ".") else { return nil }
        return String(rest[..<dot])
    }

    /// A reaction chip under one message: inside `chat.reactions.<token>`, the
    /// button `reaction-chip-<Tapback raw value>` (ChatRows.swift).
    func chip(_ app: XCUIApplication, under bubble: XCUIElement, tapback: String = "hand.thumbsup.fill") -> XCUIElement {
        let container = el(app, "chat.reactions.\(token(of: bubble) ?? "<no-token>")")
        return container.buttons["reaction-chip-\(tapback)"]
    }

    func scrollChat(to e: XCUIElement, in app: XCUIApplication, swipes: Int = 12) -> Bool {
        if e.exists && e.isHittable { return true }
        for _ in 0..<swipes {
            if e.exists && e.frame.maxY > 80 && e.frame.minY < app.windows.firstMatch.frame.maxY - 80 { return true }
            app.swipeUp()
        }
        return e.exists
    }

    /// Taps the field until it has keyboard focus. typeText without focus fails the
    /// whole test ("Neither element nor any descendant has keyboard focus").
    func focus(_ field: XCUIElement, in app: XCUIApplication) -> Bool {
        for attempt in 1...3 {
            guard field.waitForExistence(timeout: 8) else { return false }
            if field.isHittable { field.tap() } else { field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            if app.keyboards.firstMatch.waitForExistence(timeout: 3) || (field.value(forKey: "hasKeyboardFocus") as? Bool) == true {
                return true
            }
            note("no keyboard focus on '\(field.identifier)' (attempt \(attempt))")
        }
        return false
    }

    func send(_ app: XCUIApplication, _ text: String) -> Bool {
        // The squad panel must be gone first, or the Message field sits under the sheet.
        if panelOpen(app) && !closePanel(app) { note("send: panel would not close"); return false }
        let field = app.textFields["Message"]
        guard field.waitForExistence(timeout: 8) else { note("composer missing"); return false }
        guard focus(field, in: app) else { note("send: Message field never got focus"); shot("send-no-focus"); return false }
        field.typeText(text)
        let send = app.buttons["send-message"]
        if send.exists { send.tap() } else { field.typeText("\n") }
        let visible = bubble(app, containing: text).waitForExistence(timeout: 8)
        note("send '\(text)' visible=\(visible)")
        return visible
    }

    /// Measures the bubble and fails the test when it's on the wrong side or row-wide.
    func sideReport(_ app: XCUIApplication, body: String, expectOwn: Bool) -> String {
        let window = app.windows.firstMatch.frame
        let b = bubble(app, containing: body)
        guard b.exists else {
            XCTFail("\(tag): no bubble for '\(body)'")
            return "\(body): missing"
        }
        let frame = b.frame
        let mid = frame.midX
        let ownOK = mid > window.midX + 1 && frame.width < window.width - 40
        let otherOK = mid < window.midX - 1 && frame.width < window.width - 40
        let ok = expectOwn ? ownOK : otherOK
        let report = "\(body): label='\(b.label)' id='\(b.identifier)' midX=\(Int(mid)) winMid=\(Int(window.midX)) minX=\(Int(frame.minX)) maxX=\(Int(frame.maxX)) w=\(Int(frame.width)) expectOwn=\(expectOwn) sideOK=\(ok)"
        XCTAssertTrue(ok, "\(tag): bubble on the wrong side or row-wide: \(report)")
        return report
    }

    func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        var tries = 0
        while element.exists && !element.isHittable && tries < 8 {
            app.swipeUp()
            tries += 1
        }
    }

    func openPanel(_ app: XCUIApplication) -> Bool {
        let title = el(app, "squad-title")
        guard title.waitForExistence(timeout: 15) else { return false }
        title.tap()
        return app.textFields["profile-name"].waitForExistence(timeout: 8)
    }

    func panelOpen(_ app: XCUIApplication) -> Bool {
        el(app, "squad-count").exists || app.textFields["profile-name"].exists
    }

    /// Dismisses the squad panel and waits until it's gone. A plain swipeDown only
    /// scrolled the panel back up after reveal() had scrolled it, so the sheet stayed
    /// and the next typeText had no focus. Drag from the sheet's top edge instead.
    @discardableResult
    func closePanel(_ app: XCUIApplication) -> Bool {
        let marker = el(app, "squad-count")
        for attempt in 1...4 {
            guard panelOpen(app) else { return true }
            if app.keyboards.firstMatch.exists { app.keyboards.buttons["Return"].firstMatch.tap() }
            for name in ["Close", "Done"] where app.buttons[name].exists && app.buttons[name].isHittable {
                app.buttons[name].tap()
                break
            }
            if panelOpen(app) {
                let window = app.windows.firstMatch
                let top = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.07))
                let bottom = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
                top.press(forDuration: 0.1, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0)
            }
            if marker.waitForNonExistence(timeout: 4) && !app.textFields["profile-name"].exists {
                note("panel closed (attempt \(attempt))")
                return true
            }
        }
        note("panel still open after 4 tries")
        shot("panel-stuck")
        return false
    }

    // MARK: Games fixture (Grok Test on sim A)

    struct GamesFixture: Codable, Equatable {
        var games: [String]
        var defaultGame: String
    }

    var fixturePath: String { "\(dir)/fixture-games-a.json" }

    /// What Grok Test's games are put back to after every run, whatever they were
    /// before: LIVE_BASELINE_GAMES (|-separated) and LIVE_BASELINE_DEFAULT, by
    /// default Call of Duty only, default Call of Duty.
    var baseline: GamesFixture {
        let env = ProcessInfo.processInfo.environment
        let games = (env["LIVE_BASELINE_GAMES"] ?? "Call of Duty").split(separator: "|").map(String.init)
        return GamesFixture(games: games, defaultGame: env["LIVE_BASELINE_DEFAULT"] ?? games.first ?? "Call of Duty")
    }

    /// The panel must be open. Waits for the list to load, then reads rows and default.
    func readGames(_ app: XCUIApplication) -> GamesFixture? {
        guard app.textFields["profile-add-game"].waitForExistence(timeout: 12) else {
            note("games list never loaded: error='\(lab(app, "profile-games-load-error"))'")
            return nil
        }
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'profile-games-row-'"))
        var games: [String] = []
        for i in 0..<rows.count {
            let name = String(rows.element(boundBy: i).identifier.dropFirst("profile-games-row-".count))
            if !games.contains(name) { games.append(name) }
        }
        let field = app.textFields["profile-game"]
        var value = field.value as? String ?? ""
        if value == field.placeholderValue { value = "" }
        return GamesFixture(games: games, defaultGame: value)
    }

    /// Records what the account held before this run, for the notes only. The
    /// teardown never restores this: it forces `baseline`. The file stays until a
    /// verified restore, so run-live.sh can warn when one didn't happen.
    func snapshotFixture(_ app: XCUIApplication) {
        let before = readGames(app)
        note("fixture: before run \(before.map { "\($0)" } ?? "<unreadable>"); teardown forces \(baseline)")
        if let before, let data = try? JSONEncoder().encode(before) { FileManager.default.createFile(atPath: fixturePath, contents: data) }
    }

    func clear(_ field: XCUIElement) {
        let current = field.value as? String ?? ""
        guard !current.isEmpty, current != field.placeholderValue else { return }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }

    /// Sets exactly the baseline list and default through the panel and Save, as the
    /// signed-in user, then proves it after a relaunch: the same set of games and the
    /// same default. Deletes the before-run record only once it reads back equal.
    @discardableResult
    func restoreFixture(_ fixture: GamesFixture) -> Bool {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["-backend", "live"]
        app.launch()
        guard openPanel(app), let current = readGames(app) else { note("restore: panel or list missing"); shot("restore-failed"); return false }
        for game in current.games where !fixture.games.contains(game) {
            let remove = app.buttons["profile-remove-\(game)"]
            reveal(remove, in: app)
            if remove.exists { remove.tap() }
        }
        let entry = app.textFields["profile-add-game"]
        for game in fixture.games where !current.games.contains(game) {
            reveal(entry, in: app)
            if focus(entry, in: app) { entry.typeText(game + "\n") }
        }
        let makeDefault = app.buttons["profile-default-\(fixture.defaultGame)"]
        reveal(makeDefault, in: app)
        if makeDefault.exists { makeDefault.tap() }
        let field = app.textFields["profile-game"]
        if (field.value as? String) != fixture.defaultGame, focus(field, in: app) {
            clear(field)
            field.typeText(fixture.defaultGame)
        }
        let save = app.buttons["save-profile"]
        reveal(save, in: app)
        save.tap()
        let saved = el(app, "profile-saved").waitForExistence(timeout: 8)
        note("restore: saved=\(saved) error='\(lab(app, "profile-games-error"))'")
        shot("a-restore-saved")

        app.terminate()
        app.launch()
        guard openPanel(app), let back = readGames(app) else { note("restore: re-read failed"); return false }
        let ok = back.defaultGame == fixture.defaultGame && Set(back.games) == Set(fixture.games)
        note("restore: read back \(back) want \(fixture) ok=\(ok)")
        shot("a-restore-verified")
        if ok { try? FileManager.default.removeItem(atPath: fixturePath) }
        XCTAssertTrue(ok, "Grok Test's games were not restored: \(back) vs \(fixture)")
        closePanel(app)
        return ok
    }

    func spotState(_ app: XCUIApplication) -> String {
        let ids = ["spot-card","spot-title","spot-join","spot-ready","spot-lock","spot-cancel","spot-end","spot-countdown","active-call-bar","active-call-join","active-call-leave","active-call-lock"]
        return ids.map { id in
            let e = el(app, id)
            if !e.exists { return "\(id)=no" }
            return "\(id)='\(e.label)' hittable=\(e.isHittable)"
        }.joined(separator: " | ")
    }

    /// + menu, Call spots, then the sheet: waits for the sheet's game field, types this
    /// run's game, taps the sheet's own button (spot-sheet-call, not the menu item of
    /// the same name), waits for the sheet to go and the call to show. Fails the test
    /// with the reason when any step doesn't happen.
    @discardableResult
    func callSpots(_ app: XCUIApplication) -> Bool {
        if panelOpen(app) { closePanel(app) }
        if app.keyboards.firstMatch.exists { app.keyboards.buttons["Return"].firstMatch.tap() }
        let game = app.textFields["spot-sheet-game"]
        for attempt in 1...3 where !game.exists {
            let plus = app.buttons["composer-plus"]
            guard plus.waitForExistence(timeout: 8) else { break }
            plus.tap()
            // The menu item by id; some systems drop ids on menu items, so then by label.
            var item = app.buttons["composer-call-spots"]
            if !item.waitForExistence(timeout: 3) {
                item = app.collectionViews.buttons["Call spots"].firstMatch
            }
            if item.waitForExistence(timeout: 3) { item.tap() }
            if game.waitForExistence(timeout: 8) { break }
            note("callSpots: sheet not open (attempt \(attempt)) note='\(lab(app, "spot-note"))'")
            shot("a-callspots-no-sheet-\(attempt)")
        }
        guard game.exists else {
            XCTFail("Call spots sheet never opened: spot-note='\(lab(app, "spot-note"))' \(spotState(app))")
            return false
        }
        if focus(game, in: app) {
            clear(game)
            game.typeText(gameName)
        }
        let call = app.buttons["spot-sheet-call"]
        guard call.waitForExistence(timeout: 5) else {
            XCTFail("The sheet has no Call spots button")
            return false
        }
        call.tap()
        let closed = game.waitForNonExistence(timeout: 10)
        let opened = el(app, "spot-card").waitForExistence(timeout: 10) || el(app, "active-call-bar").waitForExistence(timeout: 2)
        note("callSpots sheetClosed=\(closed) opened=\(opened) error='\(lab(app, "spot-sheet-error"))' \(spotState(app))")
        XCTAssertTrue(closed && opened, "Calling spots didn't open a call: error='\(lab(app, "spot-sheet-error"))' \(spotState(app))")
        return closed && opened
    }

    func waitForLabel(_ e: XCUIElement, _ predicate: String, timeout: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: e)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func waitForValue(_ e: XCUIElement, _ value: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", value), object: e)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Taps the DEBUG network switch until it reads `value` (a tap that lands on the
    /// keyboard or a sheet changes nothing, which is how it stayed On before).
    func setNetwork(_ network: XCUIElement, to value: String, in app: XCUIApplication) -> Bool {
        for attempt in 1...3 {
            if (network.value as? String) == value { return true }
            if app.keyboards.firstMatch.exists { app.keyboards.buttons["Return"].firstMatch.tap() }
            if network.isHittable { network.tap() } else { network.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            if waitForValue(network, value) { return true }
            note("network switch still '\(network.value as? String ?? "<none>")' after tap \(attempt)")
        }
        return false
    }

    func testLiveB() {
        tag = "live-b"
        let app = live()
        shot("b-00-launch")
        flag("b-ready")
        _ = flagTime("a-sent", 90)
        _ = bubble(app, containing: aBody).waitForExistence(timeout: 20)
        note("B other-side: \(sideReport(app, body: aBody, expectOwn: false))")
        shot("b-01-seen-A")
        flag("b-seen-A")
        _ = send(app, bBody)
        note("B sent own: \(sideReport(app, body: bBody, expectOwn: true))")
        shot("b-02-sent-B")
        flag("b-sent")
        _ = flagTime("a-reacted", 60)
        // A reacted on B's own message: the chip is under that bubble.
        let mineB = bubble(app, containing: bBody)
        _ = mineB.waitForExistence(timeout: 10)
        let chip = chip(app, under: mineB)
        XCTAssertTrue(chip.waitForExistence(timeout: 15), "B never saw A's thumbs-up under '\(bBody)'")
        note("B saw A's reaction=\(chip.exists) chip='\(chip.label)' selected=\(chip.isSelected) frame=\(chip.frame)")
        shot("b-03-saw-react")
        if chip.exists {
            if !chip.isHittable { scrollChat(to: chip, in: app) }
            let before = chip.label
            chip.tap()
            sleep(2)
            note("B toggled chip: before='\(before)' after='\(chip.label)' selected=\(chip.isSelected)")
        }
        shot("b-04-toggled-react")
        flag("b-reacted")
        _ = flagTime("a-called", 90)
        var joined = false
        for _ in 0..<20 {
            let join = el(app, "active-call-join")
            let cardJoin = el(app, "spot-join")
            if join.exists || cardJoin.exists {
                note("B sees call: \(spotState(app))")
                shot("b-05-spot-before-join")
                let btn = join.exists ? join : cardJoin
                if btn.isHittable { btn.tap() } else { btn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
                sleep(2)
                joined = true
                break
            }
            sleep(1)
        }
        XCTAssertTrue(joined, "B never saw a call to join")
        note("B after join: joined=\(joined) ready=\(el(app, "spot-ready").exists) \(spotState(app))")
        shot("b-06-after-join")
        flag("b-joined")
        _ = flagTime("a-locked", 60)
        note("B after lock: \(spotState(app))")
        shot("b-07-after-lock")
        flag("b-saw-lock")
        _ = flagTime("a-banner-done", 180)
        note("B during/after banner: link='\(linkNote(app))'")
        shot("b-08-after-banner")
        flag("b-done")
        note("B done")
        shot("b-99-end")
    }

    func testLiveA() {
        tag = "live-a"
        var app = live(["-SQ8NetworkFault"])
        shot("a-00-launch")

        // Profile games: snapshot, add, set default, save, relaunch, confirm from server.
        // The teardown block restores the snapshot even when a later step fails.
        // Registered first, so the baseline is forced even if the panel never opens.
        let target = baseline
        addTeardownBlock { [weak self] in self?.restoreFixture(target) }
        if openPanel(app) {
            snapshotFixture(app)
            shot("a-01-profile-open")
            let entry = app.textFields["profile-add-game"]
            reveal(entry, in: app)
            if entry.exists {
                if focus(entry, in: app) { entry.typeText(addedGame + "\n") }
                sleep(1)
            }
            let row = el(app, "profile-games-row-\(addedGame)")
            note("added row exists=\(row.waitForExistence(timeout: 6))")
            let makeDefault = app.buttons["profile-default-\(addedGame)"]
            reveal(makeDefault, in: app)
            if makeDefault.exists { makeDefault.tap(); sleep(1) }
            let defaultField = app.textFields["profile-game"]
            note("default field='\(defaultField.value as? String ?? "<none>")' row='\(row.exists)' savedMark=\(el(app, "profile-games-row-\(addedGame)").exists)")
            shot("a-02-profile-before-save")
            let save = app.buttons["save-profile"]
            reveal(save, in: app)
            if save.exists { save.tap() }
            let saved = el(app, "profile-saved")
            note("save confirm=\(saved.waitForExistence(timeout: 8)) label='\(saved.exists ? saved.label : "<none>")' error=\(el(app, "profile-games-error").exists)")
            shot("a-03-profile-saved")
        } else {
            note("profile panel did not open")
            shot("a-01-profile-missing")
        }
        flag("a-profile-saved")

        app.terminate()
        sleep(2)
        app = live(["-SQ8NetworkFault"])
        shot("a-04-relaunch")
        if openPanel(app) {
            let row = el(app, "profile-games-row-\(addedGame)")
            reveal(row, in: app)
            let defaultField = app.textFields["profile-game"]
            note("relaunch row=\(row.waitForExistence(timeout: 8)) default='\(defaultField.value as? String ?? "<none>")'")
            shot("a-05-profile-after-relaunch")
            // No ad-hoc cleanup here: the fixture teardown restores games and default.
            XCTAssertTrue(closePanel(app), "The squad panel would not close")
        } else {
            note("profile panel did not open after relaunch")
        }
        flag("a-profile-checked")

        _ = flagTime("b-ready", 60)
        _ = send(app, aBody)
        note("A sent own: \(sideReport(app, body: aBody, expectOwn: true))")
        shot("a-07-sent-A")
        flag("a-sent")
        _ = flagTime("b-sent", 60)
        _ = bubble(app, containing: bBody).waitForExistence(timeout: 20)
        note("A other-side: \(sideReport(app, body: bBody, expectOwn: false))")
        shot("a-08-seen-B")
        flag("a-seen-B")

        let target = bubble(app, containing: bBody)
        if scrollChat(to: target, in: app) {
            if target.isHittable { target.tap() } else { target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            let react = app.buttons["react"]
            if react.waitForExistence(timeout: 5) { react.tap() }
            var thumbs = app.buttons["tapback-hand.thumbsup.fill"]
            if !thumbs.waitForExistence(timeout: 5) { thumbs = app.buttons["Thumbs up"].firstMatch }
            if thumbs.waitForExistence(timeout: 3) { thumbs.tap() }
        }
        let chip = chip(app, under: target)
        let reacted = chip.waitForExistence(timeout: 8)
        XCTAssertTrue(reacted, "A's thumbs-up never showed under '\(bBody)'")
        note("A reacted on B's message: exists=\(reacted) chip='\(chip.label)' selected=\(chip.isSelected)")
        shot("a-09-reacted")
        flag("a-reacted")
        _ = flagTime("b-reacted", 30)
        note("A after B toggle: chip='\(chip.label)' selected=\(chip.isSelected)")
        shot("a-10-after-B-react")

        let called = callSpots(app)
        note("A called=\(called)")
        shot("a-11-called")
        flag("a-called")
        _ = flagTime("b-joined", 60)
        note("A after B join: ready=\(el(app, "spot-ready").exists) \(spotState(app))")
        shot("a-12-after-join")
        let lock = el(app, "spot-lock")
        let barLock = el(app, "active-call-lock")
        let lockBtn = lock.exists ? lock : barLock
        if lockBtn.waitForExistence(timeout: 8) {
            note("A lock visible=true \(spotState(app))")
            shot("a-13-lock-visible")
            if lockBtn.isHittable { lockBtn.tap() } else { lockBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            sleep(2)
        } else {
            note("A lock missing")
            XCTFail("No Lock on A's call after B joined: \(spotState(app))")
        }
        note("A after lock: \(spotState(app))")
        shot("a-14-locked")
        flag("a-locked")
        // End the call so it doesn't linger
        sleep(2)
        let end = el(app, "spot-end")
        if end.exists {
            if end.isHittable { end.tap() } else { end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            let confirm = app.buttons["End spot"]
            if confirm.waitForExistence(timeout: 4) { confirm.tap() }
            sleep(1)
        }
        note("A after end: \(spotState(app))")
        shot("a-15-ended")
        flag("a-ended")

        // Banner: the DEBUG network switch, an offline send, then Retry. The banner
        // (squad-title's value) must first appear and then clear; a label that was
        // empty all along is not "cleared".
        let network = app.buttons["debug-network-fault"]
        let title = el(app, "squad-title")
        let hasSwitch = network.waitForExistence(timeout: 8)
        note("network toggle exists=\(hasSwitch) value='\(network.value as? String ?? "<none>")' link='\(linkNote(app))'")
        XCTAssertTrue(hasSwitch, "No DEBUG network switch (launched without -SQ8NetworkFault?)")
        shot("a-16-before-fault")
        let off = hasSwitch && setNetwork(network, to: "Off", in: app)
        XCTAssertTrue(off, "The network switch never went Off")
        note("toggled off=\(off) value='\(network.value as? String ?? "")' link='\(linkNote(app))'")
        shot("a-17-fault-off")
        flag("a-banner-on")
        if off {
            _ = send(app, offlineBody)
            let offline = bubble(app, containing: offlineBody)
            let notDelivered = app.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'delivery-caption' AND label == 'Not delivered'")).firstMatch
            let failed = notDelivered.waitForExistence(timeout: 15)
            let shown = waitForLabel(title, "value != nil AND value != ''", timeout: 15)
            let banner = linkNote(app)
            note("after offline send: bubble=\(offline.exists) notDelivered=\(failed) banner='\(banner)' retry=\(app.buttons["retry-send"].exists)")
            shot("a-18-offline-send")
            XCTAssertTrue(failed, "The offline send didn't say Not delivered")
            XCTAssertTrue(shown, "No banner while offline: '\(banner)'")

            let on = setNetwork(network, to: "On", in: app)
            XCTAssertTrue(on, "The network switch never came back On")
            note("toggled on=\(on) link='\(linkNote(app))'")
            shot("a-19-fault-on")
            let retry = app.buttons["retry-send"]
            let hasRetry = retry.waitForExistence(timeout: 10)
            XCTAssertTrue(hasRetry, "No Retry on the failed send")
            if hasRetry {
                if retry.isHittable { retry.tap() } else { retry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
            }
            let delivered = notDelivered.waitForNonExistence(timeout: 15)
            let cleared = shown && waitForLabel(title, "value == nil OR value == ''", timeout: 20)
            note("after Retry: delivered=\(delivered) cleared=\(cleared) final link='\(linkNote(app))' retry=\(retry.exists)")
            shot("a-20-after-retry")
            XCTAssertTrue(delivered, "The retried send still says Not delivered")
            XCTAssertTrue(cleared, "The banner appeared but never cleared after Retry: '\(linkNote(app))'")
        }
        shot("a-21-banner-final")
        flag("a-banner-done")
        note("A done")
        shot("a-99-end")
        _ = flagTime("b-done", 30)
    }
}
