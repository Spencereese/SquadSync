import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/auth/data/fake_auth_repository.dart';
import 'package:squadsync/features/auth/domain/auth_user.dart';
import 'package:squadsync/features/push/data/push_notifications.dart';
import 'package:squadsync/features/push/data/push_token_repository.dart';
import 'package:squadsync/features/push/domain/squad_push.dart';

void main() {
  test('a squad message payload parses and anything else is ignored', () {
    expect(
      parseSquadPush({
        'type': 'squad_message',
        'squad_id': ' squad ',
        'message_id': 'msg-1',
      }),
      isA<SquadPush>()
          .having((push) => push.squadId, 'squadId', 'squad')
          .having((push) => push.messageId, 'messageId', 'msg-1'),
    );
    expect(parseSquadPush({'type': 'other', 'squad_id': 'squad'}), isNull);
    expect(
      parseSquadPush({
        'type': 'squad_message',
        'squad_id': '',
        'message_id': 'msg-1',
      }),
      isNull,
    );
    expect(
      parseSquadPush({
        'type': 'squad_message',
        'squad_id': 'squad',
        'message_id': 4,
      }),
      isNull,
    );
  });

  test('routing opens only the signed-in squad', () {
    const push = SquadPush(squadId: 'squad', messageId: 'msg-1');
    expect(
      routeSquadPush(signedIn: false, openSquadId: null, push: push),
      SquadPushRoute.wait,
    );
    expect(
      routeSquadPush(signedIn: true, openSquadId: null, push: push),
      SquadPushRoute.wait,
    );
    expect(
      routeSquadPush(signedIn: true, openSquadId: 'squad', push: push),
      SquadPushRoute.openChat,
    );
    expect(
      routeSquadPush(signedIn: true, openSquadId: 'other', push: push),
      SquadPushRoute.wrongSquad,
    );
  });

  testWidgets('a cold start opens this squad chat and leaves a different one', (
    tester,
  ) async {
    final pushes = FakePushNotifications(
      launch: const SquadPush(squadId: 'squad', messageId: 'msg-9'),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(
            FakeAuthRepository(
              signedIn: const AuthUser(
                id: 'spencer',
                email: 'spencer@example.com',
              ),
            ),
          ),
          pushNotificationsProvider.overrideWithValue(pushes),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push-opened-chat')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsOneWidget);
    expect(find.byKey(const Key('message-list')), findsOneWidget);
    expect(find.byKey(const Key('section-playing')), findsNothing);

    await tester.tap(find.text("Who's on"));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('notifications-off')), findsOneWidget);
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    pushes.deliver(const SquadPush(squadId: 'other', messageId: 'msg-10'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('push-wrong-squad')), findsOneWidget);
    expect(find.byKey(const Key('composer')), findsOneWidget);
  });

  testWidgets('a token registers only when notifications are on', (
    tester,
  ) async {
    final tokens = MemoryPushTokenRepository();
    final pushes = FakePushNotifications(
      availabilityResult: const PushAvailability.on(
        token: 'device-token',
        platform: 'ios',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationsProvider.overrideWithValue(pushes),
          pushTokenRepositoryProvider.overrideWithValue(tokens),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tokens.token, 'device-token');
    expect(tokens.platform, 'ios');
    expect(find.byKey(const Key('notifications-off')), findsNothing);
  });

  testWidgets('the default install stays notifications off', (tester) async {
    final tokens = MemoryPushTokenRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushTokenRepositoryProvider.overrideWithValue(tokens),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tokens.token, isNull);
    expect(find.byKey(const Key('notifications-off')), findsOneWidget);
    expect(find.byKey(const Key('push-opened-chat')), findsNothing);
  });

  testWidgets('a missing Firebase config says it is not set up', (
    tester,
  ) async {
    final tokens = MemoryPushTokenRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationsProvider.overrideWithValue(
            const UnconfiguredPushNotifications(setupMissing: true),
          ),
          pushTokenRepositoryProvider.overrideWithValue(tokens),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(tokens.token, isNull);
    expect(find.byKey(const Key('notifications-not-set-up')), findsOneWidget);
    expect(find.byKey(const Key('notifications-off')), findsNothing);
  });

  testWidgets('a refreshed token is registered again', (tester) async {
    final tokens = MemoryPushTokenRepository();
    final pushes = FakePushNotifications(
      availabilityResult: const PushAvailability.on(
        token: 'device-token',
        platform: 'ios',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pushNotificationsProvider.overrideWithValue(pushes),
          pushTokenRepositoryProvider.overrideWithValue(tokens),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tokens.token, 'device-token');

    pushes.refreshToken(
      const PushAvailability.on(token: 'next-token', platform: 'android'),
    );
    await tester.pumpAndSettle();

    expect(tokens.token, 'next-token');
    expect(tokens.platform, 'android');
  });

  testWidgets('sign-in registers the token and sign-out removes it', (
    tester,
  ) async {
    final tokens = MemoryPushTokenRepository();
    final auth = FakeAuthRepository();
    final pushes = FakePushNotifications(
      availabilityResult: const PushAvailability.on(
        token: 'device-token',
        platform: 'ios',
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appLinkProvider.overrideWithValue(AppLink.live),
          authRepositoryProvider.overrideWithValue(auth),
          pushNotificationsProvider.overrideWithValue(pushes),
          pushTokenRepositoryProvider.overrideWithValue(tokens),
          availabilityTickProvider.overrideWithValue(Duration.zero),
        ],
        child: const SquadSyncApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tokens.token, isNull);

    auth.restore(const AuthUser(id: 'spencer', email: 'spencer@example.com'));
    await tester.pumpAndSettle();
    expect(tokens.token, 'device-token');
    expect(tokens.platform, 'ios');

    await tester.tap(find.byKey(const Key('sign-out')));
    await tester.pumpAndSettle();

    expect(tokens.removedToken, 'device-token');
    expect(tokens.token, isNull);
    expect(pushes.deletedLocal, isTrue);
  });
}
