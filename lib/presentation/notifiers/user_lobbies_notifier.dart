import '../../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/injection.dart';

class LobbySummary {
  const LobbySummary({
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
    return other is LobbySummary &&
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
    return 'LobbySummary(id: $id, name: $name, primaryGameName: $primaryGameName, memberCount: $memberCount, lastMessage: $lastMessage, lastActivity: $lastActivity, unreadCount: $unreadCount, maxSpots: $maxSpots, activeSpots: $activeSpots)';
  }
}

final userLobbiesProvider = StreamProvider<List<LobbySummary>>((ref) {
  final uid = AuthServiceSupabase().currentUser!.id;
  final repository = ref.watch(lobbyRepositoryProvider);

  return repository.getUserLobbiesStream(uid).map((lobbies) {
    return lobbies.map((lobby) {
      final activeSpots = lobby.spots.where((spot) => spot != null).length;

      return LobbySummary(
        id: lobby.id,
        name: lobby.name,
        primaryGameName: lobby.gameName,
        memberCount: lobby.memberUids.length,
        lastMessage: '', // TODO: integrate with chat to get last message
        lastActivity: lobby.createdAt, // TODO: use actual last_activity field
        unreadCount: null, // TODO: calculate unread count from chat
        maxSpots: lobby.maxSpots,
        activeSpots: activeSpots,
      );
    }).toList();
  });
});
