# VideoService vs VoiceService Comparison

## Overview

**VideoService** extends all capabilities of **VoiceService** while adding comprehensive video features. Both services share the same Agora RTC engine foundation.

## Feature Comparison

| Feature | VoiceService | VideoService |
|---------|-------------|--------------|
| **Audio Chat** | ✅ Full support | ✅ Full support |
| **Video Chat** | ❌ Not supported | ✅ Full HD video |
| **Microphone Control** | ✅ Mute/unmute | ✅ Mute/unmute |
| **Camera Control** | ❌ | ✅ Toggle, flip, front/back |
| **Beauty Filters** | ❌ | ✅ Adjustable levels |
| **Virtual Backgrounds** | ❌ | ✅ Blur or custom image |
| **Permission Handling** | ✅ Microphone only | ✅ Camera + microphone |
| **Network Monitoring** | ✅ Connection state | ✅ Quality indicators |
| **Token Generation** | ✅ Backend token | ✅ Backend token |
| **Firestore Sync** | ✅ Room state | ✅ Room + video state |
| **Analytics Tracking** | ✅ Voice sessions | ✅ Video sessions |
| **SQLite Caching** | ✅ Offline support | ✅ Offline support |

## Code Comparison

### Initialization

**VoiceService:**
```dart
final voiceService = VoiceService(
  notificationManager: NotificationManager(),
  appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
  firestoreService: FirestoreService(),
  sqliteHelper: SQLiteHelper(),
);

await voiceService.initializeEngine(); // Mic permission only
```

**VideoService:**
```dart
final videoService = VideoService(
  notificationManager: NotificationManager(),
  appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
  firestoreService: FirestoreService(),
  sqliteHelper: SQLiteHelper(),
);

await videoService.initializeEngine(); // Camera + mic permissions
```

### Joining a Room

**VoiceService:**
```dart
await voiceService.joinChannel('my_channel', uid: 12345);
```

**VideoService:**
```dart
await videoService.joinVideoRoom(
  'my_channel',
  uid: 12345,
  enableVideo: true, // Enable video on join
);
```

### Basic Controls

**VoiceService:**
```dart
// Mute/unmute microphone
await voiceService.toggleMute(true);
```

**VideoService:**
```dart
// Audio controls (same as voice)
await videoService.toggleMute(true);

// Video-specific controls
await videoService.toggleCamera();     // Turn camera on/off
await videoService.flipCamera();       // Switch front/back
await videoService.muteLocalVideo(true); // Hide video without stopping camera
```

### State Models

**VoiceParticipant:**
```dart
VoiceParticipant(
  uid: '12345',
  displayName: 'John Doe',
  isMuted: false,
  isSpeaking: true,
  isHost: false,
  isOnline: true,
  lastSeen: DateTime.now(),
)
```

**VideoParticipant (extends voice features):**
```dart
VideoParticipant(
  uid: '12345',
  displayName: 'John Doe',
  isMuted: false,
  isSpeaking: true,
  isHost: false,
  isOnline: true,
  hasVideo: true,          // NEW: Video streaming
  isCameraEnabled: true,   // NEW: Camera on/off
  lastSeen: DateTime.now(),
)
```

### Room State

**VoiceRoomState:**
```dart
VoiceRoomState(
  roomId: 'room_123',
  roomName: 'Squad Voice',
  participants: [...],
  isJoined: true,
  isMuted: false,
  isLoading: false,
  error: null,
  isReconnecting: false,
  reconnectAttempts: 0,
  isHost: false,
  isNetworkAvailable: true,
)
```

**VideoRoomState (extends voice state):**
```dart
VideoRoomState(
  roomId: 'room_123',
  roomName: 'Squad Video',
  participants: [...],
  isJoined: true,
  isMuted: false,
  isVideoEnabled: true,              // NEW: Local video on/off
  isCameraFront: true,               // NEW: Camera direction
  isBeautyFilterEnabled: false,      // NEW: Beauty filter state
  isVirtualBackgroundEnabled: false, // NEW: Background effect state
  isLoading: false,
  error: null,
  isReconnecting: false,
  reconnectAttempts: 0,
  isHost: false,
  isNetworkAvailable: true,
)
```

## When to Use Each Service

### Use VoiceService When:
- ✅ Audio-only communication is needed
- ✅ Minimizing bandwidth usage
- ✅ Supporting low-end devices
- ✅ Background voice chat during gameplay
- ✅ Reduced battery consumption is priority

### Use VideoService When:
- ✅ Face-to-face communication is needed
- ✅ Visual engagement is important
- ✅ Squad planning/strategy sessions
- ✅ Social hangouts and events
- ✅ Onboarding new squad members

## Migration Guide

### From VoiceService to VideoService

**Step 1: Update Imports**
```dart
// Old
import '../services/voice_service.dart';

// New
import '../services/video_service.dart';
```

**Step 2: Update Service Instance**
```dart
// Old
final voiceService = VoiceService(...);

// New
final videoService = VideoService(...);
```

**Step 3: Update Join Call**
```dart
// Old
await voiceService.joinChannel('my_room');

// New
await videoService.joinVideoRoom('my_room', enableVideo: true);
```

**Step 4: Add Video Views**
```dart
// Add local video preview
Widget localView = videoService.setupLocalVideoView();

// Add remote video views
Widget remoteView = videoService.setupRemoteVideoView(remoteUid);
```

**Step 5: Update State Management**
```dart
// Old
final voiceRoomProvider = StateNotifierProvider<VoiceRoomNotifier, ...>(...);

// New
final videoRoomProvider = StateNotifierProvider<VideoRoomNotifier, ...>(...);
```

## Shared Infrastructure

Both services share these common components:

### 1. Agora Configuration
```dart
AgoraConfigEnhanced.getValidatedAppId()
AgoraConfigEnhanced.getValidatedCertificate()
```

### 2. Token Generation
```dart
// Same backend endpoint for both
Future<String?> generateToken(String channelName, int uid)
```

### 3. Error Handling
```dart
// Both use Result pattern
VoiceServiceResult<T> / VideoServiceResult<T>
```

### 4. Network Monitoring
```dart
// Both monitor connectivity
StreamSubscription<List<ConnectivityResult>> _connectivitySubscription
```

### 5. Analytics Integration
```dart
// Both track sessions
await appFlowManager?.trackVoiceSession(...) // Used by both
```

## Performance Comparison

| Metric | VoiceService | VideoService |
|--------|-------------|--------------|
| **Bandwidth** | ~50 kbps | ~500 kbps (SD) / ~1 Mbps (HD) |
| **CPU Usage** | ~5-10% | ~15-30% |
| **Battery Impact** | Low | Medium-High |
| **Network Stability** | High tolerance | Requires stable connection |
| **Max Participants** | 10-20 | 4-8 recommended |

## Code Reuse

VideoService reuses VoiceService patterns:

```dart
// Shared patterns
✅ Engine initialization
✅ Permission handling
✅ Event handlers setup
✅ Audio configuration
✅ Token generation
✅ Network monitoring
✅ Error classification
✅ Firestore sync
✅ SQLite caching
✅ Analytics tracking

// Video-specific additions
➕ Camera permissions
➕ Video encoder configuration
➕ Video state tracking
➕ Beauty filter setup
➕ Virtual background processing
➕ Video view widgets
➕ Camera control methods
```

## Example: Switching Between Services

Create a unified chat service that supports both:

```dart
class ChatService {
  final VoiceService _voiceService;
  final VideoService _videoService;
  bool _useVideo = false;

  ChatService(this._voiceService, this._videoService);

  Future<void> joinRoom(String roomId, {bool withVideo = false}) async {
    _useVideo = withVideo;
    
    if (_useVideo) {
      await _videoService.initializeEngine();
      await _videoService.joinVideoRoom(roomId, enableVideo: true);
    } else {
      await _voiceService.initializeEngine();
      await _voiceService.joinChannel(roomId);
    }
  }

  Future<void> toggleVideo() async {
    if (_useVideo) {
      await _videoService.toggleCamera();
    } else {
      // Upgrade to video
      await _voiceService.leaveChannel();
      await _videoService.initializeEngine();
      await _videoService.joinVideoRoom('current_room', enableVideo: true);
      _useVideo = true;
    }
  }
}
```

## Best Practices

1. **Start with Voice**: Begin with VoiceService for basic features
2. **Upgrade to Video**: Add VideoService when visual communication is needed
3. **User Choice**: Let users choose between voice/video based on context
4. **Bandwidth Awareness**: Auto-downgrade to voice on poor network
5. **Battery Monitoring**: Suggest voice mode on low battery
6. **Device Capability**: Check camera availability before using VideoService

## Testing Checklist

- [ ] Voice-only calls work correctly
- [ ] Video calls work with camera enabled
- [ ] Can switch from voice to video mid-call
- [ ] Beauty filters work on supported devices
- [ ] Virtual backgrounds work without lag
- [ ] Network quality monitoring functions
- [ ] Auto-reconnection works for both
- [ ] Permissions handled gracefully
- [ ] Analytics tracking accurate
- [ ] Offline caching works

## Summary

**VideoService** is a **superset** of **VoiceService** - it does everything VoiceService does, plus adds comprehensive video capabilities. Choose based on your use case, network conditions, and user preferences.

For most squad gaming scenarios, use **VoiceService** for background voice chat during gameplay, and **VideoService** for pre-game planning, post-game discussions, or social hangouts.
