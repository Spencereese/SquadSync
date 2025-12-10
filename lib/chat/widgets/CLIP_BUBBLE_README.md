# ClipMessageBubble - NEON VOID Style

## Overview

The `ClipMessageBubble` widget provides a stunning, glassmorphic clip display with NEON VOID aesthetic for SquadSync. It features:

- **Glassmorphic card** with frosted blur effect and neon borders
- **CachedNetworkImage** thumbnail with dark overlay
- **Pulsing play icon** at center (animated with flutter_animate)
- **Duration badge** in bottom left
- **Hype button** with 🔥 count in bottom right
- **Upload progress** overlay for pending clips
- **Full-screen player** on tap with video controls

## Features

### Visual Design
- Large 280x400 glassmorphic card
- Game-specific neon border colors (or default cyan)
- Gradient overlays for readability
- Neon glow shadows
- Smooth hover/press animations

### Interactions
- **Tap**: Opens full-screen `ClipPlayerScreen` and increments view count
- **Hype button tap**: Toggles hype reaction (adds/removes user UID)
- **Uploading state**: Shows progress circle with "Uploading..." text

### Animations
- Pulsing play button (1.2s loop with scale animation)
- Hype button pulse when active
- Scale down on press (0.98x)
- Smooth fade-in/out for overlays

## Usage

### Basic Integration

```dart
import 'package:squad_sync/chat/widgets/clip_message_bubble.dart';

// In your message list builder
if (messageData.type == MessageType.clip) {
  return ClipMessageBubble(
    messageData: messageData,
    isMe: isMe,
    chatGroupId: chatGroupId,
    chatType: chatType,
    gameColor: const Color(0xFF00FF00), // Optional: game-specific neon color
  );
}
```

### With Dynamic Game Colors

```dart
import 'package:squad_sync/chat/widgets/clip_message_bubble.dart';

Color getGameNeonColor(String? gameName) {
  switch (gameName) {
    case 'Call of Duty':
      return const Color(0xFF00FF00); // Green
    case 'Fortnite':
      return const Color(0xFFFF00FF); // Magenta
    case 'Apex Legends':
      return const Color(0xFFFF0000); // Red
    case 'Warzone':
      return const Color(0xFFFFFF00); // Yellow
    default:
      return const Color(0xFF00FFFF); // Cyan
  }
}

// In your message builder
ClipMessageBubble(
  messageData: messageData,
  isMe: isMe,
  chatGroupId: chatGroupId,
  chatType: chatType,
  gameColor: getGameNeonColor(currentGame?.name),
)
```

### Sending a Clip

```dart
import 'package:squad_sync/presentation/notifiers/chat_notifier.dart';

Future<void> sendClipMessage(
  WidgetRef ref,
  String videoFilePath,
  String chatGroupId,
  ChatType chatType,
) async {
  await ref.read(chatNotifierProvider.notifier).sendMessage(
    chatGroupId: chatGroupId,
    chatType: chatType,
    content: 'Check out this clip! 🎮',
    messageType: MessageType.clip,
    clipFilePath: videoFilePath,
    onUploadProgress: (progress) {
      print('Upload: ${(progress * 100).toStringAsFixed(1)}%');
    },
  );
}
```

## ClipPlayerScreen

Full-screen video player with NEON VOID styling that opens when tapping a clip.

### Features
- **Video playback** with video_player
- **Play/pause controls** with neon-styled buttons
- **Progress bar** with scrubbing
- **View count** display
- **Hype button** (same functionality as bubble)
- **Sender info** at top
- **Close button** to return to chat
- **Immersive mode** (hides system UI)
- **Auto-hide controls** (tap to toggle)

### Layout
```
┌─────────────────────────────┐
│ [X] Sender Name        🔥 5 │ ← Top bar (glassmorphic)
│     123 views              │
│                            │
│                            │
│         [▶/⏸]             │ ← Center play/pause (pulsing neon)
│                            │
│                            │
│ ━━━━━━━━━━━━━━━━━━━━━━━  │ ← Progress bar (neon)
│ 0:15 / 1:23               │ ← Time indicator
└─────────────────────────────┘
```

## Components Breakdown

### ClipMessageBubble Structure

```
Stack:
  ├─ Glassmorphic Card Container
  │  ├─ CachedNetworkImage (thumbnail)
  │  ├─ Dark overlay gradient
  │  └─ BackdropFilter (blur)
  │
  ├─ Top Gradient (for sender name visibility)
  ├─ Bottom Gradient (for badges visibility)
  │
  └─ Content Overlay
     ├─ Sender name (if not me)
     ├─ Pulsing Play Button (center)
     └─ Bottom Row
        ├─ Duration Badge (left)
        └─ Hype Button (right)
```

### State Management

The widget uses Riverpod to:
- Increment view count when clip is tapped
- Toggle hype reactions
- Access current user UID

### Data Flow

```
User taps clip
    ↓
Increment view count (Firestore atomic increment)
    ↓
Navigate to ClipPlayerScreen
    ↓
Video loads and plays
    ↓
User can hype/unhype
    ↓
Close returns to chat
```

## Styling Constants

### Colors
- **Default Neon**: `Color(0xFF00FFFF)` (Cyan)
- **Glass Background**: `Colors.white.withOpacity(0.05)`
- **Dark Overlay**: `Colors.black.withOpacity(0.7)`
- **Border Opacity**: `0.5`

### Dimensions
- **Card Size**: 280 x 400
- **Border Radius**: 24
- **Border Width**: 2
- **Play Button**: 80 x 80
- **Badge Padding**: 12h x 6v
- **Neon Glow Blur**: 20
- **Shadow Blur**: 10

### Animations
- **Pulse Duration**: 1200ms (600ms up, 600ms down)
- **Press Scale**: 0.98x
- **Hype Scale**: 1.2x
- **Transition Duration**: 100-200ms
- **Fade Duration**: 200ms

## Dependencies

Required packages (already in pubspec.yaml):
```yaml
dependencies:
  flutter_animate: ^4.5.0
  cached_network_image: ^3.4.1
  video_player: ^2.9.2
  flutter_riverpod: ^2.6.1
  firebase_auth: (existing)
  cloud_firestore: (existing)
```

## File Structure

```
lib/chat/widgets/
├─ clip_message_bubble.dart      # Main clip bubble widget
├─ clip_player_screen.dart       # Full-screen player
└─ clip_integration_example.dart # Usage examples
```

## Error Handling

### Thumbnail Loading
- Shows loading spinner while thumbnail loads
- Shows fallback icon (`Icons.videocam_off`) on error
- Uses `CachedNetworkImage` for performance

### Video Playback
- Shows loading state during initialization
- Displays error screen with "Go Back" button on failure
- Logs errors to debug console

### Upload State
- Shows "Uploading..." overlay during send
- Progress tracked via `MessageStatus.sending`
- Blocks tap interactions until complete

## Performance Considerations

1. **Lazy Loading**: Thumbnails cached by `CachedNetworkImage`
2. **Atomic Updates**: View count uses `FieldValue.increment(1)`
3. **Optimistic UI**: Hype toggles immediately, syncs with Firestore
4. **Animations**: Uses hardware-accelerated transforms
5. **Video Disposal**: Controller disposed properly in `dispose()`

## Accessibility

- Semantic labels for screen readers
- High contrast neon borders
- Large tap targets (80x80 for play button)
- Clear visual feedback on interactions

## Troubleshooting

### Clip not showing
- Check `messageData.type == MessageType.clip`
- Verify `clipData` is not null
- Ensure thumbnail URL is valid

### Video won't play
- Check video URL is accessible
- Verify video format is supported (MP4, WebM)
- Check network connectivity
- Review console for error logs

### Views not incrementing
- Verify user is authenticated
- Check Firestore collection paths match `ChatType`
- Ensure message document exists

### Hype not working
- Verify Firebase Auth user is available
- Check `hypeReactions` array structure
- Ensure Firestore security rules allow updates

## Future Enhancements

Potential additions:
- [ ] Pinch-to-zoom in player
- [ ] Double-tap to hype
- [ ] Share clip externally
- [ ] Download clip option
- [ ] Trim/edit before sending
- [ ] Multiple hype reactions (not just 🔥)
- [ ] Comment threads on clips
- [ ] Trending clips view
- [ ] Clip playlists

## Credits

Built for **SquadSync** with NEON VOID aesthetic inspired by modern gaming UIs.
