import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseStorageTestWidget extends StatefulWidget {
  const FirebaseStorageTestWidget({super.key});

  @override
  State<FirebaseStorageTestWidget> createState() =>
      _FirebaseStorageTestWidgetState();
}

class _FirebaseStorageTestWidgetState extends State<FirebaseStorageTestWidget> {
  String _testResult = 'Not tested yet';
  bool _isTesting = false;

  Future<void> _runStorageTest() async {
    setState(() {
      _isTesting = true;
      _testResult = 'Testing...';
    });

    try {
      // Initialize Firebase if not already done
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        _testResult += '\nFirebase initialized';
      } else {
        _testResult += '\nFirebase already initialized';
      }

      // Check authentication
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _testResult += '\n❌ No authenticated user - uploads will fail';
        return;
      }
      _testResult += '\n✅ User authenticated: ${user.uid}';

      // Test storage access
      final storage = FirebaseStorage.instance;
      _testResult += '\nStorage bucket: ${storage.bucket}';

      // Try to create a reference
      final ref = storage.ref().child('test.txt');
      _testResult += '\n✅ Storage reference created: ${ref.fullPath}';

      // Try to list files in chat_group_images
      try {
        final listResult =
            await storage.ref().child('chat_group_images').listAll();
        _testResult +=
            '\n✅ Successfully listed files: ${listResult.items.length} items';
      } catch (e) {
        _testResult += '\n❌ Failed to list files: $e';
        _testResult += '\nThis suggests storage rules or permissions issue';
      }

      // Test writing access by trying to upload a small test file
      try {
        final testData = 'test data';
        final testRef =
            storage.ref().child('chat_group_images').child('test_upload.txt');
        await testRef.putString(testData);
        _testResult += '\n✅ Test upload successful';

        // Clean up test file
        await testRef.delete();
        _testResult += '\n✅ Test file cleaned up';
      } catch (e) {
        _testResult += '\n❌ Test upload failed: $e';
      }

      _testResult += '\n\n🎉 Firebase Storage test completed!';
    } catch (e, stackTrace) {
      _testResult = '❌ Test failed: $e\nStack trace: $stackTrace';
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firebase Storage Test'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isTesting ? null : _runStorageTest,
              child: Text(_isTesting ? 'Testing...' : 'Run Storage Test'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Test Results:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _testResult,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
