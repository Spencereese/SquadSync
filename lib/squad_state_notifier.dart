import 'package:flutter/material.dart';

/// Typedef for backward compatibility during Riverpod migration
typedef SquadState = LegacySquadState;

/// Legacy SquadState class for backward compatibility
class LegacySquadState extends ChangeNotifier {
  // Basic properties for compatibility
  String displayName = 'Unknown User';
  String? selectedSquadId;
  Map<String, List<String?>> gameSquadSpots = {};
  Map<String, String> statuses = {};
  List<Map<String, dynamic>> scheduledTimes = [];
  List<Map<String, dynamic>> availableGames = [];

  // Managers for compatibility
  dynamic dataManager;
  dynamic persistenceManager;
  dynamic uiManager;
  dynamic persistenceService;
  Map<String, dynamic>? currentGame;
  String? profileImage;
  List<String> squadMembers = [];
  Map<String, String?> memberProfileImages = {};
  List<String> userSquadIds = [];

  List<String> get getFilteredMembers => [];

  Map<String, Map<String, dynamic>> userSquads = {};
  List<Map<String, dynamic>> gameHistory = [];
  Map<String, int> complaints = {};
  Map<String, Map<String, bool>> userBlocks = {};
  Map<String, Map<String, int>> dailyRatings = {};

  Map<String, Map<String, int>> allTimeRatings = {};
  dynamic userManager;
  List<String> get getBlockedUsers => [];
  bool isInitialized = true;
  List<String?> get squadSpots => [];

  // Constructor
  LegacySquadState() {
    // Initialize with default values
  }

  // Compatibility methods - these are stubs for migration
  Future<void> leaveChatGroup(String groupId) async {
    // Stub implementation
  }

  Future<void> addBan(String userName, String displayName) async {
    // Stub implementation
  }

  Future<void> blockUser(String userName) async {
    // Stub implementation
  }

  String getDisplayNameForUid(String uid) {
    return 'Unknown User'; // Stub implementation
  }

  String? getPlayerGame(String member) {
    return null; // Stub implementation
  }

  Future<void> updateFirestore() async {
    // Stub implementation
  }

  Future<void> updateTiltEnabled(bool enabled) async {
    // Stub implementation
  }

  Future<void> updateProfileImage(String downloadUrl) async {
    // Stub implementation
  }

  Future<void> updatePreferredMode(String displayName, String mode) async {
    // Stub implementation
  }

  Future<void> unblockUser(String user) async {
    // Stub implementation
  }

  // Other methods that might be called
  void notifyListeners() {
    super.notifyListeners();
  }
}
