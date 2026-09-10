import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Single source of truth for runtime env.
///
/// Load order (later wins only when the value is non-empty and not a
/// placeholder): asset `.env.example` → gitignored `.env` if readable →
/// `--dart-define` / `--dart-define-from-file=.env`.
///
/// iOS/Android cannot read the repo `.env`. For simulator:
///   flutter run --dart-define-from-file=.env -d <device-id>
/// Dart-defines are compile-time: stop the old run and start one new
/// process with that flag. Hot restart does not inject them.
class AppEnv {
  AppEnv._();

  static const _exampleAsset = '.env.example';

  static Map<String, String> _values = {};

  static String? get(String key) {
    final resolved = _values[key];
    if (resolved != null && resolved.isNotEmpty) return resolved;
    try {
      final fromDotenv = dotenv.env[key];
      if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    } catch (_) {
      // dotenv not initialized — treat as unset. Friends IPA must not
      // throw on cold start when client secrets are missing.
    }
    return null;
  }

  /// Null when missing, empty, or a YOUR_ / your_ placeholder.
  static String? configured(String key) {
    final value = get(key);
    if (isPlaceholderEnvValue(key, value)) return null;
    return value;
  }

  static String? get supabaseUrl => get('SUPABASE_URL');

  static String? get supabaseAnonKey => get('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      !isPlaceholderEnvValue('SUPABASE_URL', supabaseUrl) &&
      !isPlaceholderEnvValue('SUPABASE_ANON_KEY', supabaseAnonKey);

  static String? get twitchClientId => configured('TWITCH_CLIENT_ID');
  static String? get twitchClientSecret => configured('TWITCH_CLIENT_SECRET');
  static String? get igdbClientId => configured('IGDB_CLIENT_ID');
  static String? get igdbClientSecret => configured('IGDB_CLIENT_SECRET');
  static String? get agoraAppId => configured('AGORA_APP_ID');
  static String? get agoraAppCertificate => configured('AGORA_APP_CERTIFICATE');
  static String? get xaiApiKey => configured('XAI_API_KEY');

  static bool get isTwitchSecretConfigured => twitchClientSecret != null;
  static bool get isIgdbSecretConfigured => igdbClientSecret != null;
  static bool get isAgoraConfigured => agoraAppId != null;
  static bool get isAgoraCertificateConfigured => agoraAppCertificate != null;
  static bool get isXaiConfigured => xaiApiKey != null;

  /// Friends IPA shell. Unset / empty defaults on. `false` / `0` keeps
  /// the prior full root (Discovery, join, stats, clips).
  static bool get friendsMode {
    final raw = get('FRIENDS_MODE')?.trim();
    if (raw == null || raw.isEmpty) return true;
    final normalized = raw.toLowerCase();
    return normalized != 'false' && normalized != '0';
  }

  /// Secrets the Friends IPA must tolerate unset at cold start.
  static const clientSecretKeys = <String>[
    'TWITCH_CLIENT_SECRET',
    'IGDB_CLIENT_SECRET',
    'AGORA_APP_CERTIFICATE',
    'XAI_API_KEY',
  ];

  /// Test hook. Does not load assets or dart-defines.
  @visibleForTesting
  static void debugReplaceForTest(Map<String, String> values) {
    _values = Map<String, String>.from(values);
    _syncDotenv(_values);
  }

  static Future<void> load() async {
    var asset = <String, String>{};
    try {
      await dotenv.load(fileName: _exampleAsset, isOptional: true);
      asset = Map<String, String>.from(dotenv.env);
    } catch (e) {
      debugPrint('dotenv asset load failed: $e');
    }

    try {
      final merged = mergeEnvLayers(
        asset: asset,
        file: _fileOverlay(),
        dartDefines: dartDefineOverlay(),
      );
      _values = merged;
      _syncDotenv(merged);
    } catch (e) {
      debugPrint('AppEnv merge/sync parked: $e');
      _values = {};
    }

    if (!isSupabaseConfigured) {
      debugPrint(
        'AppEnv: SUPABASE_URL parked (${supabaseUrl ?? '(empty)'}). '
        'No network. flutter run --dart-define-from-file=.env',
      );
    }
    for (final key in clientSecretKeys) {
      if (configured(key) == null) {
        debugPrint('AppEnv: $key unset — feature parked (no throw).');
      }
    }
  }

  /// Visible for tests. Compile-time `--dart-define` / from-file.
  static Map<String, String> dartDefineOverlay() {
    const raw = <String, String>{
      'SUPABASE_URL': String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': String.fromEnvironment('SUPABASE_ANON_KEY'),
      'IGDB_CLIENT_ID': String.fromEnvironment('IGDB_CLIENT_ID'),
      'IGDB_CLIENT_SECRET': String.fromEnvironment('IGDB_CLIENT_SECRET'),
      'TWITCH_CLIENT_ID': String.fromEnvironment('TWITCH_CLIENT_ID'),
      'TWITCH_CLIENT_SECRET': String.fromEnvironment('TWITCH_CLIENT_SECRET'),
      'GOOGLE_WEB_CLIENT_ID': String.fromEnvironment('GOOGLE_WEB_CLIENT_ID'),
      'GOOGLE_IOS_CLIENT_ID': String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
      'AGORA_APP_ID': String.fromEnvironment('AGORA_APP_ID'),
      'AGORA_APP_CERTIFICATE': String.fromEnvironment('AGORA_APP_CERTIFICATE'),
      'XAI_API_KEY': String.fromEnvironment('XAI_API_KEY'),
      'FRIENDS_MODE': String.fromEnvironment('FRIENDS_MODE'),
    };
    return {
      for (final entry in raw.entries)
        if (entry.value.isNotEmpty) entry.key: entry.value,
    };
  }

  static Map<String, String> _fileOverlay() {
    if (kIsWeb) return const {};
    try {
      final file = File('.env');
      if (!file.existsSync()) {
        return const {};
      }
      return parseEnv(file.readAsStringSync());
    } catch (e) {
      debugPrint('dotenv file overlay skipped: $e');
      return const {};
    }
  }

  static void _syncDotenv(Map<String, String> values) {
    final buffer = StringBuffer();
    values.forEach((key, value) {
      buffer.writeln('$key=$value');
    });
    dotenv.testLoad(fileInput: buffer.toString());
  }
}

/// Placeholder keys must never beat a real dart-define or `.env` value.
bool isPlaceholderEnvValue(String key, String? value) {
  if (value == null) return true;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return true;
  final lower = trimmed.toLowerCase();
  if (key == 'SUPABASE_URL') {
    return lower.contains('your-project') ||
        lower.contains('your_project') ||
        lower.contains('yourproject.supabase');
  }
  if (key == 'SUPABASE_ANON_KEY') {
    return lower.contains('your_anon') ||
        lower.contains('your-anon') ||
        lower.startsWith('your_');
  }
  return trimmed.contains('YOUR_') ||
      lower.contains('your_google') ||
      lower.startsWith('your_');
}

/// asset → file → dart-defines. Placeholders never overwrite a real value.
Map<String, String> mergeEnvLayers({
  Map<String, String> asset = const {},
  Map<String, String> file = const {},
  Map<String, String> dartDefines = const {},
}) {
  final out = <String, String>{};

  void apply(Map<String, String> layer) {
    for (final entry in layer.entries) {
      final value = entry.value.trim();
      if (value.isEmpty) continue;
      final existing = out[entry.key];
      final incomingPlaceholder = isPlaceholderEnvValue(entry.key, value);
      final existingIsReal =
          existing != null && !isPlaceholderEnvValue(entry.key, existing);
      if (incomingPlaceholder && existingIsReal) {
        continue;
      }
      out[entry.key] = value;
    }
  }

  apply(asset);
  apply(file);
  apply(dartDefines);
  return out;
}

Map<String, String> parseEnv(String contents) {
  final out = <String, String>{};
  for (final rawLine in contents.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) {
      continue;
    }
    final eq = line.indexOf('=');
    if (eq <= 0) {
      continue;
    }
    final key = line.substring(0, eq).trim();
    var value = line.substring(eq + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    if (key.isNotEmpty) {
      out[key] = value;
    }
  }
  return out;
}
