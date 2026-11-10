import 'package:squadsync/features/steam/domain/steam_presence.dart';

class SteamLink {
  const SteamLink(this.steamId);

  final String steamId;
}

class SteamLinkResult {
  const SteamLinkResult({this.link, this.message});

  final SteamLink? link;
  final String? message;

  bool get saved => link != null;
}

/// Squad PC presence. A missing function or secret is [SteamBoard.notSetUp],
/// not an error and not a guess.
abstract class SteamRepository {
  Future<SteamBoard> presence();

  Future<SteamLink?> mine();

  Future<SteamLinkResult> link(String raw);

  Future<void> unlink();
}
