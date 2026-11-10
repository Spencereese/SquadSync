import 'package:squadsync/features/availability/domain/availability_board.dart';
import 'package:squadsync/features/availability/domain/check_in.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/squad/domain/squad.dart';

/// Where one person sits on the home answer to "who can play right now?".
enum WhoGroup { playingNow, available, maybeLater, offline }

/// One row. [game] is the person's own check-in label, not a console reading.
class WhoRow {
  const WhoRow({required this.person, required this.game, required this.group});

  final PersonAvailability person;
  final String game;
  final WhoGroup group;

  String get userId => person.userId;
  String get displayName => person.displayName;
}

/// Glanceable groups. Available-now people with a game are playing now.
/// The same person is not listed twice. A blank game stays under Available.
/// Expired check-ins are offline and are never counted as available.
class WhoCanPlay {
  WhoCanPlay({required this.rows, required this.squadSize});

  factory WhoCanPlay.group({
    required AvailabilityBoard board,
    required List<Member> members,
  }) {
    final games = <String, String>{
      for (final member in members) member.id: member.defaultGame.trim(),
    };
    return WhoCanPlay(
      squadSize: members.length,
      rows: [
        for (final person in board.people)
          WhoRow(
            person: person,
            game: games[person.userId] ?? '',
            group: _group(person, games[person.userId] ?? ''),
          ),
      ],
    );
  }

  final List<WhoRow> rows;

  /// Members in the squad, not a padded 8. The summary still says "of 8".
  final int squadSize;

  List<WhoRow> get playingNow =>
      rows.where((row) => row.group == WhoGroup.playingNow).toList();

  List<WhoRow> get available =>
      rows.where((row) => row.group == WhoGroup.available).toList();

  List<WhoRow> get maybeLater =>
      rows.where((row) => row.group == WhoGroup.maybeLater).toList();

  List<WhoRow> get offline =>
      rows.where((row) => row.group == WhoGroup.offline).toList();

  /// People who can play right now. Later, can't, and last seen are not in this.
  int get availableCount => playingNow.length + available.length;

  bool get nobodyCheckedIn =>
      rows.every((row) => row.person.effect == AvailabilityEffect.notCheckedIn);

  String get summary => '$availableCount of $squadCapacity available';
}

WhoGroup _group(PersonAvailability person, String game) {
  switch (person.effect) {
    case AvailabilityEffect.availableNow:
      return game.isEmpty ? WhoGroup.available : WhoGroup.playingNow;
    case AvailabilityEffect.availableLater:
      return WhoGroup.maybeLater;
    case AvailabilityEffect.unavailable:
    case AvailabilityEffect.expired:
    case AvailabilityEffect.notCheckedIn:
      return WhoGroup.offline;
  }
}

/// Short line under a name. Stale rows say last seen and are not available.
String whoStatusLine(WhoRow row, {required Duration localOffset}) {
  final checkIn = row.person.checkIn;
  switch (row.person.effect) {
    case AvailabilityEffect.availableNow:
      final promoted = checkIn?.kind == CheckInKind.availableLater;
      final when = checkIn?.until;
      final clock = when == null
          ? ''
          : promoted
          ? 'Available since ${formatLocalClock(when, localOffset)}'
          : 'until ${formatLocalClock(when, localOffset)}';
      if (row.group == WhoGroup.playingNow) {
        return [
          if (clock.isNotEmpty) clock,
          row.game,
          'checked in, not detected',
        ].join(' · ');
      }
      return clock.isEmpty ? 'Available' : clock;
    case AvailabilityEffect.availableLater:
      final until = checkIn?.until;
      if (until == null) return 'Maybe later, time not set.';
      return 'Maybe later from ${formatLocalClock(until, localOffset)}.';
    case AvailabilityEffect.unavailable:
      return "Can't";
    case AvailabilityEffect.notCheckedIn:
      return 'Not checked in';
    case AvailabilityEffect.expired:
      final ended = availabilityEnded(checkIn);
      if (ended == null) return 'Last seen';
      return 'Last seen ${formatLocalClock(ended, localOffset)}';
  }
}

/// When this check-in stopped counting. An available-now row ends at its
/// until instant. A later row ends 60 minutes after the chosen time.
/// The check-in instant is not last seen.
DateTime? availabilityEnded(StoredCheckIn? row) {
  final until = row?.until;
  if (row == null || until == null) return null;
  if (row.kind == CheckInKind.availableLater) {
    return until.add(availableNowWindow);
  }
  return until;
}

/// One VoiceOver node for a row. The visible line can stay shorter.
String whoSpokenLine(WhoRow row, {required Duration localOffset}) {
  final name = row.displayName;
  final checkIn = row.person.checkIn;
  switch (row.person.effect) {
    case AvailabilityEffect.availableNow:
      final promoted = checkIn?.kind == CheckInKind.availableLater;
      final when = checkIn?.until;
      final clock = when == null ? '' : formatLocalClock(when, localOffset);
      if (row.group == WhoGroup.playingNow) {
        if (clock.isEmpty) return '$name, playing ${row.game}';
        if (promoted) {
          return '$name, playing ${row.game}, available since $clock';
        }
        return '$name, playing ${row.game}, until $clock';
      }
      if (clock.isEmpty) return '$name, available';
      if (promoted) return '$name, available since $clock';
      return '$name, available until $clock';
    case AvailabilityEffect.availableLater:
      final until = checkIn?.until;
      if (until == null) return '$name, maybe later';
      return '$name, available at ${formatLocalClock(until, localOffset)}';
    case AvailabilityEffect.unavailable:
      return "$name, can't";
    case AvailabilityEffect.notCheckedIn:
      return '$name, not checked in';
    case AvailabilityEffect.expired:
      final ended = availabilityEnded(checkIn);
      if (ended == null) return '$name, last seen';
      return '$name, last seen ${formatLocalClock(ended, localOffset)}';
  }
}
