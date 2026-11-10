/// What the board may say about one person's PC. A Steam game name is never
/// treated as a console.
enum SteamView { notSetUp, notLinked, privateProfile, playing, notInGame }

class SteamMember {
  const SteamMember({required this.userId, required this.view, this.game});

  final String userId;
  final SteamView view;
  final String? game;
}

class SteamBoard {
  const SteamBoard({required this.setUp, this.members = const []});

  final bool setUp;
  final List<SteamMember> members;

  static const notSetUp = SteamBoard(setUp: false);

  SteamMember? forUser(String userId) {
    for (final member in members) {
      if (member.userId == userId) return member;
    }
    return null;
  }
}

/// The visible line. Not-in-game is silent: Steam did not name a game.
String? steamStatusLine(SteamMember? member, {required bool setUp}) {
  if (!setUp) return 'Steam presence not set up yet';
  if (member == null) return 'Steam not linked';
  switch (member.view) {
    case SteamView.notSetUp:
      return 'Steam presence not set up yet';
    case SteamView.notLinked:
      return 'Steam not linked';
    case SteamView.privateProfile:
      return 'Steam profile private';
    case SteamView.playing:
      final game = member.game?.trim() ?? '';
      if (game.isEmpty) return null;
      return 'Playing $game · via Steam';
    case SteamView.notInGame:
      return null;
  }
}

String steamSpokenLine(String name, String status) {
  if (status.startsWith('Playing ') && status.endsWith(' · via Steam')) {
    final game = status.substring(
      'Playing '.length,
      status.length - ' · via Steam'.length,
    );
    return '$name, playing $game via Steam';
  }
  return '$name, $status';
}
