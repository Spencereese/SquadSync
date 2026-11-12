import XCTest
@testable import SquadSync

final class VoiceRoomServiceTests: XCTestCase {
    func testJoinLeaveAndMuteKeepSpeakingLevels() async {
        let room = InMemoryVoiceRoomService()
        XCTAssertEqual(room.connection, .idle)

        await room.join(userId: "spencer")
        XCTAssertEqual(room.connection, .connected)
        XCTAssertEqual(room.participants.map(\.id), ["spencer"])
        XCTAssertGreaterThan(room.participants[0].speakingLevel, 0)

        await room.mute(userId: "spencer", muted: true)
        XCTAssertEqual(room.participants[0].muted, true)
        XCTAssertEqual(room.participants[0].speakingLevel, 0)

        await room.mute(userId: "spencer", muted: false)
        XCTAssertGreaterThan(room.participants[0].speakingLevel, 0)

        await room.leave(userId: "spencer")
        XCTAssertTrue(room.participants.isEmpty)
        XCTAssertEqual(room.connection, .idle)
    }

    func testConnectionCanReconnectOrFailWithoutAProvider() {
        let room = InMemoryVoiceRoomService(connection: .connected)
        room.markReconnecting()
        XCTAssertEqual(room.connection, .reconnecting)
        room.markFailed("The lounge dropped.")
        if case .failed(let reason) = room.connection {
            XCTAssertEqual(reason, "The lounge dropped.")
        } else {
            XCTFail("expected a failed connection")
        }
    }
}

@MainActor
final class VoiceStoreTests: XCTestCase {
    func testTheStoreJoinsThroughTheService() async {
        let service = InMemoryVoiceRoomService()
        let store = MockStore.seeded()
        let fresh = MockStore(
            people: store.people,
            conversations: store.conversations,
            messages: store.messages,
            party: store.party,
            voice: VoiceRoom(
                title: "Lounge",
                occupantIds: [],
                mutedIds: [],
                speakingLevels: [:],
                connection: .idle,
                collapsed: true
            ),
            voiceService: service,
            viewerId: "jordan"
        )
        XCTAssertFalse(fresh.voice.occupantIds.contains("jordan"))
        await fresh.joinVoice()
        XCTAssertEqual(service.connection, .connected)
        XCTAssertTrue(fresh.voice.occupantIds.contains("jordan"))
        XCTAssertEqual(fresh.voice.connection, .connected)
        XCTAssertGreaterThan(fresh.voice.speakingLevels["jordan"] ?? 0, 0)
        await fresh.toggleMute()
        XCTAssertTrue(fresh.voice.mutedIds.contains("jordan"))
        XCTAssertEqual(fresh.voice.speakingLevels["jordan"], 0)
        await fresh.leaveVoice()
        XCTAssertFalse(fresh.voice.occupantIds.contains("jordan"))
    }
}
