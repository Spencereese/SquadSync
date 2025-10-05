import 'package:flutter/material.dart';

/// Manages user profiles, blocking, and preferences
class UserManager with ChangeNotifier {
  String? _profileImage;
  String? _displayName;
  Map<String, String?> memberProfileImages = {};
  Map<String, String?> preferredModes = {};

  // Blocked users map per user
  Map<String, Map<String, bool>> userBlocks = {};

  String? get profileImage => _profileImage;
  String? get displayName => _displayName;

  void updateProfileImage(String url) {
    _profileImage = url;
    notifyListeners();
  }

  void updateDisplayName(String name) {
    _displayName = name;
    notifyListeners();
  }

  void updatePreferredMode(String user, String? mode) {
    preferredModes[user] = mode;
    notifyListeners();
  }

  void blockUser(String user) {
    final currentUser = 'current_user'; // TODO: Get from auth
    userBlocks[currentUser] ??= {};
    userBlocks[currentUser]![user] = true;
    notifyListeners();
  }

  void unblockUser(String user) {
    final currentUser = 'current_user'; // TODO: Get from auth
    userBlocks[currentUser]?.remove(user);
    notifyListeners();
  }

  bool isUserBlocked(String user) {
    final currentUser = 'current_user'; // TODO: Get from auth
    return userBlocks[currentUser]?.containsKey(user) ?? false;
  }
}
