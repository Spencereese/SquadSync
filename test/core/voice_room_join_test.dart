import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/voice_room_join.dart';
import 'package:squad_sync/screens/voice_room_screen.dart';

void main() {
  test('openVoiceRoom pushes VoiceRoomScreen with room id and name', () async {
    Widget? page;
    await openVoiceRoom(
      roomId: 'lobby-9',
      squadName: 'Warzone',
      push: (widget) async {
        page = widget;
        return null;
      },
    );
    expect(page, isA<VoiceRoomScreen>());
    final room = page! as VoiceRoomScreen;
    expect(room.roomId, 'lobby-9');
    expect(room.squadName, 'Warzone');
    expect(room.isHost, isFalse);
  });

  test('openVoiceRoom trims room id and falls back on empty name', () async {
    Widget? page;
    await openVoiceRoom(
      roomId: '  lobby-9  ',
      squadName: '   ',
      isHost: true,
      push: (widget) async {
        page = widget;
        return null;
      },
    );
    final room = page! as VoiceRoomScreen;
    expect(room.roomId, 'lobby-9');
    expect(room.squadName, kDefaultVoiceSquadName);
    expect(room.isHost, isTrue);
  });

  test('openVoiceRoom no-ops on empty room id', () async {
    var pushed = false;
    await openVoiceRoom(
      roomId: '  ',
      squadName: 'Warzone',
      push: (widget) async {
        pushed = true;
        return null;
      },
    );
    expect(pushed, isFalse);
  });

  group('resolveVoiceLobbyHeaderPhase', () {
    test('missing lobby id is empty, not a dead reconnecting spinner', () {
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: null, isJoining: true),
        VoiceLobbyHeaderPhase.empty,
      );
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: '  ', isOffline: true),
        VoiceLobbyHeaderPhase.empty,
      );
    });

    test('offline with a lobby id is error, not empty', () {
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: 'lobby-9', isOffline: true),
        VoiceLobbyHeaderPhase.error,
      );
      expect(
        resolveVoiceLobbyHeaderPhase(
          lobbyId: 'lobby-9',
          error: 'timeout',
        ),
        VoiceLobbyHeaderPhase.error,
      );
    });

    test('drop is reconnecting even when offline', () {
      expect(
        resolveVoiceLobbyHeaderPhase(
          lobbyId: 'lobby-9',
          isDropped: true,
          isOffline: true,
        ),
        VoiceLobbyHeaderPhase.reconnecting,
      );
    });

    test('joined or joining is joined, not a spinner', () {
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: 'lobby-9', isJoined: true),
        VoiceLobbyHeaderPhase.joined,
      );
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: 'lobby-9', isJoining: true),
        VoiceLobbyHeaderPhase.joined,
      );
    });

    test('live lobby with no session is ready', () {
      expect(
        resolveVoiceLobbyHeaderPhase(lobbyId: 'lobby-9'),
        VoiceLobbyHeaderPhase.ready,
      );
    });
  });

  group('voice lobby header copy', () {
    test('empty / error / reconnecting copy is arm length', () {
      expect(
        voiceLobbyHeaderMessage(VoiceLobbyHeaderPhase.empty),
        kVoiceLobbyEmptyCopy,
      );
      expect(
        voiceLobbyHeaderMessage(VoiceLobbyHeaderPhase.error),
        kVoiceLobbyOfflineCopy,
      );
      expect(
        voiceLobbyHeaderMessage(VoiceLobbyHeaderPhase.reconnecting),
        kVoiceLobbyReconnectingCopy,
      );
      expect(
        voiceLobbyHeaderMessage(VoiceLobbyHeaderPhase.joined),
        kVoiceLobbyAlreadyJoinedCopy,
      );
      expect(voiceLobbyJoinHint(VoiceLobbyJoinOutcome.offline),
          kVoiceLobbyOfflineHint);
      expect(voiceLobbyJoinHint(VoiceLobbyJoinOutcome.empty), isNull);
      expect(
        voiceLobbyHeaderKey(VoiceLobbyHeaderPhase.empty),
        const Key('lobby-voice-empty'),
      );
      expect(
        voiceLobbyHeaderKey(VoiceLobbyHeaderPhase.error),
        const Key('lobby-voice-error'),
      );
      expect(
        voiceLobbyHeaderKey(VoiceLobbyHeaderPhase.reconnecting),
        const Key('lobby-voice-reconnecting'),
      );
    });
  });

  group('no double-join', () {
    test('already joining or joined would double-join', () {
      expect(
        wouldDoubleJoinVoice(roomId: 'lobby-9'),
        isFalse,
      );
      expect(
        wouldDoubleJoinVoice(roomId: 'lobby-9', isJoining: true),
        isTrue,
      );
      expect(
        wouldDoubleJoinVoice(
          roomId: 'lobby-9',
          joinedRoomId: 'lobby-9',
        ),
        isTrue,
      );
      expect(
        wouldDoubleJoinVoice(
          roomId: 'lobby-8',
          joinedRoomId: 'lobby-9',
        ),
        isTrue,
      );
    });

    test('empty id is empty, not a double-join', () {
      expect(
        wouldDoubleJoinVoice(
          roomId: '  ',
          joinedRoomId: 'lobby-9',
          isJoining: true,
        ),
        isFalse,
      );
    });

    test('dropped session is reconnect, not a stack', () {
      expect(
        wouldDoubleJoinVoice(
          roomId: 'lobby-9',
          joinedRoomId: 'lobby-9',
          isDropped: true,
        ),
        isFalse,
      );
      expect(
        shouldReconnectVoiceAfterDrop(
          roomId: 'lobby-9',
          joinedRoomId: 'lobby-9',
          isDropped: true,
        ),
        isTrue,
      );
      expect(
        shouldReconnectVoiceAfterDrop(
          roomId: 'lobby-8',
          joinedRoomId: 'lobby-9',
          isDropped: true,
        ),
        isFalse,
      );
      expect(
        shouldReconnectVoiceAfterDrop(
          roomId: 'lobby-9',
          joinedRoomId: 'lobby-9',
          isDropped: false,
        ),
        isFalse,
      );
    });
  });

  group('voice reconnect toast', () {
    test('fires on drop from joined, not a first join', () {
      expect(
        shouldShowVoiceReconnectToast(
          previous: VoiceLobbyHeaderPhase.joined,
          current: VoiceLobbyHeaderPhase.reconnecting,
        ),
        isTrue,
      );
      expect(
        shouldShowVoiceReconnectToast(
          previous: VoiceLobbyHeaderPhase.ready,
          current: VoiceLobbyHeaderPhase.reconnecting,
        ),
        isFalse,
      );
      expect(
        shouldShowVoiceReconnectToast(
          previous: VoiceLobbyHeaderPhase.reconnecting,
          current: VoiceLobbyHeaderPhase.reconnecting,
          voiceDrop: true,
        ),
        isFalse,
      );
      expect(
        shouldShowVoiceReconnectToast(
          previous: VoiceLobbyHeaderPhase.error,
          current: VoiceLobbyHeaderPhase.reconnecting,
        ),
        isTrue,
      );
      expect(
        shouldShowVoiceReconnectToast(
          previous: VoiceLobbyHeaderPhase.empty,
          current: VoiceLobbyHeaderPhase.empty,
          voiceDrop: true,
        ),
        isTrue,
      );
      expect(
        shouldShowVoiceReconnectToast(
          previous: null,
          current: VoiceLobbyHeaderPhase.reconnecting,
        ),
        isFalse,
      );
    });

    test('copy is arm length and gate claims once per cooldown', () {
      expect(kVoiceLobbyReconnectingCopy, 'Reconnecting to voice...');
      expect(kVoiceReconnectToastKey, 'lobby-voice-reconnect-toast');
      final gate = VoiceReconnectToastGate();
      final t = DateTime.utc(2026, 9, 6, 12);
      expect(gate.claim(now: t), isTrue);
      expect(gate.claim(now: t.add(const Duration(seconds: 1))), isFalse);
      expect(
        gate.claim(now: t.add(kVoiceReconnectToastCooldown)),
        isTrue,
      );
    });
  });

  group('joinVoiceRoom', () {
    test('empty lobby id is empty and does not push', () async {
      var pushed = 0;
      final session = VoiceJoinSession();
      final result = await joinVoiceRoom(
        roomId: '  ',
        session: session,
        push: (_) async {
          pushed++;
        },
      );
      expect(result.isEmpty, isTrue);
      expect(result.outcome, VoiceLobbyJoinOutcome.empty);
      expect(pushed, 0);
      expect(voiceLobbyJoinMessage(result), kVoiceLobbyEmptyCopy);
      expect(
        voiceLobbyJoinFeedbackKey(result.outcome),
        const Key('lobby-voice-empty'),
      );
    });

    test('offline is error, not a hang or a push', () async {
      var pushed = 0;
      final result = await joinVoiceRoom(
        roomId: 'lobby-9',
        isOffline: true,
        session: VoiceJoinSession(),
        push: (_) async {
          pushed++;
        },
      );
      expect(result.isOffline, isTrue);
      expect(pushed, 0);
      expect(voiceLobbyJoinMessage(result), kVoiceLobbyOfflineCopy);
      expect(
        voiceLobbyJoinFeedbackKey(result.outcome),
        const Key('lobby-voice-error'),
      );
    });

    test('opens VoiceRoomScreen and skips a second join', () async {
      final gate = Completer<void>();
      var pushed = 0;
      Widget? page;
      final session = VoiceJoinSession();
      final first = await joinVoiceRoom(
        roomId: 'lobby-9',
        squadName: 'Warzone',
        session: session,
        clearOnRouteDone: false,
        push: (widget) {
          pushed++;
          page = widget;
          return gate.future;
        },
      );
      expect(first.isOpened, isTrue);
      expect(pushed, 1);
      expect(page, isA<VoiceRoomScreen>());
      expect((page! as VoiceRoomScreen).roomId, 'lobby-9');

      final second = await joinVoiceRoom(
        roomId: 'lobby-9',
        session: session,
        clearOnRouteDone: false,
        push: (widget) {
          pushed++;
          return gate.future;
        },
      );
      expect(second.outcome, VoiceLobbyJoinOutcome.alreadyJoined);
      expect(pushed, 1);
      expect(voiceLobbyJoinMessage(second), kVoiceLobbyAlreadyJoinedCopy);
    });

    test('reconnect after drop pushes again, not a stack deny', () async {
      final gate = Completer<void>();
      var pushed = 0;
      final session = VoiceJoinSession();
      final first = await joinVoiceRoom(
        roomId: 'lobby-9',
        session: session,
        clearOnRouteDone: false,
        push: (_) {
          pushed++;
          return gate.future;
        },
      );
      expect(first.isOpened, isTrue);
      session.markDropped();
      expect(
        resolveVoiceLobbyHeaderPhase(
          lobbyId: 'lobby-9',
          isDropped: session.isDropped,
          isJoined: session.isJoined,
        ),
        VoiceLobbyHeaderPhase.reconnecting,
      );

      final second = await joinVoiceRoom(
        roomId: 'lobby-9',
        session: session,
        clearOnRouteDone: false,
        push: (_) {
          pushed++;
          return Future<void>.value();
        },
      );
      expect(second.outcome, VoiceLobbyJoinOutcome.reconnecting);
      expect(pushed, 2);
      expect(voiceLobbyJoinMessage(second), kVoiceLobbyReconnectingCopy);
      expect(session.isDropped, isFalse);
      expect(session.isJoined, isTrue);
    });

    test('thrown push is offline error and marks dropped', () async {
      final session = VoiceJoinSession();
      session.markJoined('lobby-9');
      session.markDropped();
      final result = await joinVoiceRoom(
        roomId: 'lobby-9',
        session: session,
        clearOnRouteDone: false,
        push: (_) => throw Exception('denied'),
      );
      expect(result.isOffline, isTrue);
      expect(session.isDropped, isTrue);
      expect(voiceLobbyJoinMessage(result), '$kVoiceLobbyOfflineCopy: denied');
    });
  });
}
