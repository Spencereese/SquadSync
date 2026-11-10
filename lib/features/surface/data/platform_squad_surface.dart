import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';
import 'package:live_activities/live_activities.dart';
import 'package:squadsync/features/surface/domain/squad_surface.dart';

/// Writes the home widget on iOS and Android, and a Live Activity on iOS.
/// Android skips Live Activities. Every plugin failure is stored and swallowed.
///
/// [otherMemberLiveActivityHook] is the parked path. Remote updates stay off
/// so this activity is only the phone that called the spot.
class PlatformSquadSurface implements SquadSurface {
  PlatformSquadSurface({required this.ios});

  final bool ios;

  Object? lastProblem;
  bool skippedLiveActivity = false;
  LiveActivities? _activities;
  bool _activitiesReady = false;
  String? _activityId;

  LiveActivities get _live => _activities ??= LiveActivities();

  @override
  Future<void> publish(HomeWidgetSnapshot snapshot) async {
    try {
      await HomeWidget.setAppGroupId(squadAppGroupId);
      for (final entry in snapshot.fields.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(
        name: squadWidgetKind,
        iOSName: squadWidgetKind,
        qualifiedAndroidName: squadAndroidWidget,
      );
    } on MissingPluginException catch (error) {
      lastProblem = error;
    } catch (error) {
      lastProblem = error;
    }
  }

  @override
  Future<void> upsertCallerActivity(CallerActivity activity) async {
    if (!ios) {
      skippedLiveActivity = true;
      return;
    }
    try {
      final live = _live;
      if (!_activitiesReady) {
        await live.init(
          appGroupId: squadAppGroupId,
          requestAndroidNotificationPermission: false,
        );
        _activitiesReady = true;
      }
      await live.createOrUpdateActivity(
        activity.callId,
        activity.fields,
        iOSEnableRemoteUpdates: false,
      );
      _activityId = activity.callId;
    } on MissingPluginException catch (error) {
      lastProblem = error;
    } catch (error) {
      lastProblem = error;
    }
  }

  @override
  Future<void> endCallerActivity() async {
    final id = _activityId;
    _activityId = null;
    if (!ios || id == null) return;
    try {
      await _live.endActivity(id);
    } on MissingPluginException catch (error) {
      lastProblem = error;
    } catch (error) {
      lastProblem = error;
    }
  }
}

/// iOS only. Android and this Linux checkout report false and skip.
bool squadSurfaceIsIos() {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.iOS;
}
