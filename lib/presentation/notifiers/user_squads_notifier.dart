import '../../services/auth_service_supabase.dart';
import '../../services/supabase_service.dart';
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
  final uid = AuthServiceSupabase().currentUser!.id;

  /// Safely parse timestamp from data (handles both DateTime and String)
  DateTime _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return DateTime.now();
      }
    }
    return DateTime.now();
  }

  return SupabaseService.client
      .from('squads')
      .stream(primaryKey: ['id'])
      .order('last_activity', ascending: false)
      .map((data) {
        // Filter in-memory for member_uids containment
        final filteredData = data.where((row) {
          final memberUids = List<String>.from(row['member_uids'] ?? []);
          return memberUids.contains(uid);
        }).toList();

        return filteredData.map((row) {
          final spots = row['spots'] as List<dynamic>? ?? [];
          final activeSpots = spots.where((spot) => spot != null).length;
          final squadMaxSpots = row['max_spots'] as int?;

          return SquadSummary(
            id: row['id'] as String,
            name: row['name'] as String,
            primaryGameName: row['game_name'] as String?,
            memberCount: (row['member_uids'] as List<dynamic>).length,
            lastMessage: row['last_message'] as String? ?? '',
            lastActivity: _parseTimestamp(row['last_activity']),
            unreadCount: null, // TODO: calculate unread count
            maxSpots: squadMaxSpots,
            activeSpots: activeSpots,
          );
        }).toList();
      });
});
