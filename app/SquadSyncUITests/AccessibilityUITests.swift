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

        let chip = app.buttons["reaction-chip-hand.thumbsup.fill"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The reaction chip was not visible")
        XCTAssertEqual(chip.label, "Thumbs up, 1 reaction, including yours")

        thumbs.tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "The reaction chip stayed after it was removed")
    }

    func testMockSpotCallJoinAndReady() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Squad title was not on the chat screen")
        XCTAssertEqual(title.label, "Friday · 5 of 8")
        XCTAssertGreaterThan(title.frame.height, 1, "Squad title was squeezed out, frame \(title.frame)")
        XCTAssertTrue(app.windows.firstMatch.frame.intersects(title.frame), "Squad title is off screen, frame \(title.frame)")
        let heading = app.descendants(matching: .any)["spot-title"]
        XCTAssertTrue(heading.waitForExistence(timeout: 15), "Spot title was not on the card")
        XCTAssertTrue(heading.label.contains("Calling spots"))
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

    func testExpiredSpotStillOffersCallSpots() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallExpired"]
        app.launch()

        let stale = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(stale.waitForExistence(timeout: 15), "The stale spot was not on screen as history")
        XCTAssertTrue(stale.label.contains("expired"), "The stale call did not read as expired: \(stale.label)")
        XCTAssertFalse(app.descendants(matching: .any)["spot-card"].exists, "An expired call kept the full card")
        let call = app.buttons["call-spots"]
        XCTAssertTrue(call.waitForExistence(timeout: 5), "Call spots was hidden by the expired card")
        XCTAssertEqual(call.label, "Call spots")
        reveal(call, in: app)
        call.tap()
        let replacement = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(replacement.waitForExistence(timeout: 5))
        XCTAssertTrue(replacement.label.contains("left"), "The new call did not replace the stale one, label \(replacement.label)")
        XCTAssertFalse(app.buttons["call-spots"].exists)
        let archived = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(archived.waitForExistence(timeout: 5), "The replaced call did not move into the thread as history")
        XCTAssertTrue(archived.label.contains("Warzone"))
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

        let history = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "The cancelled call did not turn into a history card")
        XCTAssertTrue(history.label.contains("cancelled"), "History card label: \(history.label)")
        XCTAssertFalse(app.buttons["spot-join"].exists)
        XCTAssertFalse(app.buttons["spot-lock"].exists)
        XCTAssertFalse(app.buttons["spot-cancel"].exists)
    }

    func testCallerEndsALockedSpot() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine"]
        app.launch()

        let lock = app.buttons["spot-lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 15), "Lock was not on the caller's card")
        reveal(lock, in: app)
        lock.tap()

        let end = app.buttons["spot-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "End spot was not on the locked card")
        XCTAssertEqual(end.label, "End the spot call")
        reveal(end, in: app)
        end.tap()

        let confirm = app.buttons["spot-end-confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "End confirmation was not shown")
        confirm.tap()

        let history = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "The ended call did not turn into a history card")
        XCTAssertTrue(history.label.contains("ended"), "History card label: \(history.label)")
        XCTAssertFalse(app.buttons["spot-end"].exists)
        XCTAssertFalse(app.buttons["spot-lock"].exists)
    }

    func testCancelEndKeepsTheSpotLocked() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine"]
        app.launch()

        let lock = app.buttons["spot-lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 15), "Lock was not on the caller's card")
        reveal(lock, in: app)
        lock.tap()

        let end = app.buttons["spot-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "End spot was not on the locked card")
        reveal(end, in: app)
        end.tap()

        let cancel = app.buttons["spot-end-cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Cancel was not on the end confirmation")
        XCTAssertEqual(cancel.label, "Cancel")
        cancel.tap()

        let status = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Locked")
        XCTAssertTrue(app.buttons["spot-end"].waitForExistence(timeout: 5), "End spot left after Cancel")
        XCTAssertFalse(app.buttons["spot-end-confirm"].exists)
    }

    func testEndSpotStaysHittableAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine", "-uitest-largeText"]
        app.launch()

        let lock = app.buttons["spot-lock"]
        XCTAssertTrue(lock.waitForExistence(timeout: 15), "Lock was not on the caller's card at large text")
        reveal(lock, in: app)
        lock.tap()

        let end = app.buttons["spot-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5), "End spot was not on the locked card at large text")
        reveal(end, in: app)
        XCTAssertTrue(end.isHittable, "End spot was not reachable at the largest text size")
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Composer was not on screen")
        XCTAssertLessThanOrEqual(end.frame.maxY + 8, composer.frame.minY, "End spot is under the composer")
        XCTAssertLessThan(end.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
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
        XCTAssertLessThanOrEqual(join.frame.maxY + 8, composer.frame.minY, "Card Join is still under the composer")
        XCTAssertLessThan(join.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
        XCTAssertTrue(app.descendants(matching: .any)["spot-countdown"].exists)
        assertListClearsComposer(app)
    }

    func testPinnedJoinStaysHittableAtLargeTextWithKeyboard() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall", "-uitest-largeText"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Squad title was not on the chat screen at large text")
        XCTAssertEqual(title.label, "Friday · 5 of 8")
        XCTAssertGreaterThan(title.frame.height, 1, "Squad title was squeezed out at large text, frame \(title.frame)")
        let join = app.buttons["active-call-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 15), "Pinned Join was not under the title")
        XCTAssertLessThanOrEqual(title.frame.maxY, join.frame.minY + 1, "Pinned Join covers the squad title")
        XCTAssertEqual(join.label, "Join the spot call")
        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Message field was not on screen")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3), "Keyboard did not come up")
        XCTAssertTrue(join.isHittable, "Pinned Join was covered with the keyboard up, frame \(join.frame)")
        XCTAssertLessThan(join.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
    }

    private func tapJoin(in app: XCUIApplication) {
        let join = app.buttons["join-squad"]
        XCTAssertTrue(join.waitForExistence(timeout: 5), "Join was not in the members sheet")
        if join.isHittable {
            join.tap()
        } else {
            join.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }

    /// Scrolls until the element is hittable and, when the chat composer is on screen,
    /// sits fully above it with the 8-point gap the assertions check. A control whose
    /// center has just crossed the list's bottom edge is hittable but still clipped,
    /// so hittable alone is not "revealed".
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        let list = app.scrollViews["message-list"]
        let composer = app.descendants(matching: .any)["composer"]
        var moves = 0
        while !revealed(element, above: composer), moves < 24 {
            if list.exists {
                let start = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72))
                let end = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
                start.press(forDuration: 0.01, thenDragTo: end)
            } else {
                app.swipeUp()
            }
            moves += 1
        }
    }

    private func revealed(_ element: XCUIElement, above composer: XCUIElement) -> Bool {
        guard element.isHittable else { return false }
        guard composer.exists else { return true }
        return element.frame.maxY + 8 <= composer.frame.minY
    }

    private func assertListClearsComposer(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let list = app.scrollViews["message-list"]
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5), "Composer was not on screen", file: file, line: line)
        var end = app.descendants(matching: .any)["message-list-end"]
        var swipes = 0
        while !end.exists, swipes < 30 {
            if list.exists { list.swipeUp() } else { app.swipeUp() }
            swipes += 1
            end = app.descendants(matching: .any)["message-list-end"]
        }
        XCTAssertTrue(end.waitForExistence(timeout: 2), "List end was not in the accessibility tree after scrolling", file: file, line: line)
        swipes = 0
        while end.frame.maxY > composer.frame.minY + 1, swipes < 8 {
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
                lowest.frame.maxY + 8,
                composer.frame.minY,
                "Last row footer is under the composer. row \(lowest.frame) composer \(composer.frame)",
                file: file,
                line: line
            )
        }
    }

    func testMockInviteLeaveAndRejoin() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "Squad title was not on the invite screen")
        XCTAssertEqual(title.label, "Friday · 2 of 8")
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 5), "Members button was not in the bar")
        members.tap()

        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Member count was not in the sheet")
        XCTAssertEqual(count.label, "Friday · 2 of 8")
        XCTAssertTrue(app.descendants(matching: .any)["invite-empty"].waitForExistence(timeout: 5), "Empty invite state was missing")
        app.buttons["create-invite"].tap()
        let code = app.descendants(matching: .any)["invite-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 5), "Invite code was not shown")
        XCTAssertEqual(code.label, "ABCD2345")
        XCTAssertFalse(app.descendants(matching: .any)["invite-empty"].exists)

        app.buttons["remove-Riley"].tap()
        let status = app.descendants(matching: .any)["membership-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Removed Riley.")
        XCTAssertEqual(count.label, "Friday · 1 of 8")

        let field = app.textFields["join-code"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Join field was not in the sheet")
        field.tap()
        field.typeText("JOIN2345")
        tapJoin(in: app)
        XCTAssertEqual(status.label, "Joined.")
        XCTAssertEqual(count.label, "Friday · 2 of 8")

        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        field.typeText("EXPIRED2")
        tapJoin(in: app)
        XCTAssertEqual(status.label, "This invite has expired.")
        XCTAssertEqual(count.label, "Friday · 2 of 8")
    }

    func testMockLeaveSquadThenRejoin() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "Members button was not in the bar")
        members.tap()
        let leave = app.buttons["leave-squad"]
        XCTAssertTrue(leave.waitForExistence(timeout: 5), "Leave was not in the members sheet")
        leave.tap()
        XCTAssertTrue(app.descendants(matching: .any)["confirm-leave-title"].waitForExistence(timeout: 5))
        let confirm = app.buttons["confirm-leave"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Leave did not ask for confirmation")
        confirm.tap()
        let status = app.descendants(matching: .any)["membership-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Choose the next owner before you leave.")
        XCTAssertTrue(app.descendants(matching: .any)["transfer-prompt"].exists)

        app.buttons["transfer-Riley"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["transfer-prompt"].exists)
        XCTAssertFalse(status.exists)
        app.buttons["confirm-leave"].tap()

        XCTAssertTrue(app.staticTexts["You're not in a squad yet."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields.matching(identifier: "join-code").count, 1)
        XCTAssertEqual(app.buttons.matching(identifier: "join-squad").count, 1)

        let field = app.textFields["join-code"]
        field.tap()
        field.typeText("JOIN2345")
        tapJoin(in: app)
        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Friday · 2 of 8")
    }

    func testMembersSheetUsesTheLaunchTextSize() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15))
        members.tap()
        let heading = app.staticTexts["Members"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5), "Members title was not in the sheet")
        XCTAssertGreaterThan(heading.frame.height, 40, "Members sheet did not pick up the launch text size, height \(heading.frame.height)")
    }

    func testDebugFailSendRetriesIntoOneBubble() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-fail-sends", "1"]
        app.launch()

        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("once")
        app.buttons["send-message"].tap()
        let retry = app.buttons["retry-send"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "Failed send did not offer Retry")
        XCTAssertTrue(caption("Not delivered", in: app).exists, "The failed send didn't say Not delivered")
        if retry.isHittable {
            retry.tap()
        } else {
            retry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let sent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, once, "))
        XCTAssertTrue(sent.firstMatch.waitForExistence(timeout: 5), "Sent bubble did not appear")
        XCTAssertEqual(sent.count, 1)
        XCTAssertFalse(app.buttons["retry-send"].waitForExistence(timeout: 2))
        XCTAssertTrue(
            app.descendants(matching: .any)["home-status"].waitForNonExistence(timeout: 3),
            "The failed-send line stayed after the retry went through"
        )
    }

    func testMockEighthJoinFillsAndNinthIsRejected() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "almostFull"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertEqual(title.label, "Friday · 7 of 8")
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 5), "Members button was not in the bar")
        members.tap()
        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "Friday · 7 of 8")
        let field = app.textFields["join-code"]
        field.tap()
        field.typeText("JOIN2345")
        tapJoin(in: app)
        let status = app.descendants(matching: .any)["membership-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Joined.")
        XCTAssertEqual(count.label, "Friday · 8 of 8")
        tapJoin(in: app)
        XCTAssertEqual(status.label, "That squad is full (8).")
        XCTAssertEqual(count.label, "Friday · 8 of 8")
    }

    func testOwnerRemoveStaysOneControlAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "Members button was not in the bar")
        members.tap()
        let remove = app.buttons["remove-Riley"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5), "Remove was not in the members sheet")
        XCTAssertEqual(app.buttons.matching(identifier: "remove-Riley").count, 1)
        XCTAssertEqual(remove.label, "Remove Riley")
        reveal(remove, in: app)
        XCTAssertTrue(remove.isHittable, "Remove was not one hittable control at the largest text size")
        XCTAssertLessThan(remove.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
        XCTAssertGreaterThan(remove.frame.height, 1)
    }

    func testPushOpensTheSignedInSquadChat() {
        let app = XCUIApplication()
        let payload = #"{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-0000-0000-00000000A001"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", payload]
        app.launch()

        let opened = app.descendants(matching: .any)["push-opened-chat"]
        XCTAssertTrue(opened.waitForExistence(timeout: 15), "The chat from the notification did not open")
        XCTAssertEqual(opened.label, "Opened this chat.")
        XCTAssertTrue(opened.isHittable, "Opened this chat. was not on screen")
        XCTAssertGreaterThan(opened.frame.height, 1)
        XCTAssertFalse(app.descendants(matching: .any)["push-notice"].exists)
    }

    func testPushBeforeASquadSaysYouAreNotInIt() {
        let app = XCUIApplication()
        let payload = #"{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-0000-0000-00000000A001"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "noSquad", "-debug-push-open", payload]
        app.launch()

        let notice = app.descendants(matching: .any)["push-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 15), "A squad you have not joined did not explain itself")
        XCTAssertEqual(notice.label, "You're not in that squad.")
        XCTAssertTrue(notice.isHittable, "You're not in that squad. was not on screen")
        XCTAssertGreaterThan(notice.frame.height, 1)
        XCTAssertFalse(app.descendants(matching: .any)["push-opened-chat"].exists)
    }

    func testPushForALeftSquadSaysSo() {
        let app = XCUIApplication()
        let payload = #"{"type":"squad","squad_id":"00000000-0000-0000-0000-000000000099"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", payload]
        app.launch()

        let notice = app.descendants(matching: .any)["push-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 15), "A former squad did not explain itself")
        XCTAssertEqual(notice.label, "You're not in that squad.")
        XCTAssertTrue(notice.isHittable, "You're not in that squad. was not on screen")
        XCTAssertGreaterThan(notice.frame.height, 1)
        XCTAssertFalse(app.descendants(matching: .any)["push-opened-squad"].exists)
    }

    func testOwnerRenamesTheSquad() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "Members button was not in the bar")
        members.tap()
        let field = app.textFields["rename-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Rename was not in the members sheet")
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 12))
        field.typeText("Night")
        app.buttons["rename-squad"].tap()
        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5))
        XCTAssertEqual(count.label, "Night · 2 of 8")
        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertEqual(title.label, "Night · 2 of 8")
    }

    func testRenameStaysHittableAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15), "Members button was not in the bar")
        members.tap()
        let field = app.textFields["rename-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5), "Rename was not in the members sheet at large text")
        reveal(field, in: app)
        XCTAssertTrue(field.isHittable, "Rename was not reachable at the largest text size")
        XCTAssertLessThan(field.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
        let button = app.buttons["rename-squad"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        reveal(button, in: app)
        XCTAssertTrue(button.isHittable, "Rename button was not reachable at the largest text size")
        XCTAssertLessThan(button.frame.maxX, app.windows.firstMatch.frame.maxX + 1)
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

    // MARK: Chat-first home (redesign S1)

    func testSignedInMockOpensStraightIntoTheChat() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 15), "The home screen was not the squad chat")
        XCTAssertTrue(app.descendants(matching: .any)["message-row-seed-1"].waitForExistence(timeout: 5), "Riley's message was not in the home chat")
        XCTAssertTrue(app.textFields["Message"].exists, "The composer was not on the home screen")
        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The squad header was missing")
        XCTAssertTrue(title.isHittable, "The squad header was not tappable, frame \(title.frame)")
        XCTAssertLessThanOrEqual(title.frame.maxY, list.frame.minY + 1, "The header overlaps the chat")
        XCTAssertFalse(app.textFields["profile-name"].exists, "Profile fields are still on the home screen")
        XCTAssertFalse(app.textFields["Display name"].exists, "Profile fields are still on the home screen")
    }

    func testHeaderOpensTheSquadPanel() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The squad header was missing")
        XCTAssertEqual(title.label, "Friday · 2 of 8")
        title.tap()

        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "Tapping the squad name did not open the squad panel")
        XCTAssertEqual(count.label, "Friday · 2 of 8")
        XCTAssertTrue(app.buttons["remove-Riley"].waitForExistence(timeout: 5), "Members were not in the squad panel")
        XCTAssertTrue(app.textFields["rename-field"].waitForExistence(timeout: 5), "Rename was not in the squad panel")
        let profile = app.textFields["profile-name"]
        XCTAssertTrue(profile.waitForExistence(timeout: 5), "Profile did not move into the squad panel")
        XCTAssertTrue(app.textFields["profile-game"].exists, "Default game did not move into the squad panel")
        XCTAssertTrue(app.buttons["save-profile"].exists, "Save profile was not in the squad panel")
    }

    func testPresenceStripIsPresentAndHittable() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let strip = app.descendants(matching: .any)["presence-strip"]
        XCTAssertTrue(strip.waitForExistence(timeout: 15), "The presence strip was not in the header")
        XCTAssertGreaterThan(strip.frame.height, 1)
        let riley = app.buttons["presence-Riley"]
        XCTAssertTrue(riley.waitForExistence(timeout: 5), "Riley was not in the presence strip")
        XCTAssertTrue(riley.isHittable, "Riley's avatar was not hittable, frame \(riley.frame)")
        XCTAssertTrue(riley.label.contains("presence isn't tracked yet"), "Mock presence claimed a status it does not have: \(riley.label)")
        XCTAssertFalse(riley.label.lowercased().contains("online"))
        let me = app.buttons["presence-You"]
        XCTAssertTrue(me.exists, "The viewer was not in the presence strip")
        XCTAssertTrue(me.isHittable)

        riley.tap()
        XCTAssertTrue(app.descendants(matching: .any)["squad-count"].waitForExistence(timeout: 5), "An avatar did not open the squad panel")
    }

    func testPresenceStripShowsSpotSeats() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall"]
        app.launch()

        let alex = app.buttons["presence-Alex"]
        XCTAssertTrue(alex.waitForExistence(timeout: 15), "Alex was not in the presence strip")
        XCTAssertTrue(alex.label.contains("ready"), "A Ready seat did not show as ready: \(alex.label)")
        let sam = app.buttons["presence-Sam"]
        XCTAssertTrue(sam.exists, "Sam was not in the presence strip")
        XCTAssertTrue(sam.label.contains("in the spot call"), "A seat that is not Ready did not show as in the spot: \(sam.label)")
    }

    func testVoicePillStaysAMock() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let pill = app.buttons["voice-room-pill"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "The voice-room pill was not in the header")
        XCTAssertTrue(pill.isHittable)
        XCTAssertTrue(pill.label.contains("mock"), "The voice pill did not say it is a mock: \(pill.label)")
        XCTAssertTrue(pill.label.contains("Double tap to join."))
        pill.tap()
        let joined = NSPredicate(format: "label CONTAINS %@", "Double tap to leave.")
        let flipped = expectation(for: joined, evaluatedWith: pill)
        wait(for: [flipped], timeout: 5)
    }

    func testPresenceStripStaysHittableAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The squad header was missing at large text")
        XCTAssertGreaterThan(title.frame.height, 1)
        XCTAssertFalse(app.buttons["presence-Riley"].exists, "At large text presence starts folded so the chat keeps the screen")
        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Presence toggle was not in the large-text header")
        XCTAssertTrue(toggle.isHittable)
        XCTAssertEqual(toggle.label, "Show squad presence")
        toggle.tap()
        XCTAssertEqual(toggle.label, "Hide squad presence")
        let riley = app.buttons["presence-Riley"]
        XCTAssertTrue(riley.waitForExistence(timeout: 5), "Riley was not in the presence roster at large text")
        XCTAssertTrue(riley.isHittable, "Riley's avatar was not hittable at large text, frame \(riley.frame)")
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertLessThan(riley.frame.maxY, composer.frame.minY, "The presence strip runs into the composer")
        XCTAssertTrue(app.buttons["members"].isHittable, "Members was squeezed out of the header at large text")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(riley.frame.maxX, window.maxX + 1, "Riley's row runs off the right edge")
        let note = app.descendants(matching: .any)["presence-untracked"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The untracked-presence line was missing at large text")
        XCTAssertEqual(note.label, "Presence isn't live yet")
        XCTAssertLessThanOrEqual(note.frame.maxX, window.maxX + 1, "The untracked-presence line is cut off at the right")
        toggle.tap()
        XCTAssertTrue(riley.waitForNonExistence(timeout: 5), "The roster did not fold again")
    }

    func testHeaderIsOneRowAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall", "-uitest-largeText"]
        app.launch()

        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The squad header was missing at large text")
        let members = app.buttons["members"]
        let account = app.buttons["account"]
        XCTAssertTrue(members.waitForExistence(timeout: 5))
        XCTAssertTrue(members.isHittable, "Members was not hittable in the one-row header")
        XCTAssertTrue(account.isHittable, "Account was not hittable in the one-row header")
        XCTAssertLessThan(abs(members.frame.midY - title.frame.midY), title.frame.height, "Members dropped to a second header row, members \(members.frame) title \(title.frame)")
        XCTAssertLessThan(abs(account.frame.midY - title.frame.midY), title.frame.height, "Account dropped to a second header row")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(title.frame.maxY, window.height * 0.22, "The header takes too much of the screen at large text, title \(title.frame)")
        let bar = app.descendants(matching: .any)["active-call-bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "The pinned spot bar was missing")
        XCTAssertLessThan(bar.frame.height, window.height * 0.22, "The pinned spot bar is not compact at large text, frame \(bar.frame)")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.exists)
        XCTAssertGreaterThan(list.frame.height, window.height * 0.4, "The chat keeps less than 40% of the screen at large text, list \(list.frame)")
        let closedHeight = list.frame.height

        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "Presence toggle was not in the large-text header")
        toggle.tap()
        let alex = app.buttons["presence-Alex"]
        XCTAssertTrue(alex.waitForExistence(timeout: 5), "Alex was not in the presence roster during the spot")
        XCTAssertTrue(alex.isHittable, "The roster row was covered during the spot, frame \(alex.frame)")
        XCTAssertGreaterThan(list.frame.height, window.height * 0.4, "Opening presence during a spot squeezed the chat, list \(list.frame)")
        XCTAssertEqual(list.frame.height, closedHeight, accuracy: 1, "The roster pushed the chat down instead of floating over it")
        XCTAssertTrue(app.buttons["active-call-cancel"].exists || app.buttons["active-call-join"].exists, "The pinned bar's action went missing with the roster open")
        XCTAssertTrue(app.textFields["Message"].isHittable, "The roster covered the composer")
        toggle.tap()
        XCTAssertTrue(alex.waitForNonExistence(timeout: 5), "The roster did not fold again")
    }

    func testCardCancelSitsInsideTheChatAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine", "-uitest-largeText"]
        app.launch()

        let cancel = app.buttons["spot-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15), "The card's Cancel was not on the caller's card at large text")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertGreaterThan(list.frame.height, window.height * 0.4, "The chat keeps less than 40% of the screen with the spot open, list \(list.frame)")
        reveal(cancel, in: app)
        XCTAssertTrue(cancel.isHittable, "The card's Cancel was not reachable at the largest text size")
        let frame = cancel.frame
        let visible = list.frame
        XCTAssertGreaterThanOrEqual(frame.minY, visible.minY - 1, "The card's Cancel runs above the chat list. cancel \(frame) list \(visible)")
        XCTAssertLessThanOrEqual(frame.maxY, visible.maxY + 1, "The card's Cancel runs below the chat list. cancel \(frame) list \(visible)")
        let composer = app.descendants(matching: .any)["composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(frame.maxY + 8, composer.frame.minY, "The card's Cancel is under the composer")
        XCTAssertLessThanOrEqual(frame.maxX, window.maxX + 1)
        cancel.tap()
        let history = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "Cancelling from the card did not cancel the call")
        XCTAssertTrue(history.label.contains("cancelled"))
    }

    func testPresenceDecorationsAreNotReadAloud() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let note = app.descendants(matching: .any)["presence-untracked"]
        XCTAssertTrue(note.waitForExistence(timeout: 15), "The untracked-presence pill was missing")
        XCTAssertEqual(note.label, "Presence isn't live yet")
        XCTAssertTrue(note.isHittable || note.frame.width > 0)
        XCTAssertLessThanOrEqual(note.frame.maxX, app.windows.firstMatch.frame.maxX + 1, "The untracked pill is cut off at the right")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "presence-untracked").count, 1, "The pill's symbol is a second element")
        let symbolNames = ["antenna", "radiowaves", "mic.slash", "waveform", "gamecontroller", "checkmark", "lock.fill", "chevron", "person.3", "person.2", "ellipsis"]
        let format = symbolNames.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed to VoiceOver: \(leaked.allElementsBoundByIndex.map(\.label))")
        let me = app.buttons["presence-You"]
        XCTAssertTrue(me.exists)
        XCTAssertTrue(me.label.hasPrefix("You"), "The viewer's avatar does not identify you: \(me.label)")
    }

    func testSquadPanelGroupsSectionsAndKeepsIdentifiers() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15))
        members.tap()
        XCTAssertTrue(app.staticTexts["Members"].waitForExistence(timeout: 5), "The panel title was missing")
        for heading in ["Join with a code", "In this squad", "Rename", "Invite", "Your profile"] {
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5), "Panel section \(heading) was missing")
        }
        XCTAssertTrue(app.buttons["leave-squad"].waitForExistence(timeout: 5), "Leave did not appear after the probe")
        XCTAssertTrue(app.textFields["rename-field"].waitForExistence(timeout: 5), "Rename did not appear after the probe")
        for identifier in ["squad-count", "join-code", "join-squad", "remove-Riley", "leave-squad", "rename-field", "rename-squad", "create-invite", "invite-empty", "profile-name", "profile-game", "save-profile"] {
            XCTAssertEqual(
                app.descendants(matching: .any).matching(identifier: identifier).count,
                1,
                "\(identifier) is missing or duplicated in the restyled panel"
            )
        }
    }

    // MARK: S2 spot card

    private func tapMenuCallSpots(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let plus = app.buttons["composer-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "The composer's + menu was missing", file: file, line: line)
        XCTAssertTrue(plus.isHittable, "The composer's + menu was not hittable, frame \(plus.frame)", file: file, line: line)
        plus.tap()
        let item = app.buttons["composer-call-spots"]
        if item.waitForExistence(timeout: 3) {
            item.tap()
            return
        }
        let fallback = app.collectionViews.buttons["Call spots"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Call spots was not in the + menu", file: file, line: line)
        fallback.tap()
    }

    private func sendCommand(_ text: String, in app: XCUIApplication) {
        let field = app.textFields["Message"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "Message field was missing")
        field.tap()
        field.typeText(text)
        app.buttons["send-message"].tap()
    }

    private func historyCard(_ game: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "spot-history")
            .matching(NSPredicate(format: "label CONTAINS %@", game))
            .firstMatch
    }

    func testPlusMenuCallsSpotsFromTheComposer() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"]
        app.launch()

        XCTAssertFalse(app.descendants(matching: .any)["spot-card"].exists, "There should be no open call yet")
        tapMenuCallSpots(app)
        let game = app.textFields["spot-sheet-game"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "The call sheet did not open from the + menu")
        let call = app.buttons["spot-sheet-call"]
        XCTAssertTrue(call.isHittable)
        call.tap()
        XCTAssertTrue(call.waitForNonExistence(timeout: 5), "The call sheet stayed open after a successful call")
        let title = app.descendants(matching: .any)["spot-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "The new call did not pin its card in the chat")
        XCTAssertTrue(title.label.contains("Warzone"), "Card title: \(title.label)")
        XCTAssertTrue(app.descendants(matching: .any)["active-call-bar"].waitForExistence(timeout: 5), "The pinned bar did not appear for the active call")
        XCTAssertFalse(app.buttons["call-spots"].exists, "Call spots stayed offered while a call is active")
    }

    func testPlusMenuWithAnActiveCallSaysOneIsOpen() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall"]
        app.launch()

        tapMenuCallSpots(app)
        XCTAssertFalse(app.buttons["spot-sheet-call"].waitForExistence(timeout: 2), "A second call sheet opened over an active call")
        let note = app.descendants(matching: .any)["spot-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertEqual(note.label, "This squad already has a spot call.")
    }

    func testSlashSpotsWithAGameCallsRightAway() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"]
        app.launch()

        sendCommand("/spots Halo", in: app)
        let title = app.descendants(matching: .any)["spot-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5), "/spots Halo did not call spots")
        XCTAssertTrue(title.label.contains("Halo"), "Card title: \(title.label)")
        let sent = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "/spots"))
        XCTAssertEqual(sent.count, 0, "The command was sent as a chat message")
    }

    func testBareSlashSpotsOpensTheCallSheet() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"]
        app.launch()

        sendCommand("/spots", in: app)
        let call = app.buttons["spot-sheet-call"]
        XCTAssertTrue(call.waitForExistence(timeout: 5), "/spots did not open the call sheet")
        app.buttons["spot-sheet-cancel"].tap()
        XCTAssertTrue(call.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["spot-card"].exists, "Not now still called spots")
    }

    func testPinnedCardTurnsIntoHistoryWhenCancelled() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCallMine"]
        app.launch()

        let card = app.descendants(matching: .any)["spot-card"]
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let bar = app.descendants(matching: .any)["active-call-bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 5), "The active call was not pinned")
        let cancel = app.buttons["spot-cancel"]
        reveal(cancel, in: app)
        cancel.tap()
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "The full card stayed after cancel")
        XCTAssertTrue(bar.waitForNonExistence(timeout: 5), "The pinned bar stayed after cancel")
        let history = app.descendants(matching: .any)["spot-history"]
        XCTAssertTrue(history.waitForExistence(timeout: 5), "No history card after cancel")
        XCTAssertTrue(history.label.hasPrefix("Spot call for Warzone, cancelled"), "History label: \(history.label)")
        XCTAssertTrue(app.buttons["call-spots"].waitForExistence(timeout: 5), "Call spots did not come back after cancel")
    }

    func testHistoryCardsSitBetweenMessagesInTimeOrder() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"]
        app.launch()

        let first = app.descendants(matching: .any)["message-row-00000000-0000-0000-0000-000000000201"]
        let middle = app.descendants(matching: .any)["message-row-00000000-0000-0000-0000-000000000202"]
        let last = app.descendants(matching: .any)["message-row-00000000-0000-0000-0000-000000000203"]
        let apex = historyCard("Apex", in: app)
        let valorant = historyCard("Valorant", in: app)
        for element in [first, middle, last, apex, valorant] {
            XCTAssertTrue(element.waitForExistence(timeout: 15), "A thread row was missing: \(element)")
        }
        XCTAssertLessThan(first.frame.minY, apex.frame.minY)
        XCTAssertLessThan(apex.frame.minY, middle.frame.minY)
        XCTAssertLessThan(middle.frame.minY, valorant.frame.minY)
        XCTAssertLessThan(valorant.frame.minY, last.frame.minY)
        XCTAssertTrue(apex.label.contains("ended"))
        XCTAssertTrue(apex.label.contains("4 people joined"), "Apex label: \(apex.label)")
        XCTAssertTrue(valorant.label.contains("cancelled"))
        XCTAssertFalse(app.descendants(matching: .any)["spot-card"].exists, "A finished call kept the full card")
    }

    func testServerWithoutSpotRpcsSaysSo() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotServerMissing"]
        app.launch()

        let note = app.descendants(matching: .any)["spot-history-note"]
        XCTAssertTrue(note.waitForExistence(timeout: 15), "The failed history read was silent")
        tapMenuCallSpots(app)
        let call = app.buttons["spot-sheet-call"]
        XCTAssertTrue(call.waitForExistence(timeout: 5))
        call.tap()
        let error = app.descendants(matching: .any)["spot-sheet-error"]
        XCTAssertTrue(error.waitForExistence(timeout: 5), "The sheet did not say why the call failed")
        XCTAssertEqual(error.label, "Spot calls aren't set up on this server yet.")
        XCTAssertTrue(call.exists, "The sheet closed even though the call failed")
        app.buttons["spot-sheet-cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["spot-card"].exists)
    }

    func testSpotCardPathsStayUsableAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory", "-uitest-largeText"]
        app.launch()

        let valorant = historyCard("Valorant", in: app)
        XCTAssertTrue(valorant.waitForExistence(timeout: 15))
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(valorant.frame.maxX, window.maxX + 1, "The history card runs off the right edge")
        tapMenuCallSpots(app)
        let call = app.buttons["spot-sheet-call"]
        XCTAssertTrue(call.waitForExistence(timeout: 5))
        var swipes = 0
        while !call.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(call.isHittable, "The sheet's Call spots was not reachable at AX5")
        call.tap()
        // The caller's bar offers Lock (mock calls have no Ready gate) or Cancel.
        let lock = app.buttons["active-call-lock"]
        let cancel = app.buttons["active-call-cancel"]
        XCTAssertTrue(lock.waitForExistence(timeout: 5) || cancel.exists, "The pinned bar's action was missing at AX5")
        XCTAssertTrue(lock.exists ? lock.isHittable : cancel.isHittable, "The pinned bar's action was not hittable at AX5")
        let symbolNames = ["plus.circle", "antenna", "radiowaves", "mic.slash", "waveform", "checkmark", "lock.fill", "chevron", "ellipsis"]
        let format = symbolNames.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed to VoiceOver: \(leaked.allElementsBoundByIndex.map(\.label))")
    }

    // MARK: AX5 presence roster regressions

    func testPresenceRosterShowsItsLastRowAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()

        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let roster = app.descendants(matching: .any)["presence-strip"]
        let note = app.descendants(matching: .any)["presence-untracked"]
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The roster's last row was missing")
        XCTAssertLessThanOrEqual(note.frame.maxY, roster.frame.maxY + 1, "The last row is cut off by the roster. note \(note.frame) roster \(roster.frame)")
        let list = app.scrollViews["message-list"]
        XCTAssertLessThanOrEqual(note.frame.maxY, list.frame.maxY + 1, "The last row runs past the chat list. note \(note.frame) list \(list.frame)")
        XCTAssertFalse(roster.scrollViews.firstMatch.exists, "The roster scrolls instead of fitting")
    }

    func testPresenceRosterKeepsThePinnedBarVisibleAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotCall", "-uitest-largeText"]
        app.launch()

        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let roster = app.descendants(matching: .any)["presence-strip"]
        XCTAssertTrue(roster.waitForExistence(timeout: 5))
        let bar = app.descendants(matching: .any)["active-call-bar"]
        XCTAssertTrue(bar.exists)
        XCTAssertGreaterThanOrEqual(roster.frame.minY, bar.frame.maxY - 1, "The roster covers the pinned bar. roster \(roster.frame) bar \(bar.frame)")
        let join = app.buttons["active-call-join"]
        XCTAssertTrue(join.isHittable, "The pinned Join was covered with the roster open")
        let list = app.scrollViews["message-list"]
        XCTAssertGreaterThan(list.frame.height, app.windows.firstMatch.frame.height * 0.4, "The chat dropped under 40% with the roster open")
    }

    /// The roster's empty space must let a tap reach the message button under it.
    /// The tap point is a real hittable message button under an empty part of the
    /// open roster. A control tap at the same point with the roster closed must
    /// select the message first, so the test can't pass on a point that never works.
    func testPresenceRosterPassesEmptyTapsToTheChat() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-uitest-largeText"]
        app.launch()

        // Find the point with the roster open.
        openRoster(app)
        guard let pick = emptyRosterPointOverMessageButton(app) else {
            XCTFail("No hittable message button lies under an empty area of the open roster. roster \(rosterFrame(app)), kids \(rosterKidFrames(app)), buttons \(messageButtonFrames(app))")
            return
        }

        // Control: roster closed, same point, the tap selects the message.
        app.buttons["presence-toggle"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["presence-strip"].waitForNonExistence(timeout: 5), "The roster didn't close for the control tap")
        let controlButton = messageButton(app, label: pick.label)
        XCTAssertTrue(controlButton.exists && controlButton.isHittable, "Control: message button '\(pick.label)' isn't hittable with the roster closed")
        XCTAssertTrue(controlButton.frame.contains(pick.point), "Control: the point \(pick.point) left '\(pick.label)' \(controlButton.frame) when the roster closed")
        tap(app, at: pick.point)
        XCTAssertTrue(app.buttons["react"].waitForExistence(timeout: 3), "Control: with the roster closed, tapping '\(pick.label)' at \(pick.point) didn't show React, so the point is not a working tap target")

        // Dismiss: the app has no deselect, so relaunch to clear the selection.
        app.terminate()
        app.launch()
        XCTAssertFalse(app.buttons["react"].waitForExistence(timeout: 2), "React was still showing after relaunch")

        // Roster open, same point, the tap reaches the same message.
        openRoster(app)
        let roster = app.descendants(matching: .any)["presence-strip"]
        XCTAssertTrue(roster.frame.contains(pick.point), "The roster moved off the point \(pick.point), roster \(roster.frame)")
        let kids = rosterKidFrames(app)
        XCTAssertFalse(kids.contains { $0.insetBy(dx: -4, dy: -4).contains(pick.point) }, "The point \(pick.point) is now on a roster control, kids \(kids)")
        let button = messageButton(app, label: pick.label)
        XCTAssertTrue(button.frame.contains(pick.point), "The point \(pick.point) left '\(pick.label)' \(button.frame) with the roster open")
        let voice = app.buttons["voice-room-pill"]
        let voiceLabel = voice.exists ? voice.label : nil
        tap(app, at: pick.point)
        XCTAssertTrue(app.buttons["react"].waitForExistence(timeout: 3), "The tap on the roster's empty area at \(pick.point) did not reach '\(pick.label)' under it")
        XCTAssertTrue(roster.exists, "The tap closed the roster, so it hit a roster control")
        XCTAssertFalse(app.descendants(matching: .any)["squad-count"].exists, "The tap opened the squad panel, so it hit a roster row or 'more'")
        if let voiceLabel {
            XCTAssertEqual(app.buttons["voice-room-pill"].label, voiceLabel, "The tap toggled the voice room")
        }
    }

    private struct RosterTapPoint {
        let point: CGPoint
        let label: String
    }

    private func openRoster(_ app: XCUIApplication) {
        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        XCTAssertTrue(app.descendants(matching: .any)["presence-strip"].waitForExistence(timeout: 5), "The roster didn't open")
    }

    private func rosterFrame(_ app: XCUIApplication) -> CGRect {
        app.descendants(matching: .any)["presence-strip"].frame
    }

    /// Every element inside the roster (rows, their text, the voice pill, "more").
    private func rosterKidFrames(_ app: XCUIApplication) -> [CGRect] {
        let roster = app.descendants(matching: .any)["presence-strip"]
        let whole = roster.frame
        return roster.descendants(matching: .any).allElementsBoundByIndex
            .map(\.frame)
            .filter { !$0.isEmpty && $0 != whole }
    }

    /// Buttons in the message list that are not part of the roster. The control tap
    /// checks the chosen one is hittable with the roster closed.
    private func messageButtons(_ app: XCUIApplication) -> [XCUIElement] {
        let kids = Set(rosterKidFrames(app).map { "\($0)" })
        return app.scrollViews["message-list"].buttons.allElementsBoundByIndex.filter { button in
            let id = button.identifier
            return !id.hasPrefix("presence-") && id != "voice-room-pill"
                && !button.label.isEmpty
                && !kids.contains("\(button.frame)")
        }
    }

    private func messageButtonFrames(_ app: XCUIApplication) -> [String] {
        messageButtons(app).map { "'\($0.label)' \($0.frame)" }
    }

    private func messageButton(_ app: XCUIApplication, label: String) -> XCUIElement {
        app.scrollViews["message-list"].buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// Scans the open roster for a point inside a hittable message button that no
    /// roster element covers, with a 4 pt margin on every side.
    private func emptyRosterPointOverMessageButton(_ app: XCUIApplication) -> RosterTapPoint? {
        let roster = rosterFrame(app).insetBy(dx: 4, dy: 4)
        let list = app.scrollViews["message-list"].frame
        let kids = rosterKidFrames(app).map { $0.insetBy(dx: -4, dy: -4) }
        for button in messageButtons(app) {
            let area = roster.intersection(button.frame.insetBy(dx: 4, dy: 4)).intersection(list)
            guard !area.isNull, !area.isEmpty else { continue }
            var y = area.minY
            while y <= area.maxY {
                var x = area.maxX
                while x >= area.minX {
                    let point = CGPoint(x: x, y: y)
                    if !kids.contains(where: { $0.contains(point) }) {
                        return RosterTapPoint(point: point, label: button.label)
                    }
                    x -= 4
                }
                y += 4
            }
        }
        return nil
    }

    private func tap(_ app: XCUIApplication, at point: CGPoint) {
        let origin = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
    }

    // MARK: Message polish (redesign S3)

    private enum Polish {
        static func id(_ suffix: Int) -> String {
            "message-row-00000000-0000-0000-0000-" + String(format: "%012X", 0x300 + suffix)
        }
        static let question = id(0x21)
        static let alexSecond = id(0x22)
        static let mineFirst = id(0x23)
        static let longLine = id(0x24)
        static let firstUnread = id(0x25)
        static let reply = id(0x26)
        static let thumbs = "reaction-chip-hand.thumbsup.fill"
    }

    private func launchChat(_ scenario: String, largeText: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", scenario] + (largeText ? ["-uitest-largeText"] : []) + extra
        app.launch()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func caption(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "delivery-caption")
            .matching(NSPredicate(format: "label == %@", text))
            .firstMatch
    }

    /// Scrolls the chat until the element is hittable: up toward older messages
    /// first, then back down.
    @discardableResult
    private func reveal(_ target: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let list = app.scrollViews["message-list"]
        for direction in [true, false] {
            for _ in 0..<10 {
                if target.exists && target.isHittable { return true }
                if direction { list.swipeDown() } else { list.swipeUp() }
            }
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "Couldn't scroll to \(target)", file: file, line: line)
        return found
    }

    /// The message bubble inside a row: the row's first button.
    private func bubble(_ rowIdentifier: String, in app: XCUIApplication) -> XCUIElement {
        element(rowIdentifier, in: app).buttons.element(boundBy: 0)
    }

    private func waitForLabel(_ target: XCUIElement, _ predicate: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: target)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    func testThreadGroupsBySenderUnderDaySeparators() {
        let app = launchChat("chatPolish")
        let latest = element(Polish.reply, in: app)
        XCTAssertTrue(latest.waitForExistence(timeout: 15), "The seeded thread didn't load")
        let days = app.descendants(matching: .any).matching(identifier: "day-separator")
        let today = days.matching(NSPredicate(format: "label == 'Today'")).firstMatch
        XCTAssertTrue(reveal(today, in: app), "No Today separator")
        let yesterday = days.matching(NSPredicate(format: "label == 'Yesterday'")).firstMatch
        XCTAssertTrue(reveal(yesterday, in: app), "No Yesterday separator")
        XCTAssertTrue(yesterday.frame.maxY <= today.frame.minY || !today.exists, "Yesterday should sit above Today")

        let first = element(Polish.question, in: app)
        reveal(first, in: app)
        let second = element(Polish.alexSecond, in: app)
        let mine = element(Polish.mineFirst, in: app)
        XCTAssertTrue(second.exists && mine.exists)
        XCTAssertTrue(bubble(Polish.question, in: app).label.hasPrefix("Alex, Who's on tonight?, "), bubble(Polish.question, in: app).label)
        XCTAssertTrue(bubble(Polish.alexSecond, in: app).label.hasPrefix("Alex, I can do 9, "))
        let inGroup = second.frame.minY - first.frame.maxY
        let betweenGroups = mine.frame.minY - second.frame.maxY
        XCTAssertLessThan(inGroup, betweenGroups, "Alex's second line should sit tight under the first; a new sender gets a header. in \(inGroup) between \(betweenGroups)")
        XCTAssertLessThan(first.frame.maxY, mine.frame.minY)
    }

    func testOnlyTheLatestMessageShowsSeenBy() {
        let app = launchChat("chatPolish")
        let latest = element(Polish.reply, in: app)
        XCTAssertTrue(latest.waitForExistence(timeout: 15))
        let seen = app.descendants(matching: .any).matching(identifier: "seen-by")
        XCTAssertTrue(seen.firstMatch.waitForExistence(timeout: 5), "No Seen by line")
        XCTAssertEqual(seen.count, 1, "Seen by belongs on the latest message only")
        XCTAssertEqual(seen.firstMatch.label, "Seen by Alex and Jordan")
        XCTAssertTrue(latest.frame.contains(CGPoint(x: seen.firstMatch.frame.midX, y: seen.firstMatch.frame.midY)), "Seen by isn't on the latest message")
        let mine = element(Polish.longLine, in: app)
        reveal(mine, in: app)
        let captions = app.descendants(matching: .any).matching(identifier: "delivery-caption")
        XCTAssertLessThanOrEqual(captions.count, 1, "Only your latest message gets Sent; others' messages get no caption")
        let sent = caption("Sent", in: app)
        XCTAssertTrue(sent.exists, "Your latest message should say Sent")
        XCTAssertTrue(mine.frame.contains(CGPoint(x: sent.frame.midX, y: sent.frame.midY)), "Sent isn't on your latest message")
    }

    func testUnreadDividerSitsAboveTheFirstUnreadAndStays() {
        let app = launchChat("chatPolish")
        let divider = element("unread-divider", in: app)
        XCTAssertTrue(divider.waitForExistence(timeout: 15), "No unread divider")
        XCTAssertEqual(divider.label, "2 unread messages")
        let unread = element(Polish.firstUnread, in: app)
        let before = element(Polish.longLine, in: app)
        XCTAssertLessThanOrEqual(divider.frame.maxY, unread.frame.minY + 1, "The divider isn't above the first unread message")
        XCTAssertGreaterThanOrEqual(divider.frame.minY, before.frame.maxY - 1, "The divider isn't below the last read message")
        sleep(2)
        XCTAssertTrue(divider.exists, "Reading the chat made the divider jump away")
    }

    func testJumpToLatestShowsWhenScrolledUpAndBringsYouBack() {
        let app = launchChat("chatPolish")
        let latest = element(Polish.reply, in: app)
        XCTAssertTrue(latest.waitForExistence(timeout: 15))
        let jump = app.buttons["jump-to-latest"]
        XCTAssertFalse(jump.exists, "Jump to latest showed while already at the bottom")
        let list = app.scrollViews["message-list"]
        for _ in 0..<4 { list.swipeDown() }
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "Jump to latest didn't show after scrolling up")
        XCTAssertTrue(jump.isHittable)
        XCTAssertTrue(jump.label.lowercased().contains("jump to latest"), jump.label)
        jump.tap()
        XCTAssertTrue(jump.waitForNonExistence(timeout: 5), "Jump to latest stayed after jumping")
        XCTAssertTrue(latest.isHittable, "The latest message isn't on screen after jumping")
    }

    func testReactionChipsAreBigEnoughAndToggleYours() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let chip = app.buttons[Polish.thumbs]
        reveal(chip, in: app)
        XCTAssertEqual(chip.label, "Thumbs up, 2 reactions, including yours")
        XCTAssertGreaterThanOrEqual(chip.frame.height, 44, "Chip is too short to hit: \(chip.frame)")
        XCTAssertGreaterThanOrEqual(chip.frame.width, 44, "Chip is too narrow to hit: \(chip.frame)")
        chip.tap()
        XCTAssertTrue(waitForLabel(chip, "label == 'Thumbs up, 1 reaction'"), "Tapping your chip didn't take yours back: \(chip.label)")
        chip.tap()
        XCTAssertTrue(waitForLabel(chip, "label == 'Thumbs up, 2 reactions, including yours'"), "Tapping again didn't add yours: \(chip.label)")
        let fire = app.buttons["reaction-chip-exclamationmark"]
        XCTAssertEqual(fire.label, "Emphasis, 1 reaction")
    }

    func testLongPressOffersReactReplyAndCopy() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let target = bubble(Polish.question, in: app)
        reveal(target, in: app)
        target.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5), "Long-press had no Copy")
        XCTAssertTrue(app.buttons["Reply"].exists, "Long-press had no Reply")
        XCTAssertTrue(app.buttons["Thumbs up"].exists, "Long-press had no reactions")
        XCTAssertFalse(app.buttons["Retry sending"].exists, "A sent message offered Retry")
        app.buttons["Copy"].tap()
        let toast = element("chat-toast", in: app)
        XCTAssertTrue(toast.waitForExistence(timeout: 2), "Copy didn't say Copied")
        XCTAssertEqual(toast.label, "Copied")
    }

    func testReplyFromLongPressQuotesTheOriginal() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let quotes = app.descendants(matching: .any).matching(identifier: "reply-quote")
        XCTAssertEqual(quotes.firstMatch.label, "Replying to Alex: Who's on tonight?", "The seeded reply's quote is wrong")
        let target = bubble(Polish.question, in: app)
        reveal(target, in: app)
        target.press(forDuration: 1.2)
        let reply = app.buttons["Reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5))
        reply.tap()
        let banner = element("reply-banner", in: app)
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "No reply banner over the composer")
        XCTAssertEqual(banner.label, "Replying to Alex: Who's on tonight?")
        let field = app.textFields["Message"]
        field.tap()
        field.typeText("Me too")
        app.buttons["send-message"].tap()
        XCTAssertTrue(banner.waitForNonExistence(timeout: 5), "The banner stayed after sending")
        let sent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, Me too, "))
        XCTAssertTrue(sent.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(sent.count, 1, "The reply was duplicated")
        XCTAssertEqual(quotes.count, 2, "The new reply has no quote")
    }

    func testCancelReplyDropsTheBanner() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let target = bubble(Polish.question, in: app)
        reveal(target, in: app)
        target.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Reply"].waitForExistence(timeout: 5))
        app.buttons["Reply"].tap()
        let cancel = app.buttons["reply-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertEqual(cancel.label, "Cancel reply")
        cancel.tap()
        XCTAssertTrue(element("reply-banner", in: app).waitForNonExistence(timeout: 5))
    }

    func testWithoutTheReplyColumnLongPressHasNoReply() {
        let app = launchChat("chatNoReplies")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "reply-quote").count, 0)
        let target = bubble(Polish.question, in: app)
        reveal(target, in: app)
        target.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Reply"].exists, "Reply showed on a server without reply_to_id")
    }

    func testFailedSendSaysNotDeliveredThenOneBubbleSaysSent() {
        let app = launchChat("chatPolish", extra: ["-debug-fail-sends", "1"])
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let field = app.textFields["Message"]
        field.tap()
        field.typeText("once")
        app.buttons["send-message"].tap()
        XCTAssertTrue(caption("Not delivered", in: app).waitForExistence(timeout: 5), "No Not delivered caption")
        let retry = app.buttons["retry-send"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44, "Retry is too short to hit")
        retry.tap()
        XCTAssertTrue(caption("Sent", in: app).waitForExistence(timeout: 5), "The retried message didn't say Sent")
        XCTAssertFalse(caption("Not delivered", in: app).exists)
        let sent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, once, "))
        XCTAssertEqual(sent.count, 1, "Retry made a second bubble")
        XCTAssertFalse(element("unread-divider", in: app).exists, "Sending should clear the unread divider")
    }

    func testEmptySquadSaysSo() {
        let app = launchChat("chatEmpty")
        let empty = element("chat-empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 15), "No empty state")
        XCTAssertEqual(empty.label, "No messages yet. Say hi to the squad.")
        XCTAssertFalse(app.buttons["jump-to-latest"].exists)
    }

    func testHistoryErrorOffersRetryThenLoads() {
        let app = launchChat("chatHistoryFailed")
        let error = element("chat-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 15), "No history error")
        XCTAssertEqual(error.label, "Messages couldn't load.")
        let retry = app.buttons["chat-retry"]
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 10), "Retry didn't load the thread")
        XCTAssertTrue(error.waitForNonExistence(timeout: 5), "The error stayed after loading")
    }

    func testHistoryLoadingShowsThenMessagesArrive() {
        let app = launchChat("chatHistorySlow")
        let loading = element("chat-loading", in: app)
        XCTAssertTrue(loading.waitForExistence(timeout: 10), "No loading row")
        XCTAssertTrue(loading.label.contains("Loading messages"), loading.label)
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15), "The thread never arrived")
        XCTAssertTrue(loading.waitForNonExistence(timeout: 5), "The loading row stayed")
        XCTAssertFalse(element("chat-empty", in: app).exists, "Loading must not flash the empty state")
    }

    func testMessagePolishStaysUsableAtLargeText() {
        let app = launchChat("chatPolish", largeText: true)
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let width = app.windows.firstMatch.frame.width
        let seen = element("seen-by", in: app)
        reveal(seen, in: app)
        XCTAssertGreaterThanOrEqual(seen.frame.minX, 0)
        XCTAssertLessThanOrEqual(seen.frame.maxX, width + 1, "Seen by runs off screen: \(seen.frame)")

        let divider = element("unread-divider", in: app)
        reveal(divider, in: app)
        XCTAssertLessThanOrEqual(divider.frame.maxX, width + 1, "The unread divider runs off screen")

        let long = bubble(Polish.longLine, in: app)
        reveal(long, in: app)
        XCTAssertLessThanOrEqual(long.frame.maxX, width + 1, "The long message runs off screen")
        XCTAssertGreaterThan(long.frame.height, 100, "The long message didn't wrap at AX5: \(long.frame)")

        let chip = app.buttons[Polish.thumbs]
        reveal(chip, in: app)
        XCTAssertGreaterThanOrEqual(chip.frame.height, 44)
        XCTAssertLessThanOrEqual(chip.frame.maxX, width + 1, "A chip runs off screen at AX5")

        let jump = app.buttons["jump-to-latest"]
        if !jump.exists {
            app.scrollViews["message-list"].swipeDown()
        }
        XCTAssertTrue(jump.waitForExistence(timeout: 5), "Jump to latest didn't show at AX5")
        XCTAssertTrue(jump.isHittable)
        let composer = element("composer", in: app)
        XCTAssertLessThanOrEqual(jump.frame.maxY, composer.frame.minY + 1, "Jump to latest covers the composer")
        XCTAssertLessThanOrEqual(jump.frame.maxX, width + 1)
    }

    func testReplyBannerStaysHittableAtLargeTextWithTheKeyboard() {
        let app = launchChat("chatPolish", largeText: true)
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let target = bubble(Polish.question, in: app)
        reveal(target, in: app)
        target.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Reply"].waitForExistence(timeout: 5))
        app.buttons["Reply"].tap()
        let cancel = app.buttons["reply-cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "Reply should focus the composer")
        XCTAssertTrue(cancel.isHittable, "Cancel reply is covered at AX5: \(cancel.frame)")
        XCTAssertGreaterThanOrEqual(cancel.frame.height, 44)
        let send = app.buttons["send-message"]
        XCTAssertTrue(send.isHittable, "Send is covered at AX5 while replying: \(send.frame)")
        let banner = element("reply-banner", in: app)
        XCTAssertLessThanOrEqual(banner.frame.maxX, app.windows.firstMatch.frame.width + 1)
    }

    func testDayLabelsAreReadOnceWithoutSymbolNames() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let today = app.descendants(matching: .any).matching(identifier: "day-separator")
            .matching(NSPredicate(format: "label == 'Today'")).firstMatch
        XCTAssertTrue(reveal(today, in: app))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Today'")).count == 1,
                      "The day label is read more than once")
        let symbolNames = ["arrow.down", "xmark", "doc.on.doc", "arrowshape", "hand.thumbsup", "exclamationmark", "arrow.clockwise"]
        let format = symbolNames.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed to VoiceOver: \(leaked.allElementsBoundByIndex.map(\.label))")
    }

    // MARK: Call sheet and the keyboard

    /// XCUITest's keyboard frame leaves out the QuickType bar (about 43 pt), so
    /// Call spots must end at least 50 pt above the keyboard's top to clear it.
    private func assertCallSheetClearsTheKeyboardBar(largeText: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"] + (largeText ? ["-uitest-largeText"] : [])
        app.launch()
        tapMenuCallSpots(app, file: file, line: line)
        let game = app.textFields["spot-sheet-game"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "The call sheet's game field was missing", file: file, line: line)
        game.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "The keyboard didn't come up", file: file, line: line)
        let call = app.buttons["spot-sheet-call"]
        XCTAssertTrue(call.waitForExistence(timeout: 5), file: file, line: line)
        // Let the sheet finish moving to the large detent.
        let deadline = Date().addingTimeInterval(3)
        while Date() < deadline, call.frame.maxY > keyboard.frame.minY - 50 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertTrue(call.isHittable, "Call spots is covered with the keyboard up: \(call.frame)", file: file, line: line)
        XCTAssertLessThanOrEqual(
            call.frame.maxY,
            keyboard.frame.minY - 50,
            "Call spots \(call.frame) sits on the QuickType bar; keyboard keys start at \(keyboard.frame.minY)",
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(call.frame.minY, game.frame.maxY - 1, "Call spots covers the game field", file: file, line: line)
        XCTAssertTrue(game.isHittable, "The game field went off screen with the keyboard up", file: file, line: line)
        call.tap()
        XCTAssertTrue(call.waitForNonExistence(timeout: 5), "Calling from the keyboard-up sheet didn't work", file: file, line: line)
    }

    func testCallSheetButtonClearsTheKeyboardBarAtLargeText() {
        assertCallSheetClearsTheKeyboardBar(largeText: true)
    }

    func testCallSheetButtonClearsTheKeyboardBarAtDefaultSize() {
        assertCallSheetClearsTheKeyboardBar(largeText: false)
    }
}
