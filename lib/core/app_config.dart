/// Application Configuration
/// Simple configuration for app-wide settings
class AppConfig {
  // ============================================================================
  // APP SETTINGS
  // ============================================================================

  /// App environment
  static const bool isProduction = false;

  /// Enable debug logging
  static const bool debugLogging = true;

  /// API timeout duration
  static const Duration apiTimeout = Duration(seconds: 30);

  // ============================================================================
  // FEATURE FLAGS
  // ============================================================================

  /// Enable experimental features
  static const bool enableExperimentalFeatures = false;
}

/// Database mode enum (for future expansion)
enum DatabaseMode {
  supabaseOnly,
}
