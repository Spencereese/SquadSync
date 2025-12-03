import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:squad_sync/domain/entities/squad.dart';

abstract class SquadRemoteDataSource {
  Future<Squad> createSquad(Squad squad);
  Future<Squad?> getSquad(String squadId);
  Future<Squad?> getSquadByInviteCode(String inviteCode);
  Future<List<Squad>> getUserSquads(String userId);
  Future<void> updateSquad(Squad squad);
  Future<void> deleteSquad(String squadId);

  // Membership operations
  Future<void> joinSquad(String squadId, String userId);
  Future<void> leaveSquad(String squadId, String userId);
  Future<void> kickMember(String squadId, String memberId, String kickedBy);

  // Spot management
  Future<void> assignSpot(String squadId, int spotIndex, String? userId);
  Future<void> startSpotTimer(String squadId, int spotIndex, Duration duration);
  Future<void> cancelSpotTimer(String squadId, int spotIndex);

  // Timer processing (calls Cloud Functions)
  Future<void> processExpiredTimers();

  // Real-time streams
  Stream<Squad> getSquadStream(String squadId);
  Stream<List<Squad>> getUserSquadsStream(String userId);

  // Analytics
  Future<void> trackSquadEvent(String event, Map<String, dynamic> data);
}

class SquadRemoteDataSourceImpl implements SquadRemoteDataSource {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  SquadRemoteDataSourceImpl(this._firestore, this._auth);

  @override
  Future<Squad> createSquad(Squad squad) async {
    final docRef = _firestore.collection('squads').doc(squad.id);
    await docRef.set(squad.toJson());
    return squad;
  }

  @override
  Future<Squad?> getSquad(String squadId) async {
    final doc = await _firestore.collection('squads').doc(squadId).get();
    if (!doc.exists) return null;

    return Squad.fromJson(doc.data()!..['id'] = doc.id);
  }

  @override
  Future<Squad?> getSquadByInviteCode(String inviteCode) async {
    final query = await _firestore
        .collection('squads')
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return Squad.fromJson(doc.data()..['id'] = doc.id);
  }

  @override
  Future<List<Squad>> getUserSquads(String userId) async {
    final query = await _firestore
        .collection('squads')
        .where('memberUids', arrayContains: userId)
        .get();

    return query.docs
        .map((doc) => Squad.fromJson(doc.data()..['id'] = doc.id))
        .toList();
  }

  @override
  Future<void> updateSquad(Squad squad) async {
    await _firestore.collection('squads').doc(squad.id).update(squad.toJson());
  }

  @override
  Future<void> deleteSquad(String squadId) async {
    await _firestore.collection('squads').doc(squadId).delete();
  }

  @override
  Future<void> joinSquad(String squadId, String userId) async {
    await _firestore.collection('squads').doc(squadId).update({
      'memberUids': FieldValue.arrayUnion([userId]),
    });
  }

  @override
  Future<void> leaveSquad(String squadId, String userId) async {
    await _firestore.collection('squads').doc(squadId).update({
      'memberUids': FieldValue.arrayRemove([userId]),
    });
  }

  @override
  Future<void> kickMember(
      String squadId, String memberId, String kickedBy) async {
    // Remove from squad
    await _firestore.collection('squads').doc(squadId).update({
      'memberUids': FieldValue.arrayRemove([memberId]),
    });

    // Log the kick event
    await _firestore.collection('squad_events').add({
      'squadId': squadId,
      'type': 'member_kicked',
      'memberId': memberId,
      'kickedBy': kickedBy,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignSpot(String squadId, int spotIndex, String? userId) async {
    // First ensure the spots array is large enough
    final squadDoc = await _firestore.collection('squads').doc(squadId).get();
    final squad = Squad.fromJson(squadDoc.data()!..['id'] = squadDoc.id);

    final spots = List<String?>.from(squad.spots);
    while (spots.length <= spotIndex) {
      spots.add(null);
    }
    spots[spotIndex] = userId;

    await _firestore.collection('squads').doc(squadId).update({
      'spots': spots,
    });
  }

  @override
  Future<void> startSpotTimer(
      String squadId, int spotIndex, Duration duration) async {
    final timerData = {
      'startTime': DateTime.now().toIso8601String(),
      'duration': duration.inSeconds,
      'spotIndex': spotIndex,
    };

    await _firestore.collection('squads').doc(squadId).update({
      'spotTimers.$spotIndex': timerData,
    });

    // Call Cloud Function for server-side timer processing
    // This would be implemented with Firebase Functions
  }

  @override
  Future<void> cancelSpotTimer(String squadId, int spotIndex) async {
    await _firestore.collection('squads').doc(squadId).update({
      'spotTimers.$spotIndex': FieldValue.delete(),
    });
  }

  @override
  Future<void> processExpiredTimers() async {
    // This would call a Cloud Function to process expired timers server-side
    // For now, we'll handle this locally in the repository implementation
  }

  @override
  Stream<Squad> getSquadStream(String squadId) {
    return _firestore.collection('squads').doc(squadId).snapshots().map((doc) {
      if (!doc.exists) throw Exception('Squad not found');
      return Squad.fromJson(doc.data()!..['id'] = doc.id);
    });
  }

  @override
  Stream<List<Squad>> getUserSquadsStream(String userId) {
    return _firestore
        .collection('squads')
        .where('memberUids', arrayContains: userId)
        .snapshots()
        .map((query) => query.docs
            .map((doc) => Squad.fromJson(doc.data()..['id'] = doc.id))
            .toList());
  }

  @override
  Future<void> trackSquadEvent(String event, Map<String, dynamic> data) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('analytics').add({
      'userId': userId,
      'event': event,
      'data': data,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
