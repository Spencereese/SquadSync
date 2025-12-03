import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cod_squad_app/presentation/screens/squad_tab_screen.dart';
import 'package:cod_squad_app/presentation/notifiers/squad_notifier.dart';
import 'package:cod_squad_app/domain/entities/squad.dart';
import '../../helpers/mocks.mocks.dart';

void main() {
  late MockSquadRepository mockRepository;

  setUp(() {
    mockRepository = MockSquadRepository();
  });

  final testSquad = Squad(
    id: 'squad123',
    name: 'Test Squad',
    memberUids: ['uid1', 'uid2'],
    gameName: 'cod',
    maxSpots: 4,
    createdBy: 'uid1',
    createdAt: DateTime.now(),
    spots: [null, 'uid1', null, null],
    spotTimers: [null, null, null, null],
    viewers: [],
    statuses: {},
    isActive: true,
  );

  group('SquadTabScreen', () {
    testWidgets('should display loading indicator when loading', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => const AsyncValue.loading());

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );

      // Assert
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should display squad list when loaded', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => AsyncValue.data([testSquad]));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('Test Squad'), findsOneWidget);
      expect(find.text('cod'), findsOneWidget);
    });

    testWidgets('should display error message when loading fails', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => AsyncValue.error('Failed to load squads'));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('Failed to load squads'), findsOneWidget);
    });

    testWidgets('should display empty state when no squads', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => const AsyncValue.data([]));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('No squads found'), findsOneWidget);
      expect(find.text('Create your first squad to get started!'), findsOneWidget);
    });

    testWidgets('should navigate to create squad when create button tapped', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => const AsyncValue.data([]));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: const SquadTabScreen(),
            routes: {
              '/create-squad': (context) => const Scaffold(body: Text('Create Squad Screen')),
            },
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the create squad button
      final createButton = find.byIcon(Icons.add);
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Create Squad Screen'), findsOneWidget);
    });

    testWidgets('should display squad spots correctly', (tester) async {
      // Arrange
      final squadWithSpots = testSquad.copyWith(
        spots: ['uid1', 'uid2', null, null],
        spotTimers: [null, null, null, null],
      );
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => AsyncValue.data([squadWithSpots]));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Assert
      expect(find.text('2/4 spots filled'), findsOneWidget);
    });

    testWidgets('should handle squad tap navigation', (tester) async {
      // Arrange
      when(mockRepository.getUserSquads('uid1')).thenAnswer((_) async => AsyncValue.data([testSquad]));

      // Act
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            squadNotifierProvider.overrideWith((ref) => SquadNotifier(mockRepository)),
          ],
          child: MaterialApp(
            home: const SquadTabScreen(),
            routes: {
              '/squad-details': (context) => const Scaffold(body: Text('Squad Details Screen')),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/squad-details') {
                return MaterialPageRoute(
                  builder: (context) => const Scaffold(body: Text('Squad Details Screen')),
                );
              }
              return null;
            },
          ),
        ),
      );
      await tester.pump(); // Allow async operations to complete

      // Find and tap the squad card
      final squadCard = find.byType(Card);
      expect(squadCard, findsOneWidget);
      await tester.tap(squadCard);
      await tester.pumpAndSettle();

      // Assert
      expect(find.text('Squad Details Screen'), findsOneWidget);
    });
  });
}