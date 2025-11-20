import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceRoomNotifier voiceRoomNotifier;

  setUp(() {
    // Create VoiceRoomNotifier with test dependencies
    voiceRoomNotifier = VoiceRoomNotifier(
      'test-room',
      'Test Room',
      appId: 'test-app-id',
      engineFactory: () =>
          throw UnimplementedError('Mock engine not implemented'),
      requestPermission: () async =>
          throw UnimplementedError('Mock permission not implemented'),
    );
  });

  tearDown(() {
    voiceRoomNotifier.dispose();
  });

  group('VoiceRoomNotifier', () {
    test('initial state is correct', () {
      expect(voiceRoomNotifier.state.roomId, 'test-room');
      expect(voiceRoomNotifier.state.roomName, 'Test Room');
      expect(voiceRoomNotifier.state.participants, isEmpty);
      expect(voiceRoomNotifier.state.isJoined, false);
      expect(voiceRoomNotifier.state.isMuted, false);
      expect(voiceRoomNotifier.state.isLoading, false);
      expect(voiceRoomNotifier.state.error, null);
    });

    test('copyWith creates new state correctly', () {
      final newState = voiceRoomNotifier.state.copyWith(
        isJoined: true,
        isMuted: true,
        error: 'Test error',
      );

      expect(newState.roomId, 'test-room');
      expect(newState.roomName, 'Test Room');
      expect(newState.isJoined, true);
      expect(newState.isMuted, true);
      expect(newState.error, 'Test error');
    });

    test('VoiceParticipant copyWith works correctly', () {
      final participant = VoiceParticipant(
        uid: 'test-uid',
        displayName: 'Test User',
        isMuted: false,
        isSpeaking: false,
      );

      final updated = participant.copyWith(
        isMuted: true,
        isSpeaking: true,
      );

      expect(updated.uid, 'test-uid');
      expect(updated.displayName, 'Test User');
      expect(updated.isMuted, true);
      expect(updated.isSpeaking, true);
    });
  });
}
