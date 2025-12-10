# ClipPlayerScreen - Enhanced Full-Screen Experience

## 🎬 Overview

The enhanced `ClipPlayerScreen` is a comprehensive full-screen video player with **NEON VOID styling** that includes:

- ✅ **Video playback** with custom neon controls
- ✅ **Top bar** with username, game badge, timestamp, and share
- ✅ **Big Hype button** with Riverpod state management
- ✅ **Threaded comment section** with replies
- ✅ **Share functionality** via deep links
- ✅ **Auto-play next clip** from squad
- ✅ **View count increment** on open
- ✅ **Landscape mode** support
- ✅ **Haptic feedback** for interactions

## 🎨 Features Breakdown

### 1. Custom Neon Video Controls

- **Play/Pause button**: 80x80 neon circle that glows in game color
- **Progress bar**: Neon-colored with scrubbing support
- **Time display**: Current / Total duration
- **Tap to toggle**: Controls auto-hide

```dart
GestureDetector(
  onTap: () => setState(() => _showControls = !_showControls),
  child: VideoPlayer(_controller),
)
```

### 2. Top Bar with User Info

```
┌──────────────────────────────────────┐
│ [X] Username  [🎮 SQUAD]  [Share]   │
│     127 views • 2h ago               │
└──────────────────────────────────────┘
```

- **Close button**: Neon circle with X icon
- **Username**: Bold white text
- **Game badge**: Neon border with gamepad icon
- **Timestamp**: Relative time (e.g., "2h ago")
- **View count**: Updates from Firestore
- **Share button**: Opens system share sheet

### 3. Big Hype Button 🔥

```dart
┌────────────────────────────────────┐
│  🔥  HYPE THIS CLIP  [5]          │ ← Not hyped
│  🔥  HYPED!  [6]                  │ ← Hyped (neon glow)
└────────────────────────────────────┘
```

**Features:**
- Full-width button with gradient background
- Animates on tap (bounce effect)
- Shows hype count badge
- Neon border and glow when hyped
- Riverpod integration for real-time updates
- Haptic feedback (heavy impact)

**Implementation:**
```dart
GestureDetector(
  onTap: _handleHypeTap,
  child: AnimatedBuilder(
    animation: _hypeAnimationController,
    builder: (context, child) {
      final scale = 1.0 + (_hypeAnimationController.value * 0.2) * 
                    (1 - _hypeAnimationController.value);
      return Transform.scale(scale: scale, child: ...);
    },
  ),
)
```

### 4. Threaded Comment Section

```
┌─────────────────────────────────────┐
│ 💬 Comments                          │
├─────────────────────────────────────┤
│ [A] Alice • 5m                      │
│     This clip is fire! 🔥           │
│     Reply                           │
│                                     │
│     [B] Bob • 2m                    │ ← Threaded reply
│         Agreed!                     │
├─────────────────────────────────────┤
│ [Add a comment...] [Send]          │
└─────────────────────────────────────┘
```

**Features:**
- Threaded replies (parent → child)
- Avatar with first letter of username
- Relative timestamps (5m, 2h, 3d)
- "Reply" button on top-level comments
- Real-time updates via Riverpod StreamProvider
- Empty state with "Be the first to comment!"

**Data Model:**
```dart
class ClipComment {
  final String id;
  final String clipMessageId;
  final String authorUid;
  final String authorName;
  final String text;
  final DateTime timestamp;
  final String? parentCommentId; // For threading
}
```

**Firestore Structure:**
```json
{
  "clip_comments/{commentId}": {
    "clipMessageId": "msg_123",
    "authorUid": "uid_456",
    "authorName": "Alice",
    "text": "This clip is fire!",
    "timestamp": Timestamp,
    "parentCommentId": null // or parent comment ID
  }
}
```

### 5. Share Functionality

```dart
Future<void> _shareClip() async {
  final clipLink = 'codsquadapp://clip/$chatGroupId/$messageId';
  await Share.share(
    'Check out this clip from ${sender}!\n$clipLink',
    subject: 'SquadSync Clip',
  );
}
```

**Share Options:**
- System share sheet (iOS/Android)
- Deep link to clip: `codsquadapp://clip/{groupId}/{messageId}`
- Includes sender name in share text
- Haptic feedback on share

**Deep Link Handling:**
To handle incoming deep links, add to `main.dart`:

```dart
// In your app initialization
void _handleDeepLink(Uri uri) {
  if (uri.pathSegments[0] == 'clip') {
    final chatGroupId = uri.pathSegments[1];
    final messageId = uri.pathSegments[2];
    
    // Navigate to ClipPlayerScreen
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => ClipPlayerScreen(...),
    ));
  }
}
```

### 6. Auto-Play Next Clip

**Feature:**
When a clip finishes, automatically loads and plays the next clip in the squad.

**Implementation:**
```dart
void _videoListener() {
  if (_controller.value.position >= _controller.value.duration) {
    _playNextClip();
  }
}

void _playNextClip() {
  final currentIndex = squadClips!.indexWhere(
    (clip) => clip.id == messageData.id,
  );
  
  if (currentIndex < squadClips!.length - 1) {
    final nextClip = squadClips![currentIndex + 1];
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (context) => ClipPlayerScreen(
        clipData: nextClip.clipData!,
        messageData: nextClip,
        squadClips: squadClips, // Pass through
      ),
    ));
  }
}
```

**Usage:**
Pass all squad clips when opening player:

```dart
// Get all clip messages in squad
final squadClips = messages.where((m) => m.type == MessageType.clip).toList();

// Open player with auto-play list
ClipPlayerScreen(
  clipData: selectedClip.clipData!,
  messageData: selectedClip,
  squadClips: squadClips, // Enable auto-play
)
```

### 7. View Count Increment

**Automatic on Open:**
```dart
@override
void initState() {
  super.initState();
  _incrementViewCount(); // Called immediately
}

Future<void> _incrementViewCount() async {
  await ref.read(chatNotifierProvider.notifier).incrementClipViews(
    chatGroupId,
    messageId,
    chatType,
  );
}
```

**Firestore Update:**
```dart
await FirebaseFirestore.instance
  .collection(collectionPath)
  .doc(messageId)
  .update({
    'clipData.views': FieldValue.increment(1), // Atomic
  });
```

**Display:**
- Top bar shows live view count
- Updates in real-time via StreamBuilder
- Atomic increment prevents race conditions

### 8. Landscape Mode Support

**Orientation Handling:**
```dart
@override
void initState() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
}

@override
void dispose() {
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
}
```

**Landscape Layout:**
- Full-screen video
- Overlay controls (top bar + progress bar)
- No comments in landscape (portrait only)
- Auto-hide controls on tap

## 🎮 Riverpod Integration

### 1. Clip Comments Provider

```dart
final clipCommentsProvider = StreamProvider.family<List<ClipComment>, String>(
  (ref, clipMessageId) {
    return FirebaseFirestore.instance
      .collection('clip_comments')
      .where('clipMessageId', isEqualTo: clipMessageId)
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ClipComment.fromFirestore(doc))
          .toList());
  },
);
```

**Usage:**
```dart
final commentsAsync = ref.watch(clipCommentsProvider(messageId));

commentsAsync.when(
  data: (comments) => CommentsList(comments),
  loading: () => CircularProgressIndicator(),
  error: (e, st) => ErrorWidget(),
)
```

### 2. Hype Reactions

```dart
// Toggle hype
await ref.read(chatNotifierProvider.notifier).toggleClipHype(
  chatGroupId,
  messageId,
  chatType,
);

// Firestore automatically triggers StreamBuilder update
// UI rebuilds with new hypeReactions list
```

## 🎯 Complete Flow

```
User taps clip bubble
    ↓
Navigate to ClipPlayerScreen
    ↓
incrementViewCount() → views++
    ↓
Video auto-plays
    ↓
User can:
  ├─ Play/Pause video
  ├─ Scrub timeline
  ├─ Hype the clip → toggleClipHype()
  ├─ View/post comments → Firestore
  ├─ Reply to comments → threaded
  ├─ Share clip → deep link
  └─ Watch next clip → auto-play
    ↓
Video finishes → _playNextClip()
    ↓
Load next clip in squad (if available)
```

## 📁 File Structure

```
lib/chat/widgets/
├─ clip_player_screen.dart       ← Full-screen player (1000+ lines)
│  ├─ ClipComment model
│  ├─ clipCommentsProvider
│  ├─ ClipPlayerScreen widget
│  ├─ Video player with controls
│  ├─ Hype button logic
│  ├─ Comment section
│  └─ Auto-play next
│
├─ clip_message_bubble.dart      ← Bubble in chat (456 lines)
│  └─ Passes squadClips to player
│
└─ CLIP_PLAYER_README.md         ← This file
```

## 🚀 Usage Examples

### Basic Usage

```dart
ClipPlayerScreen(
  clipData: message.clipData!,
  messageData: message,
  chatGroupId: 'squad_123',
  chatType: ChatType.squad,
  gameColor: Color(0xFF00FF00), // Green neon
)
```

### With Auto-Play

```dart
// Get all clips from chat
final allClips = messages
  .where((m) => m.type == MessageType.clip)
  .toList();

ClipPlayerScreen(
  clipData: selectedClip.clipData!,
  messageData: selectedClip,
  chatGroupId: chatGroupId,
  chatType: chatType,
  gameColor: gameColor,
  squadClips: allClips, // Enable auto-play
)
```

### From ClipMessageBubble

```dart
ClipMessageBubble(
  messageData: message,
  isMe: isMe,
  chatGroupId: chatGroupId,
  chatType: chatType,
  gameColor: getGameColor(currentGame),
  squadClips: allSquadClips, // Pass for auto-play
)
```

## 🎨 Styling

### Neon Colors

```dart
final neonColor = gameColor ?? Color(0xFF00FFFF); // Cyan default

// Applied to:
- Play button border and icon
- Progress bar
- Hype button (when active)
- Comment input border (focused)
- Share button icon
- Game badge
```

### Animations

| Element | Animation | Duration |
|---------|-----------|----------|
| Play button | Scale on tap | 200ms |
| Hype button | Bounce on tap | 600ms |
| Controls | Fade in/out | 200ms |
| Comment send | Pulse | Instant |

### Layout Dimensions

| Element | Size |
|---------|------|
| Play button | 80 x 80 |
| Top bar padding | 16px all |
| Hype button height | ~60px |
| Comment avatar | 32px (28px for replies) |
| Share button | 36 x 36 |

## 🔧 Dependencies

All required packages already in `pubspec.yaml`:

```yaml
dependencies:
  video_player: ^2.9.2      # Video playback
  share_plus: ^12.0.0       # Share functionality
  intl: ^0.20.2             # Date formatting
  flutter_animate: ^4.5.0   # Animations
  flutter_riverpod: ^2.6.1  # State management
  firebase_auth: (existing)
  cloud_firestore: (existing)
```

## ⚡ Performance

- **View increment**: Atomic operation (O(1))
- **Comment loading**: Streamed from Firestore
- **Video buffering**: Handled by video_player
- **Memory**: Controller disposed properly
- **Orientation locks**: Reset on dispose

## 🐛 Error Handling

### Video Load Failure

```dart
if (_isError) {
  return ErrorScreen(
    icon: Icons.error_outline,
    message: 'Failed to load clip',
    action: ElevatedButton(
      onPressed: () => Navigator.pop(),
      child: Text('Go Back'),
    ),
  );
}
```

### Comment Post Failure

```dart
try {
  await FirebaseFirestore.instance
    .collection('clip_comments')
    .add(comment.toMap());
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Failed to post comment')),
  );
}
```

## 🎯 Next Steps

1. **Get game name dynamically** - Replace "SQUAD" badge with actual game
2. **Add reaction types** - Beyond just 🔥 hype
3. **Download clips** - Save to device
4. **Edit clips** - Trim before sharing
5. **Clip playlists** - Create collections
6. **Stats tracking** - Analytics for popular clips

## 📊 Firestore Security Rules

```javascript
// Allow reading comments
match /clip_comments/{commentId} {
  allow read: if request.auth != null;
  
  // Allow writing if authenticated and author matches
  allow create: if request.auth != null && 
                request.resource.data.authorUid == request.auth.uid;
  
  // Allow updating/deleting own comments
  allow update, delete: if request.auth != null && 
                         resource.data.authorUid == request.auth.uid;
}
```

## 🎉 Summary

You now have a **complete, production-ready** full-screen clip player with:

✅ Custom neon video controls  
✅ User info + game badge + timestamp  
✅ Big Hype button with Riverpod  
✅ Threaded comment section  
✅ Share via deep links  
✅ Auto-play next clip  
✅ View count tracking  
✅ Landscape mode support  
✅ Haptic feedback  
✅ Error handling  
✅ Real-time updates  

**Ready to integrate!** 🚀🔥
