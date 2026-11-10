import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/presence/domain/app_presence.dart';

class AppPresenceController extends Notifier<AppPresenceBoard> {
  StreamSubscription<AppPresenceBoard>? _live;
  String? _squadId;
  String? _userId;
  var _generation = 0;

  @override
  AppPresenceBoard build() {
    ref.onDispose(() {
      final live = _live;
      _live = null;
      if (live != null) unawaited(live.cancel());
    });
    return const AppPresenceBoard.unavailable();
  }

  /// Joins `sq8-presence-<squad>` and tracks [userId]. A second open for the
  /// same person does not stack a channel.
  Future<void> open({required String squadId, required String userId}) async {
    if (_live != null && _squadId == squadId && _userId == userId) return;
    await _drop();
    _squadId = squadId;
    _userId = userId;
    final generation = ++_generation;
    final sub = ref
        .read(appPresenceSourceProvider)
        .watch(squadId: squadId, userId: userId)
        .listen(
          (board) {
            if (generation != _generation) return;
            state = board;
          },
          onError: (Object _, StackTrace _) {
            if (generation != _generation) return;
            state = const AppPresenceBoard.unavailable();
          },
        );
    if (generation != _generation) {
      await sub.cancel();
      return;
    }
    _live = sub;
  }

  /// Leaves the channel. Dots go away. Safe to call twice.
  Future<void> leave() async {
    _squadId = null;
    _userId = null;
    await _drop();
    if (!ref.mounted) return;
    state = const AppPresenceBoard.unavailable();
  }

  Future<void> _drop() async {
    _generation++;
    final live = _live;
    _live = null;
    if (live != null) await live.cancel();
  }
}

final appPresenceControllerProvider =
    NotifierProvider<AppPresenceController, AppPresenceBoard>(
      AppPresenceController.new,
    );
