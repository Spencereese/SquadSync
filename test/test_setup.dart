import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:firebase_core/firebase_core.dart';

/// Test setup utilities for Firebase and Flutter testing
class TestSetup {
  static late FakeFirebaseFirestore fakeFirestore;
  static late MockFirebaseAuth mockAuth;

  /// Initialize Firebase for testing with fake implementations
  static Future<void> initializeFirebase() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize Firebase with test app
    await Firebase.initializeApp(
      name: 'test_app',
      options: const FirebaseOptions(
        apiKey: 'test_api_key',
        appId: 'test_app_id',
        messagingSenderId: 'test_sender_id',
        projectId: 'test_project_id',
      ),
    );

    // Create fake Firestore instance
    fakeFirestore = FakeFirebaseFirestore();

    // Add some test data
    await fakeFirestore.collection('games').add({
      'name': 'Warzone',
      'maxSpots': 4,
      'imageUrl': 'https://example.com/warzone.jpg',
    });
    await fakeFirestore.collection('games').add({
      'name': 'Modern Warfare',
      'maxSpots': 4,
      'imageUrl': 'https://example.com/mw.jpg',
    });

    // Set up mock Auth
    mockAuth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(
        uid: 'test_user_id',
        email: 'test@example.com',
        displayName: 'Test User',
      ),
    );
  }

  /// Clean up after tests
  static void tearDown() {
    // Reset any global state if needed
  }

  /// Legacy function for backward compatibility
  static Future<void> setupTestEnvironment() async {
    await initializeFirebase();
  }

  /// Legacy function for backward compatibility
  static void teardownTestEnvironment() {
    tearDown();
  }
}

/// Global functions for backward compatibility with existing tests
Future<void> setupTestEnvironment() async {
  await TestSetup.initializeFirebase();
}

void teardownTestEnvironment() {
  TestSetup.tearDown();
}

/// Test data helpers
class TestData {
  static const String testUserId = 'test_user_id';
  static const String testSquadId = 'test_squad_id';
  static const String testGameName = 'Warzone';

  static Map<String, dynamic> createTestUser() {
    return {
      'uid': testUserId,
      'displayName': 'Test User',
      'email': 'test@example.com',
      'photoURL': 'https://example.com/photo.jpg',
      'isBlocked': false,
      'rating': 5.0,
      'isBanned': false,
    };
  }

  static Map<String, dynamic> createTestSquad() {
    return {
      'id': testSquadId,
      'name': 'Test Squad',
      'memberUids': [testUserId],
      'gameName': testGameName,
      'maxSpots': 4,
    };
  }

  static Map<String, dynamic> createTestGame() {
    return {
      'name': testGameName,
      'maxSpots': 4,
      'imageUrl': 'https://example.com/game.jpg',
    };
  }

  static Map<String, dynamic> createTestMessage() {
    return {
      'id': 'msg1',
      'text': 'Test message',
      'senderUid': testUserId,
      'timestamp': DateTime.now(),
      'type': 'text',
    };
  }
}
