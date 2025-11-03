import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../squad_state.dart';

/// Service responsible for managing user online status
class ChatOnlineStatusManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Update user's online status in Firestore
  void updateOnlineStatus(bool isOnline, SquadState squadState) {
    String? uid = _auth.currentUser?.uid;
    if (uid != null) {
      String displayName = squadState.displayName ??
          _auth.currentUser?.displayName ??
          'Anonymous';
      if (displayName == 'User' || displayName.isEmpty) {
        displayName = _auth.currentUser?.displayName ?? 'Anonymous';
      }
      debugPrint('Updating online status: uid=$uid, displayName=$displayName');
      _firestore.collection('users').doc(uid).set({
        'displayName': displayName,
        'profileImage': squadState.profileImage,
        'lastOnline': FieldValue.serverTimestamp(),
        'online': isOnline,
      }, SetOptions(merge: true));
    } else {
      debugPrint('No authenticated user');
    }
  }
}
