import 'dart:convert';

/// Coerces a `get_lobby_stats` RPC payload into a wins/losses/draws map.
///
/// PostgREST may return a list of rows, a single map, a nested
/// `{get_lobby_stats: ...}` wrapper, JSON text, or a Postgres record literal.
Map<String, dynamic> coerceLobbyStatsResponse(dynamic response) {
  if (response == null) return const {};

  if (response is Map) {
    final map = Map<String, dynamic>.from(response);
    if (_looksLikeLobbyStats(map)) return map;
    for (final key in ['get_lobby_stats', 'data', 'result', 'stats']) {
      if (!map.containsKey(key)) continue;
      final nested = coerceLobbyStatsResponse(map[key]);
      if (_looksLikeLobbyStats(nested)) return nested;
    }
    return const {};
  }

  if (response is List) {
    if (response.isEmpty) return const {};
    return coerceLobbyStatsResponse(response.first);
  }

  if (response is String) {
    final trimmed = response.trim();
    if (trimmed.isEmpty) return const {};
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      try {
        return coerceLobbyStatsResponse(jsonDecode(trimmed));
      } catch (_) {
        return const {};
      }
    }
    if (trimmed.startsWith('(') && trimmed.endsWith(')')) {
      return _lobbyStatsFromRecordLiteral(trimmed);
    }
  }

  return const {};
}

bool _looksLikeLobbyStats(Map<String, dynamic> map) {
  return map.containsKey('wins') ||
      map.containsKey('losses') ||
      map.containsKey('draws') ||
      map.containsKey('total_matches');
}

/// `RETURNS TABLE (total_matches, wins, losses, draws, win_rate)` record text.
Map<String, dynamic> _lobbyStatsFromRecordLiteral(String raw) {
  final inner = raw.substring(1, raw.length - 1).trim();
  if (inner.isEmpty) return const {};
  final parts = inner.split(',').map((s) => s.trim()).toList();
  if (parts.length < 4) return const {};
  return {
    'total_matches': parts[0],
    'wins': parts[1],
    'losses': parts[2],
    'draws': parts[3],
    if (parts.length > 4) 'win_rate': parts[4],
  };
}
