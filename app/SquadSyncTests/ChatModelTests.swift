import XCTest
import Observation
@testable import SquadSync

/// Message polish (redesign S3) through the session model on the mock backend:
/// replies behind the capability check, Copy, the unread divider, history states,
/// and reaction chips.
@MainActor
final class ChatModelTests: XCTestCase {
    private func model(_ scenario: LaunchScenario) -> LiveSessionModel {
        LiveSessionModel(
            config: BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test"),
            backend: .mock,
            scenario: scenario
        )
    }

    func testFirstLoadSettlesTheUnreadDividerAndSendingClearsIt() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        XCTAssertEqual(model.chatLoad, .loaded)
        XCTAssertEqual(model.unreadMarker.anchor, ChatPolishSeed.firstUnread)
        await model.catchUp(pinned: true)
        XCTAssertEqual(model.unreadMarker.anchor, ChatPolishSeed.firstUnread, "Reading must not move the divider")
        model.draft = "on my way"
        await model.send()
        XCTAssertNil(model.unreadMarker.anchor, "Sending clears the divider")
    }

    /// The mock backend has no socket, so it polls every 3 s for the app's whole
    /// life. A poll that brings nothing new must not write anything a view reads:
    /// an @Observable write redraws its readers even when the value is equal, and
    /// re-entering the spot's loading state put a spinner row at the top of the
    /// thread. That redraw every 3 s kept the AX5 chat busy under XCUI snapshots.
    func testAPollThatBringsNothingNewRedrawsNothing() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        await model.pollNow()
        XCTAssertEqual(model.polls, 1, "The poll didn't run; is the chat loaded?")
        XCTAssertEqual(model.spotLoad, .loaded)
        let changed = Changed()
        let reads: [(String, () -> Void)] = [
            ("log", { _ = model.log }),
            ("chatLoad", { _ = model.chatLoad }),
            ("spot", { _ = model.spot }),
            ("spotLoad", { _ = model.spotLoad }),
            ("spotServer", { _ = model.spotServer }),
            ("spotHistory", { _ = model.spotHistory }),
            ("spotHistoryNote", { _ = model.spotHistoryNote }),
            ("status", { _ = model.status }),
            ("presenceNote", { _ = model.presenceNote }),
            ("reconnecting", { _ = model.reconnecting }),
            ("link", { _ = model.link })
        ]
        for (name, read) in reads {
            withObservationTracking(read, onChange: { changed.add(name) })
        }
        await model.pollNow()
        XCTAssertEqual(model.polls, 2)
        XCTAssertEqual(changed.names, [], "A poll with nothing new redrew views that read these")
        XCTAssertEqual(model.spotLoad, .loaded, "A refresh must not show the spot loading row again")
    }

    func testReplySendsWithTheOriginalsIdAndClearsTheBanner() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        XCTAssertTrue(model.chatCaps.replies)
        model.startReply(ChatPolishSeed.question)
        XCTAssertEqual(model.replyQuote?.text, "Alex: Who's on tonight?")
        model.draft = "Me too"
        await model.send()
        let sent = model.log.ordered.last
        XCTAssertEqual(sent?.body, "Me too")
        XCTAssertEqual(sent?.replyToId, ChatPolishSeed.question)
        XCTAssertEqual(sent?.delivery, .sent)
        XCTAssertNil(model.replyingTo)
        await model.reloadChat()
        XCTAssertEqual(model.log.entries.filter { $0.body == "Me too" }.count, 1, "The reload must not duplicate the reply")
    }

    func testCancelReplySendsAPlainMessage() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        model.startReply(ChatPolishSeed.question)
        model.cancelReply()
        model.draft = "plain"
        await model.send()
        XCTAssertNil(model.log.ordered.last?.replyToId)
    }

    func testWithoutTheReplyColumnReplyIsOffAndSaysWhy() async {
        let model = model(.chatNoReplies)
        await model.reloadChat()
        XCTAssertFalse(model.chatCaps.replies)
        model.startReply(ChatPolishSeed.question)
        XCTAssertNil(model.replyingTo)
        XCTAssertEqual(model.chatToast, ChatCapabilities.repliesUnavailable)
        model.draft = "still sends"
        await model.send()
        XCTAssertEqual(model.log.ordered.last?.delivery, .sent)
        XCTAssertNil(model.log.ordered.last?.replyToId)
    }

    func testCopyPutsTheBodyOnTheClipboardAndSaysCopied() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        var copied: [String] = []
        model.copyText = { copied.append($0) }
        model.copy(ChatPolishSeed.question)
        XCTAssertEqual(copied, ["Who's on tonight?"])
        XCTAssertEqual(model.chatToast, "Copied")
    }

    func testHistoryFailureSaysSoAndRetryLoads() async {
        let model = model(.chatHistoryFailed)
        await model.reloadChat()
        XCTAssertEqual(model.chatLoad, .failed(ChatHistoryState.failedText))
        XCTAssertEqual(model.chatLoad.display(hasMessages: !model.log.entries.isEmpty), .failed(ChatHistoryState.failedText))
        await model.retryChatLoad()
        XCTAssertEqual(model.chatLoad, .loaded)
        XCTAssertFalse(model.log.entries.isEmpty)
        XCTAssertNil(model.chatLoad.display(hasMessages: true))
    }

    func testEmptySquadSaysSo() async {
        let model = model(.chatEmpty)
        await model.reloadChat()
        XCTAssertEqual(model.chatLoad.display(hasMessages: !model.log.entries.isEmpty), .empty)
    }

    func testChatViewerIsTheSessionUserSoYourOwnMessagesAreMine() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        XCTAssertNotNil(model.chatViewerId)
        XCTAssertEqual(model.chatViewerId, model.viewerId)
        let mineSent = model.log.ordered.filter { $0.senderId == model.chatViewerId }
        XCTAssertFalse(mineSent.isEmpty, "The polish seed has messages from you")
        XCTAssertTrue(model.log.ordered.contains { $0.senderId != model.chatViewerId }, "and from others")
    }

    func testTappingAReactionChipTogglesYoursOnly() async {
        let model = model(.chatPolish)
        await model.reloadChat()
        let before = ChatReactions.chips(marks: model.board.marks, messageId: ChatPolishSeed.question, viewerId: model.viewerId)
        XCTAssertEqual(before.first?.count, 2)
        XCTAssertEqual(before.first?.mine, true)
        await model.tap(.thumbs, on: ChatPolishSeed.question)
        let after = ChatReactions.chips(marks: model.board.marks, messageId: ChatPolishSeed.question, viewerId: model.viewerId)
        XCTAssertEqual(after.first?.count, 1)
        XCTAssertEqual(after.first?.mine, false)
        await model.tap(.emphasize, on: ChatPolishSeed.question)
        let fire = ChatReactions.chips(marks: model.board.marks, messageId: ChatPolishSeed.question, viewerId: model.viewerId)
            .first { $0.tapback == .emphasize }
        XCTAssertEqual(fire?.count, 2)
        XCTAssertEqual(fire?.mine, true)
    }
}

/// Which observed properties were written. onChange runs synchronously on the
/// writer's thread (the main actor here), so no lock.
private final class Changed: @unchecked Sendable {
    private(set) var names: [String] = []
    func add(_ name: String) { names.append(name) }
}
