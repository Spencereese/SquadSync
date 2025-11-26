import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Provider for Firebase Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

// Provider for Firestore service (alias for backward compatibility)
final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

// Stub FirestoreService class for compatibility
class FirestoreService {
  // Stub implementation
  Future<void> loadFirestoreData(
      {Map<String, String>? displayNameCache}) async {
    // Stub implementation
  }
}
