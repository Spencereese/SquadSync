# ClipService Chat Integration Guide

## Quick Start: Add Clip Upload to Chat

### 1. Extend ChatMediaHandler

Add clip upload method to `lib/chat/services/chat_media_handler.dart`:

```dart
import 'package:squad_sync/services/clip_service.dart';

class ChatMediaHandler {
  // Existing fields...
  final ClipService _clipService = ClipService();

  /// Pick and send a gaming clip
  Future<void> sendClip(
    WidgetRef ref, {
    required String? chatGroupId,
    required ChatType chatType,
  }) async {
    try {
      // Pick video from gallery
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 2),
      );

      if (video == null) return;

      ref.read(chatStateProvider.notifier).setUploading(true);

      final user = _auth.currentUser;
      if (user == null) return;

      // Process the clip
      final clipData = await _clipService.processClip(
        video.path,
        onProgress: (progress) {
          // Update progress in chat state
          ref.read(chatStateProvider.notifier).setUploadProgress(progress);
        },
      );

      final timestampMs = DateTime.now().millisecondsSinceEpoch;

      // Send message with clip
      await _chatService.sendMessage(
        ref,
        senderUid: user.uid,
        text: '', // Optional: Add caption
        videos: [
          {
            'uri': clipData.videoUrl,
            'thumbnail': clipData.thumbUrl,
            'duration': clipData.duration,
            'width': clipData.width,
            'height': clipData.height,
            'clipId': clipData.clipId,
            'creation_timestamp': timestampMs,
          }
        ],
        chatGroupId: chatGroupId,
        chatType: chatType,
      );

      ref.read(chatStateProvider.notifier).setUploading(false);
      HapticFeedback.lightImpact();
    } on ClipProcessingException catch (e) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        SnackBar(content: Text('Clip upload failed: ${e.message}')),
      );
      ref.read(chatStateProvider.notifier).setUploading(false);
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _clipService.dispose();
  }
}
```

### 2. Add Clip Button to Chat UI

In `lib/chat/chat_screen.dart`, add a clip button next to media button:

```dart
// In _buildMessageInputActions() or similar
IconButton(
  icon: const Icon(Icons.movie),
  tooltip: 'Send Gaming Clip',
  onPressed: () async {
    final mediaHandler = ChatMediaHandler();
    await mediaHandler.sendClip(
      ref,
      chatGroupId: widget.chatGroupId,
      chatType: widget.chatType,
    );
    mediaHandler.dispose();
  },
),
```

### 3. Add Progress State to ChatState

Extend `lib/chat/chat_state_notifier.dart`:

```dart
class ChatState {
  // Existing fields...
  final double uploadProgress;

  ChatState({
    // Existing parameters...
    this.uploadProgress = 0.0,
  });

  ChatState copyWith({
    // Existing parameters...
    double? uploadProgress,
  }) {
    return ChatState(
      // Existing fields...
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

class ChatStateNotifier extends StateNotifier<ChatState> {
  // Existing code...

  void setUploadProgress(double progress) {
    state = state.copyWith(uploadProgress: progress);
  }
}
```

### 4. Display Progress in UI

Add progress indicator to chat screen:

```dart
// In ChatScreen build method
if (chatState.isUploading && chatState.uploadProgress > 0)
  Container(
    padding: const EdgeInsets.all(8),
    color: Colors.blue.withValues(alpha: 0.1),
    child: Column(
      children: [
        Text('Uploading clip: ${(chatState.uploadProgress * 100).toStringAsFixed(0)}%'),
        LinearProgressIndicator(value: chatState.uploadProgress),
      ],
    ),
  ),
```

### 5. Update Message Model (Optional)

If you want to track clip metadata separately:

```dart
// In Message entity or MessageData model
class Message {
  // Existing fields...
  final String? clipId;
  final String? clipThumbnail;
  final int? clipDuration;
  final int? clipWidth;
  final int? clipHeight;

  Message({
    // Existing parameters...
    this.clipId,
    this.clipThumbnail,
    this.clipDuration,
    this.clipWidth,
    this.clipHeight,
  });
}
```

## Advanced: Squad Feed Integration

### Post Clips to Squad Feed

```dart
// In squad_tab or similar
Future<void> postClipToFeed(String videoPath) async {
  final clipService = ClipService();
  
  try {
    final clipData = await clipService.processClip(
      videoPath,
      onProgress: (progress) {
        // Update UI progress
      },
    );

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('squads')
        .doc(squadId)
        .collection('feed')
        .add({
          'type': 'clip',
          'userId': user.uid,
          'clipId': clipData.clipId,
          'videoUrl': clipData.videoUrl,
          'thumbUrl': clipData.thumbUrl,
          'duration': clipData.duration,
          'width': clipData.width,
          'height': clipData.height,
          'timestamp': FieldValue.serverTimestamp(),
          'likes': 0,
          'comments': 0,
        });
  } finally {
    clipService.dispose();
  }
}
```

### Display Clips in Feed

```dart
// Feed item widget for clips
class ClipFeedItem extends StatelessWidget {
  final Map<String, dynamic> clipData;

  const ClipFeedItem({required this.clipData});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with play button
          Stack(
            alignment: Alignment.center,
            children: [
              Image.network(
                clipData['thumbUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${(clipData['duration'] / 1000).toStringAsFixed(0)}s',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          // User info and actions
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // User avatar
                // Like button
                // Comment button
                // Share button
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

## Testing Integration

### Unit Test Example

```dart
// test/chat_clip_integration_test.dart
void main() {
  group('Clip Upload Integration', () {
    testWidgets('should upload clip and send message', (tester) async {
      // Setup mocks
      final mockClipService = MockClipService();
      final mockChatService = MockChatService();
      
      when(mockClipService.processClip(any, onProgress: anyNamed('onProgress')))
          .thenAnswer((_) async => ClipData(
                videoUrl: 'https://example.com/clip.mp4',
                thumbUrl: 'https://example.com/thumb.jpg',
                duration: 30000,
                width: 1280,
                height: 720,
                clipId: 'test-clip',
              ));

      // Test upload flow
      // Verify message sent with clip data
    });
  });
}
```

## Performance Tips

1. **Background Processing**: Consider using `compute()` for heavy processing
2. **Cancellation**: Always implement cancel functionality for long uploads
3. **Retry Logic**: Add retry for failed uploads with exponential backoff
4. **Cleanup**: Delete temporary files after successful upload
5. **Compression Queue**: Limit concurrent clip processing to 1-2 at a time

## Security Considerations

### Firebase Storage Rules

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /clips/{clipId} {
      // Only authenticated users can upload
      allow write: if request.auth != null 
                   && request.resource.size < 50 * 1024 * 1024  // 50 MB
                   && request.resource.contentType.matches('video/.*');
      
      // Anyone can read
      allow read: if true;
    }
  }
}
```

### Firestore Rules for Clip Metadata

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /clips/{clipId} {
      allow create: if request.auth != null
                    && request.resource.data.userId == request.auth.uid;
      allow read: if true;
      allow delete: if request.auth != null
                    && resource.data.userId == request.auth.uid;
    }
  }
}
```

## Troubleshooting

### Issue: Progress callbacks not updating UI
**Solution**: Ensure you're using `setState()` or state management update methods

### Issue: Clips taking too long to upload
**Solution**: Check network connection, reduce quality settings, or implement chunked uploads

### Issue: Memory issues on low-end devices
**Solution**: Process clips one at a time, add memory monitoring, clear cache more frequently

### Issue: Thumbnails not generating
**Solution**: Verify video format is supported, check video duration > 0, ensure video_compress permissions

## Next Steps

1. Add clip analytics (views, shares, likes)
2. Implement clip highlights/best moments detection
3. Add filters and effects to clips
4. Create clip compilation features
5. Integrate with game-specific APIs for automatic clip capture
