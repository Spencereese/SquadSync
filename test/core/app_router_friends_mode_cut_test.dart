import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';

/// Slice CUT 4A reds: friendsMode compile-out. Files stay; no product
/// in this commit. Loop greens later in friends shell entrypoints only:
/// 1. [app_router] friends route table + compile-out allowlist
/// 2. [tonight_home] / [lobby_tab_screen] import lease
/// 3. main friends shell (`lib/main.dart`, `lib/widgets/app_widgets.dart`)
///
/// When [AppEnv.friendsMode] is true (default):
/// 1. Root tabs are exactly Tonight | Chat | You
/// 2. Discovery, constitution voting, Grok assistant thread, poll
///    history / poll create are not registered (404 or absent).
///    404 Go Home lands `/squad`
/// 3. Friends entrypoints do not import those compile-out modules
/// 4. `friendsMode == false` still builds the prior full shell
///    (do not delete production files in RED)
///
/// Builder: add `// Slice CUT: friendsMode compile-out` on
/// `lib/core/app_router.dart`. Do not bump pubspec. Do not delete files.
const kCutCompileOutAllowlistNeedle = 'Slice CUT: friendsMode compile-out';

const kFriendsErrorGoHomeKey = Key('friends-error-go-home');

const kCutCompileOutPaths = <String>[
  '/discover-swipe',
  '/constitution',
  '/constitution/vote',
  '/grok',
  '/grok/assistant',
  '/poll/history',
  '/poll/create',
];

const kFriendsEntrypoints = <String>[
  'lib/core/app_router.dart',
  'lib/screens/tonight_home.dart',
  'lib/screens/lobby_tab_screen.dart',
  'lib/main.dart',
  'lib/widgets/app_widgets.dart',
];

const kForbiddenImportNeedles = <String>[
  'discovery_notifier',
  'discovery_screen',
  'discovery_swipe_screen',
  'constitution_voting_sheet',
  'grok_message_bubble',
  'grok_service',
  'poll_creation_dialog',
  'poll_history_screen',
];

const kFullShellFilesStay = <String>[
  'lib/screens/discovery_swipe_screen.dart',
  'lib/screens/discovery_screen.dart',
  'lib/presentation/notifiers/discovery_notifier.dart',
  'lib/chat/dialogs/constitution_voting_sheet.dart',
  'lib/chat/widgets/grok_message_bubble.dart',
  'lib/services/grok_service.dart',
  'lib/chat/poll_creation_dialog.dart',
  'lib/chat/poll_history_screen.dart',
];

String _read(String path) => File(path).readAsStringSync();

/// Import URIs only (comments / strings do not count).
List<String> _importUris(String source) {
  return RegExp(
    r'''^import\s+['"]([^'"]+)['"]''',
    multiLine: true,
  ).allMatches(source).map((match) => match.group(1)!).toList();
}

bool _uriHitsNeedle(String uri, String needle) {
  final base = uri.split('/').last;
  return base == needle ||
      base == '$needle.dart' ||
      uri.endsWith('/$needle.dart') ||
      uri.endsWith('/$needle');
}

List<String> _forbiddenImportsIn(String source) {
  final hits = <String>[];
  for (final uri in _importUris(source)) {
    for (final needle in kForbiddenImportNeedles) {
      if (_uriHitsNeedle(uri, needle)) {
        hits.add(uri);
        break;
      }
    }
  }
  return hits;
}

/// A GoRoute path is friendsMode-registered unless it sits behind
/// `if (!AppEnv.friendsMode)` / `if (!friendsMode)`.
bool _pathRegisteredInFriendsMode(String source, String path) {
  final pattern = "path: '$path'";
  var from = 0;
  var found = false;
  while (true) {
    final idx = source.indexOf(pattern, from);
    if (idx < 0) return found;
    found = true;
    final windowStart = idx < 500 ? 0 : idx - 500;
    final window = source.substring(windowStart, idx);
    final gated = RegExp(
          r'if\s*\(\s*!\s*(?:AppEnv\.)?friendsMode\b',
        ).hasMatch(window) ||
        window.contains('friendsCompiledOutLocations') ||
        window.contains('friendsModeCompiledOut');
    if (!gated) return true;
    from = idx + pattern.length;
  }
}

List<String> _leakedFriendsRoutes(String source) {
  return kCutCompileOutPaths
      .where((path) => _pathRegisteredInFriendsMode(source, path))
      .toList();
}

void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('Slice CUT — friendsMode default + tabs', () {
    test('AppEnv.friendsMode defaults true', () {
      AppEnv.debugReplaceForTest({});
      expect(AppEnv.friendsMode, isTrue);
    });

    test('friends root tabs are exactly Tonight | Chat | You', () {
      expect(AppEnv.friendsMode, isTrue);
      final tabs = friendsRootTabs(friendsMode: AppEnv.friendsMode);
      expect(tabs, hasLength(3));
      expect(
        tabs.map((tab) => tab.label).toList(),
        ['Tonight', 'Chat', 'You'],
      );
      expect(
        tabs.map((tab) => tab.route).toList(),
        ['/squad', '/chat', '/profile'],
      );
    });
  });

  group('Slice CUT — compile-out allowlist + routes 404', () {
    test('app_router records the Slice CUT compile-out allowlist', () {
      final src = _read('lib/core/app_router.dart');
      expect(
        src.contains(kCutCompileOutAllowlistNeedle),
        isTrue,
        reason: 'Budget file is missing the Slice CUT allowlist comment. '
            'Builder: add `// $kCutCompileOutAllowlistNeedle` to '
            'lib/core/app_router.dart. Then stop registering Discovery / '
            'constitution / Grok / poll routes when friendsMode is true.',
      );
    });

    test(
      'friendsMode does not register Discovery / constitution / Grok / poll',
      () {
        expect(AppEnv.friendsMode, isTrue);
        final src = _read('lib/core/app_router.dart');
        final leaked = _leakedFriendsRoutes(src);
        expect(
          leaked,
          isEmpty,
          reason: 'friendsMode must not register $leaked '
              '(404 or absent — not a redirect). '
              'Discovery, constitution voting, Grok assistant thread, '
              'poll history / poll create compile out of the Friends IPA.',
        );
      },
    );

    testWidgets(
      'compile-out routes 404 and Go Home lands /squad',
      (tester) async {
        AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
        expect(AppEnv.friendsMode, isTrue);

        final src = _read('lib/core/app_router.dart');
        final leaked = _leakedFriendsRoutes(src);
        expect(
          leaked,
          isEmpty,
          reason: 'still registered under friendsMode: $leaked',
        );

        String? landed;
        var saw404 = false;
        final dest = friendsErrorHomeLocation(friendsMode: true);
        expect(dest, '/squad');

        final router = GoRouter(
          initialLocation: '/discover-swipe',
          routes: [
            GoRoute(
              path: '/squad',
              builder: (_, __) {
                landed = '/squad';
                return const Text('landed-squad');
              },
            ),
            GoRoute(
              path: '/',
              builder: (_, __) {
                landed = '/';
                return const Text('landed-root');
              },
            ),
            for (final path in leaked)
              GoRoute(
                path: path,
                builder: (_, __) => Text('leaked-$path'),
              ),
          ],
          errorBuilder: (context, state) {
            saw404 = true;
            return Scaffold(
              body: ElevatedButton(
                key: kFriendsErrorGoHomeKey,
                onPressed: () => context.go(dest),
                child: const Text('Go Home'),
              ),
            );
          },
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();

        expect(saw404, isTrue, reason: '/discover-swipe must 404, not render');
        expect(find.textContaining('leaked-'), findsNothing);
        expect(find.byKey(kFriendsErrorGoHomeKey), findsOneWidget);

        await tester.tap(find.byKey(kFriendsErrorGoHomeKey));
        await tester.pumpAndSettle();

        expect(landed, '/squad');
        expect(find.text('landed-squad'), findsOneWidget);
        expect(find.text('landed-root'), findsNothing);
      },
    );

    testWidgets(
      'constitution / Grok / poll paths 404 and Go Home lands /squad',
      (tester) async {
        expect(AppEnv.friendsMode, isTrue);
        final src = _read('lib/core/app_router.dart');
        for (final path in const [
          '/constitution/vote',
          '/grok/assistant',
          '/poll/history',
          '/poll/create',
        ]) {
          expect(
            _pathRegisteredInFriendsMode(src, path),
            isFalse,
            reason: '$path must be 404 or absent under friendsMode',
          );
        }

        String? landed;
        final dest = friendsErrorHomeLocation(friendsMode: true);
        final router = GoRouter(
          initialLocation: '/constitution/vote',
          routes: [
            GoRoute(
              path: '/squad',
              builder: (_, __) {
                landed = '/squad';
                return const Text('landed-squad');
              },
            ),
          ],
          errorBuilder: (context, state) => Scaffold(
            body: ElevatedButton(
              key: kFriendsErrorGoHomeKey,
              onPressed: () => context.go(dest),
              child: const Text('Go Home'),
            ),
          ),
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pump();
        expect(find.byKey(kFriendsErrorGoHomeKey), findsOneWidget);
        await tester.tap(find.byKey(kFriendsErrorGoHomeKey));
        await tester.pumpAndSettle();
        expect(landed, '/squad');
      },
    );
  });

  group('Slice CUT — import lease on friends entrypoints', () {
    test(
      'friendsMode entrypoints do not import compile-out modules',
      () {
        expect(AppEnv.friendsMode, isTrue);
        final leaks = <String, List<String>>{};
        for (final path in kFriendsEntrypoints) {
          expect(File(path).existsSync(), isTrue, reason: path);
          final hits = _forbiddenImportsIn(_read(path));
          if (hits.isNotEmpty) leaks[path] = hits;
        }
        expect(
          leaks,
          isEmpty,
          reason: 'friendsMode entrypoints must not import '
              'discovery_notifier / discovery screens, '
              'constitution_voting_sheet, grok_message_bubble / grok_service, '
              'or poll_creation_dialog / poll_history_screen. '
              'Leaked: $leaks',
        );
      },
    );
  });

  group('Slice CUT — friendsMode false keeps the prior full shell', () {
    test('gated surface files stay on disk (do not delete in RED)', () {
      for (final path in kFullShellFilesStay) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    });

    test('full root tabs and Discovery route still exist', () {
      final tabs = friendsRootTabs(friendsMode: false);
      expect(tabs.length, greaterThan(3));
      expect(
        tabs.map((tab) => tab.route),
        containsAll(['/', '/discover-swipe', '/squad', '/chat', '/profile']),
      );
      expect(
        tabs.map((tab) => tab.label),
        contains('Discover'),
      );

      final src = _read('lib/core/app_router.dart');
      expect(src.contains("path: '/discover-swipe'"), isTrue);
      expect(
        friendsGatesSurface(
          FriendsGatedSurface.discovery,
          friendsMode: false,
        ),
        isFalse,
      );
    });
  });
}
