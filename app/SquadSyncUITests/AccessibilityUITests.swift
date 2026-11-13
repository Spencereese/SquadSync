import XCTest

final class AccessibilityUITests: XCTestCase {
    func testTabsAndThreadButtonsAreExposed() {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "inbox", "-scenario", "seated"]
        app.launch()

        let inbox = app.descendants(matching: .any)["tab-inbox"]
        let space = app.descendants(matching: .any)["tab-space"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 15), "Inbox tab was not in the accessibility tree")
        XCTAssertTrue(space.exists, "Space tab was not in the accessibility tree")

        app.terminate()
        app.launchArguments = ["-screen", "thread-general", "-scenario", "seated"]
        app.launch()

        let voice = app.descendants(matching: .any)["voice-room"]
        let handoff = app.descendants(matching: .any)["handoff-menu"]
        XCTAssertTrue(voice.waitForExistence(timeout: 15), "Voice room button was not in the accessibility tree")
        XCTAssertTrue(handoff.exists, "Handoff menu button was not in the accessibility tree")
    }

    func testSpaceMemberRowClearsTheTabBarAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "space", "-uitest-largeText"]
        app.launch()

        let row = app.descendants(matching: .any)["member-sam"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Sam's row was not in the accessibility tree")
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar was not in the accessibility tree")
        XCTAssertLessThanOrEqual(
            row.frame.maxY,
            tabBar.frame.minY + 1,
            "Sam's row ends at \(row.frame.maxY), under the tab bar at \(tabBar.frame.minY)"
        )
    }

    func testInboxLastRowClearsTheTabBarAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "inbox", "-uitest-largeText"]
        app.launch()

        let row = app.descendants(matching: .any)["inbox-friday"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Friday crew was not in the accessibility tree")
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15), "Tab bar was not in the accessibility tree")
        XCTAssertLessThanOrEqual(
            row.frame.maxY,
            tabBar.frame.minY + 1,
            "Friday crew ends at \(row.frame.maxY), under the tab bar at \(tabBar.frame.minY)"
        )
    }

    func testPartySheetDetailsClearTheActionBarAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "thread-general", "-uitest-largeText"]
        app.launch()

        let summary = app.descendants(matching: .any)["party-summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Party summary was not in the accessibility tree")
        summary.tap()

        let last = app.descendants(matching: .any)["party-details-last"]
        let actions = app.descendants(matching: .any)["party-actions"]
        XCTAssertTrue(last.waitForExistence(timeout: 15), "Last party details line was not in the accessibility tree")
        XCTAssertTrue(actions.waitForExistence(timeout: 15), "Inline party actions were not in the accessibility tree")
        XCTAssertLessThanOrEqual(
            last.frame.maxY,
            actions.frame.minY + 1,
            "Party details end at \(last.frame.maxY), under the inline actions at \(actions.frame.minY)"
        )

        let scroll = app.scrollViews.firstMatch
        var swipes = 0
        while !actions.isHittable, swipes < 6 {
            scroll.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(actions.isHittable, "Inline party actions were not reachable after scrolling")
    }

    func testMockInviteCanAddAndRemoveAReaction() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let row = app.descendants(matching: .any)["message-row-seed-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Seeded message row was not visible")
        if !row.isHittable {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        } else {
            row.tap()
        }

        let react = app.buttons["React"]
        XCTAssertTrue(react.waitForExistence(timeout: 5), "React button was not visible")
        react.tap()

        let thumbs = app.buttons["Thumbs up"]
        XCTAssertTrue(thumbs.waitForExistence(timeout: 5), "Thumbs up was not in the reaction row")
        thumbs.tap()

        let count = app.staticTexts["reaction-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Reaction count was not visible")
        XCTAssertEqual(count.label, "1")

        thumbs.tap()
        XCTAssertTrue(count.waitForNonExistence(timeout: 5), "Reaction count stayed after it was removed")
    }

    func testMockSpotCallJoinAndReady() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall"]
        app.launch()

        let join = app.buttons["spot-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 15), "Join was not on the spot card")
        XCTAssertEqual(join.label, "Join the spot call")
        reveal(join, in: app)
        join.tap()

        let ready = app.buttons["spot-ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 5), "Ready was not on the spot card after joining")
        XCTAssertEqual(ready.label, "Ready, off")
        ready.tap()
        XCTAssertEqual(ready.label, "Ready, on")
        ready.tap()
        XCTAssertEqual(ready.label, "Ready, off")
        assertListClearsComposer(app)
    }

    func testMockSpotCallCallerCanCancel() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine"]
        app.launch()

        let cancel = app.buttons["spot-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "Cancel was not on the caller's card")
        XCTAssertEqual(cancel.label, "Cancel the spot call")
        XCTAssertTrue(app.buttons["spot-lock"].waitForExistence(timeout: 5), "Lock was not on the caller's card")
        reveal(cancel, in: app)
        cancel.tap()

        let status = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Cancelled")
        XCTAssertFalse(app.buttons["spot-join"].exists)
        XCTAssertFalse(app.buttons["spot-lock"].exists)
        XCTAssertFalse(app.buttons["spot-cancel"].exists)
    }

    func testMockSpotCallStaysReadableAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall", "-uitest-largeText"]
        app.launch()

        let card = app.descendants(matching: .any)["spot-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15), "Spot card was not in the accessibility tree")
        let join = app.buttons["spot-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5), "Join was not in the accessibility tree")
        reveal(join, in: app)
        XCTAssertTrue(join.isHittable, "Join was not reachable at the largest text size")
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Composer was not on screen")
        XCTAssertLessThanOrEqual(join.frame.maxY, composer.frame.minY + 1, "Card Join is still under the composer")
        XCTAssertLessThan(join.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
        XCTAssertTrue(app.descendants(matching: .any)["spot-countdown"].exists)
        assertListClearsComposer(app)
    }

    func testPinnedJoinStaysHittableAtLargeTextWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall", "-uitest-largeText"]
        app.launch()

        let join = app.buttons["active-call-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 15), "Pinned Join was not under the title")
        XCTAssertEqual(join.label, "Join the spot call")
        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field was not on screen")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard did not come up")
        XCTAssertTrue(join.isHittable, "Pinned Join was covered with the keyboard up, frame \(join.frame)")
        XCTAssertLessThan(join.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.scrollViews["message-list"]
        var swipes = 0
        while !element.isHittable, swipes < 12 {
            if list.exists { list.swipeUp() } else { app.swipeUp() }
            swipes += 1
        }
    }

    private func assertListClearsComposer(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let list = app.scrollViews["message-list"]
        let end = app.descendants(matching: .any)["message-list-end"]
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Composer was not on screen", file: file, line: line)
        XCTAssertTrue(end.waitForExistence(timeout: 5), "List end was not in the accessibility tree", file: file, line: line)
        var swipes = 0
        while end.frame.maxY > composer.frame.minY + 1, swipes < 12 {
            if list.exists { list.swipeUp() } else { app.swipeUp() }
            swipes += 1
        }
        XCTAssertLessThanOrEqual(
            end.frame.maxY,
            composer.frame.minY + 1,
            "List content ends under the composer. end \(end.frame) composer \(composer.frame)",
            file: file,
            line: line
        )
        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'message-row-'"))
        if rows.count > 0 {
            var lowest = rows.element(boundBy: 0)
            if rows.count > 1 {
                for index in 1..<rows.count {
                    let row = rows.element(boundBy: index)
                    if row.frame.maxY > lowest.frame.maxY { lowest = row }
                }
            }
            XCTAssertLessThanOrEqual(
                lowest.frame.maxY,
                composer.frame.minY + 1,
                "Last row is under the composer. row \(lowest.frame) composer \(composer.frame)",
                file: file,
                line: line
            )
        }
    }

    func testMockInviteSendShowsTheRow() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Message field was not on the invite screen")
        assertListClearsComposer(app)
        let send = app.buttons["send-message"]
        XCTAssertTrue(send.waitForExistence(timeout: 5), "Send was not on screen")
        XCTAssertTrue(send.isHittable, "Send is covered, frame \(send.frame)")
        field.tap()
        field.typeText("hello")
        XCTAssertTrue(send.isHittable, "Send dropped under the keyboard, frame \(send.frame)")
        send.tap()
        let sent = app.descendants(matching: .any).matching(
            NSPredicate(
                format: "(identifier BEGINSWITH 'message-row-' AND identifier != 'message-row-seed-1') OR label CONTAINS 'hello'"
            )
        ).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5), "Sent message did not appear")
    }
}
