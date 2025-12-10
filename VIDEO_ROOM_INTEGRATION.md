# VideoRoomScreen Integration Guide

## NEON VOID Video Room Features

The `VideoRoomScreen` is a production-ready, stunning video chat interface with:

### 🎨 Visual Features
- **Adaptive Grid Layout**: 1x1, 2x2, or 3x3 grid based on participant count (1-9 users)
- **Glassmorphic UI**: Frosted glass effect with backdrop blur
- **Neon Border Effects**: Glowing borders that pulse when speaking
- **Speaking Indicators**: Animated neon pulse rings + volume waveforms
- **Floating PiP**: Draggable local video bubble when >4 users
- **Dark Void Theme**: Perfect match for NEON VOID aesthetic

### 🎥 Video Features
- **Virtual Background**: Blur enabled by default on join
- **Beauty Filter**: Toggle-able enhancement
- **Camera Controls**: Toggle, flip, mute
- **Live State**: Real-time mute/video status indicators
- **Auto-Layout**: Discord-like adaptive grid

### 📊 UI Components
- **Top Bar**: Room name, participant count, call duration timer
- **Video Grid**: Adaptive layout with neon speaking borders
- **Control Bar**: Glass bottom bar with all controls
- **Effect Menu**: Bottom sheet for beauty/background toggles

## Quick Integration

### Option 1: From Squad Tab

Add to your squad screen (e.g., `lib/squad_tab/squad_screen.dart`):

```dart
import '../screens/video_room_screen.dart';

// In your squad screen widget
ElevatedButton.icon(
  icon: const Icon(Icons.video_call),
  label: const Text('Start Video Call'),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          roomId: 'squad_${currentSquad.id}',
          roomName: '${currentSquad.name} Video',
        ),
      ),
    );
  },
)
```

### Option 2: From Chat Screen

Add video button to chat header:

```dart
// In lib/chat/chat_screen.dart app bar actions
IconButton(
  icon: const Icon(Icons.videocam),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          roomId: 'chat_${chatGroupId}',
          roomName: chatGroupName,
        ),
      ),
    );
  },
)
```

### Option 3: From Main Navigation

Add to your bottom navigation:

```dart
// In lib/main_navigation_screen.dart
case 3: // Video tab
  return const VideoLobbyScreen(); // Shows active rooms
```

## Features Walkthrough

### Adaptive Grid Layout
- **1 user**: Full screen single video
- **2 users**: 2x1 grid (side by side)
- **3-4 users**: 2x2 grid
- **5-9 users**: 3x3 grid with floating PiP for local video

### Speaking Indicators
When a user speaks:
- **Neon pulse ring** animates around their video
- **Border glows** brighter with animated intensity
- **Waveform indicator** shows in top-right corner
- **Visual feedback** syncs with audio levels

### Floating PiP (>4 users)
- **Draggable**: Touch and drag to reposition
- **Compact**: 120x160 size doesn't block grid
- **Auto-constrained**: Stays within screen bounds
- **Same indicators**: Shows mute/speaking status

### Control Bar Features

1. **Mute/Unmute**
   - Red border when muted
   - Neon glow when active
   - Haptic feedback on toggle

2. **Toggle Camera**
   - Live state indicator (on/off)
   - Smooth transition
   - Placeholder when camera off

3. **Flip Camera**
   - Instant front ↔ back switch
   - Works during active call
   - No interruption

4. **Effects Menu**
   - Virtual background blur (on by default)
   - Beauty filter toggle
   - Bottom sheet with glassmorphic UI

5. **Leave Button**
   - Red destructive styling
   - Confirmation dialog
   - Safe disconnect

### Top Bar Information
- **Room Name**: Displays call title
- **Participant Count**: Live count with icon
- **Call Duration**: Live timer (MM:SS or HH:MM:SS)
- **Glassmorphic**: Semi-transparent with blur

## Customization

### Change Default Virtual Background
In `_initializeAndJoin()`:

```dart
// Use custom image instead of blur
await notifier.enableVirtualBackground(
  blur: false,
  imagePath: 'assets/images/custom_background.png',
);
```

### Adjust Grid Layout
In `_getGridCrossAxisCount()`:

```dart
int _getGridCrossAxisCount(int participantCount) {
  if (participantCount <= 1) return 1;
  if (participantCount <= 2) return 1; // Stack vertically
  if (participantCount <= 6) return 2; // 2x3 instead of 3x3
  return 3;
}
```

### Modify Speaking Animation Speed
In `initState()`:

```dart
_pulseAnimationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 800), // Faster pulse
)..repeat(reverse: true);
```

### Change Neon Colors
The screen automatically uses `theme.colorScheme.primary` from your dynamic theme. To override:

```dart
// In _buildRemoteVideoTile or _buildLocalVideoTile
border: Border.all(
  color: const Color(0xFF00F5FF), // Cyan neon
  width: 2,
),
```

## Example: Complete Integration

```dart
// lib/squad_tab/squad_screen.dart

import 'package:flutter/material.dart';
import '../screens/video_room_screen.dart';
import '../models/squad.dart';

class SquadScreen extends StatelessWidget {
  final Squad squad;

  const SquadScreen({super.key, required this.squad});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(squad.name),
        actions: [
          // Voice call button
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _startVoiceCall(context),
          ),
          
          // Video call button (NEON VOID style)
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _startVideoCall(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Squad info, members, etc.
          // ...
          
          // Quick action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_call),
                    label: const Text('Start Video Chat'),
                    onPressed: () => _startVideoCall(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startVideoCall(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoRoomScreen(
          roomId: 'squad_${squad.id}',
          roomName: '${squad.name} Video',
        ),
      ),
    );
  }

  void _startVoiceCall(BuildContext context) {
    // Use VoiceService for audio-only
    // Navigator.push(context, MaterialPageRoute(...));
  }
}
```

## Performance Notes

1. **Virtual Background**: CPU intensive, auto-enabled but can be disabled
2. **Beauty Filter**: Moderate CPU usage, off by default
3. **Grid Layout**: Optimized for 1-9 participants
4. **Animations**: Hardware-accelerated for smooth 60fps

## Troubleshooting

### Issue: Black Screen
**Solution**: Ensure camera permission granted and `enableVideo()` called

### Issue: No Video Shows
**Solution**: Check Agora App ID in `.env` and backend token endpoint running

### Issue: Lag/Stuttering  
**Solution**: Disable beauty filter, reduce to audio-only on poor network

### Issue: Can't Hear Audio
**Solution**: Verify microphone permission and not muted locally

## Advanced: Screen Share

To add screen sharing (future enhancement):

```dart
// In control bar, add screen share button
_buildControlButton(
  theme: theme,
  icon: Icons.screen_share,
  label: 'Share',
  isActive: state.isSharingScreen,
  onPressed: () => notifier.toggleScreenShare(),
),
```

## Summary

The `VideoRoomScreen` is a complete, production-ready video chat interface that:
- ✅ Matches NEON VOID aesthetic perfectly
- ✅ Handles 1-9 participants with adaptive layouts
- ✅ Includes all controls (mute, camera, effects, leave)
- ✅ Shows live speaking indicators with neon pulse effects
- ✅ Supports virtual backgrounds and beauty filters
- ✅ Provides floating PiP for large calls
- ✅ Uses glassmorphic UI throughout
- ✅ Integrates seamlessly with VideoService

Just pass a `roomId` and `roomName` to launch! 🚀
