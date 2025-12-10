import 'auth_service_supabase.dart';
import 'supabase_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../presentation/notifiers/current_squad_notifier.dart';

/// Service for automatically selecting a squad on app launch
Future<String?> autoSelectSquad(WidgetRef ref) async {
  final user = AuthServiceSupabase().currentUser;
  if (user == null) return null;

  final userData = await SupabaseService.client
      .from('users')
      .select('squad_ids, pinned_squad_id')
      .eq('uid', user.id)
      .maybeSingle();

  final data = userData ?? {};
  final squadIds =
      (data['squad_ids'] as List<dynamic>?)?.cast<String>() ?? <String>[];

  String? chosenId;

  // 1. Pinned squad first
  final pinned = data['pinned_squad_id'] as String?;
  if (pinned != null && squadIds.contains(pinned)) {
    chosenId = pinned;
  }
  // 2. Most recent by last_activity
  else if (squadIds.isNotEmpty) {
    final squads = await SupabaseService.client
        .from('squads')
        .select('id')
        .contains('member_uids', [user.id])
        .order('last_activity', ascending: false)
        .limit(1);

    chosenId = squads.isNotEmpty ? squads.first['id'] as String? : null;
  }

  if (chosenId != null) {
    ref.read(currentLobbyIdProvider.notifier).state = chosenId;
  }

  return chosenId;
}
