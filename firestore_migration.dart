import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

Future<void> main() async {
  print('Starting Firestore migration...');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  // Fix existing squad documents
  print('Fixing existing squad documents...');
  final squadsSnapshot = await firestore.collection('squads').get();
  int squadFixes = 0;
  for (var doc in squadsSnapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('memberUids') || data['memberUids'] == null)
      updates['memberUids'] = <String>[];
    if (!data.containsKey('tags')) updates['tags'] = <String>[];
    if (!data.containsKey('spotClaims'))
      updates['spotClaims'] = <String, String?>{};
    if (!data.containsKey('peacockTimers'))
      updates['peacockTimers'] = <String, dynamic>{};
    if (!data.containsKey('userStatuses'))
      updates['userStatuses'] = <String, String>{};

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      squadFixes++;
      print('Fixed squad ${doc.id}');
    }
  }
  print('Fixed $squadFixes squad documents');

  // Fix existing user documents
  print('Fixing existing user documents...');
  final usersSnapshot = await firestore.collection('users').get();
  int userFixes = 0;
  for (var doc in usersSnapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('squadIds') || data['squadIds'] == null) {
      updates['squadIds'] = <String>[];
    }

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      userFixes++;
      print('Fixed user ${doc.id}');
    }
  }
  print('Fixed $userFixes user documents');

  print('Migration completed successfully!');
}
