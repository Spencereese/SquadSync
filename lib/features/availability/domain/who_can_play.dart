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
      final until = checkIn?.until;
      final clock = until == null
          ? ''
          : 'until ${formatLocalClock(until, localOffset)}';
      if (row.group == WhoGroup.playingNow) {
        return [
          if (clock.isNotEmpty) clock,
          row.game,
          'checked in, not detected',
        ].join(' · ');
      }
      return clock.isEmpty ? 'Available' : 'Available $clock';
    case AvailabilityEffect.availableLater:
      final until = checkIn?.until;
      final when = until == null
          ? 'time not set'
          : 'until ${formatLocalClock(until, localOffset)}';
      return 'Maybe later $when. Does not turn into available now.';
    case AvailabilityEffect.unavailable:
      return "Can't";
    case AvailabilityEffect.notCheckedIn:
      return 'Not checked in';
    case AvailabilityEffect.expired:
      final at = checkIn?.checkedAt;
      if (at == null) return 'Last seen';
      return 'Last seen ${formatLocalClock(at, localOffset)}';
  }
}
