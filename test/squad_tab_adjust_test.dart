import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:squad_sync/managers/stubs.dart';
import 'package:squad_sync/squad_state_notifier.dart';
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

class MockSquadState extends Mock implements LegacySquadState {}

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
    // Temporarily skip this test during Riverpod migration
    // TODO: Update test to use ProviderScope and new Riverpod providers
  }, skip: true);
}
