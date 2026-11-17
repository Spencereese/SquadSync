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

        let status = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(status.waitForExistence(timeout: 15), "The stale spot was not on screen")
        XCTAssertEqual(status.label, "Expired")
        let call = app.buttons["call-spots"]
        XCTAssertTrue(call.waitForExistence(timeout: 5), "Call spots was hidden by the expired card")
        XCTAssertEqual(call.label, "Call spots")
        reveal(call, in: app)
        call.tap()
        let replacement = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(replacement.waitForExistence(timeout: 5))
        XCTAssertTrue(replacement.label.contains("left"), "The new call did not replace the stale one, label \(replacement.label)")
        XCTAssertFalse(app.buttons["call-spots"].exists)
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

        let status = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Ended")
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
        if retry.isHittable {
            retry.tap()
        } else {
            retry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
        let sent = app.buttons.matching(NSPredicate(format: "label == %@", "once"))
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
        let status = app.descendants(matching: .any)["spot-countdown"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Cancelled", "Cancelling from the card did not cancel the call")
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
}
