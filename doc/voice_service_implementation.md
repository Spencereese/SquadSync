# Voice Service & Speech-to-Text Implementation Guide

## Overview
This document covers the implementation of Agora RTC voice chat with real-time speech-to-text transcription in SquadSync.

## Architecture

### Core Components

1. **VoiceService** (`lib/services/voice_service.dart`)
   - Riverpod provider: `voiceServiceProvider`
   - Manages Agora RTC engine lifecycle
   - Handles voice channel operations (join, leave, mute)
   - Real-time callbacks for speaking detection
   - Network monitoring and reconnection logic

2. **VoiceToTextNotifier** (`lib/services/voice_service.dart`)
   - Riverpod StateNotifier: `voiceToTextNotifierProvider`
   - Manages speech-to-text state
   - Real-time transcription with partial results
   - Sound level monitoring for audio visualization

3. **ChatMediaHandler** (`lib/chat/services/chat_media_handler.dart`)
   - Enhanced with speech-to-text integration
   - Records audio with simultaneous transcription
   - Sends voice notes with transcribed text (🎤 prefix)

4. **VoiceRoomScreen** (`lib/screens/voice_room_screen.dart`)
   - Spatial audio visualization
   - Floating glass orbs for participants
   - Dynamic orb scaling based on voice volume
   - Neon ring pulsing for active speakers

## Features

### Voice Notes in Chat
- **Long-press mic button** to start recording
- **Real-time transcription** appears as you speak
- **Release button** to send voice note with transcription
- **Message format**: `🎤 [transcribed text]` + audio file
- **Offline support**: Audio cached in SQLite, transcription stored with message

### Voice Room Features
- **Spatial audio**: Participants positioned in grid with 3D audio effect
- **Volume visualization**: Orb size and neon glow based on speaking volume
- **Speaking indicators**: Pulse animations when user is speaking
- **Host controls**: Mute participants, kick users
- **Raise hand**: Peacock feather animation
- **Screen share preview**: Corner widget (future enhancement)

## Permissions Setup

### iOS (ios/Runner/Info.plist)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>SquadSync needs microphone access for voice chat and voice notes</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>SquadSync uses speech recognition to transcribe voice notes</string>
```

### Android (android/app/src/main/AndroidManifest.xml)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### Web
- Browser automatically prompts for microphone access
- No additional configuration needed

## Usage

### Voice Service Provider

```dart
// Access VoiceService
final voiceService = ref.read(voiceServiceProvider);

// Initialize engine
final initResult = await voiceService.initializeEngine();
if (initResult.isSuccess) {
  // Join voice channel
  final joinResult = await voiceService.joinChannel('room_id_123');
}

// Setup callbacks
voiceService.onSpeakingChanged = (userId, isSpeaking) {
  // Update UI based on speaking state
};

voiceService.onParticipantJoined = (userId) {
  // Handle new participant
};

// Leave channel
await voiceService.leaveChannel();
```

### Voice-to-Text Notifier

```dart
// Access voice-to-text state
final voiceToTextNotifier = ref.read(voiceToTextNotifierProvider.notifier);
final voiceToTextState = ref.watch(voiceToTextNotifierProvider);

// Initialize
await voiceToTextNotifier.initialize();

// Start listening
await voiceToTextNotifier.startListening(
  onResult: (text) {
    print('Transcribed: $text');
  },
);

// Stop listening
await voiceToTextNotifier.stopListening();

// Access state
if (voiceToTextState.isListening) {
  print('Currently listening...');
  print('Recognized: ${voiceToTextState.recognizedText}');
  print('Sound level: ${voiceToTextState.soundLevel}');
}
```

### Voice Notes in ChatScreen

Voice notes are automatically integrated via ChatMediaHandler:

```dart
// In ChatInputBar widget
onRecordStart: _startRecording,
onRecordStop: _stopRecording,

// Implementation in ChatScreen
Future<void> _startRecording() async {
  await _mediaHandler.startRecording(ref);
  _animationController.repeat();
}

Future<void> _stopRecording() async {
  await _mediaHandler.stopRecording(ref,
      chatGroupId: widget.chatGroupId, chatType: widget.chatType);
  _animationController.stop();
}
```

## Agora Configuration

### Environment Variables (.env)
```env
AGORA_APP_ID=your_app_id_here
AGORA_APP_CERTIFICATE=your_certificate_here  # Optional for development
```

### Token Generation
- Development: Uses empty token (testing mode)
- Production: Backend generates tokens with `/api/agora/token/:channelName`
- Token includes user UID and channel name

## Testing

### Unit Tests
Run tests with:
```bash
flutter test test/services/voice_service_test.dart
```

### Integration Tests
1. **Voice Note Recording**:
   - Open any chat
   - Long-press mic button
   - Speak clearly
   - Release button
   - Verify message sent with 🎤 prefix and transcription

2. **Voice Room**:
   - Create/join voice room from lobby
   - Verify engine initialization
   - Check spatial audio visualization
   - Test mute toggle
   - Verify callbacks fire correctly

### Permission Testing
```bash
# Test on iOS Simulator
flutter run -d iPhone

# Test on Android Emulator
flutter run -d emulator-5554

# Check permission status
# On iOS: Settings > [App Name] > Microphone
# On Android: Settings > Apps > [App Name] > Permissions
```

## Troubleshooting

### Common Issues

1. **"Microphone permission denied"**
   - Solution: Check Info.plist (iOS) or AndroidManifest.xml (Android)
   - Verify permission descriptions are present

2. **Speech recognition not available**
   - Solution: Run on physical device (not simulator)
   - iOS: Enable Siri in Settings
   - Android: Check Google app is installed

3. **Agora engine initialization failed**
   - Solution: Verify AGORA_APP_ID in .env file
   - Check internet connection
   - Ensure agora_rtc_engine dependency is up to date

4. **No audio in voice room**
   - Solution: Check microphone permission granted
   - Verify audio input device is working
   - Test with System Preferences > Sound > Input

5. **Transcription not working**
   - Solution: Speak clearly near microphone
   - Check language setting (default: en_US)
   - Verify internet connection (cloud-based recognition)

## Performance Optimization

### Audio Recording
- Uses temporary files in system temp directory
- Files auto-deleted after upload
- Compressed M4A format for smaller file size

### Transcription
- Partial results enabled for real-time feedback
- Confirmation mode for final accurate text
- Sound level monitoring for visualization

### Voice Room
- Texture rendering for efficient particle effects
- Animation controller pooling for orb pulses
- Lazy loading of participant avatars
- Network state monitoring with automatic reconnection

## Security Considerations

1. **Credentials**: Never commit AGORA_APP_ID or certificates to git
2. **Token expiration**: Backend generates short-lived tokens
3. **Permission validation**: Double-check permissions before operations
4. **Audio storage**: Temporary files cleaned up after upload
5. **User privacy**: Transcriptions processed on-device or via secure cloud API

## Future Enhancements

- [ ] Noise cancellation
- [ ] Voice effects (pitch, echo)
- [ ] Multi-language transcription
- [ ] Offline transcription with on-device models
- [ ] Screen sharing in voice rooms
- [ ] Spatial audio with 3D positioning
- [ ] Voice activity detection (VAD) optimization
- [ ] Background noise suppression

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  agora_rtc_engine: ^6.5.3
  permission_handler: ^11.3.1
  speech_to_text: ^7.0.0
  record: ^6.1.1
```

## References

- [Agora RTC SDK Documentation](https://docs.agora.io/en/voice-calling/overview/product-overview)
- [speech_to_text Package](https://pub.dev/packages/speech_to_text)
- [permission_handler Package](https://pub.dev/packages/permission_handler)
- [SquadSync Architecture Guide](.github/copilot-instructions.md)
