import XCTest
@testable import SquadSync

/// Message polish (redesign S3): grouping, day separators, quiet times, delivery
/// captions, read receipts, the unread divider, reaction chips, replies, and
/// history states. Foundation only.
final class ChatThreadTests: XCTestCase {
    private let me = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let riley = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!
    private let alex = UUID(uuidString: "00000000-0000-0000-0000-000000000012")!
    private let sam = UUID(uuidString: "00000000-0000-0000-0000-000000000013")!

    private var clock: ChatClock {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return ChatClock(calendar: calendar, locale: Locale(identifier: "en_US"))
    }

    /// 2026-11-17 15:04:00 in Chicago (21:04 UTC).
    private let now = Date(timeIntervalSince1970: 1_794_949_440)

    private func entry(_ n: Int, _ sender: UUID, at offset: TimeInterval, delivery: Delivery = .sent, reply: UUID? = nil) -> ChatEntry {
        ChatEntry(
            id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!,
            senderId: sender,
            body: "m\(n)",
            sentAt: now.addingTimeInterval(offset),
            delivery: delivery,
            replyToId: reply
        )
    }

    private func context(reads: [MemberRead] = [], anchor: UUID? = nil) -> ChatThread.Context {
        ChatThread.Context(
            viewerId: me,
            names: [riley: "Riley", alex: "Alex", sam: "Sam", me: "Spencer"],
            reads: reads,
            unreadAnchor: anchor,
            clock: clock,
            now: now
        )
    }

    private func bubbles(_ rows: [ChatRow]) -> [ChatBubble] {
        rows.compactMap { if case .message(let bubble) = $0 { return bubble } else { return nil } }
    }

    private func items(_ entries: [ChatEntry]) -> [SpotThreadItem] {
        entries.map { .message($0) }
    }

    func testTimesAreQuietAndDaysReadLikeAMessenger() {
        XCTAssertEqual(clock.time(now), "3:04 PM")
        XCTAssertEqual(clock.day(now.addingTimeInterval(-3600), now: now), "Today")
        XCTAssertEqual(clock.day(now.addingTimeInterval(-86_400), now: now), "Yesterday")
        XCTAssertEqual(clock.day(now.addingTimeInterval(-3 * 86_400), now: now), "Saturday")
        XCTAssertEqual(clock.day(now.addingTimeInterval(-14 * 86_400), now: now), "Nov 3")
        XCTAssertEqual(clock.day(now.addingTimeInterval(-365 * 86_400), now: now), "Nov 17, 2025")
    }

    func testSameSenderWithinFiveMinutesIsOneGroup() {
        let entries = [
            entry(1, riley, at: -600),
            entry(2, riley, at: -540),
            entry(3, riley, at: -120),
            entry(4, alex, at: -60)
        ]
        let shown = bubbles(ChatThread.rows(items: items(entries), context: context()))
        XCTAssertEqual(shown.map(\.startsGroup), [true, false, true, true])
        XCTAssertEqual(shown.map(\.endsGroup), [false, true, true, true])
        XCTAssertEqual(shown.map(\.senderName), ["Riley", "Riley", "Riley", "Alex"])
        XCTAssertEqual(shown.map { ChatSeed.bubbleIdentifier(for: $0.entry.id, startsGroup: $0.startsGroup) },
                       shown.map { "chat.bubble.\($0.entry.id.uuidString)." + ($0.startsGroup ? "start" : "continues") },
                       "The UI tests read grouping from these identifiers")
        XCTAssertEqual(shown.map { ChatSeed.bubbleIdentifier(for: $0.entry.id, startsGroup: $0.startsGroup).components(separatedBy: ".").last },
                       ["start", "continues", "start", "start"])
        XCTAssertEqual(ChatSeed.rowIdentifier(for: ChatSeed.messageId), "message-row-seed-1")
        XCTAssertEqual(ChatSeed.bubbleIdentifier(for: ChatSeed.messageId, startsGroup: true), "chat.bubble.seed-1.start")
        XCTAssertEqual(ChatSeed.reactionsIdentifier(for: ChatSeed.messageId), "chat.reactions.seed-1")
        XCTAssertEqual(shown.first?.time, "2:54 PM")
    }

    func testANewDayBreaksTheGroupAndAddsASeparator() {
        // 23:58 and 00:01 Chicago time, same sender, three minutes apart.
        let midnight = clock.calendar.startOfDay(for: now)
        let late = ChatEntry(id: UUID(), senderId: riley, body: "late", sentAt: midnight.addingTimeInterval(-120), delivery: .sent)
        let early = ChatEntry(id: UUID(), senderId: riley, body: "early", sentAt: midnight.addingTimeInterval(60), delivery: .sent)
        let rows = ChatThread.rows(items: items([late, early]), context: context())
        let days = rows.compactMap { if case .day(_, let label) = $0 { return label } else { return nil } }
        XCTAssertEqual(days, ["Yesterday", "Today"])
        XCTAssertEqual(bubbles(rows).map(\.startsGroup), [true, true])
        XCTAssertEqual(rows.map(\.identity).count, Set(rows.map(\.identity)).count, "Row ids must be unique")
    }

    func testASpotCardBreaksTheGroup() {
        let first = entry(1, riley, at: -120)
        let second = entry(2, riley, at: -30)
        let call = SpotCall(
            id: UUID(), squadId: UUID(), callerId: riley, game: "Apex",
            calledAt: now.addingTimeInterval(-400), joinUntil: now.addingTimeInterval(-100),
            lockedAt: nil, closedAt: now.addingTimeInterval(-60), status: .cancelled, rsvps: []
        )
        let rows = ChatThread.rows(items: [.message(first), .spot(call), .message(second)], context: context())
        XCTAssertEqual(bubbles(rows).map(\.startsGroup), [true, true])
        XCTAssertEqual(bubbles(rows).map(\.endsGroup), [true, true])
    }

    func testUnreadDividerSitsBeforeTheAnchorAndCountsOthersMessages() {
        let entries = [
            entry(1, riley, at: -300),
            entry(2, riley, at: -240),
            entry(3, me, at: -200),
            entry(4, alex, at: -100)
        ]
        let rows = ChatThread.rows(items: items(entries), context: context(anchor: entries[1].id))
        let ids = rows.map(\.identity)
        let divider = ids.firstIndex(of: "unread-divider")
        XCTAssertEqual(divider.map { ids[$0 + 1] }, "message-\(entries[1].id.uuidString)")
        XCTAssertTrue(rows.contains(.unread(count: 2)), "Riley's and Alex's messages are unread; yours don't count")
        let shown = bubbles(rows)
        XCTAssertEqual(shown.map(\.startsGroup), [true, true, true, true], "The divider splits Riley's group")
        XCTAssertTrue(shown[0].endsGroup)
        XCTAssertFalse(ChatThread.rows(items: items(entries), context: context()).contains(.unread(count: 2)))
    }

    func testUnreadMarkerSettlesOnceAndClearsWhenYouSend() {
        var log = ChatLog()
        log.ingest([entry(1, riley, at: -300), entry(2, me, at: -200), entry(3, alex, at: -100)])
        log.markRead(at: now.addingTimeInterval(-250))
        XCTAssertEqual(ChatUnreadMarker.firstUnread(in: log, viewerId: me), entry(3, alex, at: -100).id, "Your own message is never the first unread")
        var marker = ChatUnreadMarker()
        marker.settle(log: log, viewerId: me)
        XCTAssertEqual(marker.anchor, entry(3, alex, at: -100).id)
        log.markRead(at: now)
        marker.settle(log: log, viewerId: me)
        XCTAssertEqual(marker.anchor, entry(3, alex, at: -100).id, "Reading the chat must not make the divider jump away")
        marker.clear()
        XCTAssertNil(marker.anchor)
        marker.settle(log: log, viewerId: me)
        XCTAssertNil(marker.anchor, "Cleared stays cleared until the squad reloads")
        marker.reset()
        marker.settle(log: log, viewerId: me)
        XCTAssertNil(marker.anchor, "Everything is read now")
        XCTAssertNil(ChatUnreadMarker.firstUnread(in: ChatLog(), viewerId: me), "No cursor means no divider, not everything unread")
    }

    func testDeliveryCaptionsOnlyOnYourMessages() {
        let entries = [
            entry(1, me, at: -500),
            entry(2, riley, at: -400),
            entry(3, me, at: -300),
            entry(4, me, at: -200, delivery: .failed),
            entry(5, me, at: -100, delivery: .sending)
        ]
        let shown = bubbles(ChatThread.rows(items: items(entries), context: context()))
        XCTAssertEqual(shown.map(\.caption), [nil, nil, "Sent", "Not delivered", "Sending…"])
        XCTAssertEqual(shown.map(\.mine), [true, false, true, true, true])
        XCTAssertEqual(shown[0].senderName, ChatThread.you)
    }

    func testClockReusesItsFormatters() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = clock.time(date)
        let built = ChatFormatterCache.shared.built
        for offset in 1...200 { _ = clock.time(date.addingTimeInterval(Double(offset) * 60)) }
        XCTAssertEqual(ChatFormatterCache.shared.built, built, "Message times reuse one formatter, not one per row per render")
        XCTAssertEqual(clock.time(date), first)
        var paris = clock
        paris.locale = Locale(identifier: "fr_FR")
        XCTAssertNotEqual(paris.time(date.addingTimeInterval(13 * 3600)), clock.time(date.addingTimeInterval(13 * 3600)), "Another locale gets its own formatter")
    }

    func testSeenByIsOnlyOnTheLatestMessageAndOnlyCountsRealReads() {
        let entries = [entry(1, riley, at: -300), entry(2, me, at: -100)]
        let reads = [
            MemberRead(userId: riley, lastReadAt: now),
            MemberRead(userId: alex, lastReadAt: now.addingTimeInterval(-50)),
            MemberRead(userId: sam, lastReadAt: now.addingTimeInterval(-200)),
            MemberRead(userId: me, lastReadAt: now)
        ]
        let shown = bubbles(ChatThread.rows(items: items(entries), context: context(reads: reads)))
        XCTAssertNil(shown[0].seen)
        XCTAssertEqual(shown[1].seen, "Seen by Alex and Riley", "Sam read before it was sent; you don't count")
        XCTAssertNil(shown[1].caption, "The seen line replaces Sent")

        let everyone = reads + [MemberRead(userId: UUID(), lastReadAt: now)]
        XCTAssertEqual(bubbles(ChatThread.rows(items: items(entries), context: context(reads: everyone)))[1].seen, "Seen by 3")
        let theirs = [entry(1, me, at: -300), entry(2, riley, at: -100)]
        XCTAssertEqual(bubbles(ChatThread.rows(items: items(theirs), context: context(reads: reads)))[1].seen, "Seen by Alex", "The sender isn't listed as a reader")
        let pending = [entry(1, me, at: -100, delivery: .sending)]
        XCTAssertNil(bubbles(ChatThread.rows(items: items(pending), context: context(reads: reads)))[0].seen, "An unsent message can't be seen")
        XCTAssertNil(bubbles(ChatThread.rows(items: items(entries), context: context()))[1].seen, "No read rows, no claim")
        XCTAssertEqual(ChatThread.seenLine(["Riley"]), "Seen by Riley")
        var unknownViewer = context(reads: reads)
        unknownViewer.viewerId = nil
        XCTAssertNil(bubbles(ChatThread.rows(items: items(entries), context: unknownViewer))[1].seen,
                     "Before you're known your own read would count (\"Seen by 3\"): no line yet")
    }

    func testReplyQuoteUsesTheLoadedOriginalOrSaysItIsMissing() {
        let original = entry(1, alex, at: -300)
        let reply = entry(2, riley, at: -100, reply: original.id)
        let orphan = entry(3, riley, at: -50, reply: UUID())
        let shown = bubbles(ChatThread.rows(items: items([original, reply, orphan]), context: context()))
        XCTAssertNil(shown[0].reply)
        XCTAssertEqual(shown[1].reply?.text, "Alex: m1")
        XCTAssertEqual(shown[1].reply?.spoken, "Replying to Alex: m1")
        XCTAssertEqual(shown[2].reply?.text, ChatReplyQuote.missing)
        XCTAssertEqual(shown[2].reply?.spoken, "Replying to a message that isn't loaded")
    }

    func testReactionChipsCountPeopleInAFixedOrderAndMarkYours() {
        let message = UUID()
        let marks = [
            ReactionMark(messageId: message, userId: riley, emoji: "🔥"),
            ReactionMark(messageId: message, userId: me, emoji: "👍"),
            ReactionMark(messageId: message, userId: alex, emoji: "👍"),
            ReactionMark(messageId: UUID(), userId: sam, emoji: "😂")
        ]
        let chips = ChatReactions.chips(marks: marks, messageId: message, viewerId: me)
        XCTAssertEqual(chips.map(\.emoji), ["👍", "🔥"])
        XCTAssertEqual(chips.map(\.count), [2, 1])
        XCTAssertEqual(chips.map(\.mine), [true, false])
        XCTAssertEqual(chips[0].spoken, "👍 2, you reacted")
        XCTAssertEqual(chips[1].spoken, "🔥 1")
        XCTAssertEqual(chips[0].hint, "Removes your reaction")
        XCTAssertEqual(chips[1].hint, "Adds your Emphasis reaction")
        XCTAssertEqual(ChatReactions.spoken(chips), "Reactions: Thumbs up 2, Emphasis 1")
        XCTAssertNil(ChatReactions.spoken([]))
    }

    func testReactionPickerSelectsYoursAndPickingItAgainTakesItBack() {
        let message = UUID()
        var board = ReactionBoard()
        board.replace(with: [ReactionMark(messageId: message, userId: alex, emoji: "👍")])
        let fresh = ChatReactions.options(marks: board.marks, messageId: message, viewerId: me)
        XCTAssertEqual(fresh.map(\.emoji), ["👍", "❤️", "😂", "🔥", "😮", "🎮"], "Only the six emoji the server's check allows")
        XCTAssertFalse(fresh.contains { $0.selected }, "Someone else's reaction is not yours")

        // Add: the chip counts both people and is marked yours.
        XCTAssertEqual(board.toggle(messageId: message, userId: me, emoji: "👍"), [.insert("👍")])
        var chips = ChatReactions.chips(marks: board.marks, messageId: message, viewerId: me)
        XCTAssertEqual(chips.map(\.spoken), ["👍 2, you reacted"])
        let picked = ChatReactions.options(marks: board.marks, messageId: message, viewerId: me)
        XCTAssertEqual(picked.filter(\.selected).map(\.emoji), ["👍"])
        XCTAssertEqual(picked.first?.hint, "Removes your reaction")

        // Toggle off: the same emoji again removes yours and keeps Alex's.
        XCTAssertEqual(board.toggle(messageId: message, userId: me, emoji: "👍"), [.remove("👍")])
        chips = ChatReactions.chips(marks: board.marks, messageId: message, viewerId: me)
        XCTAssertEqual(chips.map(\.spoken), ["👍 1"])
        XCTAssertEqual(chips.map(\.mine), [false])

        // One per person: a different emoji replaces yours with a delete then an insert,
        // the two writes sq8_message_reactions' own-row policies allow.
        _ = board.toggle(messageId: message, userId: me, emoji: "🔥")
        XCTAssertEqual(board.toggle(messageId: message, userId: me, emoji: "😂"), [.remove("🔥"), .insert("😂")])
        XCTAssertEqual(ChatReactions.chips(marks: board.marks, messageId: message, viewerId: me).map(\.spoken), ["👍 1", "😂 1, you reacted"])
        XCTAssertFalse(ChatReactions.options(marks: board.marks, messageId: message, viewerId: nil).contains { $0.selected })
    }

    func testOwnMessagesSitTrailingAndOthersLeadingWithTheirNameOncePerRun() {
        let entries = [
            entry(1, alex, at: -600),
            entry(2, alex, at: -540),
            entry(3, me, at: -500),
            entry(4, me, at: -480),
            entry(5, riley, at: -400),
            entry(6, alex, at: -300)
        ]
        let shown = bubbles(ChatThread.rows(items: items(entries), context: context()))
        XCTAssertEqual(shown.map(\.mine), [false, false, true, true, false, false])
        XCTAssertEqual(shown.map(\.side), [.leading, .leading, .trailing, .trailing, .leading, .leading])
        XCTAssertEqual(shown.map(\.showsName), [true, false, false, false, true, true], "Their name once per run, never on yours")
        XCTAssertEqual(shown.map(\.showsAvatar), shown.map(\.showsName))
        XCTAssertEqual(shown.map(\.initial), ["A", "A", "Y", "Y", "R", "A"])
        XCTAssertEqual(ChatBubbleSide.initial("  sam"), "S")
        XCTAssertEqual(ChatBubbleSide.initial(" "), "?")
    }

    func testMineMatchesTheSenderIdHoweverTheUUIDTextIsCased() {
        // sender_id comes back from PostgREST lower-case; a session id may be parsed
        // from upper-case text. Both are the same UUID value, so the side is right.
        let lower = UUID(uuidString: "6f1c2d3e-4b5a-4c6d-8e7f-90a1b2c3d4e5")!
        let upper = UUID(uuidString: "6F1C2D3E-4B5A-4C6D-8E7F-90A1B2C3D4E5")!
        let mine = ChatEntry(id: UUID(), senderId: lower, body: "hi", sentAt: now, delivery: .sent, replyToId: nil)
        let theirs = entry(2, alex, at: 10)
        var ctx = context()
        ctx.viewerId = upper
        let shown = bubbles(ChatThread.rows(items: items([mine, theirs]), context: ctx))
        XCTAssertEqual(shown.map(\.side), [.trailing, .leading])
        ctx.viewerId = nil
        XCTAssertEqual(bubbles(ChatThread.rows(items: items([mine]), context: ctx)).map(\.side), [.leading],
                       "Without a viewer nothing is yours")
    }

    func testLongPressOffersReplyOnlyWhenTheServerHasIt() {
        let sent = entry(1, riley, at: -100)
        XCTAssertEqual(ChatAction.available(for: sent, repliesAvailable: true), [.react, .reply, .copy])
        XCTAssertEqual(ChatAction.available(for: sent, repliesAvailable: false), [.react, .copy])
        XCTAssertEqual(ChatAction.available(for: entry(2, me, at: 0, delivery: .failed), repliesAvailable: true), [.copy, .retry])
        XCTAssertEqual(ChatAction.available(for: entry(3, me, at: 0, delivery: .sending), repliesAvailable: true), [.copy])
        XCTAssertEqual(ChatAction.allCases.map(\.title), ["React", "Reply", "Copy", "Retry sending"])
    }

    func testHistoryStatesSayWhatIsHappening() {
        XCTAssertNil(ChatHistoryState.idle.display(hasMessages: false))
        XCTAssertEqual(ChatHistoryState.loading.display(hasMessages: false), .loading)
        XCTAssertNil(ChatHistoryState.loading.display(hasMessages: true), "A refresh doesn't hide messages behind a spinner")
        XCTAssertEqual(ChatHistoryState.loaded.display(hasMessages: false), .empty)
        XCTAssertNil(ChatHistoryState.loaded.display(hasMessages: true))
        XCTAssertEqual(ChatHistoryState.failed("x").display(hasMessages: false), .failed("x"))
        XCTAssertEqual(ChatHistoryState.failed("x").display(hasMessages: true), .stale(ChatHistoryState.staleText))
        XCTAssertEqual(ChatHistoryState.failure(BackendFailure.notSetUp(.messages)), .failed(ChatHistoryState.notSetUpText))
        XCTAssertEqual(ChatHistoryState.failure(BackendFailure.rejected("boom")), .failed(ChatHistoryState.failedText))
    }

    func testJumpToLatestShowsOnlyWhenScrolledUpAndSaysHowManyAreNew() {
        XCTAssertFalse(ChatJump.shows(pinned: true, hasMessages: true))
        XCTAssertFalse(ChatJump.shows(pinned: false, hasMessages: false))
        XCTAssertTrue(ChatJump.shows(pinned: false, hasMessages: true))
        XCTAssertEqual(ChatJump.label(newCount: 0), "Jump to latest")
        XCTAssertEqual(ChatJump.label(newCount: 1), "1 new message, jump to latest")
        XCTAssertEqual(ChatJump.label(newCount: 4), "4 new messages, jump to latest")
        XCTAssertEqual(ChatJump.title(newCount: 4), "4 new")
        XCTAssertEqual(ChatThread.unreadLabel(1), "1 unread message")
    }

    func testBubbleSpeechIsWhoWhatAndWhen() {
        let shown = bubbles(ChatThread.rows(items: items([entry(1, riley, at: 0)]), context: context()))
        XCTAssertEqual(ChatSpeech.bubble(shown[0]), "Riley, m1, 3:04 PM")
        let unknown = ChatEntry(id: UUID(), senderId: UUID(), body: "hi", sentAt: now, delivery: .sent)
        XCTAssertEqual(bubbles(ChatThread.rows(items: items([unknown]), context: context()))[0].senderName, ChatThread.unknownSender)
    }

    func testReplyIdSurvivesFailRetryAndTheEchoAsOneRow() {
        var log = ChatLog()
        let id = UUID()
        let original = UUID()
        log.beginSend(id: id, senderId: me, body: "me too", now: now, replyToId: original)
        log.markFailed(id: id)
        log.retry(id: id)
        log.beginSend(id: id, senderId: me, body: "me too", now: now, replyToId: original)
        log.ingest([RemoteMessage(id: id, squadId: UUID(), senderId: me, body: "me too", sentAt: now, replyToId: original).entry()])
        log.ingest([ChatEntry(id: id, senderId: me, body: "me too", sentAt: now, delivery: .sent)])
        XCTAssertEqual(log.entries.count, 1)
        XCTAssertEqual(log.entries.first?.delivery, .sent)
        XCTAssertEqual(log.entries.first?.replyToId, original, "An echo without the column keeps the reply")
    }

    func testPolishSeedHasDaysGroupsAnUnreadRunAReplyAndSeenBy() {
        let midnight: TimeInterval = -15 * 3600 - 4 * 60
        let offsets: [TimeInterval] = [0, midnight + 5 * 60, midnight + 5, midnight + 45, midnight + 59]
        for offset in offsets {
            // 3:04 PM; 12:05 AM; and 5, 45 and 59 seconds after midnight, where the
            // first seed put every message at one instant (the Mac's 00:00 unit run).
            let at = now.addingTimeInterval(offset)
            let thread = ChatPolishSeed.thread(viewerId: me, squadId: UUID(), now: at, calendar: clock.calendar)
            XCTAssertTrue(thread.messages.allSatisfy { $0.sentAt <= at }, "Seeded messages must not be in the future")
            var log = ChatLog()
            log.ingest(thread.messages.map { $0.entry() })
            log.markRead(at: thread.reads.first { $0.userId == me }!.lastReadAt)
            XCTAssertEqual(ChatUnreadMarker.firstUnread(in: log, viewerId: me), ChatPolishSeed.firstUnread)
            var seeded = context(reads: thread.reads, anchor: ChatPolishSeed.firstUnread)
            seeded.now = at
            seeded.names = [SpotSeed.alex: "Alex", SpotSeed.jordan: "Jordan", SpotSeed.sam: "Sam", SpotSeed.casey: "Casey"]
            let rows = ChatThread.rows(items: log.ordered.map { .message($0) }, context: seeded)
            let days = rows.compactMap { if case .day(_, let label) = $0 { return label } else { return nil } }
            XCTAssertEqual(days, ["Yesterday", "Today"])
            XCTAssertTrue(rows.contains(.unread(count: 2)))
            let shown = bubbles(rows)
            XCTAssertEqual(shown.last?.seen, "Seen by Alex and Jordan")
            XCTAssertEqual(shown.last?.reply?.text, "Alex: Who's on tonight?")
            XCTAssertEqual(shown.first { $0.entry.body == "I can do 9" }?.startsGroup, false, "Alex's second line groups under the first")
        }
        let plain = ChatPolishSeed.thread(viewerId: me, squadId: UUID(), now: now, replies: false)
        XCTAssertTrue(plain.messages.allSatisfy { $0.replyToId == nil })
    }

    func testPolishSeedTodayRunIsOrderedAfterMidnightAndBeforeNowAtEveryTime() {
        let today = clock.calendar.startOfDay(for: now)
        for since: TimeInterval in [0.01, 0.5, 1, 5, 30, 45, 59, 60, 61, 300, 1799, 1800, 1801, 15 * 3600] {
            let at = today.addingTimeInterval(since)
            let (start, scale) = ChatPolishSeed.todaysRun(now: at, today: today)
            let first = start
            let last = start.addingTimeInterval(30 * 60 * scale)
            XCTAssertGreaterThan(scale, 0, "\(since)s after midnight: every message at one instant")
            XCTAssertGreaterThan(first, today, "\(since)s after midnight: the run starts yesterday")
            XCTAssertLessThan(last, at, "\(since)s after midnight: the run ends in the future")
            let thread = ChatPolishSeed.thread(viewerId: me, squadId: UUID(), now: at, calendar: clock.calendar)
            let todays = thread.messages.filter { $0.sentAt >= today }.map(\.sentAt)
            XCTAssertEqual(todays, todays.sorted(), "\(since)s after midnight: out of order")
            XCTAssertEqual(Set(todays).count, todays.count, "\(since)s after midnight: two messages at one instant")
            XCTAssertTrue(thread.messages.allSatisfy { $0.sentAt < at }, "\(since)s after midnight: a message in the future")
        }
        // Exactly midnight has no "today" to fit in: the run goes just before, still in the past.
        let (start, scale) = ChatPolishSeed.todaysRun(now: today, today: today)
        XCTAssertLessThan(start.addingTimeInterval(30 * 60 * scale), today)
    }
    func testRowsAreBuiltOncePerChangeNotPerRender() {
        let memo = ChatRowMemo()
        let entries = [entry(1, riley, at: -300), entry(2, me, at: -200)]
        let first = memo.rows(items: items(entries), context: context())
        for _ in 0..<50 {
            var later = context()
            later.now = now.addingTimeInterval(30)
            XCTAssertEqual(memo.rows(items: items(entries), context: later), first)
        }
        XCTAssertEqual(memo.builds, 1, "Same messages, names, reads and day: no rebuild")
        _ = memo.rows(items: items(entries + [entry(3, alex, at: -10)]), context: context())
        XCTAssertEqual(memo.builds, 2, "A new message rebuilds")
        _ = memo.rows(items: items(entries + [entry(3, alex, at: -10)]), context: context(reads: [MemberRead(userId: riley, lastReadAt: now)]))
        XCTAssertEqual(memo.builds, 3, "A read receipt rebuilds")
        var tomorrow = context(reads: [MemberRead(userId: riley, lastReadAt: now)])
        tomorrow.now = now.addingTimeInterval(86_400)
        let next = memo.rows(items: items(entries + [entry(3, alex, at: -10)]), context: tomorrow)
        XCTAssertEqual(memo.builds, 4, "A new day relabels the separators")
        XCTAssertTrue(next.contains { if case .day(_, let label) = $0.row { return label == "Yesterday" } else { return false } })
    }

    func testRowItemsStoreTheirIdentity() {
        let entries = [entry(1, riley, at: -300), entry(2, me, at: -200)]
        let rows = ChatThread.rows(items: items(entries), context: context(anchor: entries[0].id))
        let stored = rows.map(ChatRowItem.init)
        XCTAssertEqual(stored.map(\.id), rows.map(\.identity))
        XCTAssertEqual(Set(stored.map(\.id)).count, stored.count)
    }

    func testRowItemsCompareByTheirRowNotTheirBox() {
        let entries = [entry(1, riley, at: -300), entry(2, me, at: -200)]
        let rows = ChatThread.rows(items: items(entries), context: context(anchor: entries[0].id))
        let first = rows.map(ChatRowItem.init)
        let again = rows.map(ChatRowItem.init)
        XCTAssertEqual(first, again, "Same rows built twice are equal")
        XCTAssertEqual(first.map(\.row), rows, "The boxed row reads back unchanged")
        let copy = first
        XCTAssertEqual(copy, first)
        let other = ChatThread.rows(items: items([entry(1, riley, at: -300)]), context: context(anchor: nil)).map(ChatRowItem.init)
        XCTAssertNotEqual(first, other)
    }
}

/// The live chat service's reads for S3: newest history, the reply column probe,
/// and a send body that names `reply_to_id` only for a reply.
final class ChatServerTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon-test")
    private let squad = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    private let sender = UUID(uuidString: "00000000-0000-0000-0000-000000000011")!

    private func row(_ id: Int, seconds: Int, reply: UUID? = nil) -> String {
        let replyText = reply.map { "\"\($0.uuidString)\"" } ?? "null"
        return """
        {"id":"00000000-0000-0000-0000-\(String(format: "%012d", id))","squad_id":"\(squad.uuidString)","sender_id":"\(sender.uuidString)","body":"b\(id)","sent_at":"2026-11-17T21:00:\(String(format: "%02d", seconds))Z","reply_to_id":\(replyText)}
        """
    }

    private func query(_ request: URLRequest?) -> String {
        request?.url?.query?.removingPercentEncoding ?? ""
    }

    func testFullHistoryReadsTheNewestAndReturnsThemOldestFirst() async throws {
        let body = Data("[\(row(2, seconds: 20)),\(row(1, seconds: 10))]".utf8)
        let transport = ScriptedTransport(responses: [(200, body), (200, Data("[]".utf8))])
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let rows = try await chat.history(squadId: squad)
        XCTAssertEqual(rows.map(\.body), ["b1", "b2"])
        let full = query(transport.requests.first)
        XCTAssertTrue(full.contains("order=sent_at.desc,id.desc"), full)
        XCTAssertTrue(full.contains("limit=\(SupabaseChatService.historyLimit)"), full)
        XCTAssertFalse(full.contains("reply_to_id"), "Unprobed reads don't name the reply column")
        _ = try await chat.newer(squadId: squad, after: Date(timeIntervalSince1970: 1_794_949_200))
        let newer = query(transport.requests.last)
        XCTAssertTrue(newer.contains("order=sent_at.asc,id.asc"), newer)
        XCTAssertTrue(newer.contains("sent_at=gt."), newer)
    }

    func testReplyProbeIsOneReadOnlyGetAndIsRemembered() async throws {
        let reply = UUID()
        let transport = ScriptedTransport(responses: [(200, Data("[]".utf8)), (200, Data("[\(row(1, seconds: 1, reply: reply))]".utf8))])
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let first = await chat.repliesAvailable()
        let second = await chat.repliesAvailable()
        XCTAssertTrue(first)
        XCTAssertTrue(second)
        XCTAssertEqual(transport.requests.count, 1, "The probe runs once")
        XCTAssertEqual(transport.requests.first?.httpMethod, "GET")
        XCTAssertNil(transport.requests.first?.httpBody)
        XCTAssertTrue(query(transport.requests.first).contains("select=reply_to_id"))
        let rows = try await chat.history(squadId: squad)
        XCTAssertTrue(query(transport.requests.last).contains("reply_to_id"), "Once the column is known, reads select it")
        XCTAssertEqual(rows.first?.replyToId, reply)
    }

    func testAKnownReplyColumnSkipsTheProbeOnAFreshService() async throws {
        let transport = ScriptedTransport(responses: [(200, Data("[]".utf8))])
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport, knownReplies: true)
        let available = await chat.repliesAvailable()
        XCTAssertTrue(available)
        _ = try await chat.history(squadId: squad)
        XCTAssertEqual(transport.requests.count, 1, "No second probe")
        XCTAssertTrue(query(transport.requests.first).contains("reply_to_id"))
    }

    func testAServerWithoutTheReplyColumnTurnsRepliesOff() async throws {
        let missing = Data(#"{"code":"42703","message":"column sq8_messages.reply_to_id does not exist"}"#.utf8)
        let transport = ScriptedTransport(responses: [(400, missing), (200, Data("[]".utf8))])
        let chat = SupabaseChatService(config: config, accessToken: "access", transport: transport)
        let available = await chat.repliesAvailable()
        XCTAssertFalse(available)
        _ = try await chat.history(squadId: squad)
        XCTAssertFalse(query(transport.requests.last).contains("reply_to_id"))
    }

    func testSendBodyNamesTheReplyColumnOnlyForAReply() throws {
        let plain = RemoteMessage(id: UUID(), squadId: squad, senderId: sender, body: "hi", sentAt: Date())
        let plainJSON = String(decoding: try BackendJSON.encoder.encode(plain), as: UTF8.self)
        XCTAssertFalse(plainJSON.contains("reply_to_id"), plainJSON)
        var reply = plain
        reply.replyToId = UUID()
        let replyJSON = String(decoding: try BackendJSON.encoder.encode(reply), as: UTF8.self)
        XCTAssertTrue(replyJSON.contains("reply_to_id"), replyJSON)
        let decoded = try BackendJSON.decoder.decode([RemoteMessage].self, from: Data("[\(row(1, seconds: 1))]".utf8))
        XCTAssertNil(decoded.first?.replyToId)
    }

    // MARK: Chip flow (reaction chips and the emoji row)

    /// Six AX5-sized emoji buttons, as in the emoji row on a 440 pt screen.
    private func emojiRow(measured: inout Int) -> ChipFlowGeometry {
        var calls = 0
        let flow = ChipFlowGeometry(count: 6, spacing: 4) { _ in
            calls += 1
            return CGSize(width: 76, height: 76)
        }
        measured = calls
        return flow
    }

    func testChipFlowMeasuresEachChipOnceHoweverOftenItIsAsked() {
        var measured = 0
        let flow = emojiRow(measured: &measured)
        XCTAssertEqual(measured, 6)
        // A stack probes zero, infinity, ideal and the real width, again and again.
        for _ in 0..<100 {
            for width: CGFloat? in [0, .infinity, nil, 300, 412] {
                _ = flow.size(width: width)
                _ = flow.rows(width: width)
            }
        }
        XCTAssertEqual(measured, 6, "Sizes come from the one measurement, not from re-measuring")
        var many = 0
        _ = ChipFlowGeometry(count: 200, spacing: 4) { _ in many += 1; return CGSize(width: 44, height: 44) }
        XCTAssertEqual(many, 200, "One measurement per chip: linear in the chip count")
    }

    func testChipFlowNeverClaimsMoreWidthThanItCanShrinkTo() {
        var measured = 0
        let flow = emojiRow(measured: &measured)
        // "How narrow can you get?" is one emoji per row, never the whole single row
        // (the first version said 476 pt here, wider than the screen).
        XCTAssertEqual(flow.size(width: 0), CGSize(width: 76, height: 6 * 76 + 5 * 4))
        XCTAssertEqual(flow.rows(width: 0), [[0], [1], [2], [3], [4], [5]])
        // Ideal and unlimited: one row.
        XCTAssertEqual(flow.size(width: nil), CGSize(width: 6 * 76 + 5 * 4, height: 76))
        XCTAssertEqual(flow.size(width: .infinity), flow.size(width: nil))
        // The real width wraps, and the answer fits inside it.
        for width: CGFloat in [76, 100, 200, 300, 412, 476, 1000] {
            let size = flow.size(width: width)
            XCTAssertLessThanOrEqual(size.width, width, "Wider than \(width): \(size)")
            // Placing at the width it reported gives the same rows.
            XCTAssertEqual(flow.rows(width: size.width), flow.rows(width: width), "Rows moved when placed at \(size.width)")
        }
        XCTAssertEqual(flow.rows(width: 300), [[0, 1, 2], [3, 4, 5]])
        XCTAssertEqual(flow.size(width: 300), CGSize(width: 3 * 76 + 2 * 4, height: 2 * 76 + 4))
        // Narrower never gets shorter: a stack can rely on height growing as width shrinks.
        var last: CGFloat = 0
        for width in stride(from: CGFloat(1000), through: 0, by: -7) {
            let height = flow.size(width: width).height
            XCTAssertGreaterThanOrEqual(height, last, "Height dropped at \(width)")
            last = height
        }
    }

    func testChipFlowWithAChipWiderThanTheWidthGivesItARow() {
        let flow = ChipFlowGeometry(count: 3, spacing: 4) { $0 == 1 ? CGSize(width: 120, height: 50) : CGSize(width: 44, height: 44) }
        XCTAssertEqual(flow.rows(width: 100), [[0], [1], [2]])
        XCTAssertEqual(flow.size(width: 100).width, 120, "It can't be narrower than its widest chip")
        XCTAssertEqual(ChipFlowGeometry(count: 0, spacing: 4) { _ in .zero }.size(width: 300), .zero)
    }

    // AX5 reactions hang (app/docs/known-issues.md): at accessibility sizes the
    // thread is a plain VStack; every other size keeps the lazy stack.
    func testThreadIsNonLazyOnlyAtAccessibilitySizes() {
        XCTAssertFalse(ChatListStack.isLazy(accessibilitySize: true))
        XCTAssertTrue(ChatListStack.isLazy(accessibilitySize: false))
    }
}
