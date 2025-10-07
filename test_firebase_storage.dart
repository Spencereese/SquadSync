import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testFirebaseStorage() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('Firebase initialized successfully');

    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No authenticated user - this will cause upload to fail');
      return;
    }
    print('User authenticated: ${user.uid}');

    // Test Firebase Storage access
    final storage = FirebaseStorage.instance;
    print('Storage bucket: ${storage.bucket}');

    // Try to create a reference
    final ref = storage.ref().child('test.txt');
    print('Storage reference created: ${ref.fullPath}');

    // Try to list files (this will test if we have read access)
    try {
      final listResult =
          await storage.ref().child('chat_group_images').listAll();
      print(
          'Successfully listed files in chat_group_images: ${listResult.items.length} items');
    } catch (e) {
      print('Failed to list files: $e');
      print('This suggests storage rules or permissions issue');
    }

    print('Firebase Storage test completed successfully');
  } catch (e, stackTrace) {
    print('Firebase Storage test failed: $e');
    print('Stack trace: $stackTrace');
  }
}
