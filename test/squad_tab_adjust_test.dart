import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cod_squad_app/screens/squad_tab_screen.dart';
import 'package:cod_squad_app/managers/squad_manager.dart';
import 'package:cod_squad_app/squad_state.dart';
import 'test_setup.dart';

// Mock classes
class MockUser extends Mock implements User {
  @override
  String get uid => 'test-uid';
}

class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  User? get currentUser => MockUser();

  @override
  Future<UserCredential> signInAnonymously() async {
    return MockUserCredential();
  }
}

class MockUserCredential extends Mock implements UserCredential {
  @override
  User get user => MockUser();
}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

class MockQuerySnapshot extends Mock
    implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
}

class MockSquadState extends Mock implements SquadState {}

class MockSquadManager extends Mock implements SquadManager {
  @override
  Stream<QuerySnapshot> getActiveLobbiesStream() {
    // Return an empty stream for testing empty state
    return Stream.value(MockQuerySnapshot());
  }

  @override
  Future<void> joinLobby(String peacockId, String userId) async {
    // Mock implementation
  }
}

void main() {
  late MockFirebaseAuth mockAuth;
  late MockFirebaseFirestore mockFirestore;
  late MockSquadManager mockSquadManager;
  late MockSquadState mockSquadState;

  setUp(() {
    setupTestEnvironment();
    mockAuth = MockFirebaseAuth();
    mockFirestore = MockFirebaseFirestore();
    mockSquadManager = MockSquadManager();
    mockSquadState = MockSquadState();
  });

  tearDown(() {
    teardownTestEnvironment();
  });

  testWidgets('SquadTabScreen displays empty state with CTA',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirebaseAuth>.value(value: mockAuth),
          Provider<FirebaseFirestore>.value(value: mockFirestore),
          ChangeNotifierProvider<SquadManager>.value(value: mockSquadManager),
          ChangeNotifierProvider<SquadState>.value(value: mockSquadState),
        ],
        child: const MaterialApp(
          home: SquadTabScreen(),
        ),
      ),
    );

    // Wait for the widget to build
    await tester.pumpAndSettle();

    // Verify empty state is shown
    expect(find.text('No active lobbies'), findsOneWidget);
    expect(find.text('Start a new lobby'), findsOneWidget);
  });
}
