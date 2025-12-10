# VideoService - SquadSync Video Chat Integration

Complete video chat solution for SquadSync using Agora RTC Engine 6.3.0+.

## Features

- ✅ **Full Video Chat**: HD video calls with multiple participants
- ✅ **Audio + Video Controls**: Toggle camera, flip camera, mute/unmute
- ✅ **Beauty Filters**: Built-in beauty enhancement with adjustable levels
- ✅ **Virtual Backgrounds**: Blur or custom image backgrounds using AI segmentation
- ✅ **Network Quality Monitoring**: Real-time connection quality indicators
- ✅ **Permission Handling**: Automatic camera + microphone permission requests
- ✅ **Riverpod State Management**: AsyncValue-based reactive state
- ✅ **Firebase Integration**: Firestore sync and analytics tracking
- ✅ **Offline Support**: SQLite caching for room state
- ✅ **Auto-Reconnection**: Network resilience with retry logic

## Architecture

### Core Components

1. **VideoService** - Low-level Agora engine wrapper
   - Engine initialization
   - Permission management
   - Video/audio configuration
   - Event handling

2. **VideoRoomNotifier** - High-level state management
   - Room join/leave
   - Participant tracking
   - UI state synchronization
   - Analytics integration

3. **VideoParticipant** - Participant state model
   - Video/audio status
   - Display metadata
   - Speaking indicators

4. **VideoRoomState** - Room state model
   - Participants list
   - Video/audio settings
   - Network status
   - Error handling

## Quick Start

### 1. Setup Environment Variables

Add to your `.env` file:

```env
AGORA_APP_ID=your_agora_app_id_here
AGORA_APP_CERTIFICATE=your_agora_certificate_here  # Optional for testing
```

### 2. Backend Token Generation

Ensure your backend (`backend/server.js`) has the token generation endpoint:

```javascript
app.post('/generate-agora-token', (req, res) => {
  const { channelName, uid, certificate } = req.body;
  // Generate token using Agora token library
  const token = generateAgoraToken(channelName, uid, certificate);
  res.json({ token });
});
```

### 3. Create Providers

```dart
// lib/providers/video_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../services/video_service.dart';
import '../services/firestore_service.dart';
import '../services/app_flow_manager.dart';
import '../chat/sqlite_helper.dart';
import '../managers/stubs.dart';

final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService(
    notificationManager: NotificationManager(),
    appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
    firestoreService: FirestoreService(),
    sqliteHelper: SQLiteHelper(),
  );
});

final videoRoomProvider = StateNotifierProvider.family<VideoRoomNotifier,
    AsyncValue<VideoRoomState>, Map<String, String>>((ref, params) {
  final videoService = ref.watch(videoServiceProvider);
  
  return VideoRoomNotifier(
    roomId: params['roomId'] ?? '',
    roomName: params['roomName'] ?? 'Video Room',
    videoService: videoService,
    notificationManager: NotificationManager(),
    appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
    firestoreService: FirestoreService(),
    sqliteHelper: SQLiteHelper(),
  );
});
```

### 4. Basic Usage

```dart
// lib/screens/video_call_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/video_providers.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String roomId;
  final String roomName;

  const VideoCallScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAndJoin();
    });
  }

  Future<void> _initializeAndJoin() async {
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);

    await notifier.initializeVideoService();
    await notifier.joinRoom(enableVideo: true);
  }

  @override
  Widget build(BuildContext context) {
    final roomState = ref.watch(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }));

    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: roomState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
        data: (state) => _buildVideoUI(state),
      ),
    );
  }

  Widget _buildVideoUI(VideoRoomState state) {
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);

    return Column(
      children: [
        // Local video preview
        Expanded(
          child: state.isVideoEnabled
              ? notifier.getLocalVideoView()
              : const Center(child: Text('Camera is off')),
        ),
        
        // Control buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(state.isMuted ? Icons.mic_off : Icons.mic),
              onPressed: () => notifier.toggleMute(),
            ),
            IconButton(
              icon: Icon(state.isVideoEnabled ? Icons.videocam : Icons.videocam_off),
              onPressed: () => notifier.toggleVideo(),
            ),
            IconButton(
              icon: const Icon(Icons.call_end),
              onPressed: () async {
                await notifier.leaveRoom();
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    final notifier = ref.read(videoRoomProvider({
      'roomId': widget.roomId,
      'roomName': widget.roomName,
    }).notifier);
    notifier.leaveRoom();
    super.dispose();
  }
}
```

## API Reference

### VideoService Methods

#### Engine Management
```dart
// Initialize Agora engine with permissions
Future<VideoServiceResult<void>> initializeEngine()

// Clean up resources
void dispose()
```

#### Video Controls
```dart
// Enable video capture and preview
Future<VideoServiceResult<void>> enableVideo()

// Disable video capture
Future<VideoServiceResult<void>> disableVideo()

// Toggle camera on/off
Future<VideoServiceResult<void>> toggleCamera()

// Flip between front/back camera
Future<VideoServiceResult<void>> flipCamera()

// Mute/unmute local video stream
Future<VideoServiceResult<void>> muteLocalVideo(bool muted)
```

#### Audio Controls
```dart
// Mute/unmute microphone
Future<VideoServiceResult<void>> toggleMute(bool muted)
```

#### Video Effects
```dart
// Toggle beauty filter with adjustable settings
Future<VideoServiceResult<void>> toggleBeautyFilter()

// Enable virtual background (blur or image)
Future<VideoServiceResult<void>> enableVirtualBackground({
  bool blur = true,
  String? imagePath,
})

// Disable virtual background
Future<VideoServiceResult<void>> disableVirtualBackground()
```

#### Room Operations
```dart
// Join video room with audio and video
Future<VideoServiceResult<void>> joinVideoRoom(
  String channelName, {
  int uid = 0,
  bool enableVideo = true,
})

// Leave video room
Future<VideoServiceResult<void>> leaveVideoRoom()
```

#### Video Views
```dart
// Get local video preview widget
Widget setupLocalVideoView()

// Get remote participant video widget
Widget setupRemoteVideoView(int uid)
```

### VideoRoomNotifier Methods

```dart
// Initialize video service
Future<void> initializeVideoService()

// Join room
Future<void> joinRoom({bool enableVideo = true})

// Leave room
Future<void> leaveRoom()

// Toggle mute
Future<void> toggleMute()

// Toggle video
Future<void> toggleVideo()

// Flip camera
Future<void> flipCamera()

// Toggle beauty filter
Future<void> toggleBeautyFilter()

// Enable virtual background
Future<void> enableVirtualBackground({bool blur = true, String? imagePath})

// Disable virtual background
Future<void> disableVirtualBackground()

// Get video view widgets
Widget getLocalVideoView()
Widget getRemoteVideoView(int uid)
```

## Advanced Features

### Beauty Filter Settings

Customize beauty filter levels:

```dart
// In VideoService.toggleBeautyFilter(), modify BeautyOptions:
await _engine!.setBeautyEffectOptions(
  enabled: true,
  options: const BeautyOptions(
    lighteningContrastLevel: LighteningContrastLevel.lighteningContrastNormal,
    lighteningLevel: 0.7,      // Skin brightening (0.0-1.0)
    smoothnessLevel: 0.5,      // Skin smoothing (0.0-1.0)
    rednessLevel: 0.1,         // Skin redness (0.0-1.0)
    sharpnessLevel: 0.3,       // Image sharpness (0.0-1.0)
  ),
);
```

### Virtual Background with Custom Image

```dart
// Pick image from gallery
final imagePath = await ImagePicker().pickImage(source: ImageSource.gallery);

if (imagePath != null) {
  await notifier.enableVirtualBackground(
    blur: false,
    imagePath: imagePath.path,
  );
}
```

### Network Quality Monitoring

```dart
// In VideoService, onNetworkQualityChanged callback provides quality level:
// 0 = unknown
// 1 = excellent
// 2 = good
// 3 = poor
// 4 = bad
// 5 = very bad
// 6 = disconnected

_videoService.onNetworkQualityChanged = (quality) {
  if (quality >= 4) {
    showWarning('Poor network quality detected');
  }
};
```

### Video Encoder Configuration

Adjust video quality in `_configureAudioVideoProfile()`:

```dart
await _engine!.setVideoEncoderConfiguration(
  const VideoEncoderConfiguration(
    dimensions: VideoDimensions(width: 1280, height: 720), // HD
    frameRate: 30,              // Smooth video
    bitrate: 0,                 // Auto bitrate
    orientationMode: OrientationMode.orientationModeAdaptive,
    degradationPreference: DegradationPreference.maintainBalanced,
  ),
);
```

## Integration with Squad Tab

Add video call button to squad screen:

```dart
// In lib/squad_tab/squad_screen.dart
ElevatedButton.icon(
  icon: const Icon(Icons.video_call),
  label: const Text('Start Video Call'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoCallScreen(
          roomId: 'squad_${currentSquad.id}',
          roomName: '${currentSquad.name} Video',
        ),
      ),
    );
  },
)
```

## Firestore Data Structure

### Video Room Document
```
/video_rooms/{roomId}
  - roomId: string
  - roomName: string
  - hostUid: string
  - participants: array
    - uid: string
    - displayName: string
    - isMuted: bool
    - hasVideo: bool
    - isOnline: bool
  - createdAt: timestamp
  - updatedAt: timestamp
```

## Error Handling

The service uses `VideoServiceResult<T>` for error handling:

```dart
final result = await videoService.enableVideo();

if (result.isSuccess) {
  print('Video enabled successfully');
} else {
  print('Error: ${result.error} - ${result.errorMessage}');
}
```

### Error Types
- `configMissing` - Agora credentials not found
- `permissionDenied` - Camera/mic permission denied
- `networkError` - Network connectivity issues
- `joinFailed` - Failed to join channel
- `tokenGenerationFailed` - Backend token error
- `engineInitializationFailed` - Agora engine init error
- `cameraError` - Camera hardware issues
- `virtualBackgroundError` - Background effect failed
- `unknown` - Unexpected error

## Testing

### Mock Mode
When `AGORA_APP_ID` is missing, the service runs in mock mode for development:

```dart
// In debug mode without credentials
final appIdResult = AgoraConfigEnhanced.getValidatedAppId();
// Returns mock_app_id_for_development
```

### Integration Tests
See `lib/examples/video_service_example.dart` for complete UI integration example.

## Performance Tips

1. **Video Resolution**: Lower resolution (640x360) for mobile networks
2. **Frame Rate**: Use 15fps for group calls, 30fps for 1-on-1
3. **Background Effects**: Disable on low-end devices
4. **Participant Limit**: Optimal 4-6 participants per room
5. **Network Check**: Always check `isNetworkAvailable` before join

## Troubleshooting

### Video Not Showing
- Verify camera permission granted
- Check `enableVideo()` was called
- Ensure Agora App ID is correct
- Confirm backend token endpoint is running

### Poor Video Quality
- Check network quality indicator
- Reduce video resolution/frame rate
- Disable beauty filters
- Check device capabilities

### Permission Errors
- iOS: Add camera/mic usage descriptions to `Info.plist`
- Android: Ensure permissions in `AndroidManifest.xml`
- Call `openAppSettings()` if permanently denied

## References

- **Agora RTC Engine**: https://docs.agora.io/en/video-calling/overview/product-overview
- **Virtual Background**: https://docs.agora.io/en/video-calling/develop/virtual-background
- **Beauty Effects**: https://docs.agora.io/en/video-calling/develop/beauty-effects
- **SquadSync Docs**: See `doc/agora_setup.md` for Agora configuration

## License

Part of SquadSync project. See main LICENSE file.
