import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_links_policy.dart';
import 'package:squad_sync/core/auth_redirect.dart';
import 'package:squad_sync/core/deep_link_routes.dart';
import 'package:squad_sync/firebase_options.dart';

/// Slice ID + Slice AASA-HOST reds: identity scaffold constants.
/// No product in this commit. Loop greens AASA_HOST to the Firebase
/// Hosting host (`cod-squad-a4c62.web.app`) in auth_redirect, AASA
/// copies, and Associated Domains. Do not bump pubspec. DNS / UL e2e
/// is not live — these tests assert scaffold strings only.
///
/// Exact identity strings:
/// - BUNDLE_ID_IOS = com.example.codSquadApp
/// - BUNDLE_ID_ANDROID = com.example.cod_squad_app
/// - APPLE_TEAM_ID = K4ZTXPQ8J9
/// - AASA_HOST = cod-squad-a4c62.web.app
///   (Firebase Hosting from firebase_options projectId `cod-squad-a4c62`)
/// - FIREBASE_IOS_APP_ID = 1:756172684661:ios:496249d1653a47dc70e73c
/// - FIREBASE_ANDROID_APP_ID = 1:756172684661:android:3466d7ce686fff4a70e73c
/// - WIDGET_BUNDLE_ID = com.example.codSquadApp.PeacockLockWidget
const kBundleIdIos = 'com.example.codSquadApp';
const kBundleIdAndroid = 'com.example.cod_squad_app';
const kAppleTeamId = 'K4ZTXPQ8J9';
const kAasaHost = 'cod-squad-a4c62.web.app';
const kRetiredAasaHost = 'codsquad.app';
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

const _kAssociatedDomainsEntitlements = [
  'ios/associated-domains/associated-domains.entitlements',
  'ios/Runner/Runner.entitlements',
];

/// Identity / AASA / Associated Domains / auth_redirect scaffold only.
/// Do not scan lobby-share parsers or docs — leftover `codsquad.app` here
/// is a hard fail for Slice AASA-HOST.
const _kAasaHostScaffoldPaths = [
  _kAuthRedirectSrc,
  ..._kAasaPaths,
  ..._kAssociatedDomainsEntitlements,
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

  group('Slice AASA-HOST — Firebase Hosting host (not e2e)', () {
    test('AASA_HOST / UL config scaffolds to $kAasaHost', () {
      // Scaffold only. DNS / Apple CDN / device UL delivery is not live.
      // Do not treat a green host string as e2e Universal Links.
      // Lead: AASA_HOST is Firebase Hosting from projectId, not the
      // retired custom domain.
      expect(
        '${DefaultFirebaseOptions.ios.projectId}.web.app',
        kAasaHost,
        reason: 'AASA_HOST must be <firebase_options projectId>.web.app.',
      );
      expect(kLobbyUniversalLinkHost, kAasaHost);
      expect(isLobbyUniversalLinkHost(kAasaHost), isTrue);

      final deepLinkSrc = _read(_kDeepLinkRoutesSrc);
      expect(deepLinkSrc.contains("'$kAasaHost'"), isTrue);

      final authRedirect = _read(_kAuthRedirectSrc);
      expect(
        authRedirect.contains(kAasaHost),
        isTrue,
        reason: '$_kAuthRedirectSrc must scaffold AASA_HOST = $kAasaHost.',
      );

      for (final path in _kAasaPaths) {
        final text = _read(path);
        expect(
          text.contains(kAasaHost),
          isTrue,
          reason: '$path must scaffold AASA host $kAasaHost (not e2e UL).',
        );
      }

      for (final path in _kAssociatedDomainsEntitlements) {
        final entitlements = _read(path);
        expect(
          entitlements.contains('<string>applinks:$kAasaHost</string>'),
          isTrue,
          reason: '$path must claim applinks:$kAasaHost. '
              'This is UL config scaffold — DNS is not live.',
        );
      }
    });

    test('AASA host copies stay identical (web + ios associated-domains)', () {
      String? canonical;
      for (final path in _kAasaPaths) {
        final text = _read(path);
        canonical ??= text;
        expect(text, canonical, reason: '$path drifted from canonical AASA');
        expect(
          text.contains(kAasaHost),
          isTrue,
          reason: '$path must use AASA_HOST = $kAasaHost.',
        );
      }
    });

    test('identity / AASA / Associated Domains / auth_redirect reject '
        'retired host $kRetiredAasaHost', () {
      for (final path in _kAasaHostScaffoldPaths) {
        final text = _read(path);
        expect(
          text.contains(kRetiredAasaHost),
          isFalse,
          reason: '$path still has retired AASA host $kRetiredAasaHost. '
              'Loop must green host to $kAasaHost.',
        );
      }
    });

    test('AASA appIDs are APPLE_TEAM_ID.BUNDLE_ID_IOS (no TEAMID placeholder)',
        () {
      final expected = '$kAppleTeamId.$kBundleIdIos';
      for (final path in _kAasaPaths) {
        final text = _read(path);
        expect(
          text.contains('TEAMID.com.example.codSquadApp'),
          isFalse,
          reason: '$path still has TEAMID placeholder. Host $expected.',
        );
        expect(
          text.contains(expected),
          isTrue,
          reason: '$path must use $expected.',
        );
      }
    });
  });
}
