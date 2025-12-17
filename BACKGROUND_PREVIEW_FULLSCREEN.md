# Full-Screen Background Preview Implementation

## Overview
Implemented full-screen, swipeable background preview mode for multi-color background options (bubbles 3-7: Sunset, Ocean, Neon, Emerald).

## User Flow
1. User taps a background bubble with multiple options (Sunset/Ocean/Neon/Emerald)
2. **Exits** the background selection menu
3. **Enters** full-screen preview mode showing the chat screen with selected background
4. User can **swipe left/right** to preview different color variations
5. **Navigation dots** at bottom indicate current selection (one dot per variation)
6. **Variation name** displays above navigation dots
7. **Chat header** (avatar + name) remains visible at top
8. **Checkmark button** (top right) applies selected background
9. **X button** (top left) cancels and returns to background selection menu

## Implementation Details

### New Files
- **[lib/chat/widgets/background_preview_screen.dart](lib/chat/widgets/background_preview_screen.dart)**: Full-screen preview widget

### Key Features

#### BackgroundPreviewScreen Widget
**Parameters:**
- `themeName`: Display name of background theme (e.g., "Sunset", "Ocean")
- `variations`: List of color variations with id, name, and gradient
- `chatName`: Chat/squad name for header
- `chatImageUrl`: Optional chat avatar URL
- `onApply`: Callback when user confirms selection

**Layout:**
```
┌─────────────────────────────────┐
│  [X]               [✓]         │ ← Controls overlay
│                                 │
│  [Avatar] Chat Name             │ ← Chat header
│                                 │
│                                 │
│     Background Gradient         │ ← Swipeable PageView
│       (Full Screen)             │
│                                 │
│                                 │
│  Variation Name                 │ ← Bottom controls
│  ● ○ ○                          │ ← Navigation dots
└─────────────────────────────────┘
```

**Interactive Elements:**
- **PageView**: Swipe to change background variations
- **Navigation dots**: Tap to jump to specific variation
- **Active dot**: Elongated (24px) with white glow
- **Inactive dots**: Circular (8px) with 40% opacity
- **X button**: Circular black background (50% opacity)
- **Checkmark button**: Circular black background (50% opacity)

#### Updated chat_info_screen.dart
**Modified Method:** `_showAnimatedBackgroundVariations()`
- **Before**: Opened DraggableScrollableSheet modal with list of cards
- **After**: Navigates to full-screen BackgroundPreviewScreen
- **Navigation**: Uses `MaterialPageRoute` for smooth transition
- **On Apply**: Calls `BackgroundService.applyBackground()`, closes preview + picker
- **Error Handling**: Shows snackbar on success/failure

### Visual Design

#### Glass Effects
- **Chat header**: Gradient from black (60% opacity) to transparent
- **Bottom controls**: Gradient from black (70% opacity) to transparent
- **Backdrop blur**: 10px blur on both overlays
- **Text shadows**: Black shadow for readability

#### Animations
- **Page transitions**: 300ms ease-in-out curve
- **Dot transitions**: 200ms smooth resize/color change
- **Haptic feedback**: 
  - `selectionClick()` on page change
  - `mediumImpact()` on background apply
  - `lightImpact()` on cancel

### Background Variations

Each theme has 3 variations:

**Sunset:**
- Sunset Void: `#FF6B35` → `#4A1C8C`
- Fire Sunset: `#FF4500` → `#8B0000`
- Warm Sunset: `#FFAA33` → `#FF6B6B`

**Ocean:**
- Ocean Depths: `#001F3F` → `#0074D9`
- Teal Ocean: `#004D5C` → `#00CED1`
- Midnight Ocean: `#0D1B2A` → `#1B4965`

**Neon:**
- Neon Horizon: `#00F5FF` → `#FF00FF`
- Pink Neon: `#FF006E` → `#FF00FF`
- Blue Neon: `#00F5FF` → `#0066FF`

**Emerald:**
- Emerald Dream: `#00F5A0` → `#00D9F5`
- Forest Emerald: `#2ECC71` → `#27AE60`
- Mint Emerald: `#3CFFD2` → `#56FFA4`

## Technical Notes

### State Management
- `PageController` for swipeable pages
- `_currentPage` tracks active variation
- `setState()` updates UI on page change

### Navigation Flow
```
ChatInfoScreen
  → Tap Sunset/Ocean/Neon/Emerald bubble
    → _showAnimatedBackgroundVariations()
      → Navigator.push(BackgroundPreviewScreen)
        → User swipes through variations
        → User taps checkmark
          → BackgroundService.applyBackground()
          → Navigator.pop() × 2 (close preview + picker)
```

### Error Handling
- Try-catch around background application
- Mounted checks before showing snackbars
- Success snackbar with theme color
- Error snackbar with error color scheme

## Benefits

1. **Immersive preview**: Full-screen view shows exactly how background will look
2. **Chat context**: Header shows which chat the background will apply to
3. **Easy comparison**: Swipe gesture makes comparing variations intuitive
4. **Clear navigation**: Dots provide visual feedback and navigation control
5. **Obvious actions**: Checkmark/X buttons clearly communicate purpose
6. **Consistent UX**: Follows iOS/Material design patterns for previews

## Future Enhancements

- Add background preview for "None" and "Photo" options
- Show sample chat messages in preview for better context
- Add animation when transitioning from menu to preview
- Save recently selected backgrounds for quick access
- Add sharing feature to share background variations
