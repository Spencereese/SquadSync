import 'package:squadsync/features/steam/data/steam_repository.dart';
import 'package:squadsync/features/steam/domain/steam_presence.dart';

/// In-memory Steam. [board] is what the home shows. [acceptsLinks] is false
/// when the function is not set up.
class FakeSteamRepository implements SteamRepository {
  FakeSteamRepository({
    this.board = SteamBoard.notSetUp,
    this.acceptsLinks = false,
    this.linkedId,
  });

  SteamBoard board;
  bool acceptsLinks;
  String? linkedId;

  @override
  Future<SteamBoard> presence() async => board;

  @override
  Future<SteamLink?> mine() async {
    final id = linkedId;
    if (id == null || id.isEmpty) return null;
    return SteamLink(id);
  }

  @override
  Future<SteamLinkResult> link(String raw) async {
    if (!acceptsLinks) {
      return const SteamLinkResult(message: 'Steam presence not set up yet');
    }
    final text = raw.trim();
    if (!RegExp(r'^[0-9]{17}$').hasMatch(text)) {
      return const SteamLinkResult(
        message: 'That is not a SteamID64 or a vanity URL.',
      );
    }
    linkedId = text;
    return SteamLinkResult(link: SteamLink(text));
  }

  @override
  Future<void> unlink() async {
    linkedId = null;
  }
}
