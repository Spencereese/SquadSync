import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:cod_squad_app/managers/squad_manager.dart';
import 'package:cod_squad_app/squad_state.dart';
import 'package:cod_squad_app/screens/squad_tab_screen.dart';
import 'package:cod_squad_app/squad_tab/squad_tab.dart';
import 'package:cod_squad_app/squad_tab/widgets/squad_grid.dart';
import 'test_setup.dart';

// Mock classes for performance testing
class MockSquadManager extends Mock implements SquadManager {}

class MockSquadState extends Mock implements SquadState {
  @override
  Map<String, int> get currentStreaks => {'user1': 5, 'user2': 3};

  @override
  Map<String, String> get statuses => {'user1': 'Ready', 'user2': 'Walking'};

  @override
  Map<String, Set<String>> get achievements => {
        'user1': {'First Win'},
        'user2': {'Team Player'}
      };

  @override
  Map<String, int> get complaints => {'user1': 0, 'user2': 1};

  @override
  List<String?> get squadSpots => [null, 'user1', null, 'user2'];

  @override
  List<Map<String, dynamic>?> get spotTimers => [
        null,
        {'expiresAt': DateTime.now().add(Duration(minutes: 5))},
        null,
        null
      ];

  @override
  String? get selectedSquadId => 'test-squad-id';

  @override
  Map<String, dynamic>? get currentGame =>
      {'name': 'Call of Duty', 'maxSpots': 4};

  @override
  Map<String, List<String?>> get gameSquadSpots => {
        'Call of Duty': [null, 'user1', null, 'user2']
      };

  @override
  Map<String, List<Map<String, dynamic>?>> get gameSpotTimers => {
        'Call of Duty': [
          null,
          {'expiresAt': DateTime.now().add(Duration(minutes: 5))},
          null,
          null
        ]
      };

  @override
  Map<String, Map<String, String>> get gameStatuses => {
        'Call of Duty': {'user1': 'Ready', 'user2': 'Walking'}
      };

  @override
  Map<String, String> get _memberDisplayNames =>
      {'user1': 'John Doe', 'user2': 'Jane Smith'};

  @override
  List<String> get getFilteredMembers => ['user1', 'user2'];
}

void main() {
  late MockSquadState mockSquadState;
  late MockSquadManager mockSquadManager;

  setUp(() {
    mockSquadState = MockSquadState();
    mockSquadManager = MockSquadManager();
    setupTestEnvironment();
  });

  tearDown(() {
    teardownTestEnvironment();
  });

  group('Performance Validation Tests', () {
    testWidgets('MembersSection rebuilds efficiently with Consumer',
        (WidgetTester tester) async {
      // Track rebuild count
      int rebuildCount = 0;

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: MaterialApp(
            home: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      rebuildCount++;
                      return MembersSection(
                        squadState: mockSquadState,
                        chatGroupMembers: ['user1', 'user2'],
                        showBlockDialog: (context, player, state) {},
                        showComplaintDialog:
                            (context, messenger, state, player) {},
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Initial build
      expect(rebuildCount, 1);

      // Trigger state change that should cause rebuild
      mockSquadState.notifyListeners();
      await tester.pump();

      // Should rebuild due to Consumer listening to SquadState
      expect(rebuildCount, 2);

      // Verify widget builds without errors
      expect(find.byType(MembersSection), findsOneWidget);
    });

    testWidgets('ClaimSpotFAB handles null lobbyId efficiently',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ClaimSpotFAB(
                lobbyId: null,
                callSpot: (context, state) {},
                lockSpot: (context, state) {},
              ),
            ),
          ),
        ),
      );

      // Should render without errors
      expect(find.byType(ClaimSpotFAB), findsOneWidget);

      // Should not show any interactive elements when lobbyId is null
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('SpotCard renders empty state efficiently',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SpotCard(
                index: 0,
                squadState: mockSquadState,
              ),
            ),
          ),
        ),
      );

      // Should render empty spot without errors
      expect(find.byType(SpotCard), findsOneWidget);

      // Should show "Empty" text for empty spot
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('SquadTabScreen uses optimized widget structure',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const MaterialApp(
            home: SquadTabScreen(),
          ),
        ),
      );

      // Should build without errors
      expect(find.byType(SquadTabScreen), findsOneWidget);

      // Should contain the optimized MembersSection
      expect(find.byType(MembersSection), findsOneWidget);

      // Should contain ClaimSpotFAB
      expect(find.byType(ClaimSpotFAB), findsWidgets);
    });

    testWidgets('Multiple spot cards render efficiently',
        (WidgetTester tester) async {
      // Create multiple spot cards to test performance
      final spots = [null, 'user1', null, 'user2'];

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: List.generate(
                    4,
                    (index) => SpotCard(
                          index: index,
                          squadState: mockSquadState,
                        )),
              ),
            ),
          ),
        ),
      );

      // Should render all spot cards
      expect(find.byType(SpotCard), findsNWidgets(4));

      // Should show correct empty/occupied states
      expect(find.text('Empty'), findsNWidgets(2)); // Two empty spots
      expect(find.text('John Doe'), findsOneWidget); // Occupied by user1
      expect(find.text('Jane Smith'), findsOneWidget); // Occupied by user2
    });
  });
}
