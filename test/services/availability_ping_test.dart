import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/notification_routes.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/managers/notification_manager.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/availability_ping.dart';

Lobby _lobby({
  required String id,
  required List<String> members,
  String game = 'Warzone',
  String? chatGroupId,
  String createdBy = 'u1',
}) {
  return Lobby.create(
    name: 'Squad',
    gameName: game,
    maxSpots: 8,
    createdBy: createdBy,
  ).copyWith(
    id: id,
    memberUids: members,
    chatGroupId: chatGroupId,
  );
}

void main() {
  setUp(AvailabilityPing.resetTestHooks);
  tearDown(AvailabilityPing.resetTestHooks);

  group('availabilityPingRecipients', () {
    test('drops sender, blanks, and duplicates', () {
      expect(
        availabilityPingRecipients(
          memberUids: ['u1', 'u2', ' u2 ', '', 'u3', 'u1'],
          senderUid: 'u1',
        ),
        ['u2', 'u3'],
      );
    });

    test('never includes the sender (no FCM-to-self)', () {
      expect(
        availabilityPingRecipients(
          memberUids: ['me'],
          senderUid: 'me',
        ),
        isEmpty,
      );
    });
  });

  group('planAvailabilityPing', () {
    test('builds NotificationManager payload that routes to /squad', () {
      final plan = planAvailabilityPing(
        const AvailabilityPingTarget(
          senderUid: 'u1',
          memberUids: ['u1', 'u2', 'u3'],
          lobbyId: 'lobby-9',
          squadId: 'squad-1',
          gameName: 'Warzone',
          senderName: 'Alex',
        ),
      );

      expect(plan.recipientUids, ['u2', 'u3']);
      expect(plan.title, 'Alex is on now');
      expect(plan.body, 'Alex is ready to play Warzone');
      expect(plan.data['type'], kAvailabilityPingType);
      expect(plan.data['lobby_id'], 'lobby-9');
      expect(plan.data['game_name'], 'Warzone');
      expect(plan.data['from_uid'], 'u1');
      expect(plan.data['squad_id'], 'squad-1');
      expect(
        NotificationRoutes.locationFor(plan.data),
        '/squad/Warzone?lobby_id=lobby-9',
      );
      expect(
        NotificationManager.payloadFor(
          type: kAvailabilityPingType,
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
        )['type'],
        kAvailabilityPingType,
      );
    });

    test('without lobby_id routes to chat via squad_id', () {
      final plan = planAvailabilityPing(
        const AvailabilityPingTarget(
          senderUid: 'u1',
          memberUids: ['u2'],
          squadId: 'squad-1',
          senderName: 'Alex',
        ),
      );
      expect(
        NotificationRoutes.locationFor(plan.data),
        '/chat/squad-1',
      );
    });
  });

  group('resolveAvailabilityPingTarget', () {
    test('uses currentLobby members for a lobby entry', () {
      final lobby = _lobby(
        id: 'lobby-9',
        members: ['u1', 'u2'],
        chatGroupId: 'squad-1',
      );
      final target = resolveAvailabilityPingTarget(
        senderUid: 'u1',
        lobbyId: 'lobby-9',
        currentLobby: lobby,
        senderName: 'Alex',
      );
      expect(target, isNotNull);
      expect(target!.memberUids, ['u1', 'u2']);
      expect(target.lobbyId, 'lobby-9');
      expect(target.gameName, 'Warzone');
      expect(target.squadId, 'squad-1');
    });

    test('finds userLobbies by chat group for LFG entry', () {
      final lobby = _lobby(
        id: 'lobby-9',
        members: ['u1', 'u2', 'u3'],
        chatGroupId: 'squad-1',
      );
      final target = resolveAvailabilityPingTarget(
        senderUid: 'u1',
        squadId: 'squad-1',
        userLobbies: {'lobby-9': lobby},
      );
      expect(target!.lobbyId, 'lobby-9');
      expect(target.memberUids, ['u1', 'u2', 'u3']);
    });
  });

  group('AvailabilityPing.send / dispatch', () {
    test('sends to lobby members through sendToUsers hook', () async {
      String? sentTitle;
      String? sentBody;
      List<String>? sentUids;
      Map<String, dynamic>? sentData;
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentTitle = title;
        sentBody = body;
        sentUids = recipientUids;
        sentData = data;
      };

      final result = await AvailabilityPing.send(
        const AvailabilityPingTarget(
          senderUid: 'u1',
          memberUids: ['u1', 'u2', 'u3'],
          lobbyId: 'lobby-9',
          gameName: 'Warzone',
          senderName: 'Alex',
        ),
      );

      expect(result.status, AvailabilityPingStatus.sent);
      expect(result.recipientUids, ['u2', 'u3']);
      expect(result.snackbarMessage, 'On now — pinged 2 members');
      expect(sentTitle, 'Alex is on now');
      expect(sentBody, 'Alex is ready to play Warzone');
      expect(sentUids, ['u2', 'u3']);
      expect(sentData!['type'], kAvailabilityPingType);
      expect(
        NotificationRoutes.locationFor(sentData!),
        '/squad/Warzone?lobby_id=lobby-9',
      );
    });

    test('does not send when only the sender is in the lobby', () async {
      var sent = false;
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sent = true;
      };

      final result = await AvailabilityPing.send(
        const AvailabilityPingTarget(
          senderUid: 'u1',
          memberUids: ['u1'],
          lobbyId: 'lobby-9',
        ),
      );
      expect(result.status, AvailabilityPingStatus.selfOnly);
      expect(result.sent, isFalse);
      expect(sent, isFalse);
      expect(result.snackbarMessage, 'No one else in this lobby');
      expect(availabilityOnStore.isOn('u1'), isTrue);
    });

    test('second ping of the same lobby is cooldown', () async {
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {};

      const target = AvailabilityPingTarget(
        senderUid: 'u1',
        memberUids: ['u1', 'u2'],
        lobbyId: 'lobby-9',
      );
      final first = await AvailabilityPing.send(target);
      final second = await AvailabilityPing.send(target);
      expect(first.status, AvailabilityPingStatus.sent);
      expect(second.status, AvailabilityPingStatus.cooldown);
      expect(second.snackbarMessage, 'Already pinged — try again shortly');
    });

    test('dispatch uses in-memory lobby members on the live path', () async {
      List<String>? sentUids;
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
      };
      var loaded = false;
      AvailabilityPing.loadMembersHook = (
        id, {
        required senderUid,
        senderName,
      }) async {
        loaded = true;
        return null;
      };

      final lobby = _lobby(
        id: 'lobby-9',
        members: ['u1', 'u2'],
        chatGroupId: 'squad-1',
      );
      final result = await AvailabilityPing.dispatch(
        senderUid: 'u1',
        squadId: 'squad-1',
        currentLobby: lobby,
        senderName: 'Alex',
      );
      expect(result.status, AvailabilityPingStatus.sent);
      expect(sentUids, ['u2']);
      expect(loaded, isFalse);
      expect(availabilityOnStore.isOn('u1'), isTrue);
    });

    test('dispatch loads members when lobby state is empty', () async {
      List<String>? sentUids;
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sentUids = recipientUids;
      };
      AvailabilityPing.loadMembersHook = (
        id, {
        required senderUid,
        senderName,
      }) async {
        expect(id, 'squad-1');
        return AvailabilityPingTarget(
          senderUid: senderUid,
          memberUids: const ['u1', 'u4'],
          lobbyId: 'lobby-9',
          squadId: id,
          senderName: senderName,
        );
      };

      final result = await AvailabilityPing.dispatch(
        senderUid: 'u1',
        squadId: 'squad-1',
        senderName: 'Alex',
      );
      expect(result.status, AvailabilityPingStatus.sent);
      expect(sentUids, ['u4']);
    });

    test('failed send does not start cooldown', () async {
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        throw Exception('edge down');
      };
      const target = AvailabilityPingTarget(
        senderUid: 'u1',
        memberUids: ['u2'],
        lobbyId: 'lobby-9',
      );
      await expectLater(AvailabilityPing.send(target), throwsException);

      var sent = 0;
      AvailabilityPing.sendToUsersHook = ({
        required title,
        required body,
        required recipientUids,
        data,
      }) async {
        sent += 1;
      };
      final retry = await AvailabilityPing.send(target);
      expect(retry.status, AvailabilityPingStatus.sent);
      expect(sent, 1);
    });
  });
}
