import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:riverpod/riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Game theme state containing extracted colors and metadata
class GameThemeState {
  final String? currentGameId;
  final String? currentGameName;
  final String? coverImageUrl;
  final Color dominantColor;
  final Color vibrantColor;
  final Color accentColor;
  final ColorScheme? dynamicColorScheme;
  final bool isLoading;
  final String? error;
  final Brightness systemBrightness;
  final bool neonGlowEnabled;
  final bool highContrastMode;

  const GameThemeState({
    this.currentGameId,
    this.currentGameName,
    this.coverImageUrl,
    this.dominantColor = const Color(0xFF00F5FF),
    this.vibrantColor = const Color(0xFF00F5FF),
    this.accentColor = const Color(0xFF0080FF),
    this.dynamicColorScheme,
    this.isLoading = false,
    this.error,
    this.systemBrightness = Brightness.dark,
    this.neonGlowEnabled = true,
    this.highContrastMode = false,
  });

  GameThemeState copyWith({
    String? currentGameId,
    String? currentGameName,
    String? coverImageUrl,
    Color? dominantColor,
    Color? vibrantColor,
    Color? accentColor,
    ColorScheme? dynamicColorScheme,
    bool? isLoading,
    String? error,
    Brightness? systemBrightness,
    bool? neonGlowEnabled,
    bool? highContrastMode,
  }) {
    return GameThemeState(
      currentGameId: currentGameId ?? this.currentGameId,
      currentGameName: currentGameName ?? this.currentGameName,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      dominantColor: dominantColor ?? this.dominantColor,
      vibrantColor: vibrantColor ?? this.vibrantColor,
      accentColor: accentColor ?? this.accentColor,
      dynamicColorScheme: dynamicColorScheme ?? this.dynamicColorScheme,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      systemBrightness: systemBrightness ?? this.systemBrightness,
      neonGlowEnabled: neonGlowEnabled ?? this.neonGlowEnabled,
      highContrastMode: highContrastMode ?? this.highContrastMode,
    );
  }
}

/// Popular game color presets for instant fallback
class GameColorPresets {
  static const Map<String, GameColors> presets = {
    // Call of Duty: Warzone
    'warzone': GameColors(
      dominant: Color(0xFF00FF41),
      vibrant: Color(0xFF39FF14),
      accent: Color(0xFF00CC33),
    ),
    'call of duty': GameColors(
      dominant: Color(0xFF00FF41),
      vibrant: Color(0xFF39FF14),
      accent: Color(0xFF00CC33),
    ),

    // Valorant
    'valorant': GameColors(
      dominant: Color(0xFFFF4655),
      vibrant: Color(0xFFFF1744),
      accent: Color(0xFFD32F2F),
    ),

    // Apex Legends
    'apex legends': GameColors(
      dominant: Color(0xFFFF6347),
      vibrant: Color(0xFFFF4500),
      accent: Color(0xFFE64A19),
    ),

    // Fortnite
    'fortnite': GameColors(
      dominant: Color(0xFF00B4FF),
      vibrant: Color(0xFF00D9FF),
      accent: Color(0xFF0091EA),
    ),

    // League of Legends
    'league of legends': GameColors(
      dominant: Color(0xFF0AC8B9),
      vibrant: Color(0xFF00E5CC),
      accent: Color(0xFF00BFA5),
    ),

    // Overwatch
    'overwatch': GameColors(
      dominant: Color(0xFFFFA500),
      vibrant: Color(0xFFFFB300),
      accent: Color(0xFFFF8F00),
    ),

    // Counter-Strike
    'counter-strike': GameColors(
      dominant: Color(0xFFFFD700),
      vibrant: Color(0xFFFFC107),
      accent: Color(0xFFFFA000),
    ),
    'cs:go': GameColors(
      dominant: Color(0xFFFFD700),
      vibrant: Color(0xFFFFC107),
      accent: Color(0xFFFFA000),
    ),
    'cs2': GameColors(
      dominant: Color(0xFFFFD700),
      vibrant: Color(0xFFFFC107),
      accent: Color(0xFFFFA000),
    ),

    // Rocket League
    'rocket league': GameColors(
      dominant: Color(0xFF0080FF),
      vibrant: Color(0xFF2196F3),
      accent: Color(0xFF1976D2),
    ),

    // Destiny 2
    'destiny 2': GameColors(
      dominant: Color(0xFF6A4C93),
      vibrant: Color(0xFF7E57C2),
      accent: Color(0xFF5E35B1),
    ),

    // Minecraft
    'minecraft': GameColors(
      dominant: Color(0xFF8BC34A),
      vibrant: Color(0xFF9CCC65),
      accent: Color(0xFF7CB342),
    ),

    // Default fallback
    'default': GameColors(
      dominant: Color(0xFF00F5FF),
      vibrant: Color(0xFF00D9FF),
      accent: Color(0xFF00BCD4),
    ),
  };

  static GameColors getPreset(String? gameName) {
    if (gameName == null) return presets['default']!;

    final normalizedName = gameName.toLowerCase().trim();

    // Try exact match first
    if (presets.containsKey(normalizedName)) {
      return presets[normalizedName]!;
    }

    // Try partial match
    for (final entry in presets.entries) {
      if (normalizedName.contains(entry.key) ||
          entry.key.contains(normalizedName)) {
        return entry.value;
      }
    }

    return presets['default']!;
  }
}

/// Game color set
class GameColors {
  final Color dominant;
  final Color vibrant;
  final Color accent;

  const GameColors({
    required this.dominant,
    required this.vibrant,
    required this.accent,
  });
}

/// Game theme controller notifier
class GameThemeController extends StateNotifier<GameThemeState> {
  final SharedPreferences _prefs;
  Timer? _debounceTimer;

  GameThemeController(this._prefs) : super(const GameThemeState()) {
    _loadSavedTheme();
  }

  static const _keyGameId = 'theme_game_id';
  static const _keyGameName = 'theme_game_name';
  static const _keyCoverUrl = 'theme_cover_url';
  static const _keyDominantColor = 'theme_dominant_color';
  static const _keyVibrantColor = 'theme_vibrant_color';
  static const _keyAccentColor = 'theme_accent_color';
  static const _keyNeonGlowEnabled = 'theme_neon_glow_enabled';
  static const _keyHighContrastMode = 'theme_high_contrast_mode';

  /// Load saved theme from SharedPreferences
  Future<void> _loadSavedTheme() async {
    final gameId = _prefs.getString(_keyGameId);
    final gameName = _prefs.getString(_keyGameName);
    final coverUrl = _prefs.getString(_keyCoverUrl);
    final dominantColorValue = _prefs.getInt(_keyDominantColor);
    final vibrantColorValue = _prefs.getInt(_keyVibrantColor);
    final accentColorValue = _prefs.getInt(_keyAccentColor);
    final neonGlowEnabled = _prefs.getBool(_keyNeonGlowEnabled) ?? true;
    final highContrastMode = _prefs.getBool(_keyHighContrastMode) ?? false;

    if (gameId != null && gameName != null) {
      state = state.copyWith(
        currentGameId: gameId,
        currentGameName: gameName,
        coverImageUrl: coverUrl,
        dominantColor: dominantColorValue != null
            ? Color(dominantColorValue)
            : state.dominantColor,
        vibrantColor: vibrantColorValue != null
            ? Color(vibrantColorValue)
            : state.vibrantColor,
        accentColor: accentColorValue != null
            ? Color(accentColorValue)
            : state.accentColor,
        neonGlowEnabled: neonGlowEnabled,
        highContrastMode: highContrastMode,
      );
    }
  }

  /// Save theme to SharedPreferences
  Future<void> _saveTheme() async {
    await _prefs.setString(_keyGameId, state.currentGameId ?? '');
    await _prefs.setString(_keyGameName, state.currentGameName ?? '');
    if (state.coverImageUrl != null) {
      await _prefs.setString(_keyCoverUrl, state.coverImageUrl!);
    }
    await _prefs.setInt(_keyDominantColor, state.dominantColor.value);
    await _prefs.setInt(_keyVibrantColor, state.vibrantColor.value);
    await _prefs.setInt(_keyAccentColor, state.accentColor.value);
    await _prefs.setBool(_keyNeonGlowEnabled, state.neonGlowEnabled);
    await _prefs.setBool(_keyHighContrastMode, state.highContrastMode);
  }

  /// Update theme based on game change
  Future<void> updateGameTheme({
    required String gameId,
    required String gameName,
    String? coverImageUrl,
  }) async {
    // Cancel any pending debounce
    _debounceTimer?.cancel();

    // Check if game actually changed
    if (state.currentGameId == gameId) {
      return;
    }

    // Set loading state
    state = state.copyWith(
      isLoading: true,
      error: null,
    );

    // Try to get preset colors first (instant fallback)
    final preset = GameColorPresets.getPreset(gameName);

    // Update with preset immediately
    state = state.copyWith(
      currentGameId: gameId,
      currentGameName: gameName,
      coverImageUrl: coverImageUrl,
      dominantColor: preset.dominant,
      vibrantColor: preset.vibrant,
      accentColor: preset.accent,
      isLoading: false,
    );

    await _saveTheme();

    // If we have a cover URL, extract colors in background
    if (coverImageUrl != null && coverImageUrl.isNotEmpty) {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _extractColorsFromCover(coverImageUrl);
      });
    }
  }

  /// Extract colors from IGDB cover image using Flutter 3.38's ColorScheme.fromImageProvider
  Future<void> _extractColorsFromCover(String imageUrl) async {
    try {
      // Download image bytes
      final response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download image');
      }

      final Uint8List bytes = response.bodyBytes;

      // Use Flutter 3.38's new ColorScheme.fromImageProvider API
      // This replaces palette_generator with native Material 3 color extraction
      final imageProvider = MemoryImage(bytes);

      // Extract color scheme for current brightness
      final brightness = state.systemBrightness;
      final colorScheme = await ColorScheme.fromImageProvider(
        provider: imageProvider,
        brightness: brightness,
      );

      // Extract key colors from the generated scheme
      Color vibrant = colorScheme.primary;
      Color dominant = colorScheme.primaryContainer;
      Color accent = colorScheme.secondary;

      // Apply high contrast mode if enabled
      if (state.highContrastMode) {
        vibrant = _applyHighContrast(vibrant, brightness);
        dominant = _applyHighContrast(dominant, brightness);
        accent = _applyHighContrast(accent, brightness);
      }

      // Ensure colors are vibrant enough for neon effects if enabled
      if (state.neonGlowEnabled) {
        vibrant = _ensureVibrant(vibrant);
        dominant = _ensureVibrant(dominant);
      }

      // Update state with extracted colors and dynamic color scheme
      state = state.copyWith(
        dominantColor: dominant,
        vibrantColor: vibrant,
        accentColor: accent,
        dynamicColorScheme: colorScheme,
        isLoading: false,
        error: null,
      );

      await _saveTheme();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to extract colors: $e',
      );
      // Keep preset colors on error
    }
  }

  /// Ensure color is vibrant enough for neon effects
  Color _ensureVibrant(Color color) {
    final hslColor = HSLColor.fromColor(color);

    // Ensure saturation is at least 0.5
    final saturation = hslColor.saturation < 0.5 ? 0.7 : hslColor.saturation;

    // Ensure lightness is between 0.4 and 0.7 for good visibility
    var lightness = hslColor.lightness;
    if (lightness < 0.4) {
      lightness = 0.5;
    } else if (lightness > 0.7) {
      lightness = 0.6;
    }

    return hslColor
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }

  /// Apply high contrast mode adjustments for accessibility
  Color _applyHighContrast(Color color, Brightness brightness) {
    final hslColor = HSLColor.fromColor(color);

    // For high contrast, push lightness to extremes
    final lightness = brightness == Brightness.dark
        ? (hslColor.lightness < 0.5 ? 0.85 : hslColor.lightness)
        : (hslColor.lightness > 0.5 ? 0.15 : hslColor.lightness);

    // Increase saturation for better distinction
    final saturation = hslColor.saturation < 0.8 ? 0.9 : hslColor.saturation;

    return hslColor
        .withSaturation(saturation)
        .withLightness(lightness)
        .toColor();
  }

  /// Reset to default theme
  Future<void> resetToDefault() async {
    final defaultColors = GameColorPresets.presets['default']!;

    state = const GameThemeState().copyWith(
      dominantColor: defaultColors.dominant,
      vibrantColor: defaultColors.vibrant,
      accentColor: defaultColors.accent,
    );

    await _saveTheme();
  }

  /// Manually set custom colors
  Future<void> setCustomColors({
    required Color dominant,
    required Color vibrant,
    required Color accent,
  }) async {
    state = state.copyWith(
      dominantColor: dominant,
      vibrantColor: vibrant,
      accentColor: accent,
    );

    await _saveTheme();
  }

  /// Update system brightness (detects dark/light mode changes)
  Future<void> updateSystemBrightness(Brightness brightness) async {
    if (state.systemBrightness == brightness) return;

    state = state.copyWith(systemBrightness: brightness);

    // Re-extract colors if we have a cover image to get proper brightness scheme
    if (state.coverImageUrl != null && state.coverImageUrl!.isNotEmpty) {
      await _extractColorsFromCover(state.coverImageUrl!);
    }
  }

  /// Toggle neon glow effects
  Future<void> toggleNeonGlow(bool enabled) async {
    state = state.copyWith(neonGlowEnabled: enabled);
    await _saveTheme();

    // Re-apply color adjustments
    if (state.coverImageUrl != null && state.coverImageUrl!.isNotEmpty) {
      await _extractColorsFromCover(state.coverImageUrl!);
    }
  }

  /// Toggle high contrast mode for accessibility
  Future<void> toggleHighContrast(bool enabled) async {
    state = state.copyWith(highContrastMode: enabled);
    await _saveTheme();

    // Re-apply color adjustments
    if (state.coverImageUrl != null && state.coverImageUrl!.isNotEmpty) {
      await _extractColorsFromCover(state.coverImageUrl!);
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Provider for SharedPreferences
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

/// Provider for GameThemeController using legacy StateNotifier
final gameThemeControllerProvider =
    StateNotifierProvider<GameThemeController, GameThemeState>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return GameThemeController(prefs);
});

/// Convenience provider for current primary color
final currentPrimaryColorProvider = Provider<Color>((ref) {
  final themeState = ref.watch(gameThemeControllerProvider);
  return themeState.vibrantColor;
});

/// Convenience provider for current accent color
final currentAccentColorProvider = Provider<Color>((ref) {
  final themeState = ref.watch(gameThemeControllerProvider);
  return themeState.accentColor;
});

/// Convenience provider for current dominant color
final currentDominantColorProvider = Provider<Color>((ref) {
  final themeState = ref.watch(gameThemeControllerProvider);
  return themeState.dominantColor;
});
