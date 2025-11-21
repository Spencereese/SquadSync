import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgoraConfig {
  static String get appId {
    final id = dotenv.env['AGORA_APP_ID'] ?? '';
    if (id.isEmpty && kDebugMode) {
      throw Exception('AGORA_APP_ID is not set in .env file');
    }
    return id;
  }

  static String get appCertificate {
    final cert = dotenv.env['AGORA_APP_CERTIFICATE'] ?? '';
    if (cert.isEmpty && kDebugMode) {
      throw Exception('AGORA_APP_CERTIFICATE is not set in .env file');
    }
    return cert;
  }
}