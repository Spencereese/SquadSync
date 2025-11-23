import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/domain/entities/squad.dart';
import 'package:squad_sync/domain/entities/squad_state.dart';

abstract class SquadLocalDataSource {
  Future<SquadState?> loadSquadState();
  Future<void> saveSquadState(SquadState state);
  Future<void> saveSquad(Squad squad);
  Future<Squad?> getSquad(String squadId);
  Future<List<Squad>> getUserSquads(String userId);
  Future<void> deleteSquad(String squadId);
  Future<void> purgeOldData();
}

class SquadLocalDataSourceImpl implements SquadLocalDataSource {
  final SharedPreferences _prefs;
  final SQLiteHelper _sqliteHelper;

  SquadLocalDataSourceImpl(this._prefs, this._sqliteHelper);

  @override
  Future<SquadState?> loadSquadState() async {
    final stateJson = _prefs.getString('squad_state');
    if (stateJson != null) {
      try {
        final map = jsonDecode(stateJson) as Map<String, dynamic>;
        return SquadState.fromJson(map);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  @override
  Future<void> saveSquadState(SquadState state) async {
    final jsonString = jsonEncode(state.toJson());
    await _prefs.setString('squad_state', jsonString);
  }

  @override
  Future<void> saveSquad(Squad squad) async {
    final db = await _sqliteHelper.database;
    await db.insert(
      'squads',
      {
        'id': squad.id,
        'name': squad.name,
        'memberUids': squad.memberUids.join(','),
        'gameName': squad.gameName,
        'maxSpots': squad.maxSpots,
        'createdBy': squad.createdBy,
        'createdAt': squad.createdAt.toIso8601String(),
        'spots': squad.spots.map((s) => s ?? '').join(','),
        'spotTimers': squad.spotTimers.map((t) => t != null ? jsonEncode(t) : '').join(';'),
        'viewers': squad.viewers.join(','),
        'statuses': squad.statuses.entries.map((e) => '${e.key}:${e.value}').join(','),
        'isActive': squad.isActive ? 1 : 0,
        'description': squad.description,
        'settings': squad.settings != null ? jsonEncode(squad.settings) : null,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<Squad?> getSquad(String squadId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'squads',
      where: 'id = ?',
      whereArgs: [squadId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    return Squad(
      id: map['id'] as String,
      name: map['name'] as String,
      memberUids: (map['memberUids'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      gameName: map['gameName'] as String,
      maxSpots: map['maxSpots'] as int,
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      spots: (map['spots'] as String).split(',').map((s) => s.isEmpty ? null : s).toList(),
      spotTimers: (map['spotTimers'] as String).split(';').map((t) {
        if (t.isEmpty) return null;
        try {
          return jsonDecode(t) as Map<String, dynamic>;
        } catch (e) {
          return null;
        }
      }).toList(),
      viewers: (map['viewers'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      statuses: Map.fromEntries(
        (map['statuses'] as String).split(',').where((s) => s.isNotEmpty).map((s) {
          final parts = s.split(':');
          return MapEntry(parts[0], parts[1]);
        }),
      ),
      isActive: (map['isActive'] as int) == 1,
      description: map['description'] as String?,
      settings: map['settings'] != null ? jsonDecode(map['settings'] as String) as Map<String, dynamic> : null,
    );
  }

  @override
  Future<List<Squad>> getUserSquads(String userId) async {
    final db = await _sqliteHelper.database;
    final maps = await db.query(
      'squads',
      where: 'memberUids LIKE ?',
      whereArgs: ['%$userId%'],
    );

    return maps.map((map) => Squad(
      id: map['id'] as String,
      name: map['name'] as String,
      memberUids: (map['memberUids'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      gameName: map['gameName'] as String,
      maxSpots: map['maxSpots'] as int,
      createdBy: map['createdBy'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      spots: (map['spots'] as String).split(',').map((s) => s.isEmpty ? null : s).toList(),
      spotTimers: (map['spotTimers'] as String).split(';').map((t) {
        if (t.isEmpty) return null;
        try {
          return jsonDecode(t) as Map<String, dynamic>;
        } catch (e) {
          return null;
        }
      }).toList(),
      viewers: (map['viewers'] as String).split(',').where((s) => s.isNotEmpty).toList(),
      statuses: Map.fromEntries(
        (map['statuses'] as String).split(',').where((s) => s.isNotEmpty).map((s) {
          final parts = s.split(':');
          return MapEntry(parts[0], parts[1]);
        }),
      ),
      isActive: (map['isActive'] as int) == 1,
      description: map['description'] as String?,
      settings: map['settings'] != null ? jsonDecode(map['settings'] as String) as Map<String, dynamic> : null,
    )).toList();
  }

  @override
  Future<void> deleteSquad(String squadId) async {
    final db = await _sqliteHelper.database;
    await db.delete(
      'squads',
      where: 'id = ?',
      whereArgs: [squadId],
    );
  }

  @override
  Future<void> purgeOldData() async {
    final db = await _sqliteHelper.database;
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));

    // Delete old squads
    await db.delete(
      'squads',
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