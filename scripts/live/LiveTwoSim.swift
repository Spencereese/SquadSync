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
    let gameName = "Apex PR37re"
    let addedGame = "Zeta PR37re"
    let aBody = "PR37re side A"
    let bBody = "PR37re side B"

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

    func bubble(_ app: XCUIApplication, containing body: String) -> XCUIElement {
        let matches = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", body))
        for i in 0..<min(matches.count, 12) {
            let e = matches.element(boundBy: i)
            if e.identifier.hasPrefix("chat.bubble.") { return e }
        }
        for i in 0..<min(matches.count, 12) {
            let e = matches.element(boundBy: i)
            if e.identifier.hasPrefix("bubble-group") { return e }
        }
        return matches.firstMatch
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

    func sideReport(_ app: XCUIApplication, body: String, expectOwn: Bool) -> String {
        let window = app.windows.firstMatch.frame
        let b = bubble(app, containing: body)
        guard b.exists else { return "\(body): missing" }
        let mid = b.frame.midX
        let ownOK = mid > window.midX + 1 && b.frame.width < window.width - 40
        let otherOK = mid < window.midX - 1 && b.frame.width < window.width - 40
        let ok = expectOwn ? ownOK : otherOK
        return "\(body): label='\(b.label)' id='\(b.identifier)' midX=\(Int(mid)) winMid=\(Int(window.midX)) minX=\(Int(b.frame.minX)) maxX=\(Int(b.frame.maxX)) w=\(Int(b.frame.width)) expectOwn=\(expectOwn) sideOK=\(ok)"
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

    /// Used only when the account reads back empty (a run that never restored).
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

    /// Before the test changes anything. A snapshot left by a run that didn't restore
    /// is kept, because the account still holds that run's changes.
    func snapshotFixture(_ app: XCUIApplication) -> GamesFixture {
        if let data = FileManager.default.contents(atPath: fixturePath),
           let kept = try? JSONDecoder().decode(GamesFixture.self, from: data) {
            note("fixture: keeping earlier snapshot \(kept)")
            return kept
        }
        var fixture = readGames(app) ?? baseline
        if fixture.games.isEmpty || fixture.defaultGame.isEmpty {
            note("fixture: account read back empty \(fixture); using baseline \(baseline)")
            fixture = baseline
        }
        if let data = try? JSONEncoder().encode(fixture) { FileManager.default.createFile(atPath: fixturePath, contents: data) }
        note("fixture: snapshot \(fixture)")
        return fixture
    }

    func clear(_ field: XCUIElement) {
        let current = field.value as? String ?? ""
        guard !current.isEmpty, current != field.placeholderValue else { return }
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }

    /// Puts the list and default back through the panel and Save, then proves it
    /// after a relaunch. Deletes the snapshot only once it reads back equal.
    @discardableResult
    func restoreFixture(_ fixture: GamesFixture) -> Bool {
        let app = XCUIApplication()
        app.terminate()
        app.launchArguments = ["-backend", "live"]
        app.launch()
        guard openPanel(app), let current = readGames(app) else { note("restore: panel or list missing"); shot("restore-failed"); return false }
        for game in current.games {
            let remove = app.buttons["profile-remove-\(game)"]
            reveal(remove, in: app)
            if remove.exists { remove.tap() }
        }
        let entry = app.textFields["profile-add-game"]
        for game in fixture.games {
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

    func callSpots(_ app: XCUIApplication) -> Bool {
        let plus = app.buttons["composer-plus"]
        if plus.waitForExistence(timeout: 5) { plus.tap() }
        let item = app.buttons["composer-call-spots"]
        if item.waitForExistence(timeout: 4) { item.tap() }
        let call = app.buttons["Call spots"]
        let game = app.textFields["spot-sheet-game"]
        if game.waitForExistence(timeout: 6) {
            game.tap()
            if let existing = game.value as? String, !existing.isEmpty, existing != "Game" {
                game.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
            }
            game.typeText(gameName)
        }
        if call.waitForExistence(timeout: 4) { call.tap() }
        let opened = el(app, "spot-card").waitForExistence(timeout: 8) || el(app, "spot-title").waitForExistence(timeout: 2) || el(app, "active-call-bar").waitForExistence(timeout: 2)
        note("callSpots opened=\(opened) \(spotState(app))")
        return opened
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
        let chips = el(app, "chat.reactions") // may not match; look for thumb chip
        let chip = app.buttons["reaction-chip-hand.thumbsup.fill"]
        _ = chip.waitForExistence(timeout: 15)
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
        if openPanel(app) {
            let fixture = snapshotFixture(app)
            addTeardownBlock { [weak self] in self?.restoreFixture(fixture) }
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
            let react = app.buttons["React"]
            if react.waitForExistence(timeout: 5) { react.tap() }
            let thumbs = app.buttons["Thumbs up"]
            if thumbs.waitForExistence(timeout: 5) { thumbs.tap() }
        }
        let chip = app.buttons["reaction-chip-hand.thumbsup.fill"]
        note("A reacted on B's message: exists=\(chip.waitForExistence(timeout: 8)) chip='\(chip.label)' selected=\(chip.isSelected)")
        shot("a-09-reacted")
        flag("a-reacted")
        _ = flagTime("b-reacted", 30)
        note("A after B toggle: chip='\(chip.label)' selected=\(chip.isSelected)")
        shot("a-10-after-B-react")

        _ = callSpots(app)
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

        // Banner: Debug network toggle + Retry
        let network = app.buttons["debug-network-fault"]
        note("network toggle exists=\(network.waitForExistence(timeout: 8)) value='\(network.value as? String ?? "<none>")' link='\(linkNote(app))'")
        shot("a-16-before-fault")
        if network.exists {
            network.tap()
            sleep(1)
            note("toggled off value='\(network.value as? String ?? "")' link='\(linkNote(app))'")
        }
        shot("a-17-fault-off")
        flag("a-banner-on")
        _ = send(app, "PR37re offline")
        sleep(2)
        note("after offline send: link='\(linkNote(app))' retry=\(app.buttons["retry-send"].exists) not-delivered=\(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Not delivered'")).count)")
        shot("a-18-offline-send")
        if network.exists {
            network.tap()
            sleep(2)
            note("toggled on value='\(network.value as? String ?? "")' link='\(linkNote(app))'")
        }
        shot("a-19-fault-on")
        if app.buttons["retry-send"].waitForExistence(timeout: 8) {
            app.buttons["retry-send"].tap()
            sleep(3)
            note("after Retry: link='\(linkNote(app))' retry=\(app.buttons["retry-send"].exists)")
            shot("a-20-after-retry")
        } else {
            note("no retry-send after toggle on; link='\(linkNote(app))'")
            shot("a-20-no-retry")
        }
        let link = linkNote(app)
        let cleared = !link.contains("Reconnecting") && !link.contains("Live chat is down")
        note("banner cleared=\(cleared) final link='\(link)'")
        shot("a-21-banner-final")
        flag("a-banner-done")
        note("A done")
        shot("a-99-end")
        _ = flagTime("b-done", 30)
    }
}
