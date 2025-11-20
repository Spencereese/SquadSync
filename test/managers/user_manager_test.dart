import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../lib/managers/user_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late UserManager userManager;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();

    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});

    // Create UserManager - it will use the mocked FirebaseAuth and SharedPreferences
    userManager = UserManager(firestore: fakeFirestore);
  });

  tearDown(() {
    userManager.dispose();
  });

  group('UserManager - blockUser', () {
    test('should block user successfully', () async {
      // Arrange
      const blockerUid = 'user1';
      const blockedUid = 'user2';

      // Act
      await userManager.blockUser(blockerUid, blockedUid);

      // Assert
      expect(userManager.userBlocks[blockerUid]?[blockedUid], true);
      final blockedUsers = await userManager.getBlockedUsers(blockerUid);
      expect(blockedUsers[blockedUid], true);
    });

    test('should unblock user successfully', () async {
      // Arrange
      const blockerUid = 'user1';
      const blockedUid = 'user2';
      await userManager.blockUser(blockerUid, blockedUid);

      // Act
      await userManager.unblockUser(blockerUid, blockedUid);

      // Assert
      expect(userManager.userBlocks[blockerUid]?[blockedUid] ?? false, false);
      final blockedUsers = await userManager.getBlockedUsers(blockerUid);
      expect(blockedUsers.containsKey(blockedUid), false);
    });

    test('should handle blocking same user multiple times', () async {
      // Arrange
      const blockerUid = 'user1';
      const blockedUid = 'user2';

      // Act
      await userManager.blockUser(blockerUid, blockedUid);
      await userManager.blockUser(blockerUid, blockedUid); // Block again

      // Assert
      expect(userManager.userBlocks[blockerUid]?[blockedUid], true);
      final blockedUsers = await userManager.getBlockedUsers(blockerUid);
      expect(blockedUsers[blockedUid], true);
    });
  });

  group('UserManager - getUserProfile', () {
    test('should fetch profile from Firestore when not cached', () async {
      // Arrange
      const uid = 'user1';
      final firestoreData = {
        'displayName': 'Test User',
        'profileImage': 'https://example.com/image.jpg'
      };

      // Add data to fake Firestore
      await fakeFirestore.collection('users').doc(uid).set(firestoreData);

      // Act
      final profile = await userManager.getUserProfile(uid);

      // Assert
      expect(profile, isNotNull);
      expect(profile!['displayName'], 'Test User');
      expect(profile['profileImage'], 'https://example.com/image.jpg');
    });

    test('should return null when user document does not exist', () async {
      // Arrange
      const uid = 'nonexistent';

      // Act
      final profile = await userManager.getUserProfile(uid);

      // Assert
      expect(profile, isNull);
    });
  });

  // Note: Tests for methods requiring FirebaseAuth (fetchPinnedGames, addPinnedGame, etc.)
  // are omitted due to complexity of mocking FirebaseAuth in unit tests.
  // These would be better tested in integration tests or with proper FirebaseAuth mocking.
}
