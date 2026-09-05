import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/screens/components/chat_info_app_bar.dart';
import 'package:squad_sync/chat/screens/components/chat_info_actions.dart';
import 'package:squad_sync/chat/screens/components/chat_info_members.dart';
import 'package:squad_sync/chat/screens/components/chat_info_widgets.dart';
import 'package:squad_sync/chat/screens/components/chat_info_settings.dart';
import 'package:squad_sync/chat/screens/components/chat_info_backgrounds.dart';
import 'package:squad_sync/chat/screens/components/chat_info_media.dart';
import 'package:squad_sync/chat/screens/components/chat_info_links_files.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart';
import 'package:squad_sync/services/availability_on.dart';
import 'package:squad_sync/services/matchmaking_queue_machine.dart';
import 'package:squad_sync/services/presence_badges.dart';
import 'package:squad_sync/widgets/presence_badge_row.dart';

void main() {
  group('ChatInfoAppBar', () {
    testWidgets('renders with required properties',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: ChatInfoAppBar(
              squadId: 'test-squad',
              squadName: 'Test Squad',
              avatarUrl: null, // Avoid network image loading
              neonColor: Colors.blue,
              onEditPressed: () {},
            ),
          ),
        ),
      );

      // Pump extra frames to settle flutter_animate timers
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(find.text('Test Squad'), findsOneWidget);
      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    test('implements PreferredSizeWidget with height 160', () {
      final appBar = ChatInfoAppBar(
        squadId: 'test-squad',
        squadName: 'Test Squad',
        neonColor: Colors.blue,
        onEditPressed: () {},
      );

      expect(appBar.preferredSize.height, 160.0);
    });
  });

  group('Tonight strip grouping', () {
    test('I am on / Looking for Squad / Invite are Tonight; Voice+Video More',
        () {
      expect(
          slotForTonightAction(kTonightOnNowAction), TonightStripSlot.tonight);
      expect(
        slotForTonightAction(kTonightLookingForSquadAction),
        TonightStripSlot.tonight,
      );
      expect(
          slotForTonightAction(kTonightInviteAction), TonightStripSlot.tonight);
      expect(slotForTonightAction(kMoreVoiceAction), TonightStripSlot.more);
      expect(slotForTonightAction(kMoreVideoAction), TonightStripSlot.more);
    });

    test('Search is omitted until it searches', () {
      expect(slotForTonightAction(kDeadSearchAction), isNull);
      expect(slotForTonightAction('search'), isNull);
    });

    test('tonightStripChildren keeps product order', () {
      const onNow = Text('on');
      const lfg = Text('lfg');
      const invite = Text('inv');
      final children = tonightStripChildren(
        onNow: onNow,
        lookingForSquad: lfg,
        invite: invite,
      );
      expect(children, [onNow, lfg, invite]);
    });

    test('resolveInviteLobbyId prefers lobby bound to squad', () {
      final bound = Lobby.create(
        name: 'Bound',
        gameName: 'Warzone',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(id: 'lobby-bound', chatGroupId: 'squad-1');
      final other = Lobby.create(
        name: 'Other',
        gameName: 'Warzone',
        maxSpots: 4,
        createdBy: 'u1',
      ).copyWith(id: 'lobby-other');
      expect(
        resolveInviteLobbyId(
          squadId: 'squad-1',
          selectedLobbyId: 'lobby-other',
          currentLobby: other,
          userLobbies: {'lobby-bound': bound, 'lobby-other': other},
        ),
        'lobby-bound',
      );
    });

    test('resolveInviteLobbyId falls back to squadId', () {
      expect(
        resolveInviteLobbyId(squadId: 'squad-1'),
        'squad-1',
      );
    });
  });

  group('ChatInfoActionsSection', () {
    setUp(MatchmakingQueueTracker.resetInstance);
    tearDown(MatchmakingQueueTracker.resetInstance);

    Future<void> pumpActions(WidgetTester tester) {
      return tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: ChatInfoActionsSection(
                  squadId: 'test-squad',
                  squadName: 'Test Squad',
                  neonColor: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Tonight block shows I am on, Looking for Squad, Invite',
        (WidgetTester tester) async {
      await pumpActions(tester);

      expect(find.byKey(const Key('tonight-actions')), findsOneWidget);
      expect(find.text('Tonight'), findsOneWidget);
      expect(find.text("I'm on now"), findsOneWidget);
      expect(find.text('Looking for Squad'), findsOneWidget);
      expect(find.text('Invite'), findsOneWidget);
    });

    testWidgets('Grok concierge is three commands with no free-chat field',
        (WidgetTester tester) async {
      await pumpActions(tester);

      expect(find.byKey(const Key('grok-concierge')), findsOneWidget);
      expect(find.text("Who's free tonight?"), findsOneWidget);
      expect(find.text('Summarize this lobby chat since 8pm'), findsOneWidget);
      expect(find.text('Draft a peacock invite'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    });

    testWidgets('Search entry is gone (no coming-soon snackbar)',
        (WidgetTester tester) async {
      await pumpActions(tester);

      expect(find.text('Search'), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.text('Search feature coming soon!'), findsNothing);

      await tester.tap(find.text('More'));
      await tester.pump();

      expect(find.text('Search'), findsNothing);
      expect(find.byIcon(Icons.search), findsNothing);
      expect(find.text('Search feature coming soon!'), findsNothing);
    });

    testWidgets('Voice + Video live under More, collapsed by default',
        (WidgetTester tester) async {
      await pumpActions(tester);

      expect(find.text('More'), findsOneWidget);
      expect(find.text('Voice Chat'), findsNothing);
      expect(find.text('Video Chat'), findsNothing);
      expect(find.text('Beta'), findsNothing);
      expect(find.byKey(const Key('more-voice')), findsNothing);
      expect(find.byKey(const Key('more-video')), findsNothing);

      await tester.tap(find.byKey(const Key('more-actions-toggle')));
      await tester.pump();

      expect(find.text('Voice Chat'), findsOneWidget);
      expect(find.text('Video Chat'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.byKey(const Key('more-voice')), findsOneWidget);
      expect(find.byKey(const Key('more-video')), findsOneWidget);
      expect(find.byIcon(Icons.headset), findsOneWidget);
      expect(find.byIcon(Icons.video_call), findsOneWidget);
      expect(find.text('Search'), findsNothing);
    });
  });

  group('ChatInfoMembersSection', () {
    setUp(() {
      AvailabilityOnStore.scheduleExpirySweeps = false;
      MatchmakingQueueTracker.resetInstance();
      resetAvailabilityOnStore();
    });
    tearDown(() {
      MatchmakingQueueTracker.resetInstance();
      resetAvailabilityOnStore();
      AvailabilityOnStore.scheduleExpirySweeps = true;
    });

    Future<void> pumpMembers(
      WidgetTester tester, {
      required List<Map<String, dynamic>> members,
      VoidCallback? onAdd,
      LobbyState? lobbyState,
    }) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            lobbyNotifierProvider.overrideWith(
              () => _IdleLobbyNotifier(
                lobbyState ?? LobbyState.initial(),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ChatInfoMembersSection(
                squadId: 'test-squad',
                members: members,
                neonColor: Colors.blue,
                onAddMemberPressed: onAdd ?? () {},
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders with empty member list', (WidgetTester tester) async {
      await pumpMembers(tester, members: const []);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('renders member avatars', (WidgetTester tester) async {
      final members = [
        {'id': '1', 'name': 'User 1', 'isOnline': true},
        {'id': '2', 'name': 'User 2', 'isOnline': false},
      ];

      await pumpMembers(tester, members: members);
      await tester.pumpAndSettle();

      expect(find.text('User 1'), findsOneWidget);
      expect(find.text('User 2'), findsOneWidget);
    });

    testWidgets('add member button triggers callback',
        (WidgetTester tester) async {
      bool wasPressed = false;

      await pumpMembers(
        tester,
        members: const [],
        onAdd: () {
          wasPressed = true;
        },
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pump();

      expect(wasPressed, true);
    });

    testWidgets('shows On / Looking / In lobby from live sources',
        (WidgetTester tester) async {
      availabilityOnStore.markOn('u-on');
      MatchmakingQueueTracker.instance.startLooking('u-look');
      final lobby = Lobby.create(
        name: 'Squad',
        gameName: 'Warzone',
        maxSpots: 8,
        createdBy: 'u-in',
      ).copyWith(id: 'lobby-1', memberUids: const ['u-in']);

      await pumpMembers(
        tester,
        members: const [
          {'uid': 'u-on', 'name': 'On User', 'isOnline': true},
          {'uid': 'u-look', 'name': 'Looking User', 'isOnline': true},
          {'uid': 'u-in', 'name': 'Lobby User', 'isOnline': true},
        ],
        lobbyState: LobbyState.initial().copyWith(
          lobbyMemberUids: const ['u-in'],
          currentLobby: lobby,
          userLobbies: {'lobby-1': lobby},
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('On'), findsOneWidget);
      expect(find.text('Looking'), findsOneWidget);
      expect(find.text('In lobby'), findsOneWidget);
      expect(find.byKey(const Key('presence-badge-on')), findsOneWidget);
      expect(find.byKey(const Key('presence-badge-looking')), findsOneWidget);
      expect(find.byKey(const Key('presence-badge-in-lobby')), findsOneWidget);
    });
  });

  group('ChatInfoGlassCircleButton', () {
    testWidgets('renders with icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoGlassCircleButton(
              icon: Icons.edit,
              onPressed: () {},
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.edit), findsOneWidget);
    });

    testWidgets('triggers callback when pressed', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoGlassCircleButton(
              icon: Icons.edit,
              onPressed: () {
                wasPressed = true;
              },
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.edit));
      await tester.pump();

      expect(wasPressed, true);
    });
  });

  group('ChatInfoBigActionButton', () {
    testWidgets('renders with label and icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoBigActionButton(
              icon: Icons.headset,
              label: 'Voice Chat',
              neonColor: Colors.blue,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Voice Chat'), findsOneWidget);
      expect(find.byIcon(Icons.headset), findsOneWidget);
    });

    testWidgets('displays badge when provided', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoBigActionButton(
              icon: Icons.video_call,
              label: 'Video Chat',
              neonColor: Colors.blue,
              badge: 'Beta',
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('triggers callback when pressed', (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoBigActionButton(
              icon: Icons.search,
              label: 'Search',
              neonColor: Colors.blue,
              onPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.search));
      await tester.pumpAndSettle();

      expect(wasPressed, true);
    });
  });

  group('ChatInfoMemberAvatar', () {
    testWidgets('renders with name', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatInfoMemberAvatar(
              name: 'Test User',
              avatarUrl: null, // Avoid network image loading
              isOnline: true,
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('displays role badge when provided',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatInfoMemberAvatar(
              name: 'Admin User',
              avatarUrl: null,
              isOnline: true,
              role: 'ADMIN',
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('Admin User'), findsOneWidget);
      expect(find.byIcon(Icons.shield), findsOneWidget);
    });

    testWidgets('displays On / Looking / In lobby presence badges',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatInfoMemberAvatar(
              name: 'Sam',
              avatarUrl: null,
              isOnline: true,
              neonColor: Colors.blue,
              presenceBadges: PresenceBadgeRow(
                badges: PresenceBadges(
                  isOn: true,
                  isLooking: true,
                  isInLobby: true,
                ),
                compact: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sam'), findsOneWidget);
      expect(find.text('On'), findsOneWidget);
      expect(find.text('Looking'), findsOneWidget);
      expect(find.text('In lobby'), findsOneWidget);
    });
  });

  group('Tab Wrapper Components', () {
    testWidgets('ChatInfoSettingsTab calls builder function',
        (WidgetTester tester) async {
      bool builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoSettingsTab(
              builder: (context, color) {
                builderCalled = true;
                return const Text('Settings Content');
              },
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(builderCalled, true);
      expect(find.text('Settings Content'), findsOneWidget);
    });

    testWidgets('ChatInfoBackgroundsTab calls builder function',
        (WidgetTester tester) async {
      bool builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoBackgroundsTab(
              builder: (context, color) {
                builderCalled = true;
                return const Text('Backgrounds Content');
              },
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(builderCalled, true);
      expect(find.text('Backgrounds Content'), findsOneWidget);
    });

    testWidgets('ChatInfoMediaTab calls builder function',
        (WidgetTester tester) async {
      bool builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoMediaTab(
              builder: (context, color) {
                builderCalled = true;
                return const Text('Media Content');
              },
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(builderCalled, true);
      expect(find.text('Media Content'), findsOneWidget);
    });

    testWidgets('ChatInfoLinksFilesTab calls builder function',
        (WidgetTester tester) async {
      bool builderCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoLinksFilesTab(
              builder: (context, color) {
                builderCalled = true;
                return const Text('Links Content');
              },
              neonColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(builderCalled, true);
      expect(find.text('Links Content'), findsOneWidget);
    });
  });
}

class _IdleLobbyNotifier extends LobbyNotifier {
  _IdleLobbyNotifier(this._state);
  final LobbyState _state;

  @override
  Future<LobbyState> build() async => _state;
}
