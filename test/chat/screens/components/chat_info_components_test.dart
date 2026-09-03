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

  group('ChatInfoActionsSection', () {
    testWidgets('renders all three action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInfoActionsSection(
                squadId: 'test-squad',
                squadName: 'Test Squad',
                neonColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Voice Chat'), findsOneWidget);
      expect(find.text('Video Chat'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text("I'm on now"), findsOneWidget);
    });

    testWidgets('displays Beta badge on Video Chat',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInfoActionsSection(
                squadId: 'test-squad',
                squadName: 'Test Squad',
                neonColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Beta'), findsOneWidget);
    });

    testWidgets('renders action buttons with correct layout',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatInfoActionsSection(
                squadId: 'test-squad',
                squadName: 'Test Squad',
                neonColor: Colors.blue,
              ),
            ),
          ),
        ),
      );

      // Verify all buttons are present
      expect(find.byIcon(Icons.headset), findsOneWidget);
      expect(find.byIcon(Icons.video_call), findsOneWidget);
      expect(find.byIcon(Icons.search), findsOneWidget);

      // Verify buttons use Row layout
      final row = tester.widget<Row>(find.ancestor(
        of: find.text('Search'),
        matching: find.byType(Row),
      ));
      expect(row.mainAxisAlignment, MainAxisAlignment.spaceEvenly);
    });
  });

  group('ChatInfoMembersSection', () {
    testWidgets('renders with empty member list', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoMembersSection(
              squadId: 'test-squad',
              members: const [],
              neonColor: Colors.blue,
              onAddMemberPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('renders member avatars', (WidgetTester tester) async {
      final members = [
        {'id': '1', 'name': 'User 1', 'isOnline': true},
        {'id': '2', 'name': 'User 2', 'isOnline': false},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoMembersSection(
              squadId: 'test-squad',
              members: members,
              neonColor: Colors.blue,
              onAddMemberPressed: () {},
            ),
          ),
        ),
      );

      expect(find.text('User 1'), findsOneWidget);
      expect(find.text('User 2'), findsOneWidget);
    });

    testWidgets('add member button triggers callback',
        (WidgetTester tester) async {
      bool wasPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatInfoMembersSection(
              squadId: 'test-squad',
              members: const [],
              neonColor: Colors.blue,
              onAddMemberPressed: () {
                wasPressed = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.person_add));
      await tester.pump();

      expect(wasPressed, true);
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
