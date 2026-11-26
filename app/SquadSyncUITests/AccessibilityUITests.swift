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

        let picker = app.descendants(matching: .any)["reaction-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "React did not open the emoji row")
        let thumbs = app.buttons["Thumbs up"]
        XCTAssertTrue(thumbs.waitForExistence(timeout: 5), "Thumbs up was not in the reaction row")
        XCTAssertEqual(picker.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'tapback-'")).count, 6, "The emoji row should offer the six reactions")
        assertHitSize(thumbs.frame.height, "An emoji in the row is too short to hit: \(thumbs.frame)")
        thumbs.tap()
        XCTAssertTrue(picker.waitForNonExistence(timeout: 5), "Picking a reaction should close the emoji row")

        let chip = app.buttons["reaction-chip-hand.thumbsup.fill"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The reaction chip was not visible")
        XCTAssertEqual(chip.label, "👍 1, you reacted")
        XCTAssertTrue(chip.isSelected, "Your own reaction should read as selected")
        let seedBubble = bubble("message-row-seed-1", in: app)
        let chips = reactions("message-row-seed-1", in: app)
        XCTAssertTrue(seedBubble.exists, "Riley's bubble has no chat.bubble identifier")
        XCTAssertTrue(chips.exists, "Riley's chips have no chat.reactions identifier")
        XCTAssertLessThan(seedBubble.frame.width, row.frame.width - 40, "Measured the row, not the bubble: bubble \(seedBubble.frame), row \(row.frame)")
        XCTAssertLessThanOrEqual(abs(chips.frame.minX - seedBubble.frame.minX), 2, "Riley's chips should sit under his bubble on the left: chips \(chips.frame), bubble \(seedBubble.frame)")
        XCTAssertLessThanOrEqual(seedBubble.frame.minX, row.frame.minX + 40, "Riley's bubble should sit at the left of the row: bubble \(seedBubble.frame), row \(row.frame)")
        XCTAssertGreaterThanOrEqual(chips.frame.minY, seedBubble.frame.maxY - 1, "The chips overlap the bubble")

        // Tapping your own chip again turns it off.
        chip.tap()
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "The reaction chip stayed after it was removed")
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
        // The code is spelled out for VoiceOver ("A B C D…", not a word); the exact
        // mock code is still checked, character by character.
        XCTAssertEqual(code.label, "Invite code A B C D 2 3 4 5")
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

        XCTAssertTrue(app.staticTexts["You're not in a group yet."].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any)["onboarding-header"].label, "Find your group", "No step count after leaving a squad")
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
        XCTAssertEqual(status.label, "That group is full (8).")
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

    func testWarmPushClosesTheMembersSheetAndOpensTheMessage() {
        // A tap while the app is open and a sheet covers the chat: the sheet closes
        // and the pushed message is on screen. The tap is delivered 12 s after launch.
        let app = XCUIApplication()
        let payload = #"{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-0000-0000-00000000A001"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", payload, "-debug-push-open-after", "12"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "Members button was not in the bar")
        members.tap()
        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "The members sheet did not open")
        let opened = app.descendants(matching: .any)["push-opened-chat"]
        XCTAssertFalse(opened.exists, "The tap landed before the sheet was open, so this run proves nothing")

        XCTAssertTrue(opened.waitForExistence(timeout: 25), "The warm tap did not open the chat")
        XCTAssertTrue(waitUntil(timeout: 5) { !count.exists }, "The members sheet stayed over the chat")
        XCTAssertEqual(opened.label, "Opened this chat.")
        XCTAssertTrue(opened.isHittable, "Opened this chat. was not on screen")
        let row = app.descendants(matching: .any)["message-row-seed-1"]
        XCTAssertTrue(row.waitForExistence(timeout: 5), "The pushed message was not in the chat")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(waitUntil(timeout: 5) { row.frame.intersects(list.frame) }, "The pushed message was not scrolled into view: \(row.frame)")
        XCTAssertFalse(app.descendants(matching: .any)["push-notice"].exists)
    }

    private let threadPushPayload = #"{"type":"thread_message","squad_id":"00000000-0000-0000-0000-000000000010","thread_id":"00000000-0000-0000-0000-00000000B001","message_id":"00000000-0000-0000-0000-00000000B103"}"#

    func testColdThreadPushOpensTheSideThreadWithTheReplyAndYouCanAnswer() {
        // A tap on a side-thread reply's notification with the app not running: the
        // side thread opens over the chat, the tapped reply is on screen, and you can reply.
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", threadPushPayload]
        app.launch()

        let panel = app.descendants(matching: .any)["side-thread"]
        XCTAssertTrue(panel.waitForExistence(timeout: 15), "The side thread did not open")
        let title = app.staticTexts["side-thread-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Ranked")
        XCTAssertEqual(app.staticTexts["side-thread-context"].label, "Side group · 2 people")
        let reply = app.descendants(matching: .any)["side-thread-message-00000000-0000-0000-0000-00000000b103"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5), "The tapped reply was not in the side thread")
        XCTAssertEqual(reply.label, "Riley: On in 5, bring the mic")
        let list = app.scrollViews["side-thread-list"]
        XCTAssertTrue(waitUntil(timeout: 5) { reply.frame.intersects(list.frame) }, "The tapped reply was not scrolled into view: \(reply.frame)")
        XCTAssertTrue(reply.isHittable, "The tapped reply was covered")
        XCTAssertFalse(app.descendants(matching: .any)["push-opened-chat"].exists, "A side-thread tap isn't a squad-chat tap")
        XCTAssertFalse(app.descendants(matching: .any)["push-notice"].exists)

        let composer = app.descendants(matching: .any)["side-thread-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        let send = app.buttons["side-thread-send"]
        XCTAssertFalse(send.isEnabled, "Send is off with nothing typed")
        composer.tap()
        composer.typeText("omw")
        XCTAssertTrue(waitUntil(timeout: 3) { send.isEnabled }, "Send did not turn on")
        send.tap()
        let mine = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "You: omw")).firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "Your reply did not show in the side thread")

        let close = app.buttons["side-thread-close"]
        XCTAssertTrue(close.isHittable)
        close.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !panel.exists }, "Close left the side thread up")
        XCTAssertTrue(app.scrollViews["message-list"].waitForExistence(timeout: 5), "The squad chat was not under the side thread")
    }

    func testWarmThreadPushClosesTheMembersSheetAndOpensTheSideThread() {
        // A side-thread tap while the app is open and a sheet covers the chat: the sheet
        // closes and the side thread opens with the reply on screen. Delivered 12 s in.
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", threadPushPayload, "-debug-push-open-after", "12"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "Members button was not in the bar")
        members.tap()
        let count = app.descendants(matching: .any)["squad-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 5), "The members sheet did not open")
        let panel = app.descendants(matching: .any)["side-thread"]
        XCTAssertFalse(panel.exists, "The tap landed before the sheet was open, so this run proves nothing")

        XCTAssertTrue(panel.waitForExistence(timeout: 25), "The warm tap did not open the side thread")
        XCTAssertTrue(waitUntil(timeout: 5) { !count.exists }, "The members sheet stayed over the side thread")
        let reply = app.descendants(matching: .any)["side-thread-message-00000000-0000-0000-0000-00000000b103"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5), "The tapped reply was not in the side thread")
        let list = app.scrollViews["side-thread-list"]
        XCTAssertTrue(waitUntil(timeout: 5) { reply.frame.intersects(list.frame) }, "The tapped reply was not scrolled into view: \(reply.frame)")
        XCTAssertTrue(reply.isHittable, "The tapped reply was covered")
    }

    /// Side threads open from the composer's + menu (the header keeps only the name and Members).
    private func openSideThreadsFromMenu(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let plus = app.buttons["composer-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 10), "The composer's + menu was missing", file: file, line: line)
        plus.tap()
        let item = app.buttons["composer-side-threads"]
        if item.waitForExistence(timeout: 3) {
            XCTAssertEqual(item.label, "Side threads", file: file, line: line)
            item.tap()
            return
        }
        let fallback = app.collectionViews.buttons["Side threads"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Side threads was not in the + menu", file: file, line: line)
        fallback.tap()
    }

    private let rankedRowId = "side-threads-row-00000000-0000-0000-0000-00000000b001"

    func testSideThreadListShowsStartsAndOpensThreads() {
        // The list from the + menu: the seeded group with its last reply, a DM made with
        // Riley from the picker, a reply in it, Back to the list, then the group again.
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        XCTAssertFalse(app.buttons["open-side-threads"].exists, "Side threads came back into the header")
        openSideThreadsFromMenu(app)
        let panel = app.descendants(matching: .any)["side-threads"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5), "The side thread list did not open")
        let ranked = app.buttons[rankedRowId]
        XCTAssertTrue(ranked.waitForExistence(timeout: 8), "The seeded side group was not in the list")
        XCTAssertTrue(ranked.label.hasPrefix("Side group Ranked. Riley: On in 5, bring the mic."), ranked.label)
        XCTAssertTrue(ranked.isHittable)
        XCTAssertFalse(app.descendants(matching: .any)["side-threads-empty"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["side-threads-error"].exists)

        app.buttons["side-threads-new"].tap()
        let pick = app.buttons["side-thread-pick-Riley"]
        XCTAssertTrue(pick.waitForExistence(timeout: 5), "Riley was not in the picker")
        let start = app.buttons["side-thread-start"]
        XCTAssertFalse(start.isEnabled, "Start is off until someone is picked")
        pick.tap()
        XCTAssertTrue(waitUntil(timeout: 3) { start.isEnabled }, "Start did not turn on")
        XCTAssertFalse(app.textFields["side-thread-name"].exists, "One person is a DM, which has no name")
        start.tap()

        let thread = app.descendants(matching: .any)["side-thread"]
        XCTAssertTrue(thread.waitForExistence(timeout: 8), "The new thread did not open")
        let title = app.staticTexts["side-thread-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Riley")
        XCTAssertEqual(app.staticTexts["side-thread-context"].label, "Direct message")
        let composer = app.descendants(matching: .any)["side-thread-composer"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("hey")
        let send = app.buttons["side-thread-send"]
        XCTAssertTrue(waitUntil(timeout: 3) { send.isEnabled }, "Send did not turn on")
        send.tap()
        let mine = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "You: hey")).firstMatch
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "Your first message did not show")

        let back = app.buttons["side-thread-close"]
        XCTAssertEqual(back.label, "Back", "From the list, the close button says Back")
        back.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !thread.exists }, "Back left the thread up")
        let dm = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Direct message with Riley. You: hey")).firstMatch
        XCTAssertTrue(dm.waitForExistence(timeout: 8), "The new DM was not in the list with its message")
        XCTAssertTrue(ranked.exists)
        let order = [dm.frame.minY, ranked.frame.minY]
        XCTAssertLessThan(order[0], order[1], "The thread with the newest message is first")

        // Starting that DM again opens the one you have.
        app.buttons["side-threads-new"].tap()
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        start.tap()
        XCTAssertTrue(thread.waitForExistence(timeout: 8))
        XCTAssertTrue(mine.waitForExistence(timeout: 5), "A second DM was started instead of opening the first")
        back.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !thread.exists })

        ranked.tap()
        XCTAssertTrue(thread.waitForExistence(timeout: 8), "The group did not open")
        XCTAssertEqual(app.staticTexts["side-thread-title"].label, "Ranked")
        let reply = app.descendants(matching: .any)["side-thread-message-00000000-0000-0000-0000-00000000b103"]
        XCTAssertTrue(reply.waitForExistence(timeout: 5), "The group's replies did not load")
        back.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !thread.exists })
        app.buttons["side-threads-close"].tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !panel.exists }, "Close left the list up")
        XCTAssertTrue(app.scrollViews["message-list"].waitForExistence(timeout: 5), "The squad chat was not under the list")
    }

    func testSideThreadListSaysWhenThereAreNone() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-mock-side-threads", "empty"]
        app.launch()
        openSideThreadsFromMenu(app)
        let empty = app.descendants(matching: .any)["side-threads-empty"]
        XCTAssertTrue(empty.waitForExistence(timeout: 8), "An empty list should say so")
        XCTAssertTrue(empty.label.contains("No side threads yet"), empty.label)
        XCTAssertFalse(app.descendants(matching: .any)["side-threads-error"].exists)
        XCTAssertTrue(app.buttons["side-threads-new"].isHittable)
    }

    func testSideThreadListSaysWhenItCannotLoad() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-mock-side-threads", "down"]
        app.launch()
        openSideThreadsFromMenu(app)
        let failed = app.descendants(matching: .any)["side-threads-error"]
        XCTAssertTrue(failed.waitForExistence(timeout: 8), "A failed read should say so")
        XCTAssertFalse(app.descendants(matching: .any)["side-threads-empty"].exists, "A failure isn't an empty list")
        let retry = app.buttons["side-threads-retry"]
        XCTAssertTrue(retry.isHittable)
        retry.tap()
        XCTAssertTrue(failed.waitForExistence(timeout: 8), "The server is still down, so the error stays")
    }

    func testSideThreadsAreReachableFromTheSquadPanelAtLargeText() {
        // The Members panel has it too, at every size.
        let app = launchChat("invite", largeText: true)
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 10), "Members button was not in the bar")
        members.tap()
        let card = app.buttons["panel-side-threads"]
        XCTAssertTrue(waitUntil(timeout: 8) { card.exists }, "The squad panel had no side threads button")
        if !card.isHittable { app.swipeUp() }
        XCTAssertTrue(card.isHittable, "The side threads button was off screen")
        card.tap()
        XCTAssertTrue(app.descendants(matching: .any)["side-threads"].waitForExistence(timeout: 5), "The list did not open from the panel")
        let ranked = app.buttons[rankedRowId]
        XCTAssertTrue(ranked.waitForExistence(timeout: 8), "The group was not in the list")
        XCTAssertTrue(ranked.isHittable, "The row was cut off at large text")
    }

    func testAThreadPushWhileTheListIsOpenOpensTheThreadAndCloseReturnsToTheChat() {
        // The list is open when the tap arrives (12 s in): the thread opens, and closing it
        // goes to the chat, not back to a list the push skipped.
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite", "-debug-push-open", threadPushPayload, "-debug-push-open-after", "12"]
        app.launch()
        openSideThreadsFromMenu(app)
        let panel = app.descendants(matching: .any)["side-threads"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let thread = app.descendants(matching: .any)["side-thread"]
        XCTAssertFalse(thread.exists, "The tap landed before the list was open, so this run proves nothing")
        XCTAssertTrue(thread.waitForExistence(timeout: 25), "The tap did not open the thread")
        let close = app.buttons["side-thread-close"]
        XCTAssertEqual(close.label, "Close", "A push skips the list, so it says Close")
        close.tap()
        XCTAssertTrue(waitUntil(timeout: 5) { !thread.exists })
        XCTAssertFalse(panel.exists, "The list was left under the chat")
        XCTAssertTrue(app.scrollViews["message-list"].waitForExistence(timeout: 5))
    }

    func testPushBeforeASquadSaysYouAreNotInIt() {
        let app = XCUIApplication()
        let payload = #"{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-0000-0000-00000000A001"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "noSquad", "-debug-push-open", payload]
        app.launch()

        let notice = app.descendants(matching: .any)["push-notice"]
        XCTAssertTrue(notice.waitForExistence(timeout: 15), "A squad you have not joined did not explain itself")
        XCTAssertEqual(notice.label, "You're not in that group.")
        XCTAssertTrue(notice.isHittable, "You're not in that group. was not on screen")
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
        XCTAssertEqual(notice.label, "You're not in that group.")
        XCTAssertTrue(notice.isHittable, "You're not in that group. was not on screen")
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

    // MARK: Profile games editor (squad panel)

    private func openProfilePanel(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"] + extra
        app.launch()
        let title = app.descendants(matching: .any)["squad-title"]
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The squad header was missing")
        title.tap()
        XCTAssertTrue(app.textFields["profile-name"].waitForExistence(timeout: 5), "The profile was not in the squad panel")
        return app
    }

    /// Swipes the panel up until the element can be tapped.
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, _ message: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), message)
        var tries = 0
        while !element.isHittable, tries < 6 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(element.isHittable, message + " (not hittable)")
    }

    func testProfilePanelAddsRemovesAndPicksTheDefaultGame() {
        let app = openProfilePanel()
        let empty = element("profile-games-empty", in: app)
        reveal(empty, in: app, "An empty games list did not say so")
        XCTAssertEqual(empty.label, "No games yet. Add the ones you play.")

        let fortnite = app.buttons["profile-suggest-Fortnite"]
        reveal(fortnite, in: app, "Suggestions were missing")
        XCTAssertEqual(fortnite.label, "Add Fortnite")
        fortnite.tap()
        let apex = app.buttons["profile-suggest-Apex Legends"]
        reveal(apex, in: app, "Apex Legends was not suggested")
        apex.tap()
        XCTAssertFalse(app.buttons["profile-suggest-Fortnite"].exists, "An added game is still suggested")
        XCTAssertFalse(empty.exists, "The empty line stayed after adding")

        let entry = app.textFields["profile-add-game"]
        reveal(entry, in: app, "The add-a-game field was missing")
        entry.tap()
        XCTAssertTrue(app.buttons["profile-add-game-button"].exists, "The Add button was missing")
        entry.typeText("Halo Infinite\n")
        XCTAssertTrue(element("profile-games-row-Halo Infinite", in: app).waitForExistence(timeout: 5), "A typed game was not added")

        let makeDefault = app.buttons["profile-default-Fortnite"]
        reveal(makeDefault, in: app, "Make default was missing")
        XCTAssertEqual(makeDefault.label, "Make Fortnite the default game")
        makeDefault.tap()
        XCTAssertTrue(app.staticTexts["Fortnite, default game"].waitForExistence(timeout: 5), "The default was not marked for VoiceOver")
        XCTAssertFalse(app.buttons["profile-default-Fortnite"].exists, "The default still offers Make default")
        XCTAssertEqual(app.textFields["profile-game"].value as? String, "Fortnite", "The default game field did not follow")

        let removeApex = app.buttons["profile-remove-Apex Legends"]
        reveal(removeApex, in: app, "Remove was missing")
        XCTAssertEqual(removeApex.label, "Remove Apex Legends")
        removeApex.tap()
        XCTAssertFalse(element("profile-games-row-Apex Legends", in: app).waitForExistence(timeout: 2), "A removed game stayed")

        let save = app.buttons["save-profile"]
        reveal(save, in: app, "Save profile was missing")
        save.tap()
        let saved = element("profile-saved", in: app)
        XCTAssertTrue(saved.waitForExistence(timeout: 5), "Saving did not confirm")
        XCTAssertTrue(saved.label.hasPrefix("Profile saved."), "Unexpected save line: \(saved.label)")
        XCTAssertFalse(element("profile-games-error", in: app).exists, "Saving showed an error")
        XCTAssertTrue(element("profile-games-row-Fortnite", in: app).exists)
        XCTAssertTrue(element("profile-games-row-Halo Infinite", in: app).exists)
        XCTAssertFalse(element("profile-games-row-Apex Legends", in: app).exists)
    }

    func testProfileGamesSayWhyWhenTheyCantLoadAndOfferTryAgain() {
        let app = openProfilePanel(["-SQ8NetworkFault", "offline"])
        let failed = element("profile-games-load-error", in: app)
        reveal(failed, in: app, "A failed games read did not say so")
        XCTAssertEqual(failed.label, "You're offline. Your games will load when you're back online.")
        XCTAssertFalse(element("profile-games-empty", in: app).exists, "A failed read claimed there are no games")
        XCTAssertFalse(app.textFields["profile-add-game"].exists, "Editing was offered before the list loaded")
        let retry = app.buttons["profile-games-retry"]
        reveal(retry, in: app, "Try again was missing")
        retry.tap()
        XCTAssertTrue(failed.waitForExistence(timeout: 5), "Still offline, the error should stay")
    }

    func testVoicePillStaysAMockAndLivesInTheMembersPanel() {
        let app = launchChat("invite")
        XCTAssertFalse(app.buttons["voice-room-pill"].waitForExistence(timeout: 3), "The voice pill came back into the header")
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15))
        members.tap()
        let pill = app.buttons["voice-room-pill"]
        reveal(pill, in: app, "The voice-room pill was not in the Members panel")
        XCTAssertTrue(pill.label.contains("mock"), "The voice pill did not say it is a mock: \(pill.label)")
        XCTAssertTrue(pill.label.contains("Double tap to join."))
        pill.tap()
        // Joining closes the panel so you land back in the chat.
        XCTAssertTrue(app.scrollViews["message-list"].waitForExistence(timeout: 5))
        XCTAssertTrue(waitUntil(timeout: 5) { app.buttons["members"].isHittable }, "The panel stayed up after joining voice")
        app.buttons["members"].tap()
        let again = app.buttons["voice-room-pill"]
        reveal(again, in: app, "The voice-room pill went missing after joining")
        XCTAssertTrue(waitForLabel(again, "label CONTAINS \"Double tap to leave.\""), "Voice did not flip to joined: \(again.label)")
    }

    func testSignOutLivesInTheMembersPanel() {
        let app = launchChat("invite")
        XCTAssertFalse(app.buttons["account"].waitForExistence(timeout: 3), "Account came back into the header")
        app.buttons["members"].tap()
        let account = app.buttons["account"]
        reveal(account, in: app, "Sign out was not in the Members panel")
        account.tap()
        XCTAssertTrue(app.staticTexts["Sign out?"].waitForExistence(timeout: 5), "Sign out did not ask to confirm after the panel closed")
    }

    func testHeaderShowsOnlyTheGroupNameAndMembers() {
        let app = launchChat("gameOn")
        let title = element("squad-title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The group header was missing")
        XCTAssertEqual(title.label, "Friday · 5 of 8")
        let members = app.buttons["members"]
        XCTAssertTrue(members.exists)
        XCTAssertEqual(members.label, "Members")
        XCTAssertLessThan(abs(members.frame.midY - title.frame.midY), title.frame.height, "Members dropped below the name")
        for gone in ["presence-strip", "presence-toggle", "whos-in-open", "open-side-threads", "voice-room-pill", "account", "active-call-bar", "play-next-bar", "spot-card"] {
            XCTAssertFalse(element(gone, in: app).exists, "\(gone) is still on the home screen")
        }
        // The header is just the name and Members: nothing else above the pinned Game on.
        let list = app.scrollViews["message-list"]
        let card = element("game-on-card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 10), "Alex's Game on was not pinned")
        let headerButtons = app.buttons.allElementsBoundByIndex.filter {
            // Anything from the title's row down to the card: a 44 pt button centred on
            // the row starts above the shorter title, so the row is matched by overlap.
            $0.exists && $0.frame.height > 0 && $0.frame.maxY > title.frame.minY && $0.frame.maxY <= card.frame.minY
        }
        XCTAssertEqual(Set(headerButtons.map(\.identifier)).subtracting(["squad-title"]), ["members"], "Unexpected buttons above the card: \(headerButtons.map(\.identifier))")
        XCTAssertLessThanOrEqual(card.frame.maxY, list.frame.minY + 1, "The card overlaps the chat")
    }

    func testQuietGroupShowsOnlyTheGameOnButtonUpTop() {
        let app = launchChat("invite")
        let button = app.buttons["game-on-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Game on was not up top in a quiet group")
        XCTAssertEqual(button.label, "Game on")
        XCTAssertTrue(button.isHittable)
        assertHitTarget(button, "Game on")
        XCTAssertFalse(element("game-on-card", in: app).exists, "A quiet group showed a card")
        let list = app.scrollViews["message-list"]
        XCTAssertLessThanOrEqual(button.frame.maxY, list.frame.minY + 1, "Game on sits over the chat")
        XCTAssertLessThan(button.frame.height, app.windows.firstMatch.frame.height * 0.1, "The quiet top is not small")
    }

    func testHeaderIsOneRowAtLargeText() {
        let app = launchChat("gameOn", largeText: true)
        let title = element("squad-title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The group header was missing at large text")
        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 5))
        XCTAssertTrue(members.isHittable, "Members was not hittable in the one-row header")
        XCTAssertLessThan(abs(members.frame.midY - title.frame.midY), title.frame.height, "Members dropped to a second header row, members \(members.frame) title \(title.frame)")
        let window = app.windows.firstMatch.frame
        XCTAssertLessThan(title.frame.maxY, window.height * 0.22, "The header takes too much of the screen at large text, title \(title.frame)")
        let card = element("game-on-card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The pinned Game on was missing at large text")
        XCTAssertLessThanOrEqual(card.frame.height, 240 + 1, "The pinned area is not capped at large text, frame \(card.frame)")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.exists)
        XCTAssertGreaterThan(list.frame.height, window.height * 0.4, "The chat keeps less than 40% of the screen at large text, list \(list.frame)")
        XCTAssertTrue(app.textFields["Message"].isHittable, "The card covered the composer")
    }

    func testHomeDecorationsAreNotReadAloud() {
        let app = launchChat("gameOnFull")
        XCTAssertTrue(element("game-on-card", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["whos-in-open"].exists, "The Who's in pill is gone in the chat-first home")
        let symbolNames = ["antenna", "radiowaves", "mic.slash", "waveform", "gamecontroller", "checkmark", "lock.fill", "chevron", "person.3", "person.2", "person.badge", "ellipsis", "xmark", "camera"]
        let format = symbolNames.map { "label CONTAINS[c] '\($0)'" }.joined(separator: " OR ")
        let leaked = app.descendants(matching: .any).matching(NSPredicate(format: format))
        XCTAssertEqual(leaked.count, 0, "An SF Symbol name is exposed to VoiceOver: \(leaked.allElementsBoundByIndex.map(\.label))")
        // Seat faces are drawn, not read: the summary already names who's in.
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.label.contains("In: Alex and Jordan"), summary.label)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "game-on-summary").count, 1, "The summary is split into pieces")
    }

    func testSquadPanelGroupsSectionsAndKeepsIdentifiers() {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", "invite"]
        app.launch()

        let members = app.buttons["members"]
        XCTAssertTrue(members.waitForExistence(timeout: 15))
        members.tap()
        XCTAssertTrue(app.staticTexts["Members"].waitForExistence(timeout: 5), "The panel title was missing")
        for heading in ["Join with a code", "In the group", "Rename", "Invite", "Voice and side threads", "Your profile", "Account"] {
            XCTAssertTrue(app.staticTexts[heading].waitForExistence(timeout: 5), "Panel section \(heading) was missing")
        }
        XCTAssertTrue(app.buttons["leave-squad"].waitForExistence(timeout: 5), "Leave did not appear after the probe")
        XCTAssertTrue(app.textFields["rename-field"].waitForExistence(timeout: 5), "Rename did not appear after the probe")
        for identifier in ["squad-count", "join-code", "join-squad", "remove-Riley", "leave-squad", "rename-field", "rename-squad", "create-invite", "invite-empty", "voice-room-pill", "panel-side-threads", "account", "profile-name", "profile-game", "save-profile"] {
            XCTAssertEqual(
                app.descendants(matching: .any).matching(identifier: identifier).count,
                1,
                "\(identifier) is missing or duplicated in the restyled panel"
            )
        }
    }

    // MARK: Game on (chat-first round 1)

    private func tapMenuGameOn(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let plus = app.buttons["composer-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "The composer's + menu was missing", file: file, line: line)
        XCTAssertTrue(plus.isHittable, "The composer's + menu was not hittable, frame \(plus.frame)", file: file, line: line)
        plus.tap()
        let item = app.buttons["composer-game-on"]
        if item.waitForExistence(timeout: 3) {
            item.tap()
            return
        }
        let fallback = app.collectionViews.buttons["Game on"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Game on was not in the + menu", file: file, line: line)
        fallback.tap()
    }

    private func gameOnLine(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(identifier: "game-on-line")
            .matching(NSPredicate(format: "label CONTAINS %@", text))
            .firstMatch
    }

    func testGameOnJoinIsOneTap() {
        let app = launchChat("gameOn")
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Alex's Game on was not pinned")
        XCTAssertEqual(summary.label, "Alex's on Warzone. Needs 1 more. In: Alex")
        let join = app.buttons["game-on-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 5), "Join was not on the card")
        XCTAssertEqual(join.label, "Join Warzone")
        assertHitTarget(join, "Join")
        join.tap()

        XCTAssertTrue(waitForLabel(summary, "label == \"Alex's on Warzone. Full. In: Alex and You\""), "Joining did not seat you: \(summary.label)")
        XCTAssertFalse(join.exists, "Join stayed after joining")
        let ready = app.buttons["game-on-ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 5), "Ready (optional) was not offered after joining")
        XCTAssertEqual(ready.value as? String, "Off", "Joining should not mark you ready")
        XCTAssertTrue(app.buttons["game-on-leave"].exists, "Leave was not offered after joining")
        XCTAssertFalse(app.buttons["game-on-end"].exists, "Someone else's Game on offered End")
        XCTAssertFalse(app.buttons["spot-lock"].exists, "There is no Lock any more")
        assertListClearsComposer(app)
    }

    func testGameOnReadyIsOptionalAndLeaveGivesTheSeatBack() {
        let app = launchChat("gameOn")
        let join = app.buttons["game-on-join"]
        XCTAssertTrue(join.waitForExistence(timeout: 15))
        join.tap()
        let ready = app.buttons["game-on-ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 5))
        ready.tap()
        XCTAssertTrue(waitForLabel(ready, "value == \"On\""), "Ready did not turn on")
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.label.hasSuffix("1 ready"), "The card did not count ready: \(summary.label)")
        app.buttons["game-on-leave"].tap()
        XCTAssertTrue(join.waitForExistence(timeout: 5), "Leaving did not give the seat back")
        XCTAssertTrue(waitForLabel(summary, "label == \"Alex's on Warzone. Needs 1 more. In: Alex\""), summary.label)
    }

    func testFullGameOnSaysFullAndOffersNoJoin() {
        let app = launchChat("gameOnFull")
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertEqual(summary.label, "Alex's on Warzone. Full. In: Alex and Jordan. 1 ready")
        let full = element("game-on-full", in: app)
        XCTAssertTrue(full.exists, "A full card did not say Full")
        XCTAssertEqual(full.label, "Full")
        XCTAssertFalse(app.buttons["game-on-join"].exists, "A full card still offered Join")
        XCTAssertFalse(element("game-on-invite", in: app).exists, "A full card asked for invites")
    }

    func testStarterEndsTheirGameOnAndTheLineStays() {
        let app = launchChat("gameOnMine")
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertEqual(summary.label, "You're on Call of Duty. Needs 2 more. In: You and Sam")
        XCTAssertFalse(app.buttons["game-on-leave"].exists, "The starter gets End, not Leave")
        let end = app.buttons["game-on-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 5))
        XCTAssertEqual(end.label, "End Call of Duty")
        end.tap()
        XCTAssertTrue(element("game-on-card", in: app).waitForNonExistence(timeout: 5), "End left the card pinned")
        XCTAssertTrue(app.buttons["game-on-button"].waitForExistence(timeout: 5), "Game on did not come back after ending")
        let line = gameOnLine("You're on Call of Duty", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 5), "The chat lost the line where it started")
        XCTAssertEqual(line.label, "Game on. You're on Call of Duty, need 3")
    }

    func testGameOnEndStaysHittableAtLargeText() {
        let app = launchChat("gameOnMine", largeText: true)
        let end = app.buttons["game-on-end"]
        XCTAssertTrue(end.waitForExistence(timeout: 15), "End was missing at large text")
        XCTAssertTrue(end.isHittable, "End was not hittable at large text, frame \(end.frame)")
        assertHitTarget(end, "End")
        XCTAssertLessThan(end.frame.maxX, app.windows.firstMatch.frame.maxX + 1, "End runs off the screen")
        end.tap()
        XCTAssertTrue(app.buttons["game-on-button"].waitForExistence(timeout: 5), "Ending at large text did not work")
    }

    func testGameOnJoinStaysUsableAtLargeText() {
        let app = launchChat("gameOn", largeText: true)
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 15))
        XCTAssertTrue(summary.label.contains("In: Alex"), "At large text the names move into the label: \(summary.label)")
        let join = app.buttons["game-on-join"]
        XCTAssertTrue(join.isHittable, "Join was not hittable at large text, frame \(join.frame)")
        assertHitTarget(join, "Join")
        join.tap()
        XCTAssertTrue(app.buttons["game-on-ready"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["game-on-leave"].isHittable, "Leave was cut off at large text")
    }

    func testGameOnStepsAsideForTheKeyboardAtLargeText() {
        // At AX5 the pinned area hides while you type, so the composer and the
        // newest messages keep the room, then comes back when the keyboard goes.
        let app = launchChat("gameOn", largeText: true)
        let card = element("game-on-card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        let field = app.textFields["Message"]
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(card.waitForNonExistence(timeout: 5), "The card stayed pinned over a typing composer at AX5")
        XCTAssertTrue(field.isHittable, "The composer was covered with the keyboard up")
        let list = app.scrollViews["message-list"]
        XCTAssertGreaterThan(list.frame.height, 120, "The chat was squeezed out with the keyboard up: \(list.frame)")
        // The list dismisses the keyboard interactively, like in Messages.
        for _ in 0..<3 where app.keyboards.firstMatch.exists {
            list.swipeDown()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 8), "The card did not come back after typing")
    }

    func testIdleGameOnIsGoneAndGameOnIsOffered() {
        let app = launchChat("gameOnExpired")
        let button = app.buttons["game-on-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 15), "Game on was not offered after the idle one expired")
        XCTAssertFalse(element("game-on-card", in: app).exists, "A Game on idle past 3 hours stayed pinned")
        XCTAssertFalse(app.buttons["game-on-join"].exists)
    }

    func testTwoGameOnsHideTheButtonAndTheMenuSaysWhy() {
        let app = launchChat("gameOnTwo")
        let cards = app.descendants(matching: .any).matching(identifier: "game-on-card")
        XCTAssertTrue(cards.firstMatch.waitForExistence(timeout: 15))
        XCTAssertTrue(waitUntil(timeout: 5) { cards.count == 2 }, "Both Game ons should be pinned, found \(cards.count)")
        XCTAssertFalse(app.buttons["game-on-button"].exists, "A third Game on was offered at the cap")
        tapMenuGameOn(app)
        let note = element("game-on-note", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The cap was not explained")
        XCTAssertEqual(note.label, "Two games are already on. Join one, or wait for one to end.")
        XCTAssertFalse(app.buttons["game-on-start"].exists, "The sheet opened past the cap")
    }

    func testStartAGameOnFromTheButton() {
        let app = launchChat("invite")
        let button = app.buttons["game-on-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        let start = app.buttons["game-on-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The Game on sheet did not open")
        let other = app.buttons["game-on-game-other"]
        XCTAssertTrue(other.exists)
        other.tap()
        let field = app.textFields["game-on-other-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3), "Other did not offer a field")
        if !app.keyboards.firstMatch.exists { field.tap() }
        field.typeText("Halo")
        let need = app.steppers["game-on-need"]
        XCTAssertTrue(need.exists, "How many more was missing")
        need.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(waitForLabel(element("game-on-need-value", in: app), "label == \"2 more\""), "The stepper did not count up")
        XCTAssertTrue(start.isEnabled)
        start.tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5), "The sheet stayed after starting")
        let summary = element("game-on-summary", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "Your Game on was not pinned")
        XCTAssertEqual(summary.label, "You're on Halo. Needs 2 more. In: You")
        XCTAssertTrue(app.buttons["game-on-end"].exists, "You can end your own Game on")
        let line = gameOnLine("You're on Halo", in: app)
        XCTAssertTrue(line.waitForExistence(timeout: 5), "Starting did not post a line in the chat")
        XCTAssertEqual(line.label, "Game on. You're on Halo, need 2")
    }

    func testGameOnSheetNeedsAGame() {
        let app = launchChat("invite")
        tapMenuGameOn(app)
        let start = app.buttons["game-on-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        app.buttons["game-on-game-other"].tap()
        XCTAssertTrue(app.textFields["game-on-other-field"].waitForExistence(timeout: 3))
        XCTAssertFalse(start.isEnabled, "Start was on with no game picked")
        app.buttons["game-on-cancel"].tap()
        XCTAssertTrue(start.waitForNonExistence(timeout: 5), "Cancel left the sheet up")
        XCTAssertFalse(element("game-on-card", in: app).exists, "Cancel started a Game on")
    }

    func testSlashSpotsWithAGameOpensGameOnWithItPicked() {
        let app = launchChat("invite")
        sendCommand("/spots Halo", in: app)
        let halo = app.buttons["game-on-game-Halo"]
        XCTAssertTrue(halo.waitForExistence(timeout: 5), "/spots Halo did not open Game on with Halo")
        XCTAssertTrue(halo.isSelected, "Halo was not the picked game")
        XCTAssertTrue(app.buttons["game-on-start"].isEnabled)
    }

    func testBareSlashSpotsOpensGameOn() {
        let app = launchChat("invite")
        sendCommand("/spots", in: app)
        XCTAssertTrue(app.buttons["game-on-start"].waitForExistence(timeout: 5), "/spots did not open the Game on sheet")
        XCTAssertFalse(element("message-row-spots", in: app).exists)
    }

    func testServerWithoutGameOnSaysSo() {
        let app = launchChat("gameOnServerMissing")
        let note = element("game-on-unavailable", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 15), "A server without Game on did not say so")
        XCTAssertEqual(note.label, "Game on needs a server update before it works here.")
        XCTAssertFalse(app.buttons["game-on-button"].exists, "Game on was offered on a server that can't take it")
        XCTAssertFalse(element("game-on-card", in: app).exists)
        tapMenuGameOn(app)
        XCTAssertFalse(app.buttons["game-on-start"].waitForExistence(timeout: 2), "The sheet opened on a server that can't take it")
        XCTAssertTrue(app.textFields["Message"].isHittable, "The chat stopped working without Game on")
    }

    func testFailedGameOnReadSaysSoAndRetries() {
        let app = launchChat("gameOnFailed")
        let failed = element("game-on-failed", in: app)
        XCTAssertTrue(failed.waitForExistence(timeout: 15), "A failed read did not say so")
        XCTAssertFalse(element("game-on-card", in: app).exists, "A failed read claimed a card")
        let retry = app.buttons["game-on-retry"]
        XCTAssertTrue(retry.isHittable)
        assertHitTarget(retry, "Retry")
        retry.tap()
        // gameOnFailed reads fail until Retry (like chatHistoryFailed), so Retry has to
        // work: the error goes and Alex's Game on, there all along, shows.
        XCTAssertTrue(failed.waitForNonExistence(timeout: 8), "Retry left the error up")
        XCTAssertTrue(element("game-on-card", in: app).waitForExistence(timeout: 8), "Retry did not load the Game on")
    }

    func testGameOnSheetStaysUsableAtLargeText() {
        let app = launchChat("invite", largeText: true)
        tapMenuGameOn(app)
        let start = app.buttons["game-on-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "The sheet did not open at large text")
        XCTAssertTrue(start.isHittable, "Start was out of reach at large text, frame \(start.frame)")
        let other = app.buttons["game-on-game-other"]
        var tries = 0
        while !other.isHittable, tries < 6 { app.swipeUp(); tries += 1 }
        other.tap()
        let field = app.textFields["game-on-other-field"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        if !app.keyboards.firstMatch.exists { field.tap() }
        field.typeText("Halo")
        XCTAssertTrue(start.isHittable, "Start went under the keyboard at large text")
        start.tap()
        XCTAssertTrue(element("game-on-card", in: app).waitForExistence(timeout: 8), "Starting at large text did not pin the card")
    }

    func testPlannedSessionShowsAsAGameOnWhenItStarts() {
        let app = launchChat("plannedStarting")
        let card = element("planned-game-on-card", in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15), "A session that just started was not pinned")
        let summary = element("planned-game-on-summary", in: app)
        XCTAssertTrue(summary.label.contains("Alex's Warzone session is starting"), summary.label)
        XCTAssertTrue(summary.label.contains("In: Alex"), summary.label)
        let imIn = app.buttons["planned-im-in"]
        XCTAssertTrue(imIn.exists)
        assertHitTarget(imIn, "I'm in")
        imIn.tap()
        XCTAssertTrue(element("planned-you-are-in", in: app).waitForExistence(timeout: 5), "I'm in did not stick")
        XCTAssertTrue(summary.label.contains("You"), summary.label)
    }

    // MARK: Invite link and prompts

    func testAnyMemberCanMakeAndShareAnInviteLink() {
        let app = launchChat("invite")
        app.buttons["members"].tap()
        let create = app.buttons["create-invite"]
        reveal(create, in: app, "Make an invite link was missing")
        XCTAssertEqual(create.label, "Make an invite link")
        create.tap()
        let code = element("invite-code", in: app)
        XCTAssertTrue(code.waitForExistence(timeout: 5), "No code after making a link")
        XCTAssertTrue(code.label.hasPrefix("Invite code "), code.label)
        let share = app.buttons["share-invite-link"]
        reveal(share, in: app, "Share was missing after making a link")
        XCTAssertTrue(app.buttons["copy-invite"].exists, "Copy was missing")
    }

    func testWelcomeOffersImOnRightAfterJoining() {
        let app = launchChat("welcome")
        let prompt = element("welcome-prompt", in: app)
        XCTAssertTrue(prompt.waitForExistence(timeout: 15), "No welcome right after joining")
        let imOn = app.buttons["welcome-im-on"]
        reveal(imOn, in: app)
        XCTAssertTrue(app.buttons["welcome-game-on"].exists, "Game on was not offered next to I'm on")
        imOn.tap()
        // The row (message-row-*) is a container with no label; the bubble inside
        // (chat.bubble.*) carries what VoiceOver reads.
        let sent = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "I'm on")).matching(NSPredicate(format: "identifier BEGINSWITH 'chat.bubble.'")).firstMatch
        XCTAssertTrue(sent.waitForExistence(timeout: 5), "I'm on was not sent to the group")
        XCTAssertTrue(prompt.waitForNonExistence(timeout: 5), "The welcome stayed after answering")
    }

    func testWelcomeGameOnOpensTheSheet() {
        let app = launchChat("welcome")
        let button = app.buttons["welcome-game-on"]
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        reveal(button, in: app)
        button.tap()
        XCTAssertTrue(app.buttons["game-on-start"].waitForExistence(timeout: 5), "Game on from the welcome did not open the sheet")
    }

    func testSmallGroupAsksForInvitesAndAPhoto() {
        let app = launchChat("smallGroup")
        let invite = element("invite-prompt", in: app)
        XCTAssertTrue(invite.waitForExistence(timeout: 15), "A two-person group had no invite nudge")
        let photo = element("photo-prompt", in: app)
        XCTAssertTrue(photo.waitForExistence(timeout: 5), "No photo nudge early on")
        XCTAssertTrue(app.buttons["photo-prompt-add"].exists)
        let dismissPhoto = app.buttons["photo-prompt-dismiss"]
        reveal(dismissPhoto, in: app)
        XCTAssertEqual(dismissPhoto.label, "Not now")
        assertHitTarget(dismissPhoto, "Not now")
        dismissPhoto.tap()
        XCTAssertTrue(photo.waitForNonExistence(timeout: 5), "Not now left the photo nudge")
        let share = app.buttons["invite-prompt-share"]
        reveal(share, in: app)
        share.tap()
        XCTAssertTrue(element("invite-code", in: app).waitForExistence(timeout: 8), "Invite from the chat did not make a link")
    }

    func testBigGroupGetsNoInviteOrPhotoNagByDefault() {
        let app = launchChat("gameOn")
        XCTAssertTrue(element("game-on-card", in: app).waitForExistence(timeout: 15))
        XCTAssertFalse(element("invite-prompt", in: app).exists, "A five-person group was nagged to invite")
        XCTAssertFalse(element("game-on-invite", in: app).exists, "A five-person group's card asked for invites")
        XCTAssertFalse(element("welcome-prompt", in: app).exists)
    }

    // MARK: Copy

    /// The app says "group", not "squad", anywhere a person can see or hear it.
    func testNoScreenSaysSquad() {
        let app = launchChat("smallGroup")
        XCTAssertTrue(element("squad-title", in: app).waitForExistence(timeout: 15))
        assertNoSquad(in: app, "home")
        app.buttons["members"].tap()
        XCTAssertTrue(app.staticTexts["In the group"].waitForExistence(timeout: 5))
        assertNoSquad(in: app, "Members panel")
        dismissSheet(app)
        tapMenuGameOn(app)
        XCTAssertTrue(app.buttons["game-on-start"].waitForExistence(timeout: 5))
        assertNoSquad(in: app, "Game on sheet")
    }

    /// Drags a sheet down by its top edge until the home screen's Members is tappable again.
    private func dismissSheet(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let window = app.windows.firstMatch
        for _ in 0..<3 where !app.buttons["members"].isHittable {
            let top = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08))
            let bottom = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98))
            top.press(forDuration: 0.05, thenDragTo: bottom, withVelocity: .fast, thenHoldForDuration: 0.1)
            _ = waitUntil(timeout: 2) { app.buttons["members"].isHittable }
        }
        XCTAssertTrue(app.buttons["members"].isHittable, "The sheet did not close", file: file, line: line)
    }

    private func assertNoSquad(in app: XCUIApplication, _ screen: String, file: StaticString = #filePath, line: UInt = #line) {
        // "SquadSync" is the app's name and is fine (an email at squadsync.app, say).
        let candidates = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'squad' OR value CONTAINS[c] 'squad' OR placeholderValue CONTAINS[c] 'squad'"))
        let said = candidates.allElementsBoundByIndex.compactMap { element -> String? in
            let text = [element.label, element.value as? String ?? "", element.placeholderValue ?? ""].joined(separator: " ")
            let stripped = text.lowercased().replacingOccurrences(of: "squadsync", with: "")
            return stripped.contains("squad") ? "\(element.identifier): \(text)" : nil
        }
        XCTAssertEqual(said, [], "\(screen) says squad", file: file, line: line)
    }

    // MARK: Commands and history

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

    // MARK: Play sessions

    private func tapMenuScheduleSession(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let plus = app.buttons["composer-plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15), "The composer's + menu was missing", file: file, line: line)
        XCTAssertTrue(plus.isHittable, "The composer's + menu was not hittable, frame \(plus.frame)", file: file, line: line)
        plus.tap()
        let item = app.buttons["composer-schedule-session"]
        if item.waitForExistence(timeout: 3) {
            item.tap()
            return
        }
        let fallback = app.collectionViews.buttons["Schedule a session"]
        XCTAssertTrue(fallback.waitForExistence(timeout: 3), "Schedule a session was not in the + menu", file: file, line: line)
        fallback.tap()
    }

    private func playSummary(_ game: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@ AND label CONTAINS %@", "play-session-summary-", game))
            .firstMatch
    }

    func testScheduleASessionThenAnswerAndCancelFromTheChatCard() {
        let app = launchChat("playSessionsEmpty")
        XCTAssertFalse(element("play-next-bar", in: app).waitForExistence(timeout: 3), "There is nothing scheduled yet")

        tapMenuScheduleSession(app)
        let game = app.textFields["play-form-game"]
        XCTAssertTrue(game.waitForExistence(timeout: 5), "The schedule sheet did not open from the + menu")
        let tomorrow = app.buttons["play-pick-tomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 3), "Tomorrow was not offered as a quick pick")
        tomorrow.tap()
        XCTAssertTrue(tomorrow.isSelected, "The tomorrow pick did not show as chosen")
        game.tap()
        game.typeText("Rocket League")
        let schedule = app.buttons["play-schedule"]
        XCTAssertTrue(schedule.isHittable, "Schedule was not hittable, frame \(schedule.frame)")
        schedule.tap()
        XCTAssertTrue(schedule.waitForNonExistence(timeout: 5), "The sheet stayed open after a successful schedule")

        let summary = playSummary("Rocket League", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 5), "The new session's card did not show in the chat")
        XCTAssertTrue(summary.label.contains("Tomorrow"), "Card label: \(summary.label)")
        XCTAssertTrue(summary.label.contains("In: You"), "The scheduler was not put down as In: \(summary.label)")
        XCTAssertEqual(summary.value as? String, "You're in")
        let id = String(summary.identifier.dropFirst("play-session-summary-".count))

        // Chat-first: an upcoming session lives in the chat; the top keeps only Game on.
        XCTAssertFalse(element("play-next-bar", in: app).exists, "An upcoming session went back above the chat")
        XCTAssertTrue(app.buttons["game-on-button"].exists, "The Game on button left the top")

        let goIn = app.buttons["play-session-in-\(id)"]
        let goOut = app.buttons["play-session-out-\(id)"]
        XCTAssertTrue(goOut.waitForExistence(timeout: 5), "The card had no Out button")
        reveal(goOut, in: app)
        XCTAssertTrue(goIn.isSelected, "In was not marked as your answer")
        goOut.tap()
        let answeredOut = NSPredicate(format: "value == %@", "You're out")
        expectation(for: answeredOut, evaluatedWith: summary)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(goOut.isSelected, "Out was not marked as your answer")
        XCTAssertFalse(goIn.isSelected, "In stayed marked after answering Out")

        let cancel = app.buttons["play-session-cancel-\(id)"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3), "The creator had no Cancel on their card")
        reveal(cancel, in: app)
        cancel.tap()
        let confirm = app.alerts.buttons["Cancel session"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3), "Cancel did not ask to confirm")
        confirm.tap()
        XCTAssertTrue(goOut.waitForNonExistence(timeout: 5), "A cancelled session still offered In and Out")
        XCTAssertTrue(playSummary("Rocket League", in: app).label.contains("Cancelled"), "The card did not say it was cancelled")
        XCTAssertFalse(cancel.exists, "A cancelled session still offered Cancel")
    }

    func testSeededSessionCardShowsWhoIsInAndTakesYourAnswer() {
        let app = launchChat("playSessions")
        let id = "00000000-0000-0000-0000-000000000501"
        let summary = element("play-session-summary-\(id)", in: app)
        XCTAssertTrue(summary.waitForExistence(timeout: 15), "Alex's session card was not in the chat")
        XCTAssertTrue(summary.label.contains("Warzone"), "Card label: \(summary.label)")
        XCTAssertTrue(summary.label.contains("In: Alex and Jordan"), "Card label: \(summary.label)")
        XCTAssertTrue(summary.label.contains("Out: Sam"), "Card label: \(summary.label)")
        XCTAssertEqual(summary.value as? String, "You haven't answered")
        XCTAssertFalse(app.buttons["play-session-cancel-\(id)"].exists, "Someone else's session offered you Cancel")

        let goIn = app.buttons["play-session-in-\(id)"]
        XCTAssertTrue(goIn.waitForExistence(timeout: 5))
        reveal(goIn, in: app)
        goIn.tap()
        expectation(for: NSPredicate(format: "value == %@", "You're in"), evaluatedWith: summary)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(summary.label.contains("In: You, Alex and Jordan"), "Card label after In: \(summary.label)")

        XCTAssertFalse(app.buttons["play-session-in-00000000-0000-0000-0000-000000000503"].exists, "A session that's over still took answers")
        XCTAssertFalse(app.buttons["play-session-in-00000000-0000-0000-0000-000000000502"].exists, "A cancelled session still took answers")
        XCTAssertFalse(element("play-next-bar", in: app).exists, "Upcoming sessions stay in the chat, not above it")
    }

    func testPlaySessionsSayWhenTheServerIsNotSetUp() {
        let app = launchChat("playSessionsMissing")
        tapMenuScheduleSession(app)
        let note = element("play-unavailable", in: app)
        XCTAssertTrue(note.waitForExistence(timeout: 5), "The sheet did not say play sessions aren't set up")
        XCTAssertEqual(note.label, "Play sessions aren't set up on this server yet.")
        XCTAssertFalse(app.buttons["play-schedule"].isEnabled, "Schedule stayed enabled with no server support")
        XCTAssertFalse(element("play-next-bar", in: app).exists)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "play-session-card").count, 0)
    }

    func testScheduleSheetStaysUsableAtLargeText() {
        let app = launchChat("playSessionsEmpty", largeText: true)
        tapMenuScheduleSession(app)
        let schedule = app.buttons["play-schedule"]
        XCTAssertTrue(schedule.waitForExistence(timeout: 5), "The schedule sheet did not open at large text")
        var tries = 0
        while !schedule.isHittable, tries < 8 {
            app.swipeUp()
            tries += 1
        }
        XCTAssertTrue(schedule.isHittable, "Schedule was out of reach at large text, frame \(schedule.frame)")
        schedule.tap()
        XCTAssertTrue(schedule.waitForNonExistence(timeout: 5), "The sheet stayed open after scheduling at large text")
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "play-session-summary-"))
            .firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5), "The card did not show in the non-lazy chat at large text")
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

    /// Edit to shorten a hang investigation run; see launchChat.
    private static let hangAbortSeconds = "90"

    private func launchChat(_ scenario: String, largeText: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-backend", "mock", "-scenario", scenario] + (largeText ? ["-uitest-largeText"] : []) + extra
        // Hang diagnosis: a DEBUG app whose main thread stays blocked this long
        // aborts, so the simulator writes a crash report with the main thread's
        // stack (see MainThreadStallWatch). A hang fails the test either way; this
        // only turns a 240 s query timeout into a crash with a stack. Fixed here:
        // a TEST_RUNNER_ override never reached the test process on the Mac.
        let abortAfter = Self.hangAbortSeconds
        app.launchEnvironment["SQ_HANG_ABORT_SECONDS"] = abortAfter
        print("[ui-timing] launch \(scenario) hang-abort=\(abortAfter)s")
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
        // XCUI round trips, not drags, are what this costs: each one waits for the app
        // to idle and snapshots its tree on the main thread. So the list's frame is
        // read once (it doesn't move while the thread scrolls under it; a keyboard
        // the drag dismisses only makes the first reading the stricter one), and the
        // target is read once per drag, as one snapshot that answers both "is it in
        // the tree" and "where". isHittable, a third round trip, is asked only once
        // that snapshot puts it on screen. Was exists + frame + list.frame per drag.
        let visible = list.frame
        var blindDrags = 0
        for _ in 0..<maxDrags {
            var towardOlder = blindDrags < maxDrags / 3
            if let frame = try? target.snapshot().frame {
                // Ask isHittable only once the element is on screen in the list: on a lazy
                // row that exists offscreen, XCUI fails the test outright ("Activation point
                // invalid") instead of returning false.
                if onScreen(frame, in: visible), target.isHittable { return true }
                if !frame.isEmpty { towardOlder = frame.midY < visible.midY }
            } else {
                blindDrags += 1
            }
            dragChat(list, towardOlder: towardOlder)
        }
        let found = (try? target.snapshot().frame).map { onScreen($0, in: list.frame) } == true && target.isHittable
        XCTAssertTrue(found, "Couldn't scroll to \(target) in \(maxDrags) drags", file: file, line: line)
        return found
    }

    /// The element has a real frame whose centre is inside the visible list.
    private func onScreen(_ frame: CGRect, in visible: CGRect) -> Bool {
        guard !frame.isEmpty, frame.width > 0, frame.height > 0 else { return false }
        return visible.contains(CGPoint(x: frame.midX, y: frame.midY))
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
    /// The id part of a row identifier ("message-row-<token>").
    private func token(_ rowIdentifier: String) -> String {
        String(rowIdentifier.dropFirst("message-row-".count))
    }

    /// The bubble itself, by its own identifier (`chat.bubble.<token>.start` or
    /// `.continues`), so frames are the colored shape and not the full-width row.
    private func bubble(_ rowIdentifier: String, in container: XCUIElement) -> XCUIElement {
        container.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "chat.bubble.\(token(rowIdentifier)).")).firstMatch
    }

    private func bubbleIdentifier(_ rowIdentifier: String, startsGroup: Bool) -> String {
        "chat.bubble.\(token(rowIdentifier)).\(startsGroup ? "start" : "continues")"
    }

    /// The row of reaction chips under a message.
    private func reactions(_ rowIdentifier: String, in app: XCUIApplication) -> XCUIElement {
        element("chat.reactions.\(token(rowIdentifier))", in: app)
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
        // Every query is scoped to the message list and resolves one element by
        // identifier (plus label) with firstMatch, so no step walks the whole tree.
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5), "No message list")
        let today = daySeparator("Today", in: list)
        guard scrollChat(to: today, in: app) else { return }

        // Each bubble is read as one snapshot (identifier, label and frame in one
        // round trip) right after it's on screen, and the order checks use those
        // readings instead of querying again.
        let first = bubble(Polish.question, in: list)
        guard scrollChat(to: first, in: app), let firstSeen = seen(first) else { return }
        XCTAssertEqual(firstSeen.identifier, bubbleIdentifier(Polish.question, startsGroup: true), "Alex's first line should open a group")
        XCTAssertTrue(firstSeen.label.hasPrefix("Alex, Who's on tonight?, "), firstSeen.label)

        let second = bubble(Polish.alexSecond, in: list)
        guard scrollChat(to: second, in: app), let secondSeen = seen(second) else { return }
        XCTAssertEqual(secondSeen.identifier, bubbleIdentifier(Polish.alexSecond, startsGroup: false), "Alex's second line should continue his group")
        XCTAssertTrue(secondSeen.label.hasPrefix("Alex, I can do 9, "), secondSeen.label)

        let mine = bubble(Polish.mineFirst, in: list)
        guard scrollChat(to: mine, in: app), let mineSeen = seen(mine) else { return }
        XCTAssertEqual(mineSeen.identifier, bubbleIdentifier(Polish.mineFirst, startsGroup: true), "A new sender should open a new group")
        // Both of Alex's lines in one reading, so the comparison is from one layout.
        if let firstNow = read(first), let secondNow = read(second) {
            XCTAssertLessThan(firstNow.frame.minY, secondNow.frame.minY, "Alex's lines are out of order")
        }

        let yesterday = daySeparator("Yesterday", in: list)
        guard scrollChat(to: yesterday, in: app), let yesterdaySeen = seen(yesterday) else { return }
        if let todayNow = read(today) {
            XCTAssertLessThanOrEqual(yesterdaySeen.frame.maxY, todayNow.frame.minY, "Yesterday should sit above Today")
        }
    }

    /// One round trip for an element's identifier, label and frame; nil when it
    /// isn't in the tree (the same answer `exists` gives).
    private func read(_ element: XCUIElement) -> (identifier: String, label: String, frame: CGRect)? {
        guard let snapshot = try? element.snapshot() else { return nil }
        return (snapshot.identifier, snapshot.label, snapshot.frame)
    }

    /// `read`, for an element the test just scrolled to: gone by now is a failure,
    /// as reading `identifier` off a missing element was.
    private func seen(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) -> (identifier: String, label: String, frame: CGRect)? {
        guard let reading = read(element) else {
            XCTFail("\(element) left the tree right after scrolling to it", file: file, line: line)
            return nil
        }
        return reading
    }

    /// One day separator in the list, by identifier and label in a single predicate.
    private func daySeparator(_ label: String, in list: XCUIElement) -> XCUIElement {
        list.staticTexts.matching(NSPredicate(format: "identifier == 'day-separator' AND label == %@", label)).firstMatch
    }

    func testOnlyTheLatestMessageShowsSeenBy() {
        let app = launchChat("chatPolish")
        let latest = element(Polish.reply, in: app)
        XCTAssertTrue(latest.waitForExistence(timeout: 15))
        let seen = app.descendants(matching: .any).matching(identifier: "seen-by")
        XCTAssertTrue(seen.firstMatch.waitForExistence(timeout: 5), "No Seen by line")
        XCTAssertEqual(seen.count, 1, "Seen by belongs on the latest message only")
        // The read rows and your profile arrive separately; give them a moment to agree.
        _ = waitUntil(timeout: 5) { seen.firstMatch.label == "Seen by Alex and Jordan" }
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
        XCTAssertEqual(chip.label, "👍 2, you reacted")
        XCTAssertTrue(chip.isSelected, "Your reaction should be highlighted")
        assertHitSize(chip.frame.height, "Chip is too short to hit: \(chip.frame)")
        assertHitSize(chip.frame.width, "Chip is too narrow to hit: \(chip.frame)")
        chip.tap()
        XCTAssertTrue(waitForLabel(chip, "label == '👍 1'"), "Tapping your chip didn't take yours back: \(chip.label)")
        XCTAssertFalse(chip.isSelected, "The chip still read as yours after you took it back")
        chip.tap()
        XCTAssertTrue(waitForLabel(chip, "label == '👍 2, you reacted'"), "Tapping again didn't add yours: \(chip.label)")
        let fire = app.buttons["reaction-chip-exclamationmark"]
        XCTAssertEqual(fire.label, "🔥 1")
        XCTAssertFalse(fire.isSelected)
    }

    /// Bubble sides: yours on the right in the accent color, others on the left
    /// with their name once per run (read from the group identifiers).
    func testOwnMessagesSitRightAndOthersLeftWithTheirName() {
        let app = launchChat("chatPolish")
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15), "The seeded thread didn't load")

        let alex = bubble(Polish.question, in: app)
        guard scrollChat(to: alex, in: app) else { return }
        let alexRow = element(Polish.question, in: app).frame
        XCTAssertTrue(alex.label.hasPrefix("Alex, "), alex.label)
        XCTAssertEqual(alex.identifier, bubbleIdentifier(Polish.question, startsGroup: true), "Alex's run should open with his name")
        XCTAssertLessThan(alex.frame.width, alexRow.width - 40, "Measured the row, not the bubble: bubble \(alex.frame), row \(alexRow)")
        // Avatar column (28) plus spacing (8) is all that sits left of his bubble.
        XCTAssertLessThanOrEqual(alex.frame.minX, alexRow.minX + 40, "Alex's bubble should sit at the left of the row: bubble \(alex.frame), row \(alexRow)")
        XCTAssertLessThanOrEqual(alex.frame.maxX, alexRow.maxX - 40, "Alex's bubble should leave room on the right: bubble \(alex.frame), row \(alexRow)")

        let alexAgain = bubble(Polish.alexSecond, in: app)
        guard scrollChat(to: alexAgain, in: app) else { return }
        XCTAssertEqual(alexAgain.identifier, bubbleIdentifier(Polish.alexSecond, startsGroup: false), "Alex's name should show once per run")
        XCTAssertLessThanOrEqual(abs(alexAgain.frame.minX - alex.frame.minX), 1, "Alex's run should line up on the left")

        let mine = bubble(Polish.mineFirst, in: app)
        guard scrollChat(to: mine, in: app) else { return }
        let mineRow = element(Polish.mineFirst, in: app).frame
        XCTAssertTrue(mine.label.hasPrefix("You, "), mine.label)
        XCTAssertLessThan(mine.frame.width, mineRow.width - 40, "Measured the row, not the bubble: bubble \(mine.frame), row \(mineRow)")
        XCTAssertGreaterThanOrEqual(mine.frame.maxX, mineRow.maxX - 2, "Your bubble should hug the row's right edge: bubble \(mine.frame), row \(mineRow)")
        XCTAssertGreaterThanOrEqual(mine.frame.minX, mineRow.minX + 40, "Your bubble should leave room on the left: bubble \(mine.frame), row \(mineRow)")
        XCTAssertGreaterThan(mine.frame.maxX, alex.frame.maxX + 20, "Yours and Alex's are on the same side")
    }

    /// A reaction on your own message sits under it on the right, inside the
    /// screen at AX5, and the + button opens the emoji row there too.
    ///
    /// Every query here is scoped to the message list or to the row, and frames
    /// are read from one snapshot per step instead of one round trip per
    /// property. Each XCUI round trip waits for the app to idle and snapshots
    /// on the main thread; at AX5 the whole tree is large, and this test used to
    /// make dozens of whole-tree round trips (the picker loop alone made two per
    /// emoji). The assertions are the same ones as before. Each step prints its
    /// time as "[ui-timing] reactions-ax5 <step> <seconds>s" so a slow step shows
    /// up in the log even when the test passes.
    func testReactionsSitUnderTheBubbleOnItsSideAtLargeText() throws {
        var clock = StepClock("reactions-ax5")
        let app = launchChat("chatPolish", largeText: true)
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.descendants(matching: .any)[Polish.reply].waitForExistence(timeout: 15))
        let width = app.windows.firstMatch.frame.width
        clock.lap("launch")

        let row = list.descendants(matching: .any)[Polish.mineFirst]
        let mine = bubble(Polish.mineFirst, in: row)
        guard scrollChat(to: mine, in: app) else { return }
        clock.lap("scroll-to-bubble")
        mine.press(forDuration: 1.2)
        let menuThumbs = app.buttons["Thumbs up"]
        XCTAssertTrue(menuThumbs.waitForExistence(timeout: 5), "Long-press had no reactions")
        clock.lap("open-menu")
        menuThumbs.tap()
        clock.lap("tap-thumbs-up")

        let chips = row.descendants(matching: .any)["chat.reactions.\(token(Polish.mineFirst))"]
        let chip = chips.buttons[Polish.thumbs]
        guard scrollChat(to: chip, in: app) else { return }
        clock.lap("scroll-to-chip")
        // One snapshot of the row answers every frame, label and trait below.
        let rowShot = try row.snapshot()
        clock.lap("row-snapshot")
        let chipsShot = try XCTUnwrap(Self.find(rowShot) { $0.identifier == "chat.reactions.\(self.token(Polish.mineFirst))" }, "No chips under the bubble")
        let chipShot = try XCTUnwrap(Self.find(chipsShot) { $0.elementType == .button && $0.identifier == Polish.thumbs }, "No thumbs-up chip")
        let mineShot = try XCTUnwrap(Self.find(rowShot) { $0.elementType == .button && $0.identifier.hasPrefix("chat.bubble.\(self.token(Polish.mineFirst)).") }, "No bubble in the row")
        let rowFrame = rowShot.frame
        let mineFrame = mineShot.frame
        let chipsFrame = chipsShot.frame
        let chipFrame = chipShot.frame
        XCTAssertEqual(chipShot.label, "👍 1, you reacted")
        XCTAssertTrue(chipShot.isSelected)
        XCTAssertLessThanOrEqual(abs(chipsFrame.maxX - mineFrame.maxX), 2, "Your chips should sit under your bubble on the right: chips \(chipsFrame), bubble \(mineFrame)")
        XCTAssertGreaterThanOrEqual(mineFrame.maxX, rowFrame.maxX - 2, "Your bubble should hug the row's right edge at AX5: bubble \(mineFrame), row \(rowFrame)")
        XCTAssertGreaterThanOrEqual(chipFrame.minX, 0, "The chip is clipped on the left at AX5: \(chipFrame)")
        XCTAssertLessThanOrEqual(chipFrame.maxX, width + 1, "The chip runs off screen at AX5: \(chipFrame)")
        XCTAssertGreaterThan(chipFrame.minY, mineFrame.maxY - 1, "The chip overlaps the bubble: chip \(chipFrame), bubble \(mineFrame)")
        assertHitSize(chipFrame.height)

        let addShot = Self.find(chipsShot) { $0.elementType == .button && $0.identifier == "reaction-add" }
        XCTAssertNotNil(addShot, "No + to open the emoji row")
        XCTAssertEqual(addShot?.label, "Add a reaction")
        chips.buttons["reaction-add"].tap()
        clock.lap("tap-add")
        let picker = row.descendants(matching: .any)["reaction-picker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5), "+ did not open the emoji row")
        assertStillRunning(app, "after + opened the emoji row")
        clock.lap("open-picker")
        // The whole emoji row in one snapshot; was two whole-tree resolutions per emoji.
        let pickerShot = try picker.snapshot()
        clock.lap("picker-snapshot")
        let options = Self.findAll(pickerShot) { $0.elementType == .button }
        let selectedShot = options.first { $0.identifier == "tapback-hand.thumbsup.fill" }
        XCTAssertTrue(selectedShot?.isSelected == true, "The row should show your current reaction")
        for option in options {
            XCTAssertGreaterThanOrEqual(option.frame.minX, 0, "An emoji is clipped at AX5: \(option.frame)")
            XCTAssertLessThanOrEqual(option.frame.maxX, width + 1, "An emoji runs off screen at AX5: \(option.frame)")
        }
        clock.mark("tap-take-back start")
        picker.buttons["tapback-hand.thumbsup.fill"].tap()
        clock.lap("tap-take-back")
        XCTAssertTrue(chip.waitForNonExistence(timeout: 5), "Picking your own reaction again should take it back")
        // A query on a dead app also "doesn't exist": 64b2b97 run 3 passed after the
        // app had aborted mid take-back. The app must still be the one we launched.
        assertStillRunning(app, "after taking the reaction back")
        clock.lap("take-back")
        clock.total()
    }

    /// Fails if the app has crashed, aborted or been terminated. Known issue:
    /// app/docs/known-issues.md (AX5 reactions layout hang).
    private func assertStillRunning(_ app: XCUIApplication, _ when: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(app.state, .runningForeground, "The app is not running \(when) (state \(app.state.rawValue)); see the hang watchdog's crash report", file: file, line: line)
    }

    /// First element in a snapshot (itself included, depth first) that matches.
    private static func find(_ root: any XCUIElementSnapshot, where match: (any XCUIElementSnapshot) -> Bool) -> (any XCUIElementSnapshot)? {
        if match(root) { return root }
        for child in root.children {
            if let found = find(child, where: match) { return found }
        }
        return nil
    }

    /// Every element in a snapshot that matches, in tree order.
    private static func findAll(_ root: any XCUIElementSnapshot, where match: (any XCUIElementSnapshot) -> Bool) -> [any XCUIElementSnapshot] {
        (match(root) ? [root] : []) + root.children.flatMap { findAll($0, where: match) }
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
        assertHitSize(retry.frame.height, "Retry is too short to hit")
        retry.tap()
        XCTAssertTrue(caption("Sent", in: app).waitForExistence(timeout: 5), "The retried message didn't say Sent")
        XCTAssertFalse(caption("Not delivered", in: app).exists)
        let sent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, once, "))
        XCTAssertEqual(sent.count, 1, "Retry made a second bubble")
        XCTAssertFalse(element("unread-divider", in: app).exists, "Sending should clear the unread divider")
    }

    /// The phone repro without Airplane Mode: DEBUG -SQ8NetworkFault turns the
    /// network off and on. Offline send: Not delivered and Reconnecting…; back
    /// online, Retry: the banner goes and there's one bubble.
    func testBannerClearsAfterRetryOnceTheNetworkIsBack() {
        let app = launchChat("chatPolish", extra: ["-SQ8NetworkFault"])
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let title = element("squad-title", in: app)
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        // Armed mock chat simulates a connected link (no "Live chat is down") once it starts.
        XCTAssertTrue(waitForLabel(title, "value == nil OR value == ''"), "No banner before going offline: \(title.value ?? "nil")")
        let network = app.buttons["debug-network-fault"]
        XCTAssertTrue(network.waitForExistence(timeout: 5), "The DEBUG network switch is missing")
        XCTAssertEqual(network.value as? String, "On")
        network.tap()
        XCTAssertTrue(waitForLabel(network, "value == 'Off'"), "The network didn't go off")

        let field = app.textFields["Message"]
        field.tap()
        field.typeText("offline once")
        app.buttons["send-message"].tap()
        XCTAssertTrue(caption("Not delivered", in: app).waitForExistence(timeout: 5), "The offline send didn't say Not delivered")
        XCTAssertTrue(waitForLabel(title, "value == 'Reconnecting…'"), "The header didn't say Reconnecting…: \(title.value ?? "nil")")

        network.tap()
        XCTAssertTrue(waitForLabel(network, "value == 'On'"), "The network didn't come back on")
        let retry = app.buttons["retry-send"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        retry.tap()
        XCTAssertTrue(caption("Sent", in: app).waitForExistence(timeout: 5), "The retried message didn't say Sent")
        XCTAssertFalse(caption("Not delivered", in: app).exists)
        XCTAssertTrue(waitForLabel(title, "value == nil OR value == ''"), "Reconnecting… stayed after the retry went through: \(title.value ?? "nil")")
        let sent = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, offline once, "))
        XCTAssertEqual(sent.count, 1, "Retry made a second bubble")
    }

    func testEmptySquadSaysSo() {
        let app = launchChat("chatEmpty")
        let empty = element("chat-empty", in: app)
        XCTAssertTrue(empty.waitForExistence(timeout: 15), "No empty state")
        XCTAssertEqual(empty.label, "No messages yet. Say hi to the group.")
        XCTAssertFalse(app.buttons["jump-to-latest"].exists)
    }

    func testHistoryErrorOffersRetryThenLoads() {
        let app = launchChat("chatHistoryFailed")
        let error = element("chat-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 15), "No history error")
        XCTAssertEqual(error.label, "Messages couldn't load.")
        let retry = app.buttons["chat-retry"]
        XCTAssertTrue(waitUntil(timeout: 5) { retry.isHittable }, "Retry isn't on screen: \(retry.frame)")
        assertHitSize(retry.frame.height, "Retry is too short to hit")
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
        assertHitSize(retry.frame.height)
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

    // MARK: Chat durability

    private enum Long {
        static func id(_ index: Int) -> String {
            "message-row-00000000-0000-4000-8000-" + String(format: "%012X", 0x1000 + index)
        }
        static let newest = id(259)
        /// The oldest message in the first history read (the newest 200).
        static let firstReadTop = id(60)
        /// The newest message of the first older page.
        static let firstPageNewest = id(59)
        static let oldest = id(0)
    }

    /// Message rows whose frame is fully inside the list, top first.
    private func visibleMessageRows(in app: XCUIApplication, list: XCUIElement) -> [(id: String, frame: CGRect)] {
        let bounds = list.frame
        return app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'message-row-'"))
            .allElementsBoundByIndex
            .compactMap { row -> (id: String, frame: CGRect)? in
                let frame = row.frame
                guard !frame.isEmpty, frame.minY >= bounds.minY, frame.maxY <= bounds.maxY else { return nil }
                return (row.identifier, frame)
            }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    func testScrollingUpLoadsOlderMessagesUntilStartOfChat() {
        // The mock holds every older page until the test releases it
        // (-mock-older-gate), and a hidden probe reports the paging state, so
        // "before" and "after" a page lands are read with nothing racing them.
        // Pages may be asked for before the top (prefetch); what matters is that
        // what the reader sees doesn't move when one lands.
        let app = launchChat("chatLongHistory", extra: ["-mock-older-gate"])
        XCTAssertTrue(element(Long.newest, in: app).waitForExistence(timeout: 15), "The thread never loaded")
        XCTAssertFalse(element(Long.firstPageNewest, in: app).exists, "More than one read's worth loaded up front")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let probe = element("debug-older-paging", in: app)
        let release = element("debug-older-release", in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: 5), "No paging probe; is -mock-older-gate wired up?")
        XCTAssertTrue(release.exists, "No release control")
        let paging = { (probe.value as? String) ?? "" }
        let releaseOne = { release.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap() }
        let landed = element(Long.firstPageNewest, in: app)
        let start = element("chat-start", in: app)
        let error = element("chat-older-error", in: app)
        XCTAssertEqual(paging(), "idle pages=0")

        // Phase 1: swipe until page 1 is asked for (and held). It's only asked for
        // once message 60 comes up near the screen, never from the bottom.
        var held = false
        for _ in 0..<40 {
            list.swipeDown()
            if paging().hasPrefix("loading") { held = true; break }
        }
        guard held else {
            XCTFail("Scrolling up never asked for an older page: \(paging())")
            return
        }
        XCTAssertEqual(paging(), "loading pages=0")
        XCTAssertFalse(landed.exists, "Page 1 went in while held")
        XCTAssertTrue(element(Long.firstReadTop, in: app).exists, "Page 1 was asked for with message 60 nowhere near the screen")
        // Let the list come to rest (bounded), then record the topmost fully visible row.
        var previous: [CGRect] = []
        var rows: [(id: String, frame: CGRect)] = []
        _ = waitUntil(timeout: 6) {
            rows = self.visibleMessageRows(in: app, list: list)
            let frames = rows.map(\.frame)
            defer { previous = frames }
            return !rows.isEmpty && frames == previous
        }
        guard let reference = rows.first else {
            XCTFail("No message row fully on screen before page 1")
            return
        }
        XCTAssertFalse(landed.exists, "Page 1 went in while held")
        releaseOne()
        XCTAssertTrue(waitUntil(timeout: 10) { paging().contains("pages=1") }, "Page 1 never landed: \(paging())")
        // Page 1's rows are above the reader and may not be laid out yet; phase 2
        // reaching message 0 shows they went in.
        let after = element(reference.id, in: app)
        XCTAssertTrue(after.exists, "\(reference.id) left the tree when page 1 landed")
        XCTAssertTrue(after.frame.intersects(list.frame), "\(reference.id) went off screen when page 1 landed: \(after.frame)")
        XCTAssertEqual(after.frame.minY, reference.frame.minY, accuracy: 1, "\(reference.id) moved when page 1 landed")

        // Phase 2: fast flings, releasing each page as it's asked for, until the
        // start of the chat. Bounded; an error row fails the test.
        for _ in 0..<80 {
            if start.exists || error.exists { break }
            if paging().hasPrefix("loading") {
                releaseOne()
                _ = waitUntil(timeout: 10) { !paging().hasPrefix("loading") }
                continue
            }
            list.swipeDown(velocity: .fast)
        }
        XCTAssertFalse(error.exists, "Paging failed: \(error.exists ? error.label : "")")
        XCTAssertTrue(start.waitForExistence(timeout: 10), "No Start of chat after paging back: \(paging())")
        XCTAssertEqual(start.label, "Start of chat")
        XCTAssertEqual(paging(), "reachedStart pages=2")
        XCTAssertTrue(element(Long.oldest, in: app).exists, "The first message isn't there at the start of the chat")
    }

    func testColdLaunchFromAPushOpensAnOldMessage() {
        // Message 1 of 260 is outside the first read: the push has to wait for the
        // chat's first load, page back for it, then scroll to it.
        let app = XCUIApplication()
        let payload = #"{"type":"squad_message","squad_id":"00000000-0000-0000-0000-000000000010","message_id":"00000000-0000-4000-8000-000000001000"}"#
        app.launchArguments = ["-backend", "mock", "-scenario", "chatLongHistory", "-debug-push-open", payload]
        app.launch()
        let opened = element("push-opened-chat", in: app)
        XCTAssertTrue(opened.waitForExistence(timeout: 15), "The chat from the notification did not open")
        let list = app.scrollViews["message-list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let oldest = element(Long.oldest, in: app)
        XCTAssertTrue(waitUntil(timeout: 15) { oldest.exists && oldest.frame.intersects(list.frame) },
                      "The pushed message (1 of 260) wasn't opened: \(oldest.exists ? "\(oldest.frame)" : "not loaded")")
        XCTAssertFalse(element("chat-older-error", in: app).exists)
    }

    func testFailedMessageIsStillThereAfterRelaunch() {
        let first = launchChat("chatPolish", extra: ["-debug-fail-sends", "1"])
        XCTAssertTrue(element(Polish.reply, in: first).waitForExistence(timeout: 15))
        let field = first.textFields["Message"]
        field.tap()
        field.typeText("survives a kill")
        first.buttons["send-message"].tap()
        XCTAssertTrue(caption("Not delivered", in: first).waitForExistence(timeout: 5), "The send didn't fail")
        first.terminate()

        // Same mock outbox on disk; the relaunch doesn't fail sends.
        let app = launchChat("chatPolish", extra: ["-keepOutbox"])
        XCTAssertTrue(element(Polish.reply, in: app).waitForExistence(timeout: 15))
        let restored = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "You, survives a kill, "))
        XCTAssertTrue(restored.firstMatch.waitForExistence(timeout: 5), "The failed message was lost on relaunch")
        XCTAssertTrue(caption("Not delivered", in: app).exists, "The restored message doesn't say Not delivered")
        let retry = app.buttons["retry-send"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5), "No Retry on the restored message")
        scrollChat(to: retry, in: app)
        retry.tap()
        XCTAssertTrue(caption("Sent", in: app).waitForExistence(timeout: 5), "The restored message didn't send on Retry")
        XCTAssertEqual(restored.count, 1, "Retry made a second bubble")
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
        assertHitSize(chip.frame.height)
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
        assertHitSize(cancel.frame.height)
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

    // MARK: Waiting

    /// Polls a condition on the main run loop; true as soon as it holds, false at the timeout.
    private func waitUntil(timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() >= deadline { return false }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return true
    }

    // MARK: Hit sizes

    /// Floating point puts a 44pt frame at 43.99999999999994, so every 44pt size
    /// check goes through here and allows 0.5pt.
    private static let minimumHitSize: CGFloat = 44 - 0.5

    private func assertHitSize(_ value: CGFloat, _ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertGreaterThanOrEqual(value, Self.minimumHitSize, message(), file: file, line: line)
    }

    private func assertHitTarget(_ target: XCUIElement, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        assertHitSize(target.frame.height, "\(what) is too short to hit: \(target.frame)", file: file, line: line)
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
        XCTAssertEqual(element("onboarding-header", in: app).label, "Find your group, Step 4 of 4")
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
        XCTAssertEqual(error.label, "Add the name your group will see.")
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
        assertHitSize(remove.frame.width)
        XCTAssertLessThanOrEqual(remove.frame.maxX, width + 1)
        let save = app.buttons["onboarding-save-profile"]
        guard revealInOnboarding(save, in: app) else { return }
        save.tap()
        let create = app.buttons["create-squad"]
        XCTAssertTrue(create.waitForExistence(timeout: 5), "No squad step at AX5")
        guard revealInOnboarding(create, in: app, container: "onboarding-squad") else { return }
        assertHitTarget(create, "Create group")
        XCTAssertLessThanOrEqual(create.frame.maxX, width + 1)
    }

    // MARK: Errors stay above the keyboard (AX5)

    /// Waits for the keyboard (focusing `field` if it went away), then checks the
    /// whole error frame sits above the keyboard and below the top of the screen.
    private func assertErrorAboveKeyboard(_ error: XCUIElement, focusing field: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let keyboard = app.keyboards.firstMatch
        if !keyboard.waitForExistence(timeout: 2) {
            guard revealInOnboarding(field, in: app, file: file, line: line) else { return }
            field.tap()
        }
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5), "No keyboard to check against", file: file, line: line)
        let top = element("onboarding", in: app).frame.minY
        let clear = waitUntil(timeout: 4) {
            error.exists && error.frame.height > 0
                && error.frame.maxY <= keyboard.frame.minY + 0.5
                && error.frame.minY >= top - 0.5
        }
        XCTAssertTrue(clear, "The error isn't fully above the keyboard: error \(error.frame), keyboard \(keyboard.frame), top \(top)", file: file, line: line)
    }

    func testSignInEmailErrorStaysAboveKeyboardAtLargeText() {
        let app = launchChat("onboarding", largeText: true)
        let field = app.textFields["signin-email"]
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        sendCode(app, email: "nope")
        let error = element("signin-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 3), "No error for a bad email")
        XCTAssertEqual(error.label, Onboard.invalidEmail)
        assertErrorAboveKeyboard(error, focusing: field, in: app)
    }

    func testWrongCodeErrorStaysAboveKeyboardAtLargeText() {
        let app = launchChat("onboarding", largeText: true)
        XCTAssertTrue(app.textFields["signin-email"].waitForExistence(timeout: 15))
        sendCode(app)
        enterCode("000000", in: app)
        let error = element("signin-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 5), "No error for a wrong code")
        XCTAssertEqual(error.label, Onboard.wrongCode)
        assertErrorAboveKeyboard(error, focusing: app.textFields["signin-code"], in: app)
    }

    func testProfileNameErrorStaysAboveKeyboardAtLargeText() {
        let app = launchChat("onboardingProfile", largeText: true)
        let name = app.textFields["onboarding-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 15))
        guard revealInOnboarding(name, in: app) else { return }
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 20))
        let save = app.buttons["onboarding-save-profile"]
        guard revealInOnboarding(save, in: app) else { return }
        save.tap()
        let error = element("onboarding-name-error", in: app)
        XCTAssertTrue(error.waitForExistence(timeout: 3), "An empty name moved on")
        XCTAssertEqual(error.label, "Add the name your group will see.")
        assertErrorAboveKeyboard(error, focusing: name, in: app)
    }
}

/// Prints how long each step of a UI test took, as
/// "[ui-timing] <test> <step> <seconds>s", so a run log shows which XCUI round
/// trip was slow (an app that never idles makes every step slow; one huge
/// snapshot makes only that step slow).
struct StepClock {
    private let name: String
    private let started = Date()
    private var last = Date()

    init(_ name: String) {
        self.name = name
    }

    mutating func lap(_ step: String) {
        let now = Date()
        print(String(format: "[ui-timing] %@ %@ %.2fs", name, step, now.timeIntervalSince(last)))
        last = now
    }

    /// A step is about to start; if the run hangs, this is the last line printed.
    func mark(_ step: String) {
        print(String(format: "[ui-timing] %@ %@ at %.2fs", name, step, Date().timeIntervalSince(started)))
    }

    func total() {
        print(String(format: "[ui-timing] %@ total %.2fs", name, Date().timeIntervalSince(started)))
    }
}
