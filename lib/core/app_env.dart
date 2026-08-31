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
    final fromDotenv = dotenv.env[key];
    if (fromDotenv != null && fromDotenv.isNotEmpty) return fromDotenv;
    return null;
  }

  static String? get supabaseUrl => get('SUPABASE_URL');

  static String? get supabaseAnonKey => get('SUPABASE_ANON_KEY');

  static bool get isSupabaseConfigured =>
      !isPlaceholderEnvValue('SUPABASE_URL', supabaseUrl) &&
      !isPlaceholderEnvValue('SUPABASE_ANON_KEY', supabaseAnonKey);

  static Future<void> load() async {
    var asset = <String, String>{};
    try {
      await dotenv.load(fileName: _exampleAsset, isOptional: true);
      asset = Map<String, String>.from(dotenv.env);
    } catch (e) {
      debugPrint('dotenv asset load failed: $e');
    }

    final merged = mergeEnvLayers(
      asset: asset,
      file: _fileOverlay(),
      dartDefines: dartDefineOverlay(),
    );
    _values = merged;
    _syncDotenv(merged);

    if (!isSupabaseConfigured) {
      debugPrint(
        'AppEnv: SUPABASE_URL parked (${supabaseUrl ?? '(empty)'}). '
        'No network. flutter run --dart-define-from-file=.env',
      );
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
