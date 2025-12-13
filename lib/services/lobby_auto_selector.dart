import 'auth_service_supabase.dart';
import 'supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/lobby_notifier.dart';

/// Service for automatically selecting a lobby on app launch
Future<String?> autoSelectLobby(WidgetRef ref) async {
  final user = AuthServiceSupabase().currentUser;
  if (user == null) return null;

  final userData = await SupabaseService.client
      .from('users')
      .select('lobby_ids, pinned_lobby_id')
      .eq('uid', user.id)
      .maybeSingle();

  final data = userData ?? {};
  final lobbyIds =
      (data['lobby_ids'] as List<dynamic>?)?.cast<String>() ?? <String>[];

  String? chosenId;

  // 1. Pinned lobby first
  final pinned = data['pinned_lobby_id'] as String?;
  if (pinned != null && lobbyIds.contains(pinned)) {
    chosenId = pinned;
  }
  // 2. Most recent by last_activity
  else if (lobbyIds.isNotEmpty) {
    final lobbies = await SupabaseService.client
        .from('lobbies')
        .select('id')
        .contains('member_uids', [user.id])
        .order('last_activity', ascending: false)
        .limit(1);

    chosenId = lobbies.isNotEmpty ? lobbies.first['id'] as String? : null;
  }

  if (chosenId != null) {
    ref.read(lobbyNotifierProvider.notifier).setSelectedLobbyId(chosenId);
  }

  return chosenId;
}
