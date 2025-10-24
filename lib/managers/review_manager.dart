import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Manages game reviews and ratings
class ReviewManager with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Submit a game review
  Future<void> submitReview({
    required String gameName,
    required double rating,
    String? reviewText,
    String? chatGroupId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewData = {
      'userId': user.uid,
      'gameName': gameName,
      'rating': rating,
      'reviewText': reviewText ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'chatGroupId': chatGroupId,
    };

    await _firestore.collection('game_reviews').add(reviewData);
  }

  /// Get average rating for a game
  Future<double?> getAverageRating(String gameName) async {
    final snapshot = await _firestore
        .collection('game_reviews')
        .where('gameName', isEqualTo: gameName)
        .get();

    if (snapshot.docs.isEmpty) return null;

    final totalRating = snapshot.docs.fold<double>(
        0.0,
        (sum, doc) =>
            sum + ((doc.data()['rating'] as num?)?.toDouble() ?? 0.0));
    return totalRating / snapshot.docs.length;
  }

  /// Check if user has already rated a game
  Future<bool> hasUserRatedGame(String gameName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final snapshot = await _firestore
        .collection('game_reviews')
        .where('userId', isEqualTo: user.uid)
        .where('gameName', isEqualTo: gameName)
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get user's rating for a game (null if not rated)
  Future<double?> getUserRating(String gameName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;

    final snapshot = await _firestore
        .collection('game_reviews')
        .where('userId', isEqualTo: user.uid)
        .where('gameName', isEqualTo: gameName)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return (snapshot.docs.first.data()['rating'] as num?)?.toDouble();
  }
}
