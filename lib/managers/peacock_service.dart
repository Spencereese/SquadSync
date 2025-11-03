import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for handling peacock-related queries and data processing
class PeacockService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get active peacock alerts for a specific game
  Stream<List<Map<String, dynamic>>> getActivePeacockAlerts(String gameName) {
    return _firestore
        .collection('users')
        .where('peacock.game', isEqualTo: gameName)
        .where('peacock.timer',
            isGreaterThan: DateTime.now().millisecondsSinceEpoch)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            final peacock = data['peacock'] as Map<String, dynamic>?;
            if (peacock != null) {
              return {
                'userId': doc.id,
                'displayName': data['displayName'] ?? 'User',
                'game': peacock['game'],
                'spots': peacock['spots'] ?? 4,
                'timer': peacock['timer'],
                'circle': peacock['circle'],
              };
            }
            return null;
          })
          .where((alert) => alert != null)
          .cast<Map<String, dynamic>>()
          .toList();
    });
  }
}
