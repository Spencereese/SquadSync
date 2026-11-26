import XCTest
@testable import SquadSync

/// The tap-to-join link, the share text, member invites on both services, and
/// profile photo paths. Foundation only; runs in the Linux harness.
final class InviteLinkTests: XCTestCase {
    private let config = BackendConfig(urlText: "https://example.supabase.co", anonKey: "anon")
    private let user = UUID(uuidString: "0000000A-0000-0000-0000-0000000000B1")!

    func testLinkRoundTripsTheCode() throws {
        let url = try XCTUnwrap(InviteLink.url(code: "abcd-2345"))
        XCTAssertEqual(url.absoluteString, "squadsync://join/ABCD2345")
        XCTAssertEqual(InviteLink.code(from: url), "ABCD2345")
        XCTAssertEqual(InviteLink.code(from: URL(string: "SquadSync://JOIN?code=abcd2345")!), "ABCD2345")
    }

    func testOtherLinksAndJunkCodesAreIgnored() {
        XCTAssertNil(InviteLink.code(from: URL(string: "https://join/ABCD2345")!))
        XCTAssertNil(InviteLink.code(from: URL(string: "squadsync://chat/ABCD2345")!))
        XCTAssertNil(InviteLink.code(from: URL(string: "squadsync://join/AB")!))
        XCTAssertNil(InviteLink.code(from: URL(string: "squadsync://join/")!))
        XCTAssertNil(InviteLink.url(code: "  "))
    }

    func testShareTextCarriesTheLinkAndTheCodeWithoutSayingSquad() {
        let text = InviteLink.shareText(groupName: "Friday", code: "ABCD2345")
        XCTAssertEqual(text, "Join Friday on SquadSync: squadsync://join/ABCD2345\nOr open SquadSync and enter code ABCD2345.")
        XCTAssertTrue(InviteLink.shareText(groupName: " ", code: "ABCD2345").hasPrefix("Join my group on SquadSync: "))
        XCTAssertNil(CopyCheck.offending(text), "Share text: \(text)")
    }

    func testExpiryNote() {
        let now = Date(timeIntervalSince1970: 1_795_000_000)
        XCTAssertEqual(InviteLink.expiryNote(now.addingTimeInterval(7 * 86_400), now: now), "Works for 7 more days, until the group has 8.")
        XCTAssertEqual(InviteLink.expiryNote(now.addingTimeInterval(3600), now: now), "Works for 1 more day, until the group has 8.")
        XCTAssertEqual(InviteLink.expiryNote(nil, now: now), "Anyone with the link can join until the group has 8.")
    }

    func testPendingInviteWaitsForSignInAndNeverJoinsASecondGroup() {
        XCTAssertEqual(PendingInvite.action(code: "ABCD2345", signedIn: false, hasGroup: false), .wait)
        XCTAssertEqual(PendingInvite.action(code: "ABCD2345", signedIn: true, hasGroup: false), .join("ABCD2345"))
        XCTAssertEqual(PendingInvite.action(code: "ABCD2345", signedIn: true, hasGroup: true), .inAnotherGroup)
    }

    func testLiveMemberInviteUsesTheNewRpc() async throws {
        let body = #"{"ok":true,"code":"WXYZ2345","squad_id":"00000000-0000-0000-0000-0000000000aa","expires_at":"2026-12-03T15:00:00Z"}"#
        let transport = ScriptedTransport(responses: [(200, Data(body.utf8))])
        let service = SupabaseInviteService(config: config, accessToken: "token", transport: transport)
        let ticket = try await service.memberInvite()
        XCTAssertEqual(ticket.code, "WXYZ2345")
        XCTAssertNotNil(ticket.expiresAt)
        XCTAssertEqual(transport.requests.map { $0.url?.path ?? "" }, ["/rest/v1/rpc/sq8_member_invite"])
    }

    func testLiveMemberInviteFallsBackToTheOwnerInviteWithout0029() async throws {
        let missing = #"{"code":"PGRST202","message":"Could not find the function public.sq8_member_invite in the schema cache"}"#
        let owner = #"{"ok":true,"code":"OWNR2345","squad_id":"00000000-0000-0000-0000-0000000000aa"}"#
        let transport = ScriptedTransport(responses: [(404, Data(missing.utf8)), (200, Data(owner.utf8))])
        let service = SupabaseInviteService(config: config, accessToken: "token", transport: transport)
        let ticket = try await service.memberInvite()
        XCTAssertEqual(ticket.code, "OWNR2345")
        XCTAssertEqual(transport.requests.map { $0.url?.path ?? "" }, ["/rest/v1/rpc/sq8_member_invite", "/rest/v1/rpc/sq8_create_invite"])
    }

    func testLiveMemberInviteSaysWhyForANonOwnerWithout0029() async {
        let missing = #"{"code":"PGRST202","message":"Could not find the function public.sq8_member_invite in the schema cache"}"#
        let refused = #"{"ok":false,"error":"not_owner"}"#
        let transport = ScriptedTransport(responses: [(404, Data(missing.utf8)), (200, Data(refused.utf8))])
        let service = SupabaseInviteService(config: config, accessToken: "token", transport: transport)
        do {
            _ = try await service.memberInvite()
            XCTFail("A non-owner got an invite without 0029")
        } catch {
            XCTAssertEqual(error as? InviteProblem, .memberInvitesNotSetUp)
            XCTAssertEqual((error as? InviteProblem)?.message, "Only the owner can make an invite until the server is updated.")
        }
    }

    func testLiveMemberInviteFullGroup() async {
        let full = #"{"ok":false,"error":"full"}"#
        let transport = ScriptedTransport(responses: [(200, Data(full.utf8))])
        let service = SupabaseInviteService(config: config, accessToken: "token", transport: transport)
        do {
            _ = try await service.memberInvite()
            XCTFail("Invite for a full group")
        } catch {
            XCTAssertEqual(error as? InviteProblem, .full)
        }
    }

    // MARK: Photos

    func testAvatarPathIsInYourOwnFolder() {
        XCTAssertEqual(AvatarPath.object(userId: user), "0000000a-0000-0000-0000-0000000000b1/sq8-avatar.jpg")
        let url = AvatarPath.publicURL(base: URL(string: "https://example.supabase.co")!, userId: user)
        XCTAssertEqual(url.absoluteString, "https://example.supabase.co/storage/v1/object/public/avatars/0000000a-0000-0000-0000-0000000000b1/sq8-avatar.jpg")
    }

    func testLiveUploadSendsAJpegToYourFolderWithUpsert() async throws {
        let transport = ScriptedTransport(responses: [(200, Data(#"{"Key":"avatars/x"}"#.utf8))])
        let service = SupabaseAvatarService(config: config, accessToken: "token", transport: transport)
        let url = try await service.upload(userId: user, jpeg: Data([0xFF, 0xD8, 0xFF]))
        let request = transport.requests.first
        XCTAssertEqual(request?.url?.path, "/storage/v1/object/avatars/0000000a-0000-0000-0000-0000000000b1/sq8-avatar.jpg")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "Content-Type"), "image/jpeg")
        XCTAssertEqual(request?.value(forHTTPHeaderField: "x-upsert"), "true")
        XCTAssertTrue(url.absoluteString.contains("/storage/v1/object/public/avatars/"))
    }

    func testLiveMissingBucketIsNotSetUp() async {
        let missing = #"{"statusCode":"404","error":"Bucket not found","message":"Bucket not found"}"#
        let transport = ScriptedTransport(responses: [(400, Data(missing.utf8))])
        let service = SupabaseAvatarService(config: config, accessToken: "token", transport: transport)
        do {
            _ = try await service.photoURL(userId: user)
            XCTFail("No bucket, but a photo answer")
        } catch {
            XCTAssertEqual(error as? BackendFailure, .notSetUp(.avatars))
        }
    }

    func testLivePhotoLookupFindsYourFile() async throws {
        let rows = #"[{"name":"sq8-avatar.jpg","updated_at":"2026-11-26T15:00:00Z"}]"#
        let transport = ScriptedTransport(responses: [(200, Data(rows.utf8)), (200, Data("[]".utf8))])
        let service = SupabaseAvatarService(config: config, accessToken: "token", transport: transport)
        let found = try await service.photoURL(userId: user)
        XCTAssertTrue(found?.absoluteString.contains("sq8-avatar.jpg?v=") == true)
        let none = try await service.photoURL(userId: user)
        XCTAssertNil(none)
        XCTAssertEqual(transport.requests.first?.url?.path, "/storage/v1/object/list/avatars")
    }
}
