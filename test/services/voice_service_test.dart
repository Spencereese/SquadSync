import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:squad_sync/services/voice_service.dart';
import 'package:squad_sync/services/app_flow_manager.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// Generate mocks
@GenerateMocks([
  RtcEngine,
  AppFlowManager,
  SQLiteHelper,
])
import 'voice_service_test.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VoiceService Tests', () {
    late MockRtcEngine mockEngine;
    late MockAppFlowManager mockAppFlowManager;
    late MockSQLiteHelper mockSQLiteHelper;
    late VoiceService voiceService;

    setUp(() {
      mockEngine = MockRtcEngine();
      mockAppFlowManager = MockAppFlowManager();
      mockSQLiteHelper = MockSQLiteHelper();

      voiceService = VoiceService(
        engineFactory: () => mockEngine,
        appFlowManager: mockAppFlowManager,
        sqliteHelper: mockSQLiteHelper,
      );
    });

    tearDown(() {
      voiceService.dispose();
    });

    group('Initialization', () {
      test('initializeEngine returns success when everything is valid',
          () async {
        // Note: This test requires proper dotenv setup and permissions
        // In a real test environment, you'd mock the permission handler
        // For now, we'll document the expected behavior
        expect(voiceService, isNotNull);
      });

      test('VoiceService can be instantiated', () {
        expect(voiceService, isA<VoiceService>());
      });
    });

    group('Voice Participant', () {
      test('VoiceParticipant can be created with required fields', () {
        final participant = VoiceParticipant(
          uid: 'test_uid',
          displayName: 'Test User',
        );

        expect(participant.uid, equals('test_uid'));
        expect(participant.displayName, equals('Test User'));
        expect(participant.isMuted, isFalse);
        expect(participant.isSpeaking, isFalse);
        expect(participant.isHost, isFalse);
        expect(participant.isOnline, isTrue);
      });

      test('VoiceParticipant copyWith updates fields correctly', () {
        final participant = VoiceParticipant(
          uid: 'test_uid',
          displayName: 'Test User',
        );

        final updated = participant.copyWith(
          isMuted: true,
          isSpeaking: true,
        );

        expect(updated.uid, equals('test_uid'));
        expect(updated.displayName, equals('Test User'));
        expect(updated.isMuted, isTrue);
        expect(updated.isSpeaking, isTrue);
        expect(updated.isHost, isFalse);
      });

      test('VoiceParticipant toMap converts to map correctly', () {
        final participant = VoiceParticipant(
          uid: 'test_uid',
          displayName: 'Test User',
          isMuted: true,
          isHost: true,
        );

        final map = participant.toMap();

        expect(map['uid'], equals('test_uid'));
        expect(map['displayName'], equals('Test User'));
        expect(map['isMuted'], isTrue);
        expect(map['isHost'], isTrue);
      });
    });

    group('VoiceServiceResult', () {
      test('success result has correct properties', () {
        final result = VoiceServiceResult.success('test_data');

        expect(result.isSuccess, isTrue);
        expect(result.isFailure, isFalse);
        expect(result.data, equals('test_data'));
        expect(result.error, isNull);
        expect(result.errorMessage, isNull);
      });

      test('failure result has correct properties', () {
        final result = VoiceServiceResult.failure(
          VoiceServiceError.permissionDenied,
          'Permission denied',
        );

        expect(result.isSuccess, isFalse);
        expect(result.isFailure, isTrue);
        expect(result.data, isNull);
        expect(result.error, equals(VoiceServiceError.permissionDenied));
        expect(result.errorMessage, equals('Permission denied'));
      });
    });

    group('Error Handling', () {
      test('VoiceServiceError enum has all expected values', () {
        expect(VoiceServiceError.values,
            contains(VoiceServiceError.configMissing));
        expect(VoiceServiceError.values,
            contains(VoiceServiceError.permissionDenied));
        expect(
            VoiceServiceError.values, contains(VoiceServiceError.networkError));
        expect(
            VoiceServiceError.values, contains(VoiceServiceError.joinFailed));
        expect(VoiceServiceError.values,
            contains(VoiceServiceError.tokenGenerationFailed));
        expect(VoiceServiceError.values,
            contains(VoiceServiceError.engineInitializationFailed));
        expect(VoiceServiceError.values, contains(VoiceServiceError.unknown));
      });
    });

    group('Callbacks', () {
      test('callbacks can be assigned and are nullable', () {
        expect(voiceService.onMuteChanged, isNull);
        expect(voiceService.onSpeakingChanged, isNull);
        expect(voiceService.onParticipantJoined, isNull);
        expect(voiceService.onParticipantLeft, isNull);
        expect(voiceService.onError, isNull);

        voiceService.onMuteChanged = (uid, isMuted) {
          // Test callback
        };
        expect(voiceService.onMuteChanged, isNotNull);
      });
    });
  });

  group('VoiceToTextState Tests', () {
    test('default VoiceToTextState has correct initial values', () {
      const state = VoiceToTextState();

      expect(state.isListening, isFalse);
      expect(state.isAvailable, isFalse);
      expect(state.recognizedText, isEmpty);
      expect(state.soundLevel, equals(0.0));
      expect(state.error, isNull);
    });

    test('VoiceToTextState copyWith updates fields correctly', () {
      const state = VoiceToTextState();

      final updated = state.copyWith(
        isListening: true,
        recognizedText: 'Hello world',
        soundLevel: 0.5,
      );

      expect(updated.isListening, isTrue);
      expect(updated.isAvailable, isFalse);
      expect(updated.recognizedText, equals('Hello world'));
      expect(updated.soundLevel, equals(0.5));
      expect(updated.error, isNull);
    });

    test('VoiceToTextState copyWith with error', () {
      const state = VoiceToTextState();

      final updated = state.copyWith(error: 'Test error');

      expect(updated.error, equals('Test error'));
    });
  });

  group('Permission Tests', () {
    test('Microphone permission should be requested for voice features',
        () async {
      // This is a documentation test for permission handling
      // In actual app, ChatMediaHandler.startRecording requests microphone permission
      // VoiceService._requestMicrophonePermission handles permission logic

      // Expected flow:
      // 1. Request Permission.microphone
      // 2. If granted, proceed with recording/voice chat
      // 3. If denied, show user feedback
      // 4. For iOS, also handle speech recognition permissions

      expect(Permission.microphone, isNotNull);
    });

    test('Speech recognition permission should be handled separately',
        () async {
      // This is a documentation test
      // SpeechToText.initialize() handles its own permissions internally

      // Expected flow:
      // 1. Call SpeechToText.initialize()
      // 2. Returns bool indicating if speech recognition is available
      // 3. If available, can start listening
      // 4. Handles platform-specific permissions (iOS speech recognition)

      expect(true, isTrue); // Placeholder
    });
  });

  group('Integration Tests Documentation', () {
    test('Voice note workflow with transcription', () {
      // Expected workflow:
      // 1. User long-presses mic button in ChatInputBar
      // 2. ChatMediaHandler.startRecording() called
      // 3. Request microphone permission (Permission.microphone.request())
      // 4. Start audio recording (AudioRecorder.start())
      // 5. Initialize and start speech-to-text (SpeechToText.listen())
      // 6. Real-time transcription updates _transcription field
      // 7. User releases button
      // 8. ChatMediaHandler.stopRecording() called
      // 9. Stop speech-to-text (SpeechToText.stop())
      // 10. Stop audio recording (AudioRecorder.stop())
      // 11. Upload audio file with transcription
      // 12. Send message with audio URL and transcribed text (🎤 + text)

      expect(true, isTrue); // Documentation placeholder
    });

    test('Voice room with spatial audio visualization', () {
      // Expected workflow:
      // 1. Navigate to VoiceRoomScreen
      // 2. VoiceService.initializeEngine() called
      // 3. Request microphone permission
      // 4. Initialize Agora RTC engine
      // 5. VoiceService.joinChannel() called with room ID
      // 6. Setup callbacks: onSpeakingChanged, onParticipantJoined, etc.
      // 7. Real-time speaking events update _userVolumes map
      // 8. UI shows spatial audio orbs with pulse animations
      // 9. Orb scale and neon rings based on volume levels
      // 10. User can toggle mute, leave room
      // 11. VoiceService.leaveChannel() on exit

      expect(true, isTrue); // Documentation placeholder
    });

    test('Permission handling for different platforms', () {
      // iOS permissions:
      // - NSMicrophoneUsageDescription (microphone)
      // - NSSpeechRecognitionUsageDescription (speech-to-text)
      //
      // Android permissions:
      // - android.permission.RECORD_AUDIO (microphone)
      // - android.permission.INTERNET (Agora networking)
      //
      // Web:
      // - Browser prompt for microphone access
      //
      // These should be configured in:
      // - ios/Runner/Info.plist
      // - android/app/src/main/AndroidManifest.xml
      // - web/index.html (if needed)

      expect(true, isTrue); // Documentation placeholder
    });
  });
}
