import XCTest

final class AccessibilityUITests: XCTestCase {
    func testTabsAndThreadButtonsAreExposed() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-screen", "inbox", "-scenario", "seated"]
        app.launch()

        let inbox = app.descendants(matching: .any)["tab-inbox"]
        let space = app.descendants(matching: .any)["tab-space"]
        XCTAssertTrue(inbox.waitForExistence(timeout: 15), "Inbox tab was not in the accessibility tree")
        XCTAssertTrue(space.exists, "Space tab was not in the accessibility tree")

        app.terminate()
        app.launchArguments = ["-backend", "mock", "-screen", "thread-general", "-scenario", "seated"]
        app.launch()

        let voice = app.descendants(matching: .any)["voice-room"]
        let handoff = app.descendants(matching: .any)["handoff-menu"]
        XCTAssertTrue(voice.waitForExistence(timeout: 15), "Voice room button was not in the accessibility tree")
        XCTAssertTrue(handoff.exists, "Handoff menu button was not in the accessibility tree")
    }

    func testSpaceMemberRowClearsTheTabBarAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-screen", "space", "-uitest-largeText"]
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
        app.launchArguments = ["-backend", "mock", "-screen", "inbox", "-uitest-largeText"]
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
        app.launchArguments = ["-backend", "mock", "-screen", "thread-general", "-uitest-largeText"]
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
        XCTAssertEqual(app.descendants(matching: .any)["onboarding-header"].label, "Find your squad", "No step count after leaving a squad")
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
        XCTAssertTrue(waitForLabel(riley, "label CONTAINS \"hasn't checked in\""), "Without a check-in Riley should read as not checked in: \(riley.label)")
        XCTAssertFalse(riley.label.lowercased().contains("online"))
        let me = app.buttons["presence-You"]
        XCTAssertTrue(me.exists, "The viewer was not in the presence strip")
        XCTAssertTrue(me.isHittable)

        riley.tap()
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForExistence(timeout: 5), "An avatar did not open Who's in")
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
        // Check-ins are on the (mock) server, so the roster offers Who's in instead of "not live".
        let whosIn = app.buttons["whos-in-open"]
        XCTAssertTrue(whosIn.waitForExistence(timeout: 5), "Who's in was missing from the large-text roster")
        XCTAssertTrue(whosIn.isHittable)
        XCTAssertGreaterThanOrEqual(whosIn.frame.height, 44)
        XCTAssertLessThanOrEqual(whosIn.frame.maxX, window.maxX + 1, "Who's in is cut off at the right")
        XCTAssertFalse(app.descendants(matching: .any)["presence-untracked"].exists, "Presence is tracked by check-ins here")
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

        let pill = app.buttons["whos-in-open"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "The Who's in pill was missing")
        XCTAssertEqual(pill.label, "Who's in")
        XCTAssertTrue(pill.isHittable || pill.frame.width > 0)
        XCTAssertLessThanOrEqual(pill.frame.maxX, app.windows.firstMatch.frame.maxX + 1, "The Who's in pill is cut off at the right")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "whos-in-open").count, 1, "The pill's symbol is a second element")
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
        // With check-ins on the server the last row is Who's in, not the untracked line.
        let note = app.buttons["whos-in-open"]
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
        XCTAssertFalse(app.descendants(matching: .any)["whos-in-sheet"].exists, "The tap opened Who's in, so it hit a roster row, 'more', or Who's in")
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

    /// Scrolls the chat in short, slow drags until the element is hittable. The element
    /// is a query, so every check re-resolves it. While it's in the tree its frame picks
    /// the direction; while it isn't (a lazy row off screen), sweep toward older messages
    /// first, then toward the newest. Bounded, so it fails instead of hanging. Callers
    /// that read a frame afterwards should `guard` on the result.
    @discardableResult
    private func scrollChat(to target: XCUIElement, in app: XCUIApplication, maxDrags: Int = 30, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let list = app.scrollViews["message-list"]
        guard list.waitForExistence(timeout: 5) else {
            XCTFail("No message list to scroll", file: file, line: line)
            return false
        }
        var blindDrags = 0
        for _ in 0..<maxDrags {
            var towardOlder = blindDrags < maxDrags / 3
            if target.exists {
                if target.isHittable { return true }
                let frame = target.frame
                if !frame.isEmpty { towardOlder = frame.midY < list.frame.midY }
            } else {
                blindDrags += 1
            }
            dragChat(list, towardOlder: towardOlder)
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "Couldn't scroll to \(target) in \(maxDrags) drags", file: file, line: line)
        return found
    }

    /// A third of the list per drag, slow so there's no fling past lazy rows. Pressed
    /// near the trailing edge and released quickly, so it never opens a context menu.
    private func dragChat(_ list: XCUIElement, towardOlder: Bool) {
        let upper = list.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.33))
        let lower = list.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.66))
        let (from, to) = towardOlder ? (upper, lower) : (lower, upper)
        from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// The message bubble inside a row: the row's first button.
    private func bubble(_ rowIdentifier: String, in app: XCUIApplication) -> XCUIElement {
        element(rowIdentifier, in: app).buttons.element(boundBy: 0)
    }

    private func waitForLabel(_ target: XCUIElement, _ predicate: String, timeout: TimeInterval = 5) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: predicate), object: target)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Grouping is read from the bubble identifiers (start / continues), not from
    /// gaps between rows: the name header sits inside the row frame, so gaps can't
    /// tell a new group from a continued one.
    func testThreadGroupsBySenderUnderDaySeparators() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15), "The seeded thread didn't load")
        let days = app.staticTexts.matching(identifier: "day-separator")
        let today = days.matching(NSPredicate(format: "label == 'Today'")).firstMatch
        guard scrollChat(to: today, in: app) else { return }

        let first = bubble(Polish.question, in: app)
        guard scrollChat(to: first, in: app) else { return }
        XCTAssertEqual(first.identifier, "bubble-group-start", "Alex's first line should open a group")
        XCTAssertTrue(first.label.hasPrefix("Alex, Who's on tonight?, "), first.label)

        let second = bubble(Polish.alexSecond, in: app)
        guard scrollChat(to: second, in: app) else { return }
        XCTAssertEqual(second.identifier, "bubble-group-continues", "Alex's second line should continue his group")
        XCTAssertTrue(second.label.hasPrefix("Alex, I can do 9, "), second.label)

        let mine = bubble(Polish.mineFirst, in: app)
        guard scrollChat(to: mine, in: app) else { return }
        XCTAssertEqual(mine.identifier, "bubble-group-start", "A new sender should open a new group")
        if first.exists && second.exists {
            XCTAssertLessThan(first.frame.minY, second.frame.minY, "Alex's lines are out of order")
        }

        let yesterday = days.matching(NSPredicate(format: "label == 'Yesterday'")).firstMatch
        guard scrollChat(to: yesterday, in: app) else { return }
        if today.exists {
            XCTAssertLessThanOrEqual(yesterday.frame.maxY, today.frame.minY, "Yesterday should sit above Today")
        }
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
        guard scrollChat(to: mine, in: app) else { return }
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
        guard scrollChat(to: chip, in: app) else { return }
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
        guard scrollChat(to: target, in: app) else { return }
        target.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Copy"].waitForExistence(timeout: 5), "Long-press had no Copy")
        XCTAssertTrue(app.buttons["Reply"].exists, "Long-press had no Reply")
        // Reactions sit in the menu itself; there is no separate React item.
        XCTAssertTrue(app.buttons["Thumbs up"].exists, "Long-press had no reactions")
        XCTAssertTrue(app.buttons["Ha ha"].exists, "The laugh reaction should read Ha ha")
        XCTAssertFalse(app.buttons["Retry sending"].exists, "A sent message offered Retry")
        app.buttons["Copy"].tap()
        // Match on the label in the same query, so a toast that's already fading isn't read twice.
        let copied = app.descendants(matching: .any).matching(identifier: "chat-toast")
            .matching(NSPredicate(format: "label == 'Copied'")).firstMatch
        XCTAssertTrue(copied.waitForExistence(timeout: 4), "Copy didn't say Copied")
    }

    func testReplyFromLongPressQuotesTheOriginal() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let quotes = app.descendants(matching: .any).matching(identifier: "reply-quote")
        XCTAssertEqual(quotes.firstMatch.label, "Replying to Alex: Who's on tonight?", "The seeded reply's quote is wrong")
        let target = bubble(Polish.question, in: app)
        guard scrollChat(to: target, in: app) else { return }
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
        guard scrollChat(to: target, in: app) else { return }
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
        guard scrollChat(to: target, in: app) else { return }
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
        XCTAssertTrue(waitUntil(timeout: 5) { retry.isHittable }, "Retry isn't on screen: \(retry.frame)")
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44, "Retry is too short to hit")
        retry.tap()
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 10), "Retry didn't load the thread")
        XCTAssertTrue(error.waitForNonExistence(timeout: 5), "The error stayed after loading")
    }

    func testHistoryErrorRetryIsInViewAtLargeText() {
        let app = launchChat("chatHistoryFailed", largeText: true)
        let error = element("chat-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 15), "No history error")
        let retry = app.buttons["chat-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        // No swiping: the list brings the error's Retry into view by itself.
        XCTAssertTrue(waitUntil(timeout: 5) { retry.isHittable }, "Retry starts off screen at AX5: \(retry.frame)")
        let list = app.scrollViews["message-list"]
        if list.exists {
            XCTAssertLessThanOrEqual(retry.frame.maxY, list.frame.maxY + 1, "Retry is clipped by the list at AX5: \(retry.frame) in \(list.frame)")
        }
        XCTAssertGreaterThanOrEqual(retry.frame.height, 44)
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
        guard scrollChat(to: seen, in: app) else { return }
        XCTAssertGreaterThanOrEqual(seen.frame.minX, 0)
        XCTAssertLessThanOrEqual(seen.frame.maxX, width + 1, "Seen by runs off screen: \(seen.frame)")

        let divider = element("unread-divider", in: app)
        guard scrollChat(to: divider, in: app) else { return }
        XCTAssertLessThanOrEqual(divider.frame.maxX, width + 1, "The unread divider runs off screen")

        let long = bubble(Polish.longLine, in: app)
        guard scrollChat(to: long, in: app) else { return }
        XCTAssertLessThanOrEqual(long.frame.maxX, width + 1, "The long message runs off screen")
        XCTAssertGreaterThan(long.frame.height, 100, "The long message didn't wrap at AX5: \(long.frame)")

        let chip = app.buttons[Polish.thumbs]
        guard scrollChat(to: chip, in: app) else { return }
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
        guard scrollChat(to: target, in: app) else { return }
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
        guard scrollChat(to: today, in: app) else { return }
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Today'")).count == 1,
                      "The day label is read more than once")
        let symbolNames = ["arrow.down", "xmark", "doc.on.doc", "arrowshape", "hand.thumbsup", "exclamationmark", "arrow.clockwise"]
        let format = symbolNames.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed to VoiceOver: \(leaked.allElementsBoundByIndex.map(\.label))")
    }

    // MARK: Call sheet and the keyboard

    /// Polls a condition on the main run loop; true as soon as it holds, false at the timeout.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return true
    }

    /// XCUITest's keyboard frame leaves out the QuickType bar (about 43 pt), so
    /// Call spots must end at least 50 pt above the keyboard's top to clear it.
    private func assertCallSheetClearsTheKeyboardBar(largeText: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "spotHistory"] + (largeText ? ["-uitest-largeText"] : [])
        app.launch()
        tapMenuCallSpots(app, file: file, line: line)
        let game = app.textFields["spot-sheet-game"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "The call sheet's game field was missing", file: file, line: line)
        // The sheet animates up; at accessibility sizes it must open large enough that the
        // field is on screen without dragging. Wait for that, and fail with the frame if not.
        XCTAssertTrue(waitUntil(timeout: 5) { game.isHittable }, "The game field is off screen when the sheet opens: \(game.frame) in window \(app.windows.firstMatch.frame)", file: file, line: line)
        let keyboard = app.keyboards.firstMatch
        game.tap()
        if !keyboard.waitForExistence(timeout: 3) {
            // One retry covers a tap that landed while the sheet was still settling.
            game.tap()
        }
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "The keyboard didn't come up after tapping the game field at \(game.frame)", file: file, line: line)
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

    // MARK: Who's in (redesign S4)

    /// Opens Who's in from the composer's + menu, which is there at every text size.
    /// `waitForSheet: false` returns right after the tap, for checks that can't wait.
    private func openWhosInFromMenu(_ app: XCUIApplication, waitForSheet: Bool = true, file: StaticString = #filePath, line: UInt = #line) {
        let plus = app.buttons["composer-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "The composer's + menu was missing", file: file, line: line)
        plus.tap()
        let item = app.buttons["composer-whos-in"]
        if item.waitForExistence(timeout: 3) {
            item.tap()
        } else {
            let fallback = app.collectionViews.buttons["Who's in"]
            XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Who's in was not in the + menu", file: file, line: line)
            fallback.tap()
        }
        guard waitForSheet else { return }
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForExistence(timeout: 5), "Who's in didn't open", file: file, line: line)
    }

    /// Floating point puts a 44pt frame at 43.99999999999994, so size checks allow 0.5pt.
    private func assertHitTarget(_ target: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(target.frame.height, 43.5, "\(what) is too short to hit: \(target.frame)", file: file, line: line)
    }

    /// Drags Who's in up to its large detent. iOS 26 draws a medium sheet's content
    /// at about 96% scale (342/354), so a real 44pt button measures 42.25 there;
    /// at the large detent it measures true. Sizes are checked after this.
    private func expandWhosIn(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let sheet = element("whos-in-sheet", in: app)
        let window = app.windows.firstMatch
        let tall = { sheet.frame.height >= window.frame.height * 0.7 }
        for _ in 0..<3 where !tall() {
            // Grab just inside the sheet's top. Never above it: that's the dimmed
            // background, and a tap there dismisses the sheet. Pulling up on the
            // content at its top resizes a medium sheet before it scrolls.
            let origin = window.coordinate(withNormalizedOffset: .zero)
            let grab = origin.withOffset(CGVector(dx: window.frame.midX, dy: sheet.frame.minY + 8))
            let top = origin.withOffset(CGVector(dx: window.frame.midX, dy: 60))
            grab.press(forDuration: 0.05, thenDragTo: top, withVelocity: .fast, thenHoldForDuration: 0.2)
            _ = waitUntil(timeout: 2, tall)
        }
        XCTAssertTrue(tall(), "Who's in didn't reach its large detent: \(sheet.frame)", file: file, line: line)
    }

    private func whosInRow(_ name: String, in app: XCUIApplication) -> XCUIElement {
        element("whos-in-row-\(name)", in: app)
    }

    /// Short slow drags inside the sheet until the element is hittable. Bounded.
    @discardableResult
    private func scrollSheet(to target: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let sheet = element("whos-in-sheet", in: app)
        for step in 0..<16 {
            if target.exists && target.isHittable { return true }
            let towardTop = step >= 10
            let upper = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.35))
            let lower = sheet.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.7))
            let (from, to) = towardTop ? (upper, lower) : (lower, upper)
            from.press(forDuration: 0.05, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.1)
        }
        let found = target.exists && target.isHittable
        XCTAssertTrue(found, "Couldn't scroll the sheet to \(target)", file: file, line: line)
        return found
    }

    func testWhosInShowsEachSourceWithItsLabel() {
        let app = launchChat("whosIn")
        let pill = app.buttons["whos-in-open"]
        XCTAssertTrue(pill.waitForExistence(timeout: 15), "No Who's in pill in the strip")
        XCTAssertTrue(waitForLabel(pill, "label == \"Who's in, 2 on\""), "The pill should count who's on: \(pill.label)")
        pill.tap()
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(element("whos-in-section-now", in: app).waitForExistence(timeout: 5), "No On now section")
        XCTAssertEqual(element("whos-in-section-now", in: app).label, "On now · 2")

        let alex = whosInRow("Alex", in: app)
        guard scrollSheet(to: alex, in: app) else { return }
        XCTAssertTrue(alex.label.contains("on now until"), alex.label)
        XCTAssertTrue(alex.label.contains("says Halo Infinite on Xbox, from their check-in"), "A typed console must say it's a check-in: \(alex.label)")
        let jordan = whosInRow("Jordan", in: app)
        guard scrollSheet(to: jordan, in: app) else { return }
        XCTAssertTrue(jordan.label.contains("playing Counter-Strike 2 on Steam"), jordan.label)
        let sam = whosInRow("Sam", in: app)
        guard scrollSheet(to: sam, in: app) else { return }
        XCTAssertTrue(sam.label.contains("on later, around"), sam.label)
        let casey = whosInRow("Casey", in: app)
        guard scrollSheet(to: casey, in: app) else { return }
        XCTAssertTrue(casey.label.contains("can't play"), casey.label)
        XCTAssertTrue(casey.label.contains("Steam profile private"), casey.label)

        let rows = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'whos-in-row-'"))
        XCTAssertEqual(rows.count, 4, "Everyone but you gets one row, each one element")
        for row in rows.allElementsBoundByIndex {
            XCTAssertFalse(row.label.lowercased().contains("online"), "Who's in claimed online: \(row.label)")
        }
        let steamLine = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Steam: '")).firstMatch
        guard scrollSheet(to: steamLine, in: app) else { return }
        XCTAssertEqual(steamLine.label, "Steam: the game on linked public profiles. PC only.")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Xbox and PlayStation: no presence'")).firstMatch.exists)
        app.buttons["whos-in-done"].tap()
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForNonExistence(timeout: 5))
    }

    func testCheckInNowOnALiveLikeServer() {
        let app = launchChat("whosInBasic")
        openWhosInFromMenu(app)
        let status = element("check-in-status", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "You haven't checked in.")
        expandWhosIn(app)
        XCTAssertTrue(element("check-in-details-missing", in: app).exists, "This server can't keep a game; the sheet should say so")
        XCTAssertFalse(app.textFields["check-in-game"].exists, "No game field without 0022")
        XCTAssertTrue(element("check-in-honor", in: app).exists, "The honor-system note is missing")
        let now = app.buttons["check-in-now"]
        XCTAssertTrue(now.isHittable)
        assertHitTarget(now, "I'm on now")
        now.tap()
        XCTAssertTrue(waitForLabel(status, "label BEGINSWITH \"You're on until\""), "Checking in didn't update your status: \(status.label)")
        let clear = app.buttons["check-in-clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5), "No Clear after checking in")
        XCTAssertTrue(element("whos-in-sources", in: app).exists)
        app.buttons["whos-in-done"].tap()
        let pill = app.buttons["whos-in-open"]
        XCTAssertTrue(waitForLabel(pill, "label == \"Who's in, 3 on\""), "Your check-in didn't reach the strip: \(pill.label)")
        let me = app.buttons["presence-You"]
        XCTAssertTrue(me.label.contains("on now, from their check-in"), me.label)
        pill.tap()
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        XCTAssertTrue(waitForLabel(status, "label == \"You haven't checked in.\""), "Clear didn't remove your check-in")
    }

    func testCheckInLaterWithGameAndConsole() {
        let app = launchChat("whosIn")
        openWhosInFromMenu(app)
        let game = app.textFields["check-in-game"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "No game field on a server with 0022")
        expandWhosIn(app)
        game.tap()
        game.typeText("Apex")
        app.buttons["check-in-later"].tap()
        let options = app.buttons.matching(identifier: "check-in-later-option")
        XCTAssertTrue(options.firstMatch.waitForExistence(timeout: 5), "Later didn't offer times")
        XCTAssertGreaterThanOrEqual(options.count, 3)
        for option in options.allElementsBoundByIndex where option.isHittable {
            assertHitTarget(option, "A later time")
        }
        let first = options.firstMatch
        XCTAssertTrue(first.label.hasPrefix("In 30 min, around "), first.label)
        first.tap()
        let status = element("check-in-status", in: app)
        XCTAssertTrue(waitForLabel(status, "label BEGINSWITH \"You said around\""), "Later didn't save: \(status.label)")
        XCTAssertEqual((game.value as? String) ?? "", "Apex", "The typed game should stay in the field")
    }

    func testWhosInLoadingThenRows() {
        // The mock's read takes 9s (whosInSlow), so the loading row is up well past
        // the first look. Look straight after the tap, not after waiting for the sheet.
        let app = launchChat("whosInSlow")
        openWhosInFromMenu(app, waitForSheet: false)
        let loading = element("whos-in-loading", in: app)
        XCTAssertTrue(loading.waitForExistence(timeout: 5), "No loading row")
        XCTAssertTrue(loading.label.contains("Loading who's in"), loading.label)
        XCTAssertFalse(element("whos-in-section-none", in: app).exists, "Loading must not claim nobody checked in")
        XCTAssertTrue(element("whos-in-section-now", in: app).waitForExistence(timeout: 20), "Check-ins never arrived")
        XCTAssertTrue(loading.waitForNonExistence(timeout: 5))
    }

    func testWhosInErrorOffersRetryThenLoads() {
        let app = launchChat("whosInFailed")
        openWhosInFromMenu(app)
        let error = element("whos-in-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 5), "No error row")
        XCTAssertEqual(error.label, "Who's in couldn't load. The server didn't answer.")
        XCTAssertFalse(element("whos-in-section-none", in: app).exists, "A failed read must not look like nobody checked in")
        expandWhosIn(app)
        let retry = app.buttons["whos-in-retry"]
        XCTAssertTrue(waitUntil(timeout: 5) { retry.isHittable }, "Retry isn't on screen: \(retry.frame)")
        assertHitTarget(retry, "Retry")
        retry.tap()
        XCTAssertTrue(element("whos-in-section-now", in: app).waitForExistence(timeout: 5), "Retry didn't load")
        XCTAssertTrue(error.waitForNonExistence(timeout: 5))
    }

    func testWhosInSquadOfOneSaysSo() {
        let app = launchChat("whosInEmpty")
        openWhosInFromMenu(app)
        let empty = element("whos-in-empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "No empty state")
        XCTAssertEqual(empty.label, "Just you so far. Invite the squad from the squad panel.")
        XCTAssertTrue(app.buttons["check-in-now"].exists, "You can still check in alone")
    }

    func testWithoutCheckInsOnTheServerNothingIsClaimed() {
        let app = launchChat("whosInNoServer")
        let note = element("presence-untracked", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 15), "The untracked pill should stay without check-ins")
        XCTAssertEqual(note.label, "Presence isn't live yet")
        openWhosInFromMenu(app)
        let unavailable = element("check-in-unavailable", in: app)
        XCTAssertTrue(unavailable.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["check-in-now"].exists, "No check-in buttons without the table")
        let line = app.staticTexts["Check-ins: not set up on this server."]
        XCTAssertTrue(scrollSheet(to: line, in: app))
    }

    func testWhosInStaysUsableAtLargeText() {
        let app = launchChat("whosIn", largeText: true)
        let toggle = app.buttons["presence-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 15))
        toggle.tap()
        let open = app.buttons["whos-in-open"]
        XCTAssertTrue(open.waitForExistence(timeout: 5), "No Who's in in the large-text roster")
        open.tap()
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForExistence(timeout: 5))
        let width = app.windows.firstMatch.frame.width
        let now = app.buttons["check-in-now"]
        guard scrollSheet(to: now, in: app) else { return }
        assertHitTarget(now, "I'm on now")
        XCTAssertLessThanOrEqual(now.frame.maxX, width + 1, "I'm on now runs off screen at AX5: \(now.frame)")
        let cant = app.buttons["check-in-cant"]
        guard scrollSheet(to: cant, in: app) else { return }
        XCTAssertLessThanOrEqual(cant.frame.maxX, width + 1, "Can't play runs off screen at AX5: \(cant.frame)")
        let alex = whosInRow("Alex", in: app)
        guard scrollSheet(to: alex, in: app) else { return }
        XCTAssertLessThanOrEqual(alex.frame.maxX, width + 1, "Alex's row runs off screen: \(alex.frame)")
        XCTAssertGreaterThan(alex.frame.height, 60, "Alex's row didn't wrap at AX5: \(alex.frame)")
        XCTAssertTrue(alex.label.contains("from their check-in"), alex.label)
        let jordan = whosInRow("Jordan", in: app)
        guard scrollSheet(to: jordan, in: app) else { return }
        XCTAssertLessThanOrEqual(jordan.frame.maxX, width + 1)
        let done = app.buttons["whos-in-done"]
        XCTAssertTrue(done.isHittable, "Done isn't reachable at AX5")
        done.tap()
        XCTAssertTrue(element("whos-in-sheet", in: app).waitForNonExistence(timeout: 5))
    }

    func testWhosInCheckInWorksAtLargeText() {
        let app = launchChat("whosInBasic", largeText: true)
        openWhosInFromMenu(app)
        let now = app.buttons["check-in-now"]
        guard scrollSheet(to: now, in: app) else { return }
        now.tap()
        let status = element("check-in-status", in: app)
        guard scrollSheet(to: status, in: app) else { return }
        XCTAssertTrue(waitForLabel(status, "label BEGINSWITH \"You're on until\""), status.label)
        XCTAssertLessThanOrEqual(status.frame.maxX, app.windows.firstMatch.frame.width + 1)
    }

    func testWhosInErrorRetryIsInViewAtLargeText() {
        let app = launchChat("whosInFailed", largeText: true)
        openWhosInFromMenu(app)
        let retry = app.buttons["whos-in-retry"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 5) { retry.isHittable }, "Retry starts off screen at AX5: \(retry.frame)")
        assertHitTarget(retry, "Retry")
        XCTAssertLessThanOrEqual(retry.frame.maxX, app.windows.firstMatch.frame.width + 1)
    }


    // MARK: Onboarding (redesign S5)

    private enum Onboard {
        static let wrongCode = "That code didn't work. It may be mistyped or expired. Check the newest email, or send a new code."
        static let offline = "You're offline. Check your connection, then try again."
        static let invalidEmail = "Enter an email like name@example.com."
    }

    /// Swipes the onboarding scroll view slowly until the target is hittable and, when
    /// the keyboard is up, above it. Bounded: up to 8 swipes up, then up to 8 back down.
    /// Fixed-point drags only moved ~380pt each and snapped back at AX5, where Continue
    /// sits ~1700pt down the profile step.
    @discardableResult
    private func revealInOnboarding(_ target: XCUIElement, in app: XCUIApplication, container: String = "onboarding", file: StaticString = #filePath, line: UInt = #line) -> Bool {
        let scroller = element(container, in: app)
        func reachable() -> Bool {
            guard target.exists, target.isHittable else { return false }
            let keyboard = app.keyboards.firstMatch
            return !keyboard.exists || target.frame.maxY <= keyboard.frame.minY
        }
        for swipe in 0..<16 {
            if reachable() { return true }
            guard scroller.exists else { break }
            if swipe < 8 {
                scroller.swipeUp(velocity: .slow)
            } else {
                scroller.swipeDown(velocity: .slow)
            }
        }
        let found = reachable()
        XCTAssertTrue(found, "Couldn't scroll onboarding to \(target)", file: file, line: line)
        return found
    }

    /// Email step: type an address and send. Leaves the app on the code step.
    private func sendCode(_ app: XCUIApplication, email: String = "new@squad.app", file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields["signin-email"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "No email field", file: file, line: line)
        field.tap()
        field.typeText(email)
        let send = app.buttons["signin-send"]
        guard revealInOnboarding(send, in: app, file: file, line: line) else { return }
        send.tap()
    }

    private func enterCode(_ code: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let field = app.textFields["signin-code"]
        XCTAssertTrue(field.waitForExistence(timeout: 10), "No code field", file: file, line: line)
        field.tap()
        field.typeText(code)
    }

    func testOnboardingSignsInSetsUpAProfileAndCreatesASquad() {
        let app = launchChat("onboarding")
        let header = element("onboarding-header", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 15))
        XCTAssertEqual(header.label, "Sign in with email, Step 1 of 4")
        XCTAssertEqual(element("onboarding", in: app).value as? String, "Full motion")
        sendCode(app)
        XCTAssertTrue(waitForLabel(header, "label == \"Enter your code, Step 2 of 4\""), header.label)
        XCTAssertTrue(app.staticTexts["We sent a code to new@squad.app. It can take a minute to arrive."].exists)
        // The sixth digit checks the code on its own.
        enterCode("123456", in: app)
        XCTAssertTrue(waitForLabel(header, "label == \"Set up your profile, Step 3 of 4\"", timeout: 10), header.label)
        let name = app.textFields["onboarding-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "new", "The server's default name comes in")
        XCTAssertTrue(element("onboarding-games-empty", in: app).exists, "No empty state for the games list")
        let suggest = app.buttons["onboarding-suggest-Fortnite"]
        guard revealInOnboarding(suggest, in: app) else { return }
        suggest.tap()
        XCTAssertTrue(element("onboarding-game-Fortnite", in: app).waitForExistence(timeout: 3), "The suggestion didn't join the list")
        XCTAssertFalse(element("onboarding-games-empty", in: app).exists)
        XCTAssertTrue(element("onboarding-games-note", in: app).exists, "The phone-only note is missing on a server without 0023")
        let save = app.buttons["onboarding-save-profile"]
        guard revealInOnboarding(save, in: app) else { return }
        save.tap()
        let squadName = app.textFields["squad-name"]
        XCTAssertTrue(squadName.waitForExistence(timeout: 5), "No squad step after the profile")
        XCTAssertEqual(element("onboarding-header", in: app).label, "Find your squad, Step 4 of 4")
        squadName.tap()
        squadName.typeText("Friday")
        let create = app.buttons["create-squad"]
        guard revealInOnboarding(create, in: app, container: "onboarding-squad") else { return }
        create.tap()
        let title = element("squad-title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5), "Creating the squad didn't open it")
        XCTAssertEqual(title.label, "Friday · 1 of 8")
    }

    func testTyposAreCaughtBeforeACodeIsSent() {
        let app = launchChat("onboarding")
        sendCode(app, email: "nope")
        let error = element("signin-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 3), "No error for a bad email")
        XCTAssertEqual(error.label, Onboard.invalidEmail)
        XCTAssertFalse(app.textFields["signin-code"].exists, "A bad email moved on")
    }

    func testWrongCodeSaysWhatToDoAndClearsTheField() {
        let app = launchChat("onboarding")
        sendCode(app)
        enterCode("000000", in: app)
        let error = element("signin-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 5), "No error for a wrong code")
        XCTAssertEqual(error.label, Onboard.wrongCode)
        let field = app.textFields["signin-code"]
        XCTAssertTrue(waitUntil(timeout: 3) { (field.value as? String).map { $0 == "Code" || $0.isEmpty } ?? true }, "The wrong code stayed: \(String(describing: field.value))")
        enterCode("123456", in: app)
        XCTAssertTrue(app.textFields["onboarding-name"].waitForExistence(timeout: 10), "The right code after a wrong one didn't sign in")
    }

    func testResendCountsDownThenSendsANewCode() {
        let app = launchChat("onboarding")
        sendCode(app)
        let resend = app.buttons["signin-resend"]
        XCTAssertTrue(resend.waitForExistence(timeout: 5))
        XCTAssertTrue(resend.label.hasPrefix("Send a new code, available in"), resend.label)
        XCTAssertFalse(resend.isEnabled, "Resend is open during the cooldown")
        XCTAssertTrue(waitUntil(timeout: 10) { resend.isEnabled }, "Resend never opened")
        XCTAssertEqual(resend.label, "Send a new code")
        guard revealInOnboarding(resend, in: app) else { return }
        resend.tap()
        let note = element("signin-resent", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "No word that a new code went out")
        XCTAssertEqual(note.label, "We sent a new code to new@squad.app. Use the newest one.")
        XCTAssertFalse(resend.isEnabled, "The cooldown didn't restart")
        let change = app.buttons["signin-change-email"]
        guard revealInOnboarding(change, in: app) else { return }
        change.tap()
        XCTAssertTrue(app.textFields["signin-email"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["signin-email"].value as? String, "new@squad.app", "Changing email lost what was typed")
    }

    func testOfflineSendSaysSoAndStays() {
        let app = launchChat("onboardingOffline")
        sendCode(app)
        let error = element("signin-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 5))
        XCTAssertEqual(error.label, Onboard.offline)
        XCTAssertTrue(app.buttons["signin-send"].isEnabled, "Send should be ready to try again")
        XCTAssertFalse(app.textFields["signin-code"].exists)
    }

    func testSlowSendAndVerifyShowWhatTheyAreDoing() {
        let app = launchChat("onboardingSlow")
        sendCode(app)
        let send = app.buttons["signin-send"]
        XCTAssertTrue(waitForLabel(send, "label == \"Sending code…\"", timeout: 1.5), "No sending state: \(send.label)")
        XCTAssertFalse(send.isEnabled, "Send can be tapped twice while sending")
        enterCode("123456", in: app)
        let verify = app.buttons["signin-verify"]
        XCTAssertTrue(waitForLabel(verify, "label == \"Checking code…\"", timeout: 1.5), "No checking state: \(verify.label)")
        XCTAssertTrue(app.textFields["onboarding-name"].waitForExistence(timeout: 10))
    }

    func testProfileGamesListEmptyAddDuplicateRemove() {
        let app = launchChat("onboardingProfile")
        let empty = element("onboarding-games-empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 15), "No empty games state")
        let field = app.textFields["onboarding-add-game"]
        guard revealInOnboarding(field, in: app) else { return }
        field.tap()
        field.typeText("Halo Infinite")
        let add = app.buttons["onboarding-add-game-button"]
        guard revealInOnboarding(add, in: app) else { return }
        add.tap()
        let row = element("onboarding-game-Halo Infinite", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 3), "The typed game didn't join the list")
        XCTAssertFalse(empty.exists)
        guard revealInOnboarding(field, in: app) else { return }
        field.tap()
        field.typeText("halo infinite")
        guard revealInOnboarding(add, in: app) else { return }
        add.tap()
        let error = element("onboarding-games-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        XCTAssertEqual(error.label, "halo infinite is already in your list.")
        let remove = app.buttons["onboarding-remove-Halo Infinite"]
        XCTAssertEqual(remove.label, "Remove Halo Infinite")
        guard revealInOnboarding(remove, in: app) else { return }
        assertHitTarget(remove, "Remove")
        remove.tap()
        XCTAssertTrue(empty.waitForExistence(timeout: 3), "The empty state didn't come back")
    }

    func testProfileNeedsANameBeforeMovingOn() {
        let app = launchChat("onboardingProfile")
        let name = app.textFields["onboarding-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        let save = app.buttons["onboarding-save-profile"]
        guard revealInOnboarding(save, in: app) else { return }
        save.tap()
        let error = element("onboarding-name-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 3), "An empty name moved on")
        XCTAssertEqual(error.label, "Add the name your squad will see.")
        XCTAssertFalse(app.textFields["squad-name"].exists)
    }

    func testOnboardingReadsInOrderWithoutSymbolNames() {
        let app = launchChat("onboarding")
        let header = element("onboarding-header", in: app)
        XCTAssertTrue(header.waitForExistence(timeout: 15))
        let field = app.textFields["signin-email"]
        let send = app.buttons["signin-send"]
        XCTAssertEqual(field.label, "Email", "The field's spoken name is its visible label")
        XCTAssertLessThan(header.frame.minY, field.frame.minY, "The header should come before the field")
        XCTAssertLessThan(field.frame.minY, send.frame.minY, "The field should come before Send")
        sendCode(app, email: "nope")
        XCTAssertTrue(element("signin-error", in: app).waitForExistence(timeout: 3))
        let symbols = ["exclamationmark", "circle.fill", "xmark"]
        let format = symbols.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed: \(leaked.allElementsBoundByIndex.map(\.label))")
    }

    func testReduceMotionIsRespected() {
        let app = launchChat("onboarding", extra: ["-reduceMotion"])
        let container = element("onboarding", in: app)
        XCTAssertTrue(container.waitForExistence(timeout: 15))
        XCTAssertEqual(container.value as? String, "Reduced motion")
        sendCode(app)
        // No slide: the code step is there and hittable right away.
        let code = app.textFields["signin-code"]
        XCTAssertTrue(code.waitForExistence(timeout: 2))
        XCTAssertTrue(waitUntil(timeout: 1) { code.isHittable }, "The code step was still moving with Reduce Motion on")
    }

    func testOnboardingWorksAtLargeText() {
        let app = launchChat("onboarding", largeText: true)
        let width = app.windows.firstMatch.frame.width
        let field = app.textFields["signin-email"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(field.frame.maxX, width + 1)
        let send = app.buttons["signin-send"]
        field.tap()
        field.typeText("new@squad.app")
        guard revealInOnboarding(send, in: app) else { return }
        assertHitTarget(send, "Send code")
        XCTAssertLessThanOrEqual(send.frame.maxX, width + 1, "Send code runs off screen at AX5: \(send.frame)")
        send.tap()
        let resend = app.buttons["signin-resend"]
        XCTAssertTrue(resend.waitForExistence(timeout: 5))
        guard revealInOnboarding(resend, in: app) else { return }
        assertHitTarget(resend, "Send a new code")
        XCTAssertLessThanOrEqual(resend.frame.maxX, width + 1)
        enterCode("123456", in: app)
        let save = app.buttons["onboarding-save-profile"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        guard revealInOnboarding(save, in: app) else { return }
        assertHitTarget(save, "Continue")
        XCTAssertLessThanOrEqual(save.frame.maxX, width + 1)
    }

    func testProfileStepAtLargeText() {
        let app = launchChat("onboardingProfile", largeText: true)
        let width = app.windows.firstMatch.frame.width
        let suggest = app.buttons["onboarding-suggest-Warzone"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 15))
        guard revealInOnboarding(suggest, in: app) else { return }
        assertHitTarget(suggest, "A suggested game")
        XCTAssertLessThanOrEqual(suggest.frame.maxX, width + 1, "A suggestion runs off screen at AX5: \(suggest.frame)")
        suggest.tap()
        let remove = app.buttons["onboarding-remove-Warzone"]
        guard revealInOnboarding(remove, in: app) else { return }
        assertHitTarget(remove, "Remove")
        XCTAssertGreaterThanOrEqual(remove.frame.width, 43.5)
        XCTAssertLessThanOrEqual(remove.frame.maxX, width + 1)
        let save = app.buttons["onboarding-save-profile"]
        guard revealInOnboarding(save, in: app) else { return }
        save.tap()
        let create = app.buttons["create-squad"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "No squad step at AX5")
        guard revealInOnboarding(create, in: app, container: "onboarding-squad") else { return }
        assertHitTarget(create, "Create squad")
        XCTAssertLessThanOrEqual(create.frame.maxX, width + 1)
    }
}
