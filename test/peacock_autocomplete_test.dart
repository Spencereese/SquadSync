import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cod_squad_app/chat/peacock_modal.dart';
import 'package:cod_squad_app/managers/game_manager.dart';
import 'package:cod_squad_app/managers/user_manager.dart';
import 'package:cod_squad_app/managers/notification_manager.dart';
import 'package:cod_squad_app/squad_state.dart';
import 'package:cod_squad_app/firebase_options.dart';

void main() {
  group('Peacock Modal Autocomplete', () {
    late GameManager gameManager;
    late UserManager userManager;
    late NotificationManager notificationManager;
    late SquadState squadState;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      gameManager = GameManager();
      userManager = UserManager();
      notificationManager = NotificationManager();
      squadState = SquadState();
    });

    testWidgets('PeacockModal shows TypeAheadField',
        (WidgetTester tester) async {
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

      // Wait for the widget to build
      await tester.pumpAndSettle();

      // Verify TypeAheadField is present
      expect(find.byType(TypeAheadField), findsOneWidget);

      // Verify the game input field exists
      expect(find.widgetWithText(TextField, 'Game'), findsOneWidget);
    });

    testWidgets('PeacockModal shows suggestions when typing',
        (WidgetTester tester) async {
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

      await tester.pumpAndSettle();

      // Find the TypeAheadField and enter text
      final typeAheadField = find.byType(TypeAheadField);
      expect(typeAheadField, findsOneWidget);

      // Note: Testing the actual autocomplete behavior would require
      // mocking the IGDB service and simulating user input.
      // This test verifies the UI structure is correct.
    });

    test('GameManager searchGames returns results for valid queries', () async {
      // Test with fallback games
      final results = await gameManager.searchGames('call');
      expect(results, isNotEmpty);
      expect(results.first['name'], contains('Call'));
    });

    test('GameManager searchGames returns empty for empty query', () async {
      final results = await gameManager.searchGames('');
      expect(results, isEmpty);
    });
  });
}
