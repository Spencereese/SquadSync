import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:squad_sync/core/app_env.dart';
import 'package:squad_sync/core/app_router.dart';

/// PIN WAVE — P0 LAST-CHAT LANDING (RED, Tester-owned).
///
/// Chat is home. Kill Tonight (`/squad`) as the default cold-start
/// landing when [AppEnv.friendsMode] is true.
///
/// Reuses [resolveFriendsPostLoginLocation] + GoRouter
/// `initialLocation` / last-chat redirect in `lib/core/app_router.dart`.
/// No new landing API. Keys only on stub routes in this file.
///
/// Contract Loop must implement (do not invent a second resolver):
///
/// 1. Cold start / last-chat landing opens the last group thread
///    (`/chat/{id}`) when `last_chat_group` / [lastChatGroupId] exists —
///    any last group, not only the bound lobby thread.
/// 2. Else opens the Chat tab groups list (`/chat`) — not empty Tonight.
/// 3. Default friendsMode home is **not** empty Tonight `/squad`.
///
/// Loop lease (≤3 under `lib/core/*` only — Tester does not edit):
/// 1. `lib/core/app_router.dart`
///    ([resolveFriendsPostLoginLocation], `initialLocation`, last-chat
///    redirect that reads `last_chat_group`)
///
/// Out of scope: chat_screen / chat_input_bar / chat_info_screen,
/// Tonight-tab feature work, AASA, GATES, merge, pubspec bump.
const kTonightEmptyHomeKey = Key('tonight-empty-home');
const kChatGroupsListKey = Key('chat-groups-list');
const kLastChatThreadKey = Key('last-chat-thread');

void main() {
  setUp(() {
    AppEnv.debugReplaceForTest({'FRIENDS_MODE': 'true'});
  });
  tearDown(() {
    AppEnv.debugReplaceForTest({});
  });

  group('PIN WAVE P0 — friendsMode last-chat landing contract', () {
    test('friendsMode is on for this landing', () {
      expect(AppEnv.friendsMode, isTrue);
    });

    test(
      'last group thread opens even when it is not the bound lobby thread',
      () {
        expect(AppEnv.friendsMode, isTrue);
        expect(
          resolveFriendsPostLoginLocation(
            friendsMode: AppEnv.friendsMode,
            lastChatGroupId: 'group-thread-22',
            boundLobbyThreadId: 'lobby-thread-9',
          ),
          '/chat/group-thread-22',
          reason: 'Any last group thread is home — not bound-lobby-only, '
              'not Tonight /squad.',
        );
        expect(
          resolveFriendsPostLoginLocation(
            friendsMode: true,
            lastChatGroupId: 'random-chat-22',
            boundLobbyThreadId: null,
          ),
          '/chat/random-chat-22',
        );
      },
    );

    test('no last group opens Chat groups list, not empty Tonight /squad', () {
      expect(AppEnv.friendsMode, isTrue);
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: AppEnv.friendsMode,
          lastChatGroupId: null,
          boundLobbyThreadId: null,
        ),
        '/chat',
        reason: 'Fallback is Chat tab / groups list — not empty Tonight.',
      );
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: '  ',
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/chat',
      );
    });

    test('friendsMode default home is never empty Tonight /squad', () {
      expect(AppEnv.friendsMode, isTrue);
      for (final last in <String?>['group-thread-22', null, '', '  ']) {
        final landing = resolveFriendsPostLoginLocation(
          friendsMode: true,
          lastChatGroupId: last,
          boundLobbyThreadId: 'lobby-thread-9',
        );
        expect(
          landing,
          isNot('/squad'),
          reason: 'last=${last ?? 'null'} must not land empty Tonight',
        );
        expect(
          landing.startsWith('/chat'),
          isTrue,
          reason: 'last=${last ?? 'null'} must land Chat thread or list',
        );
      }
    });

    test('friendsMode false still keeps prior last-chat → / fallback', () {
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: false,
          lastChatGroupId: 'random-chat-22',
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/chat/random-chat-22',
      );
      expect(
        resolveFriendsPostLoginLocation(
          friendsMode: false,
          lastChatGroupId: null,
          boundLobbyThreadId: 'lobby-thread-9',
        ),
        '/',
      );
    });
  });

  group('PIN WAVE P0 — GoRouter initialLocation / last-chat redirect', () {
    test(
      'friendsMode GoRouter initialLocation is Chat home, not /squad',
      () {
        expect(AppEnv.friendsMode, isTrue);
        final src = File('lib/core/app_router.dart').readAsStringSync();
        expect(
          src.contains("initialLocation: AppEnv.friendsMode ? '/squad'"),
          isFalse,
          reason: 'Chat is home. Kill Tonight as default cold-start landing.',
        );

        final loc = friendsModeRouterInitialLocation(src);
        if (loc != null) {
          expect(loc, isNot('/squad'));
          expect(
            loc,
            anyOf('/chat', '/'),
            reason: 'friendsMode initialLocation must be Chat home '
                '(/chat) or / that last-chat-redirects — not /squad.',
          );
        } else {
          expect(
            src.contains('resolveFriendsPostLoginLocation') ||
                src.contains('friendsColdStartLocation') ||
                src.contains('friendsHomeLocation'),
            isTrue,
            reason: 'If initialLocation is not a literal, it must call '
                'the last-chat landing helper.',
          );
        }
      },
    );

    test(
      'last-chat redirect still reads last_chat_group and the landing helper',
      () {
        final src = File('lib/core/app_router.dart').readAsStringSync();
        expect(src.contains("getString('last_chat_group')"), isTrue);
        expect(src.contains('resolveFriendsPostLoginLocation'), isTrue);

        // Hard-wired /squad never hits last-chat (redirect is on `/`).
        final initialIsSquad =
            src.contains("initialLocation: AppEnv.friendsMode ? '/squad'");
        final redirectsBareSquad = RegExp(
          r"matchedLocation\s*==\s*'/squad'",
        ).hasMatch(src);
        expect(
          initialIsSquad && !redirectsBareSquad,
          isFalse,
          reason: 'friendsMode /squad initialLocation skips last-chat. '
              'Chat must be home, or bare /squad must redirect.',
        );
      },
    );
  });

  group('PIN WAVE P0 — widget/router cold start', () {
    testWidgets(
      'cold start with last group opens that thread, not empty Tonight',
      (tester) async {
        expect(AppEnv.friendsMode, isTrue);
        const last = 'group-thread-22';
        final landing = resolveFriendsPostLoginLocation(
          friendsMode: AppEnv.friendsMode,
          lastChatGroupId: last,
          boundLobbyThreadId: 'lobby-thread-9',
        );
        expect(landing, '/chat/$last');
        expect(landing, isNot('/squad'));

        String? landed;
        final router = GoRouter(
          initialLocation: landing,
          routes: [
            GoRoute(
              path: '/squad',
              builder: (_, __) {
                landed = '/squad';
                return const Text(
                  'landed-tonight',
                  key: kTonightEmptyHomeKey,
                );
              },
            ),
            GoRoute(
              path: '/chat',
              builder: (_, __) {
                landed = '/chat';
                return const Text(
                  'landed-groups',
                  key: kChatGroupsListKey,
                );
              },
            ),
            GoRoute(
              path: '/chat/:id',
              builder: (context, state) {
                landed = '/chat/${state.pathParameters['id']}';
                return Text(
                  'landed-thread:${state.pathParameters['id']}',
                  key: kLastChatThreadKey,
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(landed, '/chat/$last');
        expect(find.byKey(kLastChatThreadKey), findsOneWidget);
        expect(find.byKey(kTonightEmptyHomeKey), findsNothing);
        expect(find.text('landed-tonight'), findsNothing);
      },
    );

    testWidgets(
      'cold start with no last group opens Chat list, not empty Tonight',
      (tester) async {
        expect(AppEnv.friendsMode, isTrue);
        final landing = resolveFriendsPostLoginLocation(
          friendsMode: AppEnv.friendsMode,
          lastChatGroupId: null,
          boundLobbyThreadId: null,
        );
        expect(landing, '/chat');
        expect(landing, isNot('/squad'));

        String? landed;
        final router = GoRouter(
          initialLocation: landing,
          routes: [
            GoRoute(
              path: '/squad',
              builder: (_, __) {
                landed = '/squad';
                return const Text(
                  'landed-tonight',
                  key: kTonightEmptyHomeKey,
                );
              },
            ),
            GoRoute(
              path: '/chat',
              builder: (_, __) {
                landed = '/chat';
                return const Text(
                  'landed-groups',
                  key: kChatGroupsListKey,
                );
              },
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();

        expect(landed, '/chat');
        expect(find.byKey(kChatGroupsListKey), findsOneWidget);
        expect(find.byKey(kTonightEmptyHomeKey), findsNothing);
        expect(find.text('landed-tonight'), findsNothing);
      },
    );
  });
}

/// Literal friendsMode `initialLocation` from [app_router.dart], if any.
String? friendsModeRouterInitialLocation(String source) {
  final ternary = RegExp(
    r"initialLocation:\s*AppEnv\.friendsMode\s*\?\s*'([^']+)'",
  ).firstMatch(source);
  return ternary?.group(1);
}
