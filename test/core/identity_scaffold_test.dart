import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';
import 'package:squad_sync/core/auth_redirect.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/firebase_options.dart';

/// Slice ID reds: identity scaffold constants. No product in this commit.
/// Loop greens later in firebase_options + iOS/Android identity + AASA
/// scaffold only. Do not bump pubspec. DNS for Universal Links is not live
/// — these tests assert scaffold strings, not e2e UL delivery.
///
/// Exact identity strings:
/// - BUNDLE_ID_IOS = com.example.codSquadApp
/// - BUNDLE_ID_ANDROID = com.example.cod_squad_app
/// - APPLE_TEAM_ID = K4ZTXPQ8J9
/// - AASA_HOST = codsquad.app
/// - FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
/// - FIREBASE_ANDROID_APP_ID = 1:756172684661:android:3466d7ce686fff4a70e73c
/// - WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
const kBundleIdIos = 'com.example.codSquadApp';
const kBundleIdAndroid = 'com.example.cod_squad_app';
const kAppleTeamId = 'K4ZTXPQ8J9';
const kAasaHost = 'codsquad.app';
const kFirebaseIosAppId = '1:756172684661:ios:496249d1653a47dc70e73c';
const kFirebaseAndroidAppId =
    '1:756172684661:android:3466d7ce686fff4a70e73c';
const kWidgetBundleId = 'com.example.codSquadApp.PeacockLockWidget';

/// Fake OAuth-looking iOS Firebase app id. Must not remain in identity
/// scaffold. Real id is [kFirebaseIosAppId].
const kFakeOauthLookingIosAppId =
    '1:756172684661:ios:99ecq9sd74qvt9ufs28os52j9g33h1v9';

const _kFirebaseOptionsSrc = 'lib/firebase_options.dart';
const _kAuthRedirectSrc = 'lib/core/auth_redirect.dart';
const _kDeepLinkRoutesSrc = 'lib/core/deep_link_routes.dart';
const _kAndroidGradleSrc = 'android/app/build.gradle.kts';
const _kIosPbxprojSrc = 'ios/Runner.xcodeproj/project.pbxproj';
const _kExportOptionsSrc = 'ios/export_options.plist';
const _kPeacockLockDartSrc = 'lib/services/peacock_lock_live_activity.dart';
const _kPeacockLockSwiftSrc = 'ios/Runner/PeacockLockLiveActivity.swift';

const _kAasaPaths = [
  'ios/associated-domains/apple-app-site-association',
  'web/.well-known/apple-app-site-association',
  'web/apple-app-site-association',
];

String _read(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path missing from identity scaffold');
  return file.readAsStringSync();
}

String _identityScaffoldSource() {
  return [
    _read(_kFirebaseOptionsSrc),
    _read(_kAuthRedirectSrc),
    _read(_kDeepLinkRoutesSrc),
    _read(_kPeacockLockDartSrc),
  ].join('\n');
}

void main() {
  group('Slice ID — Firebase app ids', () {
    test('ios appId is FIREBASE_IOS_APP_ID (not the fake OAuth-looking id)', () {
      expect(
        DefaultFirebaseOptions.ios.appId,
        kFirebaseIosAppId,
        reason: '$_kFirebaseOptionsSrc ios.appId must be $kFirebaseIosAppId. '
            'Do not keep $kFakeOauthLookingIosAppId.',
      );
      expect(
        _read(_kFirebaseOptionsSrc),
        contains(kFirebaseIosAppId),
        reason: '$_kFirebaseOptionsSrc must scaffold FIREBASE_IOS_APP_ID '
            '$kFirebaseIosAppId.',
      );
    });

    test('identity scaffold rejects fake OAuth-looking ios app id', () {
      final firebaseSrc = _read(_kFirebaseOptionsSrc);
      final scaffold = _identityScaffoldSource();
      expect(
        firebaseSrc.contains(kFakeOauthLookingIosAppId),
        isFalse,
        reason: '$_kFirebaseOptionsSrc still has fake OAuth-looking ios id '
            '$kFakeOauthLookingIosAppId. Replace with $kFirebaseIosAppId.',
      );
      expect(
        scaffold.contains(kFakeOauthLookingIosAppId),
        isFalse,
        reason: 'Identity scaffold still has fake OAuth-looking ios id '
            '$kFakeOauthLookingIosAppId. Must be $kFirebaseIosAppId.',
      );
      expect(
        DefaultFirebaseOptions.ios.appId,
        isNot(kFakeOauthLookingIosAppId),
        reason: 'DefaultFirebaseOptions.ios.appId is the fake OAuth-looking id.',
      );
    });

    test('android appId is FIREBASE_ANDROID_APP_ID', () {
      expect(
        DefaultFirebaseOptions.android.appId,
        kFirebaseAndroidAppId,
        reason: '$_kFirebaseOptionsSrc android.appId must be '
            '$kFirebaseAndroidAppId.',
      );
      expect(
        _read(_kFirebaseOptionsSrc),
        contains(kFirebaseAndroidAppId),
      );
    });
  });

  group('Slice ID — bundle + team + widget ids', () {
    test('BUNDLE_ID_IOS is com.example.codSquadApp', () {
      expect(kIosBundleId, kBundleIdIos);
      expect(DefaultFirebaseOptions.ios.iosBundleId, kBundleIdIos);
      final pbx = _read(_kIosPbxprojSrc);
      expect(
        pbx.contains('PRODUCT_BUNDLE_IDENTIFIER = $kBundleIdIos;'),
        isTrue,
        reason: '$_kIosPbxprojSrc Runner PRODUCT_BUNDLE_IDENTIFIER must be '
            '$kBundleIdIos.',
      );
    });

    test('BUNDLE_ID_ANDROID is com.example.cod_squad_app', () {
      final gradle = _read(_kAndroidGradleSrc);
      expect(
        gradle.contains('namespace = "$kBundleIdAndroid"'),
        isTrue,
        reason: '$_kAndroidGradleSrc namespace must be $kBundleIdAndroid.',
      );
      expect(
        gradle.contains('applicationId = "$kBundleIdAndroid"'),
        isTrue,
        reason: '$_kAndroidGradleSrc applicationId must be $kBundleIdAndroid.',
      );
    });

    test('APPLE_TEAM_ID is K4ZTXPQ8J9', () {
      final export = _read(_kExportOptionsSrc);
      expect(
        export.contains('<string>$kAppleTeamId</string>'),
        isTrue,
        reason: '$_kExportOptionsSrc teamID must be $kAppleTeamId.',
      );
      expect(
        _identityScaffoldSource().contains(kAppleTeamId) ||
            export.contains(kAppleTeamId),
        isTrue,
        reason: 'Identity scaffold must record APPLE_TEAM_ID $kAppleTeamId.',
      );
    });

    test('WIDGET_BUNDLE_ID is com.example.codSquadApp.PeacockLockWidget', () {
      final surfaces = [
        _kFirebaseOptionsSrc,
        _kAuthRedirectSrc,
        _kPeacockLockDartSrc,
        _kPeacockLockSwiftSrc,
        _kIosPbxprojSrc,
      ].map(_read).join('\n');
      expect(
        surfaces.contains(kWidgetBundleId),
        isTrue,
        reason: 'Identity scaffold must declare WIDGET_BUNDLE_ID '
            '$kWidgetBundleId (firebase_options / auth_redirect / '
            'PeacockLock widget target).',
      );
    });
  });

  group('Slice ID — AASA host / UL config scaffold (not e2e)', () {
    test('AASA_HOST / UL config scaffolds to codsquad.app', () {
      // Scaffold only. DNS / Apple CDN / device UL delivery is not live.
      // Do not treat a green host string as e2e Universal Links.
      expect(kLobbyUniversalLinkHost, kAasaHost);
      expect(isLobbyUniversalLinkHost(kAasaHost), isTrue);
      expect(isLobbyUniversalLinkHost('www.$kAasaHost'), isTrue);

      final deepLinkSrc = _read(_kDeepLinkRoutesSrc);
      expect(deepLinkSrc.contains("'$kAasaHost'"), isTrue);

      for (final path in _kAasaPaths) {
        final text = _read(path);
        expect(
          text.contains(kAasaHost),
          isTrue,
          reason: '$path must scaffold AASA host $kAasaHost (not e2e UL).',
        );
      }

      final entitlements =
          File('ios/Runner/Runner.entitlements').readAsStringSync();
      expect(
        entitlements.contains('<string>applinks:$kAasaHost</string>'),
        isTrue,
        reason: 'Runner.entitlements must claim applinks:$kAasaHost. '
            'This is UL config scaffold — DNS is not live.',
      );
    });
  });
}
