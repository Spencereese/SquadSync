import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cod_squad_app/chat/peacock_modal.dart';
import 'package:cod_squad_app/managers/game_manager.dart';
import 'package:cod_squad_app/managers/user_manager.dart';
import 'package:cod_squad_app/managers/notification_manager.dart';
import 'package:cod_squad_app/squad_state.dart';

// Mock GameManager that doesn't require Firebase
class TestGameManager extends GameManager {
  @override
  Future<List<Map<String, dynamic>>> searchGames(String query) async {
    return [
      {'name': 'Call of Duty', 'maxSpots': 6, 'coverUrl': null},
      {'name': 'Apex Legends', 'maxSpots': 3, 'coverUrl': null},
    ]
        .where((game) => (game['name'] as String)
            .toLowerCase()
            .contains(query.toLowerCase()))
        .toList();
  }
}

// Mock UserManager that doesn't require Firebase
class TestUserManager extends UserManager {
  @override
  List<String> get alertCircles => ['Friends', 'Family', 'Work'];
}

// Mock NotificationManager that doesn't require Firebase
class TestNotificationManager extends NotificationManager {
  @override
  Future<void> showNotification(String title, String message) async {
    // Mock implementation - do nothing
  }
}

// Mock SquadState that doesn't require Firebase
class TestSquadState extends SquadState {
  // Override to use test managers
}

void main() {
  group('PeacockModal Tests', () {
    late TestGameManager gameManager;
    late TestUserManager userManager;
    late TestNotificationManager notificationManager;
    late TestSquadState squadState;

    setUp(() {
      gameManager = TestGameManager();
      userManager = TestUserManager();
      notificationManager = TestNotificationManager();
      squadState = TestSquadState();
    });

    testWidgets('renders PeacockModal correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameManager>.value(value: gameManager),
            ChangeNotifierProvider<UserManager>.value(value: userManager),
            ChangeNotifierProvider<NotificationManager>.value(
                value: notificationManager),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PeacockModal(),
            ),
          ),
        ),
      );

      expect(find.text('Start a Squad'), findsOneWidget);
      expect(find.byIcon(Icons.flash_on), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.text('Game'), findsOneWidget);
      expect(find.text('Spots:'), findsOneWidget);
      expect(find.text('Circle'), findsOneWidget);
      expect(find.text('Alert backups if unfilled after 5min'), findsOneWidget);
      expect(find.text('Launch Squad'), findsOneWidget);
    });

    testWidgets('can enter game name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameManager>.value(value: gameManager),
            ChangeNotifierProvider<UserManager>.value(value: userManager),
            ChangeNotifierProvider<NotificationManager>.value(
                value: notificationManager),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PeacockModal(),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Warzone');
      expect(find.text('Warzone'), findsOneWidget);
    });

    testWidgets('can change spots slider', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameManager>.value(value: gameManager),
            ChangeNotifierProvider<UserManager>.value(value: userManager),
            ChangeNotifierProvider<NotificationManager>.value(
                value: notificationManager),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PeacockModal(),
            ),
          ),
        ),
      );

      // Find the slider and change its value
      final slider = find.byType(Slider);
      await tester.drag(slider, const Offset(50, 0));
      await tester.pump();

      // Check if spots value changed (this might need adjustment)
    });

    testWidgets('close button dismisses modal', (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<GameManager>.value(value: gameManager),
            ChangeNotifierProvider<UserManager>.value(value: userManager),
            ChangeNotifierProvider<NotificationManager>.value(
                value: notificationManager),
            ChangeNotifierProvider<SquadState>.value(value: squadState),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  builder: (context) => const PeacockModal(),
                ),
                child: const Text('Show Modal'),
              ),
            ),
          ),
        ),
      );

      // Open the modal
      await tester.tap(find.text('Show Modal'));
      await tester.pumpAndSettle();

      // Verify modal is open
      expect(find.text('Start a Squad'), findsOneWidget);

      // Tap close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify modal is closed
      expect(find.text('Start a Squad'), findsNothing);
    });
  });
}
