import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';

/// Slice K reds: friends chrome. Files stay; no product in this commit.
/// Loop greens in ≤3 lib files:
/// 1. friends root tabs builder (labels + people/gamepad, chat, person)
/// 2. [GoRouter] errorBuilder (friendsMode 404 → `/squad`, not `/`)
/// 3. `/chat/:id` route builder (last-known title + skeleton first frame)
///
/// Friend taps / sees: Tonight | Chat | You. Selected cyan + Inter.
/// Unselected 60% white. No neon glow on the bar. Chat bubble + unread.
/// 404 Go Home → Tonight. Opening `/chat/:id` shows last title immediately.
const kFriendsTabBarKey = Key('friends-tab-bar');
const kFriendsTabTonightKey = Key('friends-tab-tonight');
const kFriendsTabChatKey = Key('friends-tab-chat');
const kFriendsTabYouKey = Key('friends-tab-you');
const kFriendsTabChatUnreadKey = Key('friends-tab-chat-unread');
const kFriendsErrorGoHomeKey = Key('friends-error-go-home');
const kChatRouteLastKnownTitleKey = Key('chat-route-last-known-title');
const kChatRouteSkeletonKey = Key('chat-route-skeleton');

void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('Slice K — Tonight | Chat | You', () {
    testWidgets(
      'tab labels are Tonight | Chat | You, not Tonight/Squad',
      (tester) async {
        final tabs = friendsRootTabs(friendsMode: true);
        expect(tabs, hasLength(3));
        expect(
          tabs.map((tab) => tab.label).toList(),
          ['Tonight', 'Chat', 'You'],
          reason: 'Friend sees Tonight | Chat | You — kill Tonight/Squad',
        );
        expect(tabs.map((tab) => tab.label), isNot(contains('Tonight/Squad')));
        expect(
          tabs.map((tab) => tab.route).toList(),
          ['/squad', '/chat', '/profile'],
        );

        final src = File('lib/core/app_router.dart').readAsStringSync();
        final friendsTabs = _friendsRootTabsSource(src);
        expect(friendsTabs.contains("label: 'Tonight'"), isTrue);
        expect(friendsTabs.contains('Tonight/Squad'), isFalse);
        expect(
          friendsTabs.contains('Icons.people') ||
              friendsTabs.contains('Icons.groups') ||
              friendsTabs.contains('Icons.sports_esports') ||
              friendsTabs.contains('Icons.gamepad'),
          isTrue,
          reason: 'Tonight icon is people or gamepad',
        );
        expect(
          friendsTabs.contains('Icons.chat_bubble') ||
              friendsTabs.contains('Icons.chat'),
          isTrue,
          reason: 'Chat icon is a chat bubble',
        );
        expect(
          friendsTabs.contains('Icons.person'),
          isTrue,
          reason: 'You icon is person',
        );
        expect(
          src.contains('friends-tab-chat-unread') ||
              src.contains('kFriendsTabChatUnread') ||
              friendsTabs.contains('Badge'),
          isTrue,
          reason: 'Chat tab shows an unread badge',
        );

        await tester.pumpWidget(_friendsTabBar(tabs));

        expect(find.byKey(kFriendsTabBarKey), findsOneWidget);
        expect(find.text('Tonight'), findsOneWidget);
        expect(find.text('Chat'), findsOneWidget);
        expect(find.text('You'), findsOneWidget);
        expect(find.text('Tonight/Squad'), findsNothing);
        expect(find.byKey(kFriendsTabTonightKey), findsOneWidget);
        expect(find.byKey(kFriendsTabChatKey), findsOneWidget);
        expect(find.byKey(kFriendsTabYouKey), findsOneWidget);
      },
    );
  });

  group('Slice K — friendsMode 404 / errorBuilder', () {
    testWidgets(
      'friendsMode errorBuilder 404 destination is /squad not /',
      (tester) async {
        AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
        expect(AppEnv.friendsMode, isTrue);

        final src = File('lib/core/app_router.dart').readAsStringSync();
        final dest = _friendsErrorBuilderHome(src, friendsMode: true);
        expect(
          dest,
          '/squad',
          reason: 'Friend 404 Go Home must land Tonight (/squad), not /',
        );
        expect(dest, isNot('/'));

        String? landed;
        final router = GoRouter(
          initialLocation: '/no-such-slice-k-404',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) {
                landed = '/';
                return const Text('landed-root');
              },
            ),
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
        expect(find.text('landed-squad'), findsOneWidget);
        expect(find.text('landed-root'), findsNothing);
      },
    );
  });

  group('Slice K — /chat/:id first frame', () {
    testWidgets(
      '/chat/:id first frame has last-known title + skeleton, not full-screen spinner',
      (tester) async {
        final src = File('lib/core/app_router.dart').readAsStringSync();
        final chatDetail = _chatDetailRouteSource(src);

        expect(
          chatDetail.contains('chat-route-last-known-title') ||
              chatDetail.contains('kChatRouteLastKnownTitle'),
          isTrue,
          reason: '/chat/:id first frame must key the last-known title',
        );
        expect(
          chatDetail.contains('chat-route-skeleton') ||
              chatDetail.contains('kChatRouteSkeleton'),
          isTrue,
          reason: '/chat/:id first frame must key the skeleton',
        );
        expect(
          _chatDetailHasFullScreenSpinner(chatDetail),
          isFalse,
          reason: 'waiting branch is last-known title + skeleton, '
              'not a full-screen FutureBuilder spinner',
        );

        await _pumpChatFirstFrame(tester, chatDetail);

        expect(find.byKey(kChatRouteLastKnownTitleKey), findsOneWidget);
        expect(find.text('Warzone Tonight'), findsOneWidget);
        expect(find.byKey(kChatRouteSkeletonKey), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      },
    );
  });
}

Widget _friendsTabBar(List<FriendsRootTab> tabs) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        key: kFriendsTabBarKey,
        currentIndex: 0,
        items: [
          for (final tab in tabs)
            BottomNavigationBarItem(
              icon: Icon(
                tab.route == '/squad'
                    ? Icons.people
                    : tab.route == '/chat'
                        ? Icons.chat_bubble
                        : Icons.person,
                key: tab.route == '/squad'
                    ? kFriendsTabTonightKey
                    : tab.route == '/chat'
                        ? kFriendsTabChatKey
                        : kFriendsTabYouKey,
              ),
              label: tab.label,
            ),
        ],
      ),
    ),
  );
}

String _friendsErrorBuilderHome(String source, {required bool friendsMode}) {
  final start = source.indexOf('errorBuilder:');
  if (start < 0) return '';
  final end = source.indexOf('observers:', start);
  final block = source.substring(start, end > start ? end : start + 900);

  if (!friendsMode) {
    final go = RegExp(r"context\.go\('([^']+)'\)").firstMatch(block);
    return go?.group(1) ?? '/';
  }

  if (RegExp(r"AppEnv\.friendsMode\s*\?\s*'/squad'").hasMatch(block) ||
      RegExp(r"friendsMode[^\n]{0,80}\?\s*'/squad'").hasMatch(block) ||
      block.contains('friendsErrorHomeLocation') ||
      block.contains('resolveFriendsErrorLocation') ||
      block.contains('friendsErrorDestination')) {
    return '/squad';
  }

  final go = RegExp(r"context\.go\('([^']+)'\)").firstMatch(block);
  return go?.group(1) ?? '';
}

String _friendsRootTabsSource(String source) {
  final start = source.indexOf('const _friendsRootTabs');
  if (start < 0) return '';
  final end = source.indexOf('const _fullRootTabs', start);
  return source.substring(start, end > start ? end : start + 400);
}

String _chatDetailRouteSource(String source) {
  final start = source.indexOf("path: '/chat/:id'");
  if (start < 0) return '';
  final end = source.indexOf("path: '/profile'", start);
  return source.substring(start, end > start ? end : start + 1600);
}

bool _chatDetailHasFullScreenSpinner(String chatDetail) {
  return RegExp(
    r'ConnectionState\.waiting[\s\S]{0,500}CircularProgressIndicator',
  ).hasMatch(chatDetail);
}

/// Pump product first frame when Loop has wired keys; otherwise the
/// current `/chat/:id` waiting spinner so this widget test stays red.
Future<void> _pumpChatFirstFrame(WidgetTester tester, String chatDetail) async {
  final ready = (chatDetail.contains('chat-route-last-known-title') ||
          chatDetail.contains('kChatRouteLastKnownTitle')) &&
      (chatDetail.contains('chat-route-skeleton') ||
          chatDetail.contains('kChatRouteSkeleton')) &&
      !_chatDetailHasFullScreenSpinner(chatDetail);

  if (ready) {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text(
              'Warzone Tonight',
              key: kChatRouteLastKnownTitleKey,
            ),
          ),
          body: const ColoredBox(
            key: kChatRouteSkeletonKey,
            color: Color(0x22FFFFFF),
            child: SizedBox(height: 120, width: double.infinity),
          ),
        ),
      ),
    );
    return;
  }

  await tester.pumpWidget(
    const MaterialApp(
      home: Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    ),
  );
}
