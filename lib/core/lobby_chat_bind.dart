import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../services/supabase_service.dart';

/// Lobby + sibling chat_groups used to bind open-chat to the live thread.
class LobbyChatBindSnapshot {
  const LobbyChatBindSnapshot({
    this.lobbyId,
    this.lobbyChatGroupId,
    this.historyCounts = const {},
    this.candidates = const {},
  });

  final String? lobbyId;
  final String? lobbyChatGroupId;
  final Map<String, int> historyCounts;
  final Set<String> candidates;
}

String? chatIdOrNull(Object? value) {
  if (value == null) return null;
  final id = value.toString();
  return id.isEmpty ? null : id;
}

/// Collect probe / lobby / sibling ids. Does not invent ids.
Set<String> collectOpenChatCandidates({
  String? probeId,
  String? lobbyId,
  String? lobbyChatGroupId,
  Iterable<String?> siblingChatIds = const [],
}) {
  final ids = <String>{};
  void add(String? id) {
    final clean = chatIdOrNull(id);
    if (clean != null) ids.add(clean);
  }

  add(probeId);
  add(lobbyId);
  add(lobbyChatGroupId);
  for (final id in siblingChatIds) {
    add(id);
  }
  return ids;
}

List<String> parseLobbyIds(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (chatIdOrNull(item) != null) item.toString(),
  ];
}

/// Groups that share the exact same member set as the open thread.
List<String> siblingChatIdsWithSameMembers({
  required List<String> probeMembers,
  required List<({String id, List<String> members})> groups,
}) {
  final probe = probeMembers.where((id) => id.isNotEmpty).toSet();
  if (probe.isEmpty) return const [];
  final ids = <String>[];
  for (final group in groups) {
    if (group.id.isEmpty) continue;
    final members = group.members.where((id) => id.isNotEmpty).toSet();
    if (members.length == probe.length && members.containsAll(probe)) {
      ids.add(group.id);
    }
  }
  return ids;
}

/// App Links / universal links. `codsquadapp://chat` (no id) → null.
/// The live 1f580ae log mentioned 1766270568521 once (overlay) and never opened it.
String? chatIdFromAppLink(String link) {
  Uri uri;
  try {
    uri = Uri.parse(link.trim());
  } catch (_) {
    return null;
  }

  final fromQuery = chatIdOrNull(uri.queryParameters['id']) ??
      chatIdOrNull(uri.queryParameters['chatGroupId']) ??
      chatIdOrNull(uri.queryParameters['chat_group_id']);
  if (fromQuery != null) return fromQuery;

  final segments =
      uri.pathSegments.where((segment) => segment.isNotEmpty).toList();

  if (uri.scheme == 'codsquadapp' && uri.host == 'chat') {
    return segments.isEmpty ? null : chatIdOrNull(segments.first);
  }

  final chatIndex = segments.indexOf('chat');
  if (chatIndex >= 0 && chatIndex + 1 < segments.length) {
    final id = segments[chatIndex + 1];
    if (id == 'completions') return null;
    return chatIdOrNull(id);
  }
  return null;
}

/// JSONB `cs` must be a JSON array (`["id"]`), not a Postgres `{id}` list.
String lobbyIdsContainsPayload(String lobbyId) => jsonEncode([lobbyId]);

bool isLobbyIdsContainsPayload(String payload) {
  try {
    final decoded = jsonDecode(payload);
    return decoded is List && decoded.isNotEmpty;
  } catch (_) {
    return false;
  }
}

bool isChatListAppLink(String link) {
  if (chatIdFromAppLink(link) != null) return false;
  final trimmed = link.trim();
  if (trimmed == 'codsquadapp://chat' || trimmed == 'codsquadapp://chat/') {
    return true;
  }
  try {
    final uri = Uri.parse(trimmed);
    final segments =
        uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
    return segments.isNotEmpty && segments.last == 'chat';
  } catch (_) {
    return false;
  }
}

/// Read-only bind snapshot. Does not write lobbies or chat_messages.
Future<LobbyChatBindSnapshot> loadLobbyChatBindSnapshot(String probeId) async {
  final cleanProbe = chatIdOrNull(probeId);
  if (cleanProbe == null || !SupabaseService.isInitialized) {
    return const LobbyChatBindSnapshot();
  }

  try {
    final client = SupabaseService.client;
    Map<String, dynamic>? lobby;
    try {
      lobby = await client
          .from('lobbies')
          .select()
          .eq('chat_group_id', cleanProbe)
          .maybeSingle();
    } catch (e) {
      debugPrint('Lobby bind lookup by chat_group_id skipped: $e');
    }
    lobby ??= await _maybeLobbyById(cleanProbe);

    Map<String, dynamic>? group;
    try {
      group = await client
          .from('chat_groups')
          .select('id, member_uids, lobby_ids')
          .eq('id', cleanProbe)
          .maybeSingle();
    } catch (e) {
      debugPrint('Chat group bind lookup skipped: $e');
    }

    final lobbyIds = <String>{
      if (chatIdOrNull(lobby?['id']) != null) lobby!['id'].toString(),
      ...parseLobbyIds(group?['lobby_ids']),
    };
    final extraLobbyIds = lobbyIds
        .where((id) => lobby == null || chatIdOrNull(lobby!['id']) != id)
        .toList();
    for (final lobbyId in extraLobbyIds) {
      final extra = await _maybeLobbyById(lobbyId);
      final extraId = chatIdOrNull(extra?['id']);
      if (extraId != null) lobbyIds.add(extraId);
      if (lobby == null && extra != null) lobby = extra;
    }

    final siblingIds = <String>{};
    final members = <String>[
      for (final member in (group?['member_uids'] as List?) ?? const [])
        if (chatIdOrNull(member) != null) member.toString(),
    ];
    if (members.isNotEmpty) {
      try {
        final rows = await client
            .from('chat_groups')
            .select('id, member_uids')
            .contains('member_uids', members);
        siblingIds.addAll(
          siblingChatIdsWithSameMembers(
            probeMembers: members,
            groups: [
              for (final row in rows as List)
                (
                  id: chatIdOrNull((row as Map)['id']) ?? '',
                  members: [
                    for (final member
                        in (row['member_uids'] as List?) ?? const [])
                      if (chatIdOrNull(member) != null) member.toString(),
                  ],
                ),
            ],
          ),
        );
      } catch (e) {
        debugPrint('Sibling chat_groups lookup skipped: $e');
      }
    }

    for (final lobbyId in List<String>.from(lobbyIds)) {
      final payload = lobbyIdsContainsPayload(lobbyId);
      if (!isLobbyIdsContainsPayload(payload)) {
        debugPrint('lobby_ids sibling lookup skipped; bad payload');
        continue;
      }
      try {
        final linked = await client
            .from('chat_groups')
            .select('id')
            .filter('lobby_ids', 'cs', payload);
        for (final row in linked as List) {
          final id = chatIdOrNull((row as Map)['id']);
          if (id != null) siblingIds.add(id);
        }
      } catch (e) {
        debugPrint('lobby_ids sibling lookup skipped for $lobbyId: $e');
      }
    }

    final lobbyChatGroupId = chatIdOrNull(lobby?['chat_group_id']);
    final lobbyId = chatIdOrNull(lobby?['id']);
    final candidates = collectOpenChatCandidates(
      probeId: cleanProbe,
      lobbyId: lobbyId,
      lobbyChatGroupId: lobbyChatGroupId,
      siblingChatIds: siblingIds,
    );

    final counts = <String, int>{};
    for (final id in candidates) {
      try {
        final rows = await client
            .from('chat_messages')
            .select('id')
            .eq('chat_id', id);
        counts[id] = (rows as List).length;
        debugPrint('PostgREST chat_messages count=$id raw=${counts[id]}');
      } catch (e) {
        debugPrint('Chat thread count skipped for $id: $e');
      }
    }

    return LobbyChatBindSnapshot(
      lobbyId: lobbyId,
      lobbyChatGroupId: lobbyChatGroupId,
      historyCounts: counts,
      candidates: candidates,
    );
  } catch (e) {
    debugPrint('Lobby chat bind snapshot failed: $e');
    return const LobbyChatBindSnapshot();
  }
}

Future<Map<String, dynamic>?> _maybeLobbyById(String id) async {
  try {
    return await SupabaseService.client
        .from('lobbies')
        .select()
        .eq('id', id)
        .maybeSingle();
  } catch (e) {
    debugPrint('Lobby bind lookup by id skipped: $e');
    return null;
  }
}
