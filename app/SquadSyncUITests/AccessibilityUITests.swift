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

        let row = app.descendants(matching: .any)["member-spencer"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Spencer's row was not in the accessibility tree")
        let tab = app.descendants(matching: .any)["tab-space"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Space tab was not in the accessibility tree")
        XCTAssertLessThanOrEqual(
            row.frame.maxY,
            tab.frame.minY + 1,
            "Spencer's row ends at \(row.frame.maxY), under the tab bar at \(tab.frame.minY)"
        )
    }

    func testInboxLastRowClearsTheTabBarAfterScrollingAtLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "inbox", "-uitest-largeText"]
        app.launch()

        let tab = app.descendants(matching: .any)["tab-inbox"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15), "Inbox tab was not in the accessibility tree")
        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 15), "Inbox scroll view was not found")
        for _ in 0..<8 {
            scroll.swipeUp()
        }

        let row = app.descendants(matching: .any)["inbox-dm-riley"]
        XCTAssertTrue(row.waitForExistence(timeout: 15), "Last inbox row was not in the accessibility tree")
        XCTAssertLessThanOrEqual(
            row.frame.maxY,
            tab.frame.minY + 1,
            "Last inbox row ends at \(row.frame.maxY), under the tab bar at \(tab.frame.minY)"
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
}
