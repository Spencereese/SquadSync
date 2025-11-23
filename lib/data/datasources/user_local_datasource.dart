import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract class UserLocalDataSource {
  Future<String?> getProfileImage();
  Future<void> setProfileImage(String url);
  Future<String?> getDisplayName();
  Future<void> setDisplayName(String name);
  Future<List<Map<String, dynamic>>> getPinnedGames();
  Future<void> setPinnedGames(List<Map<String, dynamic>> games);
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final SharedPreferences _prefs;

  UserLocalDataSourceImpl(this._prefs);

  @override
  Future<String?> getProfileImage() async {
    return _prefs.getString('profileImage');
  }

  @override
  Future<void> setProfileImage(String url) async {
    await _prefs.setString('profileImage', url);
  }

  @override
  Future<String?> getDisplayName() async {
    return _prefs.getString('displayName');
  }

  @override
  Future<void> setDisplayName(String name) async {
    await _prefs.setString('displayName', name);
  }

  @override
  Future<List<Map<String, dynamic>>> getPinnedGames() async {
    final json = _prefs.getString('pinnedGames');
    if (json == null) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json));
  }

  @override
  Future<void> setPinnedGames(List<Map<String, dynamic>> games) async {
    await _prefs.setString('pinnedGames', jsonEncode(games));
  }
}