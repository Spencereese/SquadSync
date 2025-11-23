import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/update_profile_image.dart';
import '../../domain/usecases/update_display_name.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/unblock_user.dart';
import '../../domain/usecases/add_pinned_game.dart';
import '../../domain/usecases/remove_pinned_game.dart';
import '../../core/injection.dart' as di;

part 'user_notifier.g.dart';

@riverpod
class UserNotifier extends _$UserNotifier {
  late final GetCurrentUser _getCurrentUser;
  late final UpdateProfileImage _updateProfileImage;
  late final UpdateDisplayName _updateDisplayName;
  late final BlockUser _blockUser;
  late final UnblockUser _unblockUser;
  late final AddPinnedGame _addPinnedGame;
  late final RemovePinnedGame _removePinnedGame;

  @override
  Future<AppUser?> build() async {
    // Get dependencies from get_it
    _getCurrentUser = di.getIt<GetCurrentUser>();
    _updateProfileImage = di.getIt<UpdateProfileImage>();
    _updateDisplayName = di.getIt<UpdateDisplayName>();
    _blockUser = di.getIt<BlockUser>();
    _unblockUser = di.getIt<UnblockUser>();
    _addPinnedGame = di.getIt<AddPinnedGame>();
    _removePinnedGame = di.getIt<RemovePinnedGame>();

    return await _getCurrentUser();
  }

  Future<void> updateProfileImage(String url) async {
    await _updateProfileImage(url);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> updateDisplayName(String name) async {
    await _updateDisplayName(name);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> blockUser(String userName) async {
    await _blockUser(userName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> unblockUser(String userName) async {
    await _unblockUser(userName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> addPinnedGame(Map<String, dynamic> game) async {
    await _addPinnedGame(game);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }

  Future<void> removePinnedGame(String gameName) async {
    await _removePinnedGame(gameName);
    state = await AsyncValue.guard(() => _getCurrentUser());
  }
}
