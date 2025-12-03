import 'package:cloud_firestore/cloud_firestore.dart';

abstract class UserRemoteDataSource {
  Future<Map<String, dynamic>?> getUserProfile(String uid);
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getUserRatings(String uid);
  Future<Map<String, dynamic>?> getUserComplaints(String uid);
  Future<void> addBan(String uid, Map<String, dynamic> banData);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final FirebaseFirestore _firestore;

  UserRemoteDataSourceImpl(this._firestore);

  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  @override
  Future<Map<String, dynamic>?> getUserRatings(String uid) async {
    final doc = await _firestore.collection('user_ratings').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  @override
  Future<Map<String, dynamic>?> getUserComplaints(String uid) async {
    final doc = await _firestore.collection('complaints').doc(uid).get();
    return doc.exists ? doc.data() : null;
  }

  @override
  Future<void> addBan(String uid, Map<String, dynamic> banData) async {
    await _firestore.collection('bans').doc(uid).set({
      'bans': FieldValue.arrayUnion([banData]),
    }, SetOptions(merge: true));
  }
}
