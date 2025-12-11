import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/domain/entities/lobby.dart';
import 'package:squad_sync/domain/entities/lobby_state.dart';

abstract class LobbyLocalDataSource {
  Future<LobbyState?> loadLobbyState();
  Future<void> saveLobbyState(LobbyState state);
  Future<void> saveSquad(Lobby lobby);
  Future<Lobby?> getLobby(String lobbyId);
  Future<List<Lobby>> getUserLobbies(String userId);
  Future<void> deleteLobby(String lobbyId);
  Future<void> purgeOldData();
}

class LobbyLocalDataSourceImpl implements LobbyLocalDataSource {
  final SharedPreferences _prefs;
  final SQLiteHelper _sqliteHelper;

  LobbyLocalDataSourceImpl(this._prefs, this._sqliteHelper);

  @override
  Future<LobbyState?> loadLobbyState() async {
    final stateJson = _prefs.getString('squad_state');
    if (stateJson != null) {
      try {
        final map = jsonDecode(stateJson) as Map<String, dynamic>;
        return LobbyState.fromJson(map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> saveLobbyState(LobbyState state) async {
    final jsonString = jsonEncode(state.toJson());
    await _prefs.setString('squad_state', jsonString);
  }

  @override
  Future<void> saveSquad(Lobby lobby) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'lobbies',
      {
        'id': lobby.id,
        'name': lobby.name,
        'memberUids': lobby.memberUids.join(','),
        'gameName': lobby.gameName,
        'maxSpots': lobby.maxSpots,
        'createdBy': lobby.createdBy,
        'createdAt': lobby.createdAt.toIso8601String(),
        'spots': lobby.spots.map((s) => s ?? '').join(','),
        'spotTimers': lobby.spotTimers
            .map((t) => t != null ? jsonEncode(t) : '')
            .join(';'),
        'viewers': lobby.viewers.join(','),
        'statuses':
            lobby.statuses.entries.map((e) => '${e.key}:${e.value}').join(','),
        'isActive': lobby.isActive ? 1 : 0,
        'description': lobby.description,
        'settings': lobby.settings != null ? jsonEncode(lobby.settings) : null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Lobby?> getLobby(String lobbyId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'lobbies',
      where: 'id = ?',
      whereArgs: [lobbyId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Lobby(
      id: map['id'] as String,
      name: map['name'] as String,
      memberUids: (map['memberUids'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      gameName: map['gameName'] as String,
      maxSpots: map['maxSpots'] as int,
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      spots: (map['spots'] as String)
          .split(',')
          .map((s) => s.isEmpty ? null : s)
          .toList(),
      spotTimers: (map['spotTimers'] as String).split(';').map((t) {
        if (t.isEmpty) return null;
        try {
          return jsonDecode(t) as Map<String, dynamic>;
        } catch (e) {
          return null;
        }
      }).toList(),
      viewers: (map['viewers'] as String)
          .split(',')
          .where((s) => s.isNotEmpty)
          .toList(),
      statuses: Map.fromEntries(
        (map['statuses'] as String)
            .split(',')
            .where((s) => s.isNotEmpty)
            .map((s) {
          final parts = s.split(':');
          return MapEntry(parts[0], parts[1]);
        }),
      ),
      isActive: (map['isActive'] as int) == 1,
      description: map['description'] as String?,
      settings: map['settings'] != null
          ? jsonDecode(map['settings'] as String) as Map<String, dynamic>
          : null,
    );
  }

  @override
  Future<List<Lobby>> getUserLobbies(String userId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'lobbies',
      where: 'memberUids LIKE ?',
      whereArgs: ['%$userId%'],
    );

    return maps
        .map((map) => Lobby(
              id: map['id'] as String,
              name: map['name'] as String,
              memberUids: (map['memberUids'] as String)
                  .split(',')
                  .where((s) => s.isNotEmpty)
                  .toList(),
              gameName: map['gameName'] as String,
              maxSpots: map['maxSpots'] as int,
              createdBy: map['createdBy'] as String,
              createdAt: DateTime.parse(map['createdAt'] as String),
              spots: (map['spots'] as String)
                  .split(',')
                  .map((s) => s.isEmpty ? null : s)
                  .toList(),
              spotTimers: (map['spotTimers'] as String).split(';').map((t) {
                if (t.isEmpty) return null;
                try {
                  return jsonDecode(t) as Map<String, dynamic>;
                } catch (e) {
                  return null;
                }
              }).toList(),
              viewers: (map['viewers'] as String)
                  .split(',')
                  .where((s) => s.isNotEmpty)
                  .toList(),
              statuses: Map.fromEntries(
                (map['statuses'] as String)
                    .split(',')
                    .where((s) => s.isNotEmpty)
                    .map((s) {
                  final parts = s.split(':');
                  return MapEntry(parts[0], parts[1]);
                }),
              ),
              isActive: (map['isActive'] as int) == 1,
              description: map['description'] as String?,
              settings: map['settings'] != null
                  ? jsonDecode(map['settings'] as String)
                      as Map<String, dynamic>
                  : null,
            ))
        .toList();
  }

  @override
  Future<void> deleteLobby(String lobbyId) async {
    final db = await _sqliteHelper.database;
    await db.delete(
      'lobbies',
      where: 'id = ?',
      whereArgs: [lobbyId],
    );
  }

  @override
  Future<void> purgeOldData() async {
    final db = await _sqliteHelper.database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Delete old lobbies
    await db.delete(
      'lobbies',
      where: 'createdAt < ?',
      whereArgs: [thirtyDaysAgo.toIso8601String()],
    );

    // Clear old preferences
    final keys = _prefs.getKeys();
    for (final key in keys) {
      if (key.startsWith('squad_') && key.contains('old_')) {
        await _prefs.remove(key);
      }
    }
  }
}
