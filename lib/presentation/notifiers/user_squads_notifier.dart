import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SquadSummary {
  const SquadSummary({
    required this.id,
    required this.name,
    this.primaryGameName,
    required this.memberCount,
    required this.lastMessage,
    required this.lastActivity,
    this.unreadCount,
    this.maxSpots,
    this.activeSpots,
  });

  final String id;
  final String name;
  final String? primaryGameName;
  final int memberCount;
  final String lastMessage;
  final DateTime lastActivity;
  final int? unreadCount;
  final int? maxSpots;
  final int? activeSpots;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SquadSummary &&
        other.id == id &&
        other.name == name &&
        other.primaryGameName == primaryGameName &&
        other.memberCount == memberCount &&
        other.lastMessage == lastMessage &&
        other.lastActivity == lastActivity &&
        other.unreadCount == unreadCount;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        primaryGameName.hashCode ^
        memberCount.hashCode ^
        lastMessage.hashCode ^
        lastActivity.hashCode ^
        unreadCount.hashCode;
  }

  @override
  String toString() {
    return 'SquadSummary(id: $id, name: $name, primaryGameName: $primaryGameName, memberCount: $memberCount, lastMessage: $lastMessage, lastActivity: $lastActivity, unreadCount: $unreadCount, maxSpots: $maxSpots, activeSpots: $activeSpots)';
  }
}

final userSquadsProvider = StreamProvider<List<SquadSummary>>((ref) {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  /// Safely parse timestamp from Firestore data (handles both Timestamp and String)
  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  return FirebaseFirestore.instance
      .collection('squads')
      .where('memberUids', arrayContains: uid)
      .orderBy('lastActivity', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            final spots = data['spots'] as List<dynamic>? ?? [];
            final activeSpots = spots.where((spot) => spot != null).length;
            final squadMaxSpots = data['maxSpots'] as int?;

            return SquadSummary(
              id: doc.id,
              name: data['name'] as String,
              primaryGameName: data['gameName'] as String?,
              memberCount: (data['memberUids'] as List<dynamic>).length,
              lastMessage: data['lastMessage'] as String? ?? '',
              lastActivity: _parseTimestamp(data['lastActivity']),
              unreadCount: null, // TODO: calculate unread count
              maxSpots: squadMaxSpots,
              activeSpots: activeSpots,
            );
          }).toList());
});
