import 'package:squadsync/features/surface/domain/squad_surface.dart';

/// Records widget payloads and caller activities. Does not touch a plugin.
class FakeSquadSurface implements SquadSurface {
  final List<HomeWidgetSnapshot> snapshots = [];
  CallerActivity? activity;
  int started = 0;
  int ended = 0;

  @override
  Future<void> publish(HomeWidgetSnapshot snapshot) async {
    snapshots.add(snapshot);
  }

  @override
  Future<void> upsertCallerActivity(CallerActivity activity) async {
    this.activity = activity;
    started += 1;
  }

  @override
  Future<void> endCallerActivity() async {
    activity = null;
    ended += 1;
  }
}
