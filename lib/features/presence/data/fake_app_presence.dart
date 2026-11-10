import 'dart:async';

import 'package:squadsync/features/presence/data/app_presence_source.dart';
import 'package:squadsync/features/presence/domain/app_presence.dart';

/// Test double. The signed-in person is here while [watch] is listened to.
class FakeAppPresence implements AppPresenceSource {
  FakeAppPresence({this.available = true});

  bool available;
  final here = <String>{};
  final topics = <String>[];
  var watches = 0;
  String? trackedUserId;

  final _listeners = <MultiStreamController<AppPresenceBoard>>[];

  @override
  Stream<AppPresenceBoard> watch({
    required String squadId,
    required String userId,
  }) {
    watches += 1;
    topics.add(appPresenceTopic(squadId));
    trackedUserId = userId;
    if (available) here.add(userId);
    return Stream<AppPresenceBoard>.multi((listener) {
      _listeners.add(listener);
      listener.onCancel = () {
        here.remove(userId);
        if (trackedUserId == userId) trackedUserId = null;
        _listeners.remove(listener);
      };
      listener.add(_board());
    });
  }

  void show(String userId) {
    here.add(userId);
    _emit();
  }

  void hide(String userId) {
    here.remove(userId);
    _emit();
  }

  void loseRealtime() {
    available = false;
    _emit();
  }

  AppPresenceBoard _board() {
    if (!available) return const AppPresenceBoard.unavailable();
    return AppPresenceBoard(available: true, here: Set<String>.of(here));
  }

  void _emit() {
    final board = _board();
    for (final listener in List<MultiStreamController<AppPresenceBoard>>.of(
      _listeners,
    )) {
      listener.add(board);
    }
  }
}
