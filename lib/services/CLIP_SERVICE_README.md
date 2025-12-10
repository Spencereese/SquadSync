# ClipService for SquadSync

## Overview
The `ClipService` provides comprehensive video processing capabilities for gaming clips in SquadSync. It handles video compression, trimming, thumbnail generation, and Firebase Storage uploads with progress tracking.

## Features

### 🎥 Video Processing
- **Automatic Compression**: Reduces video size while maintaining quality (max 720p, 30fps)
- **Smart Trimming**: Automatically trims videos longer than 30 seconds to keep the last 30 seconds
- **Thumbnail Generation**: Creates thumbnails at the 50% mark for optimal preview
- **Progress Tracking**: Real-time upload progress callbacks

### 🔒 Security & Error Handling
- **Authentication Required**: Ensures only authenticated users can upload clips
- **Null-Safe**: Fully null-safe implementation
- **Custom Exceptions**: Granular error handling with specific exception types
- **Automatic Cleanup**: Temporary files are cleaned up after processing

### ☁️ Firebase Storage Integration
- **Organized Structure**: Clips stored in `clips/` directory
- **Consistent Naming**: Format: `clips/{clipId}.mp4` and `clips/{clipId}_thumb.jpg`
- **Download URLs**: Returns public download URLs for immediate use

## Installation

### Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  uuid: ^4.4.2
  firebase_storage: ^13.0.2
  firebase_auth: ^6.1.0
  logger: ^2.6.2
  video_compress: ^3.1.2
  path: ^1.8.3
```

### Import
```dart
import 'package:squad_sync/services/clip_service.dart';
```

## Usage

### Basic Usage

```dart
final clipService = ClipService();

try {
  final clipData = await clipService.processClip(
    videoFilePath,
    onProgress: (progress) {
      print('Upload progress: ${(progress * 100).toStringAsFixed(1)}%');
    },
  );

  print('Video URL: ${clipData.videoUrl}');
  print('Thumbnail URL: ${clipData.thumbUrl}');
  print('Duration: ${clipData.duration}ms');
  print('Resolution: ${clipData.width}x${clipData.height}');
} on ClipProcessingException catch (e) {
  print('Failed to process clip: $e');
}
```

### With Progress UI

```dart
class ClipUploadWidget extends StatefulWidget {
  final String videoPath;
  
  @override
  _ClipUploadWidgetState createState() => _ClipUploadWidgetState();
}

class _ClipUploadWidgetState extends State<ClipUploadWidget> {
  final ClipService _clipService = ClipService();
  double _progress = 0.0;
  bool _isProcessing = false;
  String? _errorMessage;
  ClipData? _result;

  Future<void> _uploadClip() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      final clipData = await _clipService.processClip(
        widget.videoPath,
        onProgress: (progress) {
          setState(() {
            _progress = progress;
          });
        },
      );

      setState(() {
        _result = clipData;
        _isProcessing = false;
      });
    } on ClipProcessingException catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_isProcessing) ...[
          LinearProgressIndicator(value: _progress),
          Text('${(_progress * 100).toStringAsFixed(0)}%'),
        ],
        if (_errorMessage != null)
          Text('Error: $_errorMessage', style: TextStyle(color: Colors.red)),
        if (_result != null)
          Text('Upload complete! Clip ID: ${_result!.clipId}'),
        ElevatedButton(
          onPressed: _isProcessing ? null : _uploadClip,
          child: Text('Upload Clip'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _clipService.dispose();
    super.dispose();
  }
}
```

### Cancelling Processing

```dart
final clipService = ClipService();

// Start processing
final processingFuture = clipService.processClip(videoPath);

// Cancel if needed
await clipService.cancelProcessing();
```

### Deleting Clips

```dart
final clipService = ClipService();

try {
  await clipService.deleteClip('clip-id-123');
  print('Clip deleted successfully');
} on ClipProcessingException catch (e) {
  print('Failed to delete clip: $e');
}
```

## API Reference

### ClipService

#### Methods

##### `processClip(String filePath, {Function(double)? onProgress})`
Main method to process and upload a video clip.

**Parameters:**
- `filePath` (String): Path to the video file
- `onProgress` (Function(double)?): Optional callback for progress updates (0.0 to 1.0)

**Returns:** `Future<ClipData>`

**Throws:**
- `ClipProcessingException`: Generic processing error
- `ClipCompressionException`: Video compression failed
- `ClipThumbnailException`: Thumbnail generation failed
- `ClipUploadException`: Firebase Storage upload failed

**Process Flow:**
1. Get video information (10% progress)
2. Trim if > 30 seconds (30% progress)
3. Compress to max 720p, 30fps (50% progress)
4. Generate thumbnail at 50% mark (60% progress)
5. Upload video to Firebase Storage (80% progress)
6. Upload thumbnail to Firebase Storage (95% progress)
7. Return ClipData with URLs and metadata (100% progress)

##### `deleteClip(String clipId)`
Delete a clip and its thumbnail from Firebase Storage.

**Parameters:**
- `clipId` (String): The clip ID to delete

**Returns:** `Future<void>`

##### `cancelProcessing()`
Cancel ongoing video compression.

**Returns:** `Future<void>`

##### `getCompressionProgress()`
Get a stream of compression progress events.

**Returns:** `Stream<dynamic>`

##### `dispose()`
Cleanup resources. Call when done using the service.

**Returns:** `void`

### ClipData

Data model containing processed clip information.

**Properties:**
- `videoUrl` (String): Firebase Storage download URL for video
- `thumbUrl` (String): Firebase Storage download URL for thumbnail
- `duration` (int): Video duration in milliseconds
- `width` (int): Video width in pixels
- `height` (int): Video height in pixels
- `clipId` (String): Unique identifier for the clip

**Methods:**
- `toJson()`: Convert to JSON map
- `ClipData.fromJson(Map<String, dynamic>)`: Create from JSON map

## Configuration

### Constants

```dart
static const int maxDurationSeconds = 30;        // Maximum clip duration
static const int maxResolutionHeight = 720;      // Max vertical resolution
static const int targetFrameRate = 30;           // Target FPS
static const int targetBitrate = 2000000;        // Target bitrate (2 Mbps)
```

### Firebase Storage Paths

- Videos: `clips/{clipId}.mp4`
- Thumbnails: `clips/{clipId}_thumb.jpg`

## Exception Hierarchy

```
ClipProcessingException (base)
├── ClipCompressionException
├── ClipThumbnailException
└── ClipUploadException
```

All exceptions include:
- `message` (String): Human-readable error message
- `originalError` (dynamic?): Optional original error for debugging

## Best Practices

### 1. Always Handle Errors
```dart
try {
  final clip = await clipService.processClip(path);
} on ClipCompressionException catch (e) {
  // Handle compression errors
} on ClipUploadException catch (e) {
  // Handle upload errors
} on ClipProcessingException catch (e) {
  // Handle general errors
}
```

### 2. Provide User Feedback
```dart
await clipService.processClip(
  path,
  onProgress: (progress) {
    // Update UI with progress
    setState(() => _uploadProgress = progress);
  },
);
```

### 3. Cleanup Resources
```dart
@override
void dispose() {
  _clipService.dispose();
  super.dispose();
}
```

### 4. Cancel Long Operations
```dart
// User navigates away
@override
void deactivate() {
  _clipService.cancelProcessing();
  super.deactivate();
}
```

### 5. Store Clip Metadata
```dart
// Save to Firestore for retrieval
final clipData = await clipService.processClip(path);

await FirebaseFirestore.instance
    .collection('clips')
    .doc(clipData.clipId)
    .set(clipData.toJson());
```

## Integration with SquadSync

### Chat Integration
```dart
// In ChatMediaHandler or similar
Future<void> sendClip(String videoPath, WidgetRef ref) async {
  final clipService = ClipService();
  
  try {
    final clipData = await clipService.processClip(
      videoPath,
      onProgress: (progress) {
        ref.read(chatStateProvider.notifier).setUploadProgress(progress);
      },
    );

    await chatService.sendMessage(
      ref,
      senderUid: user.uid,
      text: 'Check out this clip!',
      videos: [
        {
          'uri': clipData.videoUrl,
          'thumbnail': clipData.thumbUrl,
          'duration': clipData.duration,
          'width': clipData.width,
          'height': clipData.height,
        }
      ],
    );
  } finally {
    clipService.dispose();
  }
}
```

### Squad Feed Integration
```dart
// Post clip to squad feed
final clipData = await clipService.processClip(recordingPath);

await FirebaseFirestore.instance
    .collection('squads')
    .doc(squadId)
    .collection('feed')
    .add({
      'type': 'clip',
      'userId': currentUser.uid,
      'clipId': clipData.clipId,
      'videoUrl': clipData.videoUrl,
      'thumbUrl': clipData.thumbUrl,
      'duration': clipData.duration,
      'timestamp': FieldValue.serverTimestamp(),
    });
```

## Testing

See `test/clip_service_test.dart` for comprehensive test examples.

### Running Tests
```bash
flutter test test/clip_service_test.dart
```

### Generate Mocks
```bash
flutter pub run build_runner build
```

## Performance Considerations

### Video Compression
- Compression time varies based on video length and device performance
- Expect ~2-5 seconds for a 30-second clip on modern devices
- Use background processing for better UX

### Upload Times
- Network speed dependent
- Typical 30s clip (720p, 30fps) = ~10-20 MB
- Progress callback helps manage user expectations

### Memory Usage
- Temporary files are created during processing
- Automatic cleanup prevents memory leaks
- Consider limiting concurrent uploads

## Troubleshooting

### Common Issues

**1. "User must be authenticated to upload clips"**
- Ensure `FirebaseAuth.instance.currentUser` is not null
- Check authentication state before calling `processClip()`

**2. Compression fails on iOS**
- Verify video_compress plugin is properly installed
- Check iOS deployment target is >= 11.0

**3. Thumbnail generation fails**
- Ensure video file is readable
- Check file format is supported (mp4, mov, etc.)

**4. Upload stalls at high percentage**
- Check network connectivity
- Verify Firebase Storage rules allow uploads
- Ensure bucket permissions are correct

### Debug Logging
The service uses the `logger` package. Enable verbose logging:
```dart
Logger.level = Level.debug;
```

## Security Rules

Add to Firebase Storage rules:
```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /clips/{clipId} {
      // Allow authenticated users to upload their own clips
      allow write: if request.auth != null 
                   && request.resource.size < 50 * 1024 * 1024;  // 50 MB limit
      
      // Allow anyone to read clips
      allow read: if true;
    }
  }
}
```

## Future Enhancements

- [ ] Server-side thumbnail generation for better quality
- [ ] AI-powered highlight detection
- [ ] Multiple thumbnail options (beginning, middle, end)
- [ ] Watermark support
- [ ] Batch processing for multiple clips
- [ ] CDN integration for faster delivery
- [ ] Video analytics (views, shares)

## License
Part of the SquadSync project.
