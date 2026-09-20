import '../core/app_env.dart';

/// Agora IDs/certs for voice. Unset or placeholder values never throw —
/// callers must treat empty as "voice parked".
class AgoraConfig {
  static String get appId => AppEnv.agoraAppId ?? '';

  static String get appCertificate => AppEnv.agoraAppCertificate ?? '';

  static bool get isConfigured => AppEnv.isAgoraConfigured;

  static bool get isCertificateConfigured =>
      AppEnv.isAgoraCertificateConfigured;
}
