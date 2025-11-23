import 'package:squad_sync/domain/entities/app_user.dart';

abstract class UserRepository {
  Future<AppUser?> getCurrentUser();
  Future<void> updateProfileImage(String url);
  Future<void> updateDisplayName(String name);
  Future<void> blockUser(String userName);
  Future<void> unblockUser(String userName);
  Future<bool> isBlocked(String userName);
  Future<void> addBan(String userName, String reason);
  Future<bool> isBanned(String userName);
  Future<int> getBanCount(String userName);
  Future<void> addPinnedGame(Map<String, dynamic> game);
  Future<void> removePinnedGame(String gameName);
  Future<void> updateMemberProfileImage(String uid, String? imageUrl);
  Future<void> updateUserProfileCache(String uid, Map<String, dynamic> profile);
  Future<Map<String, String?>> getMemberProfileImages();
  Future<Map<String, Map<String, dynamic>>> getUserProfileCache();
}