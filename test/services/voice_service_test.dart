import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:squad_sync/services/voice_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VoiceRoomNotifier voiceRoomNotifier;

  setUp(() {
    // Create VoiceRoomNotifier with test dependencies
    final voiceService = VoiceService(
      engineFactory: () =>
          throw UnimplementedError('Mock engine not implemented'),
    );
    voiceRoomNotifier = VoiceRoomNotifier(
      roomId: 'test-room',
      roomName: 'Test Room',
      voiceService: voiceService,
    );
  });

  tearDown(() {
    voiceRoomNotifier.dispose();
  });

  group('VoiceRoomNotifier', () {
    test('initial state is correct', () {
      expect(voiceRoomNotifier.state, isA<AsyncData<VoiceRoomState>>());
      final data = voiceRoomNotifier.state.value!;
      expect(data.roomId, 'test-room');
      expect(data.roomName, 'Test Room');
      expect(data.participants, isEmpty);
      expect(data.isJoined, false);
      expect(data.isMuted, false);
    });

    test('copyWith creates new state correctly', () {
      final currentData = voiceRoomNotifier.state.value!;
      voiceRoomNotifier.state = AsyncValue.data(currentData.copyWith(
        isJoined: true,
        isMuted: true,
        error: 'Test error',
      ));

      final newData = voiceRoomNotifier.state.value!;
      expect(newData.roomId, 'test-room');
      expect(newData.roomName, 'Test Room');
      expect(newData.isJoined, true);
      expect(newData.isMuted, true);
      expect(newData.error, 'Test error');
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
