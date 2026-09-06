import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app_env.dart';

/// Google Sign-In client IDs. `.env` wins when filled; otherwise the
/// project's public Firebase OAuth clients (same as GoogleService-Info
/// CLIENT_ID / android web client_type 3). Production FCM still needs
/// a real gitignored GoogleService-Info.plist.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  /// iOS OAuth CLIENT_ID from ios/Runner/GoogleService-Info.plist.
  static const bundledIosClientId =
      '756172684661-99ecq9sd74qvt9ufs28os52j9g33h1v9.apps.googleusercontent.com';

  /// Web/server client (client_type 3) for google_sign_in ID tokens.
  static const bundledWebClientId =
      '756172684661-pv3rscsdd548cb5r6orrs6u2bvu1oi6e.apps.googleusercontent.com';

  static String? get iosClientId => _preferFilled(
        AppEnv.get('GOOGLE_IOS_CLIENT_ID') ?? dotenv.env['GOOGLE_IOS_CLIENT_ID'],
        bundledIosClientId,
      );

  static String? get webClientId => _preferFilled(
        AppEnv.get('GOOGLE_WEB_CLIENT_ID') ?? dotenv.env['GOOGLE_WEB_CLIENT_ID'],
        bundledWebClientId,
      );

  static String? _preferFilled(String? envValue, String bundled) {
    if (!isPlaceholder(envValue)) return envValue;
    return bundled;
  }

  static bool isPlaceholder(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return trimmed.contains('YOUR_') ||
        trimmed.toLowerCase().contains('your_google') ||
        trimmed.toLowerCase().startsWith('your_');
  }

  static bool get isIosClientConfigured => !isPlaceholder(iosClientId);

  static bool get canAttemptSignIn {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return isIosClientConfigured && !isPlaceholder(webClientId);
    }
    return !isPlaceholder(webClientId);
  }

  static const notConfiguredHint = 'Google Sign-In is not configured.';

  static const notConfiguredMessage =
      'Google Sign-In is not configured. Copy GoogleService-Info.plist, '
      'set GIDClientID and the reversed URL scheme from that file, and put '
      'GOOGLE_IOS_CLIENT_ID / GOOGLE_WEB_CLIENT_ID in .env (no YOUR_ placeholders).';
}
