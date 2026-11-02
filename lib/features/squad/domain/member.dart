/// One person in the squad. [defaultGame] is their own preference.
class Member {
  const Member({
    required this.id,
    required this.displayName,
    required this.defaultGame,
  });

  final String id;
  final String displayName;
  final String defaultGame;

  bool get isValid =>
      id.trim().isNotEmpty &&
      displayName.trim().isNotEmpty &&
      defaultGame.trim().isNotEmpty;
}

/// The owner row this app seeds before anyone else joins.
const Member spencer = Member(
  id: 'spencer',
  displayName: 'Spencer',
  defaultGame: 'Call of Duty',
);
