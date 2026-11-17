import XCTest
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
