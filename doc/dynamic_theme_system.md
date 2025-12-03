# Dynamic Game Theme System

## Overview
SquadSync features a dynamic theming system that automatically extracts colors from game cover art (IGDB) and applies them across the entire app with smooth 600ms animated transitions. The system uses Material 3's ColorScheme.fromSeed() to generate harmonious color palettes.

## Architecture

### Components

1. **GameThemeController** (`lib/presentation/controllers/game_theme_controller.dart`)
   - Riverpod StateNotifier managing theme state
   - Extracts dominant, vibrant, and accent colors from IGDB cover images
   - Persists theme preferences to SharedPreferences
   - Provides fallback presets for popular games
   - Debounces color extraction to avoid excessive API calls

2. **AnimatedThemeWrapper** (`lib/presentation/widgets/animated_theme_wrapper.dart`)
   - Consumer widget wrapping MaterialApp
   - Watches GameThemeController for color changes
   - Applies animated theme transitions (600ms cubic curve)
   - Passes dynamic seed color to AppTheme.dark()

3. **GameThemeSync** (`lib/presentation/hooks/game_theme_sync.dart`)
   - Hook that watches GameNotifier for game selection changes
   - Automatically triggers theme updates when currentGame changes
   - Extracts game metadata (id, name, cover URL) and updates controller

4. **GameThemeState**
   - Immutable state containing:
     - currentGameId, currentGameName
     - coverImageUrl
     - dominantColor, vibrantColor, accentColor
     - isLoading, error

## Usage

### Automatic Theme Updates
Theme updates happen automatically when the user selects a game:

```dart
// In any screen where GameNotifier.currentGame changes:
// Theme will automatically update via GameThemeSync.watch(ref)
ref.read(gameNotifierProvider.notifier).setCurrentGame(game);
```

The system is already integrated in `app_widgets.dart`:
```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  // Syncs theme with game selection
  GameThemeSync.watch(ref);

  return AnimatedThemeWrapper(
    child: MaterialApp(...),
  );
}
```

### Manual Theme Control
You can manually set colors or reset to default:

```dart
// Update theme for a specific game
await ref.read(gameThemeControllerProvider.notifier).updateGameTheme(
  gameId: '12345',
  gameName: 'Warzone',
  coverImageUrl: 'https://images.igdb.com/...',
);

// Set custom colors
await ref.read(gameThemeControllerProvider.notifier).setCustomColors(
  dominant: Color(0xFF00FF41),
  vibrant: Color(0xFF39FF14),
  accent: Color(0xFF00CC33),
);

// Reset to default cyan neon
await ref.read(gameThemeControllerProvider.notifier).resetToDefault();
```

### Access Current Colors
Use convenience providers to access colors in widgets:

```dart
// Get primary color (vibrant)
final primaryColor = ref.watch(currentPrimaryColorProvider);

// Get accent color
final accentColor = ref.watch(currentAccentColorProvider);

// Get dominant color
final dominantColor = ref.watch(currentDominantColorProvider);

// Get full theme state
final themeState = ref.watch(gameThemeControllerProvider);
```

## Color Extraction

### Process
1. User selects a game from GameNotifier
2. GameThemeSync detects change and triggers updateGameTheme()
3. Preset colors applied immediately (no latency)
4. Background job downloads cover image via HTTP
5. PaletteGenerator extracts colors from image
6. Colors enhanced to ensure vibrancy (saturation ≥0.5, lightness 0.4-0.7)
7. Theme state updated, triggering AnimatedTheme transition

### Presets
Instant fallback colors for popular games:
- **Warzone/CoD**: Neon green (#00FF41)
- **Valorant**: Crimson red (#FF4655)
- **Apex Legends**: Burnt orange (#FF6347)
- **Fortnite**: Electric blue (#00B4FF)
- **League of Legends**: Teal (#0AC8B9)
- **Overwatch**: Orange (#FFA500)
- **CS:GO/CS2**: Gold (#FFD700)
- **Rocket League**: Blue (#0080FF)
- **Destiny 2**: Purple (#6A4C93)
- **Minecraft**: Green (#8BC34A)
- **Default**: Cyan neon (#00F5FF)

## Performance Optimizations

1. **Debouncing**: 300ms debounce on color extraction to avoid rapid-fire requests
2. **Caching**: SharedPreferences persists last theme to avoid re-extraction
3. **Preset Fallback**: Instant preset colors while background extraction runs
4. **Lazy Loading**: HTTP image download happens asynchronously after preset applied
5. **Color Enhancement**: Ensures vibrant colors suitable for neon UI without expensive HSL conversions

## Integration Points

### Main.dart
```dart
void main() async {
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  
  runApp(SquadSyncApp(prefs: prefs));
}

// Override SharedPreferences provider
ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(widget.prefs),
  ],
  child: const SquadSyncMaterialApp(),
);
```

### AppTheme
```dart
// AppTheme.dark() accepts dynamic seed color
static ThemeData dark({Color? dynamicSeedColor}) {
  final seedColor = dynamicSeedColor ?? _defaultNeon;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: Brightness.dark,
  );
  // ...
}
```

## Dependencies
- `palette_generator`: ^0.3.3+7 - Color extraction from images
- `shared_preferences`: ^2.3.0 - Theme persistence
- `http`: ^1.2.2 - Cover image download
- `flutter_riverpod`: ^2.5.1 - State management

## File Structure
```
lib/
  presentation/
    controllers/
      game_theme_controller.dart     # Main theme controller
    widgets/
      animated_theme_wrapper.dart    # Animated theme transition wrapper
    hooks/
      game_theme_sync.dart            # Auto-sync hook for game changes
  core/
    app_theme.dart                    # AppTheme with dynamic color support
  widgets/
    app_widgets.dart                  # MaterialApp with theme integration
  main.dart                           # SharedPreferences initialization
```

## Example: Adding New Preset

```dart
// In GameColorPresets.presets map:
'halo': GameColors(
  dominant: Color(0xFF117A00),  // Halo green
  vibrant: Color(0xFF14FF00),   // Bright green
  accent: Color(0xFF0D5C00),    // Dark green accent
),
```

## Troubleshooting

### Theme Not Updating
1. Ensure GameThemeSync.watch(ref) is called in SquadSyncMaterialApp
2. Check that gameNotifierProvider.currentGame is being set
3. Verify SharedPreferences initialized in main.dart

### Colors Too Dull
- GameThemeController._ensureVibrant() boosts saturation to ≥0.5
- Adjust lightness range in _ensureVibrant() (currently 0.4-0.7)

### Image Download Failures
- System falls back to preset colors on HTTP errors
- Check IGDB cover URL format (should include https: scheme)

## Future Enhancements
- [ ] User-customizable color picker
- [ ] Color scheme voting/sharing between squad members
- [ ] Animated gradient backgrounds based on game art
- [ ] Per-lobby theme overrides
- [ ] Light mode support with auto-adjusted palettes
