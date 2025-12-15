# Image Crop Feature

## Overview
Added image cropping functionality for all profile pictures and group chat photos across the app. Users can now adjust and center images before uploading.

## Implementation

### Package
- **image_cropper** (v8.0.2) - Cross-platform image cropping with native UI on iOS/Android and web support

### New Utility
- **`lib/core/utils/image_crop_helper.dart`** - Centralized helper class with consistent crop UI and behavior

### Crop Functions Available

#### 1. Profile Pictures
```dart
ImageCropHelper.pickAndCropProfileImage(context)
```
- **Aspect Ratio**: 1:1 (square)
- **Crop Style**: Circle
- **Max Resolution**: 1024x1024
- **Quality**: 90%
- **Used in**:
  - Profile tab avatar upload
  - Profile editing screen
  - Onboarding avatar selection

#### 2. Group Chat Photos
```dart
ImageCropHelper.pickAndCropGroupImage(context)
```
- **Aspect Ratio**: 1:1 (square)
- **Crop Style**: Rectangle
- **Max Resolution**: 1024x1024
- **Quality**: 90%
- **Used in**:
  - Chat info screen group photo upload

#### 3. Chat Backgrounds
```dart
ImageCropHelper.pickAndCropBackgroundImage(context)
```
- **Aspect Ratio**: 16:9 (landscape)
- **Crop Style**: Rectangle
- **Max Resolution**: 1920x1080
- **Quality**: 85%
- **Used in**:
  - Chat info screen background upload

#### 4. Custom Crop (Advanced)
```dart
ImageCropHelper.pickAndCropCustom(
  context,
  ratioX: 4,
  ratioY: 3,
  cropStyle: CropStyle.rectangle,
  title: 'Crop Image',
  maxWidth: 1024,
  maxHeight: 1024,
  imageQuality: 90,
)
```

## Files Modified

### Core
- ✅ `pubspec.yaml` - Added image_cropper package
- ✅ `lib/core/utils/image_crop_helper.dart` - New helper utility (created)

### Profile Images
- ✅ `lib/profile_tab.dart` - Main profile avatar upload
- ✅ `lib/screens/profile_editing_screen.dart` - Profile editing avatar
- ✅ `lib/presentation/onboarding/widgets/avatar_selection_widget.dart` - Onboarding avatar

### Group Chat Photos
- ✅ `lib/chat/screens/components/chat_info_widgets.dart` - Group photo upload

### Chat Backgrounds
- ✅ `lib/chat/screens/chat_info_screen.dart` - Background image upload

## User Experience

### Before
1. User taps to upload photo
2. Selects image from gallery
3. Image is uploaded as-is (no adjustment possible)

### After
1. User taps to upload photo
2. Selects image from gallery
3. **Crop screen appears** with:
   - Grid overlay for alignment
   - Zoom/pan controls
   - Rotation controls
   - Aspect ratio lock (appropriate for context)
4. User adjusts the crop area to center the image
5. Taps "Done" to confirm or "Cancel" to start over
6. Cropped image is uploaded

## Platform Support
- ✅ **iOS**: Native UCropViewController with iOS styling
- ✅ **Android**: Native UCrop library with Material Design
- ✅ **Web**: Browser-based cropper with dialog presentation
- ⚠️ **Desktop**: Web implementation (requires testing)

## Theme Integration
The crop UI automatically adapts to your app's theme:
- Toolbar colors match `colorScheme.surface` and `colorScheme.onSurface`
- Active controls use `colorScheme.primary`
- Grid and frame use primary color with opacity

## Testing Checklist
- [ ] Profile tab - Upload profile picture
- [ ] Profile editing screen - Change avatar
- [ ] Onboarding flow - Select custom avatar
- [ ] Chat info - Upload group photo
- [ ] Chat info - Upload custom background
- [ ] Test on iOS device
- [ ] Test on Android device
- [ ] Test on web browser

## Future Enhancements
- Add preset aspect ratios dropdown (1:1, 4:3, 16:9, free)
- Add filters/effects after cropping
- Add batch crop for multiple images
- Save crop presets per user preference
