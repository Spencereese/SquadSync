import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/services/agora_config.dart';
import 'package:squad_sync/services/voice_service.dart';

void main() {
  test('placeholder SUPABASE_URL is rejected', () {
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_URL',
        'https://your-project.supabase.co',
      ),
      isTrue,
    );
    expect(isPlaceholderEnvValue('SUPABASE_URL', ''), isTrue);
    expect(isPlaceholderEnvValue('SUPABASE_URL', null), isTrue);
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_ANON_KEY',
        'your_anon_key',
      ),
      isTrue,
    );
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_URL',
        'https://abcxyz.supabase.co',
      ),
      isFalse,
    );
  });

  test('dart-define wins over .env.example placeholder', () {
    final merged = mergeEnvLayers(
      asset: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
        'SUPABASE_ANON_KEY': 'your_anon_key',
      },
      dartDefines: const {
        'SUPABASE_URL': 'https://real-project.supabase.co',
        'SUPABASE_ANON_KEY': 'eyJhbGciOi.real',
      },
    );

    expect(merged['SUPABASE_URL'], 'https://real-project.supabase.co');
    expect(merged['SUPABASE_ANON_KEY'], 'eyJhbGciOi.real');
    expect(
      isPlaceholderEnvValue('SUPABASE_URL', merged['SUPABASE_URL']),
      isFalse,
    );
  });

  test('parked URL is not Supabase-configured', () {
    AppEnv.debugReplaceForTest({
      'SUPABASE_URL': 'https://your-project.supabase.co',
      'SUPABASE_ANON_KEY': 'your_anon_key',
    });
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    expect(AppEnv.isSupabaseConfigured, isFalse);
    expect(
      isPlaceholderEnvValue('SUPABASE_URL', AppEnv.supabaseUrl),
      isTrue,
    );
  });

  test('placeholder dart-define does not overwrite a real file .env', () {
    final merged = mergeEnvLayers(
      asset: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
      },
      file: const {
        'SUPABASE_URL': 'https://from-file.supabase.co',
      },
      dartDefines: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
      },
    );

    expect(merged['SUPABASE_URL'], 'https://from-file.supabase.co');
  });

  test('unset client secrets do not throw on cold path', () async {
    AppEnv.debugReplaceForTest({});
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    expect(() => AppEnv.get('TWITCH_CLIENT_SECRET'), returnsNormally);
    expect(() => AppEnv.get('IGDB_CLIENT_SECRET'), returnsNormally);
    expect(() => AppEnv.get('AGORA_APP_CERTIFICATE'), returnsNormally);
    expect(() => AppEnv.get('XAI_API_KEY'), returnsNormally);
    expect(() => AppEnv.dartDefineOverlay(), returnsNormally);

    expect(AppEnv.get('TWITCH_CLIENT_SECRET'), isNull);
    expect(AppEnv.get('IGDB_CLIENT_SECRET'), isNull);
    expect(AppEnv.get('AGORA_APP_CERTIFICATE'), isNull);
    expect(AppEnv.get('XAI_API_KEY'), isNull);
    expect(AppEnv.twitchClientSecret, isNull);
    expect(AppEnv.igdbClientSecret, isNull);
    expect(AppEnv.agoraAppCertificate, isNull);
    expect(AppEnv.xaiApiKey, isNull);
    expect(AppEnv.isTwitchSecretConfigured, isFalse);
    expect(AppEnv.isIgdbSecretConfigured, isFalse);
    expect(AppEnv.isAgoraConfigured, isFalse);
    expect(AppEnv.isAgoraCertificateConfigured, isFalse);
    expect(AppEnv.isXaiConfigured, isFalse);

    await AppEnv.load();
    expect(AppEnv.isTwitchSecretConfigured, isFalse);
    expect(AppEnv.isIgdbSecretConfigured, isFalse);
    expect(AppEnv.isAgoraCertificateConfigured, isFalse);
    expect(AppEnv.isXaiConfigured, isFalse);
  });

  test('placeholder client secrets are treated as unset', () {
    AppEnv.debugReplaceForTest({
      'TWITCH_CLIENT_SECRET': 'YOUR_TWITCH_CLIENT_SECRET',
      'IGDB_CLIENT_SECRET': 'your_igdb_client_secret',
      'AGORA_APP_ID': 'YOUR_AGORA_APP_ID',
      'AGORA_APP_CERTIFICATE': 'YOUR_AGORA_APP_CERTIFICATE',
      'XAI_API_KEY': 'xai-YOUR_ACTUAL_XAI_API_KEY_HERE',
    });
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    expect(AppEnv.twitchClientSecret, isNull);
    expect(AppEnv.igdbClientSecret, isNull);
    expect(AppEnv.agoraAppId, isNull);
    expect(AppEnv.agoraAppCertificate, isNull);
    expect(AppEnv.xaiApiKey, isNull);
    expect(AppEnv.isTwitchSecretConfigured, isFalse);
    expect(AppEnv.isIgdbSecretConfigured, isFalse);
    expect(AppEnv.isAgoraConfigured, isFalse);
    expect(AppEnv.isAgoraCertificateConfigured, isFalse);
    expect(AppEnv.isXaiConfigured, isFalse);
  });

  test('AppEnv.friendsMode reads FRIENDS_MODE dart-define and defaults true',
      () {
    AppEnv.debugReplaceForTest({});
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    // Unset / empty → Friends IPA on. Loop adds AppEnv.friendsMode and
    // FRIENDS_MODE to dartDefineOverlay (String.fromEnvironment).
    expect(AppEnv.friendsMode, isTrue);

    AppEnv.debugReplaceForTest(mergeEnvLayers(
      dartDefines: const {'FRIENDS_MODE': 'true'},
    ));
    expect(AppEnv.friendsMode, isTrue);

    AppEnv.debugReplaceForTest(mergeEnvLayers(
      dartDefines: const {'FRIENDS_MODE': 'false'},
    ));
    expect(AppEnv.friendsMode, isFalse);

    AppEnv.debugReplaceForTest({'FRIENDS_MODE': ''});
    expect(AppEnv.friendsMode, isTrue);

    AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'FALSE'});
    expect(AppEnv.friendsMode, isFalse);
  });

  test('AgoraConfig unset secrets fail soft (no throw)', () {
    AppEnv.debugReplaceForTest({});
    addTearDown(() => AppEnv.debugReplaceForTest({}));

    expect(() => AgoraConfig.appId, returnsNormally);
    expect(() => AgoraConfig.appCertificate, returnsNormally);
    expect(AgoraConfig.appId, isEmpty);
    expect(AgoraConfig.appCertificate, isEmpty);
    expect(AgoraConfig.isConfigured, isFalse);
    expect(AgoraConfig.isCertificateConfigured, isFalse);

    expect(() => AgoraConfigEnhanced.getValidatedAppId(), returnsNormally);
    expect(() => AgoraConfigEnhanced.getValidatedCertificate(), returnsNormally);
    final appId = AgoraConfigEnhanced.getValidatedAppId();
    expect(appId.isFailure, isTrue);
    expect(appId.error, VoiceServiceError.configMissing);
    final cert = AgoraConfigEnhanced.getValidatedCertificate();
    expect(cert.isSuccess, isTrue);
    expect(cert.data, isEmpty);
  });
}
