# VideoService Quick Reference

## 🚀 Quick Setup (5 minutes)

### 1. Add Environment Variables
```env
AGORA_APP_ID=your_app_id
AGORA_APP_CERTIFICATE=your_certificate  # Optional
```

### 2. Create Provider
```dart
final videoServiceProvider = Provider<VideoService>((ref) {
  return VideoService(
    notificationManager: NotificationManager(),
    appFlowManager: AppFlowManager(FirebaseAnalytics.instance),
    firestoreService: FirestoreService(),
    sqliteHelper: SQLiteHelper(),
  );
});
```

### 3. Start Video Call
```dart
final videoService = ref.read(videoServiceProvider);
await videoService.initializeEngine();
await videoService.joinVideoRoom('my_room', enableVideo: true);
```

## 📱 Essential Methods

### Core Video
```dart
enableVideo()                    // Turn camera on
disableVideo()                   // Turn camera off
toggleCamera()                   // Toggle on/off
flipCamera()                     // Front ↔ Back
```

### Audio
```dart
toggleMute(bool muted)           // Mute/unmute mic
muteLocalVideo(bool muted)       // Hide video stream
```

### Effects
```dart
toggleBeautyFilter()             // Beauty enhancement
enableVirtualBackground(         // Background effects
  blur: true,                    //   - Blur
  imagePath: 'path/to/image',   //   - Custom image
)
disableVirtualBackground()       // Remove effects
```

### Room Control
```dart
joinVideoRoom(                   // Join with video
  'channel_name',
  uid: 12345,
  enableVideo: true,
)
leaveVideoRoom()                 // Leave and cleanup
```

### UI Widgets
```dart
setupLocalVideoView()            // Your video preview
setupRemoteVideoView(uid)        // Participant video
```

## 🎨 UI Integration

### Minimal Video Screen
```dart
class VideoScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoService = ref.watch(videoServiceProvider);
    
    return Scaffold(
      body: Column(
        children: [
          Expanded(child: videoService.setupLocalVideoView()),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.mic),
                onPressed: () => videoService.toggleMute(false),
              ),
              IconButton(
                icon: Icon(Icons.videocam),
                onPressed: () => videoService.toggleCamera(),
              ),
              IconButton(
                icon: Icon(Icons.call_end),
                onPressed: () async {
                  await videoService.leaveVideoRoom();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
```

## 🔧 Common Use Cases

### 1. Audio-Only Join (Save Bandwidth)
```dart
await videoService.joinVideoRoom('room', enableVideo: false);
```

### 2. Add Beauty Filter
```dart
await videoService.toggleBeautyFilter(); // Quick toggle
```

### 3. Blur Background
```dart
await videoService.enableVirtualBackground(blur: true);
```

### 4. Custom Background Image
```dart
final image = await ImagePicker().pickImage(source: ImageSource.gallery);
await videoService.enableVirtualBackground(
  blur: false,
  imagePath: image?.path,
);
```

### 5. Switch Camera During Call
```dart
await videoService.flipCamera(); // Instant flip
```

### 6. Network Quality Monitoring
```dart
videoService.onNetworkQualityChanged = (quality) {
  if (quality >= 4) showWarning('Poor connection');
};
```

## 🎯 VideoRoomNotifier (High-Level)

### Setup
```dart
final videoRoomProvider = StateNotifierProvider.family<
  VideoRoomNotifier, AsyncValue<VideoRoomState>, Map<String, String>
>((ref, params) {
  return VideoRoomNotifier(
    roomId: params['roomId']!,
    roomName: params['roomName']!,
    videoService: ref.watch(videoServiceProvider),
    // ... other dependencies
  );
});
```

### Use in Widget
```dart
final roomState = ref.watch(videoRoomProvider({
  'roomId': 'squad_123',
  'roomName': 'Squad Call',
}));

roomState.when(
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error: $e'),
  data: (state) => VideoUI(state),
);
```

### Actions
```dart
final notifier = ref.read(videoRoomProvider({...}).notifier);

await notifier.initializeVideoService();
await notifier.joinRoom(enableVideo: true);
await notifier.toggleMute();
await notifier.toggleVideo();
await notifier.flipCamera();
await notifier.toggleBeautyFilter();
await notifier.leaveRoom();
```

## 📊 State Properties

### VideoRoomState
```dart
state.isJoined                   // In room?
state.isMuted                    // Mic muted?
state.isVideoEnabled             // Camera on?
state.isCameraFront              // Front camera?
state.isBeautyFilterEnabled      // Beauty on?
state.isVirtualBackgroundEnabled // Background on?
state.participants               // List<VideoParticipant>
state.isNetworkAvailable         // Connection?
state.error                      // Error message?
```

### VideoParticipant
```dart
participant.uid                  // User ID
participant.displayName          // Name
participant.isMuted              // Mic status
participant.isSpeaking           // Speaking now?
participant.hasVideo             // Video streaming?
participant.isCameraEnabled      // Camera on?
participant.isOnline             // Online?
```

## 🛠️ Error Handling

```dart
final result = await videoService.enableVideo();

if (result.isSuccess) {
  print('✅ Video enabled');
} else {
  switch (result.error) {
    case VideoServiceError.permissionDenied:
      showDialog('Camera permission required');
      break;
    case VideoServiceError.cameraError:
      showDialog('Camera not available');
      break;
    case VideoServiceError.networkError:
      showDialog('Check your connection');
      break;
    default:
      showDialog('Unknown error: ${result.errorMessage}');
  }
}
```

## 🚨 Troubleshooting

| Problem | Solution |
|---------|----------|
| Black screen | Check camera permission + `enableVideo()` |
| No audio | Verify mic permission + not muted |
| Poor quality | Lower resolution or check network |
| Lag/stuttering | Disable beauty filter + check network |
| Can't join | Verify AGORA_APP_ID + backend running |

## 🎮 Integration with Squad

### Add to Squad Screen
```dart
// In squad_tab/squad_screen.dart
ElevatedButton.icon(
  icon: Icon(Icons.video_call),
  label: Text('Video Chat'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          roomId: 'squad_${squad.id}',
          roomName: squad.name,
        ),
      ),
    );
  },
)
```

## 📏 Video Quality Presets

### Mobile Data (Low)
```dart
VideoDimensions(width: 320, height: 240)  // frameRate: 15
```

### WiFi (Medium)
```dart
VideoDimensions(width: 640, height: 360)  // frameRate: 24
```

### WiFi (High)
```dart
VideoDimensions(width: 1280, height: 720) // frameRate: 30
```

## 🔗 Backend Requirement

Ensure backend has token generation:

```javascript
// backend/server.js
app.post('/generate-agora-token', (req, res) => {
  const { channelName, uid } = req.body;
  const token = generateAgoraToken(channelName, uid);
  res.json({ token });
});
```

## 📚 Full Documentation

- **Complete Guide**: `VIDEO_SERVICE_README.md`
- **Comparison**: `VIDEO_VS_VOICE_COMPARISON.md`
- **Example Code**: `lib/examples/video_service_example.dart`
- **API Reference**: See README sections

## ⚡ Performance Tips

1. Start with video disabled, enable on demand
2. Use beauty filter sparingly (CPU intensive)
3. Blur > Custom image for performance
4. Limit to 4-6 participants per room
5. Monitor network quality, downgrade if needed
6. Disable video on low battery (<20%)

## 🎉 You're Ready!

The VideoService is production-ready with all features of VoiceService plus comprehensive video capabilities. Start with the minimal example and add features as needed!
