import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  final squadsSnapshot =
      await FirebaseFirestore.instance.collection('squads').get();
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
      print('Fixed ${doc.id}');
    }
  }
}
