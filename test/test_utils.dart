import 'package:flutter_riverpod/flutter_riverpod.dart';

// Test environment setup/teardown utilities
void setupTestEnvironment() {
  // Setup for tests if needed
}

void teardownTestEnvironment() {
  // Clean up any test state if needed
}

// Helper for creating test containers with mocks
ProviderContainer createTestContainer(List<Override> overrides) {
  return ProviderContainer(
    overrides: overrides,
  );
}

// Test data helpers
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
}
