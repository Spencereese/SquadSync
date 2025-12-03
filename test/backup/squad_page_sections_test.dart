import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cod_squad_app/screens/squad_tab_screen.dart';
import 'package:cod_squad_app/managers/squad_manager.dart';
import 'package:cod_squad_app/squad_state.dart';

// Mock classes
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => MockUser();
}

class MockSquadManager extends Mock implements SquadManager {
  @override
  Stream<QuerySnapshot> getActiveLobbiesStream() {
    return Stream.value(MockQuerySnapshot());
  }

  @override
  Future<void> joinLobby(String peacockId, String userId) async {}
}

class MockQuerySnapshot extends Mock implements QuerySnapshot {
  @override
  List<QueryDocumentSnapshot> get docs => [];
}

class MockSquadState extends Mock implements SquadState {
  @override
  String? get selectedSquadId => 'test-squad';

  @override
  List<String> get getFilteredMembers => ['Alice', 'Bob', 'Charlie'];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockFirebaseAuth mockAuth;
  late MockSquadManager mockSquadManager;
  late MockSquadState mockSquadState;

  setUpAll(() async {
    // Initialize Firebase for tests
    await Firebase.initializeApp();
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockSquadManager = MockSquadManager();
    mockSquadState = MockSquadState();
  });

  testWidgets('SquadTabScreen shows basic structure',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    // Wait for the widget to build
    await tester.pumpAndSettle();

    // Check that the screen shows the expected title
    expect(find.text('Squad Lobbies'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('Active Lobbies section shows empty state when no lobbies',
      (WidgetTester tester) async {
    when(mockSquadManager.getActiveLobbiesStream())
        .thenAnswer((_) => Stream.value(MockQuerySnapshot()));

    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No active games—start one?'), findsOneWidget);
  });

  testWidgets('Member Status section shows squad members',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MultiProvider(
          providers: [
            Provider<FirebaseAuth>.value(value: mockAuth),
            ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
            ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
          ],
          child: const SquadTabScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Charlie'), findsOneWidget);
  });
}
