import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/availability/ui/availability_controller.dart';
import 'package:squadsync/features/spot/ui/spot_controller.dart';
import 'package:squadsync/features/surface/data/platform_squad_surface.dart';
import 'package:squadsync/features/surface/domain/squad_surface.dart';

final squadSurfaceProvider = Provider<SquadSurface>((ref) {
  return PlatformSquadSurface(ios: squadSurfaceIsIos());
});

final surfaceSyncProvider = Provider<SurfaceSync>((ref) {
  final sync = SurfaceSync(ref);
  ref.onDispose(sync.dispose);
  return sync;
});

/// Pushes Who's on and the open spot to the widget, and keeps the caller's
/// Live Activity in step with the join window. A failure stays here.
class SurfaceSync {
  SurfaceSync(this.ref);

  final Ref ref;
  Timer? _tick;
  bool _showing = false;
  String? _meId;

  void dispose() {
    _tick?.cancel();
    _tick = null;
  }

  Future<void> publish({required String? meId}) async {
    _meId = meId;
    try {
      final availability = ref.read(availabilityControllerProvider);
      final spot = ref.read(spotHomeProvider);
      final clock = ref.read(squadClockProvider).now();
      final members = availability.squad?.members;
      final board = availability.board;
      final who = board == null || members == null
          ? null
          : WhoCanPlay.group(board: board, members: members);
      final snapshot = homeWidgetSnapshot(
        who: who,
        availabilityMissing: availability.notEnabled,
        spot: spot.call,
        spotMissing: spot.missing,
        clock: clock,
      );
      final surface = ref.read(squadSurfaceProvider);
      await surface.publish(snapshot);
      final activity = callerActivityFor(
        call: spot.missing ? null : spot.call,
        meId: meId,
        clock: clock,
      );
      if (activity == null) {
        _arm(false);
        if (_showing) {
          _showing = false;
          await surface.endCallerActivity();
        }
      } else {
        _showing = true;
        _arm(true);
        await surface.upsertCallerActivity(activity);
      }
    } catch (_) {
      // Home, chat, and spots stay up when the widget cannot start.
    }
  }

  void _arm(bool open) {
    if (!open) {
      _tick?.cancel();
      _tick = null;
      return;
    }
    if (_tick != null) return;
    final every = ref.read(availabilityTickProvider);
    if (every <= Duration.zero) return;
    _tick = Timer.periodic(every, (_) {
      unawaited(publish(meId: _meId));
    });
  }
}
