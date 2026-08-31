import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Google Sign-In must fail closed while Info.plist / .env still have
/// YOUR_ placeholders. Real client IDs stay out of git.
class GoogleAuthConfig {
  GoogleAuthConfig._();

  static String? get iosClientId => dotenv.env['GOOGLE_IOS_CLIENT_ID'];

  static String? get webClientId => dotenv.env['GOOGLE_WEB_CLIENT_ID'];

  static bool isPlaceholder(String? value) {
    if (value == null) return true;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return trimmed.contains('YOUR_') ||
        trimmed.toLowerCase().contains('your_google') ||
        trimmed.toLowerCase().startsWith('your_');
  }

  /// iOS Google Sign-In cannot succeed until Spencer pastes a real
  /// GOOGLE_IOS_CLIENT_ID and matching Info.plist GIDClientID / URL scheme.
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
