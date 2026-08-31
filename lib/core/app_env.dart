import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Loads environment variables without bundling a real `.env` in the app.
///
/// Order: `--dart-define` / `--dart-define-from-file` overlays a gitignored
/// filesystem `.env` (desktop / `flutter test` from the repo) over the
/// committed `.env.example` placeholders (safe to ship).
class AppEnv {
  AppEnv._();

  static const _exampleAsset = '.env.example';

  static Future<void> load() async {
    final overlay = <String, String>{
      ..._fileOverlay(),
      ..._dartDefineOverlay(),
    };

    try {
      await dotenv.load(
        fileName: _exampleAsset,
        isOptional: true,
        mergeWith: overlay,
      );
    } catch (e) {
      debugPrint('dotenv asset load failed: $e');
      if (overlay.isNotEmpty) {
        final buffer = StringBuffer();
        overlay.forEach((key, value) {
          buffer.writeln('$key=$value');
        });
        dotenv.testLoad(fileInput: buffer.toString());
      }
    }
  }

  static Map<String, String> _fileOverlay() {
    try {
      final file = File('.env');
      if (!file.existsSync()) {
        return const {};
      }
      return _parseEnv(file.readAsStringSync());
    } catch (e) {
      debugPrint('dotenv file overlay skipped: $e');
      return const {};
    }
  }

  static Map<String, String> _dartDefineOverlay() {
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

  static Map<String, String> _parseEnv(String contents) {
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
}
