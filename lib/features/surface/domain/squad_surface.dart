import 'package:squadsync/features/availability/domain/who_can_play.dart';
import 'package:squadsync/features/spot/domain/spot_call.dart';

/// App Group shared by the Runner and the widget extension.
/// Team K4ZTXPQ8J9. The group has to be created in the Apple developer
/// account before a device build can sign.
const String squadAppGroupId = 'group.com.spencereese.squadsync';

/// WidgetKit kind and the Android provider class.
const String squadWidgetKind = 'SquadHomeWidget';

const String squadAndroidWidget = 'com.spencereese.squadsync.SquadHomeWidget';

/// Shown on the widget and under Who's on. Foreground and OS refreshes
/// only. Push (0012 / FCM v1 / sq8-notify-message) is parked, so this
/// does not stay live in the background.
const String homeWidgetHonesty =
    'Updates while SquadSync is open. It does not stay live in the background until push exists.';

/// Other members do not get a Live Activity from this phone.
/// That needs Live Activity push through APNs, which waits on the same
/// parked push rewrite. [PlatformSquadSurface] keeps remote updates off.
const String otherMemberLiveActivityHook =
    'Parked. Other members need Live Activity push through APNs, which waits on the push rewrite (0012 / FCM v1 / sq8-notify-message). This phone does not send that.';

/// What the home and lock screen widget can show without a server push.
class HomeWidgetSnapshot {
  const HomeWidgetSnapshot({
    required this.whoSummary,
    required this.whoNames,
    required this.spotLine,
    required this.honesty,
  });

  final String whoSummary;
  final String whoNames;
  final String spotLine;
  final String honesty;

  Map<String, String> get fields => {
    'who_summary': whoSummary,
    'who_names': whoNames,
    'spot_line': spotLine,
    'honesty': honesty,
  };
}

/// Caller-side Live Activity. Only the phone that called the spot.
class CallerActivity {
  const CallerActivity({
    required this.callId,
    required this.game,
    required this.joinUntil,
    required this.inCount,
    required this.outCount,
  });

  final String callId;
  final String game;
  final DateTime joinUntil;
  final int inCount;
  final int outCount;

  Map<String, String> get fields => {
    'game': game,
    'inCount': '$inCount',
    'outCount': '$outCount',
    'joinUntilMillis': '${joinUntil.millisecondsSinceEpoch}',
  };
}

HomeWidgetSnapshot homeWidgetSnapshot({
  WhoCanPlay? who,
  required bool availabilityMissing,
  SpotCall? spot,
  required bool spotMissing,
  required DateTime clock,
}) {
  final String whoSummary;
  final String whoNames;
  if (availabilityMissing) {
    whoSummary = 'Availability is not enabled yet.';
    whoNames = '';
  } else if (who == null) {
    whoSummary = "Open SquadSync to see who's on.";
    whoNames = '';
  } else {
    whoSummary = who.summary;
    final names = [
      for (final row in who.playingNow) row.displayName,
      for (final row in who.available) row.displayName,
    ];
    whoNames = names.isEmpty ? 'Nobody is checked in.' : names.join(', ');
  }
  final String spotLine;
  if (spotMissing) {
    spotLine = 'Spots are not enabled yet.';
  } else {
    spotLine = spotStatusLine(call: spot, clock: clock);
  }
  return HomeWidgetSnapshot(
    whoSummary: whoSummary,
    whoNames: whoNames,
    spotLine: spotLine,
    honesty: homeWidgetHonesty,
  );
}

/// Null unless [meId] called this spot and the join window is still open.
/// Locked, ended, canceled, and expired calls dismiss the activity.
CallerActivity? callerActivityFor({
  required SpotCall? call,
  required String? meId,
  required DateTime clock,
}) {
  if (call == null || meId == null || meId.isEmpty) return null;
  if (call.callerId != meId) return null;
  if (call.phaseAt(clock) != SpotPhase.open) return null;
  final outCount = call.rsvps
      .where((row) => row.response == SpotAnswer.rsvpOut)
      .length;
  return CallerActivity(
    callId: call.id,
    game: call.game,
    joinUntil: call.joinUntil,
    inCount: call.inCount,
    outCount: outCount,
  );
}

/// Home widget plus the caller Live Activity. Implementations must not throw
/// into the squad home. A missing plugin, an older iOS, or Android is a skip.
abstract class SquadSurface {
  Future<void> publish(HomeWidgetSnapshot snapshot);

  Future<void> upsertCallerActivity(CallerActivity activity);

  Future<void> endCallerActivity();
}
