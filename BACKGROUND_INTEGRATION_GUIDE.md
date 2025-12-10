# ChatScreen Background Integration Guide

## ✅ Implementation Complete

ChatScreen now supports dynamic, real-time backgrounds with parallax scrolling!

## Features Implemented

### 1. **StreamBuilder Integration**
- Real-time background updates via `BackgroundService.getCurrentBackground(chatGroupId)`
- Automatic fallback to default `#0B0E14` when no chatGroupId or background set
- Zero-config required - works out of the box

### 2. **Stack Layout with Background Layer**
```dart
Stack(
  children: [
    // Background layer with parallax
    Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, -parallaxOffset),
        child: _buildBackgroundDecoration(background),
      ),
    ),
    // Chat content on top
    GestureDetector(...),
  ],
)
```

### 3. **Supported Background Types**

#### **Solid Color**
```dart
type: 'color' or 'solid'
value: '#0B0E14'  // Hex color string
```

#### **Gradient**
```dart
type: 'gradient'
value: 'gradient:linear:0xFF00F5FF,0xFFFF00FF'  // Linear gradient
value: 'gradient:radial:0xFFFF4500,0xFF8B0000'  // Radial gradient
```

#### **Network Image**
```dart
type: 'image'
value: 'https://example.com/image.jpg'  // Network URL
// Rendered with 0.3 opacity, BoxFit.cover
```

#### **Preset**
```dart
type: 'preset'
value: 'matrix_rain'  // Preset ID from BackgroundService.presets
// Supports: colors, gradients, asset images, network images
```

#### **Game Theme**
```dart
type: 'gameTheme'
// Uses current Material theme colors as gradient
// Integrates with GameThemeController
```

### 4. **Parallax Scrolling Effect**
- Subtle parallax on scroll: `offset = scrollOffset * 0.2`
- Background moves at 20% speed of content scroll
- Creates depth and visual polish
- Automatic based on `_scrollController.offset`

## Usage Examples

### Set a Solid Color Background
```dart
final backgroundService = BackgroundService();
await backgroundService.applyBackground(
  chatGroupId,
  type: 'color',
  value: '#1A0B2E',  // Deep purple
);
```

### Set a Gradient Background
```dart
await backgroundService.applyBackground(
  chatGroupId,
  type: 'gradient',
  value: 'gradient:linear:0xFF00F5FF,0xFFFF00FF',
);
```

### Upload Custom Image
```dart
final imageUrl = await backgroundService.uploadCustomBackground(
  chatGroupId,
  '/path/to/image.jpg',
);
// Automatically applies the image as background
```

### Use a Preset
```dart
await backgroundService.applyPreset(chatGroupId, 'matrix_rain');
// Or
await backgroundService.applyPreset(chatGroupId, 'neon_grid');
```

### Remove Background
```dart
await backgroundService.removeBackground(chatGroupId);
// Resets to default #0B0E14
```

## Firestore Data Structure

Backgrounds are stored in `chat_groups/{chatGroupId}`:
```json
{
  "backgroundType": "image",
  "backgroundValue": "https://...",
  "backgroundUpdatedAt": Timestamp,
  "backgroundUpdatedBy": "user_uid"
}
```

## Integration with UI

### Option 1: Add to ChatInfoScreen Settings Tab
```dart
// In ChatInfoScreen backgrounds tab
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BackgroundSelectorScreen(
          chatGroupId: chatGroupId,
          chatName: chatName,
        ),
      ),
    );
  },
  child: Text('Change Background'),
)
```

### Option 2: Quick Background Picker in ChatSettingsMenu
```dart
// Add to ChatSettingsMenu
onBackgroundPicker: () {
  showModalBottomSheet(
    context: context,
    builder: (context) => BackgroundQuickPicker(
      chatGroupId: chatGroupId,
    ),
  );
}
```

## Performance Notes

- **StreamBuilder**: Only rebuilds background layer on changes
- **Parallax**: Uses existing `_scrollController`, no extra listeners
- **Image opacity**: 0.3 ensures chat messages remain readable
- **Caching**: NetworkImage handles image caching automatically
- **Default fallback**: `#0B0E14` solid color for zero latency

## Customization Options

### Adjust Image Opacity
```dart
// In _buildBackgroundDecoration, change:
opacity: 0.3,  // to 0.4 for darker, 0.2 for lighter
```

### Change Parallax Speed
```dart
// In _buildChatContentWithBackground, change:
final parallaxOffset = scrollOffset * 0.2;  // to 0.3 for faster, 0.1 for slower
```

### Add Blur Effect
```dart
// Wrap background in BackdropFilter:
Positioned.fill(
  child: ClipRect(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: _buildBackgroundDecoration(background),
    ),
  ),
)
```

## Testing

1. **Test default background** (no chatGroupId):
   - Should render `#0B0E14` solid color

2. **Test solid color**:
   ```dart
   await backgroundService.applyColorBackground(chatGroupId, '#FF0000');
   ```

3. **Test gradient**:
   ```dart
   await backgroundService.applyGradientBackground(
     chatGroupId,
     'gradient:linear:0xFF00F5FF,0xFFFF00FF',
   );
   ```

4. **Test image**:
   ```dart
   await backgroundService.uploadCustomBackground(chatGroupId, imagePath);
   ```

5. **Test parallax**:
   - Scroll chat and observe subtle background movement

## Next Steps

1. ✅ **ChatScreen integration** - COMPLETE
2. **Add background picker UI** to ChatInfoScreen or ChatSettingsMenu
3. **Create preset gallery** with visual previews
4. **Add blur/brightness controls** for custom images
5. **Integrate with GameThemeController** for dynamic game-based backgrounds

## Related Files

- `lib/chat/chat_screen.dart` - Modified with background support
- `lib/services/background_service.dart` - Background management service
- `lib/examples/background_service_example.dart` - Full UI example
