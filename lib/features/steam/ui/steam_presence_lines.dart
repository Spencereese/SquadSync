import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/squad/domain/member.dart';
import 'package:squadsync/features/steam/domain/steam_presence.dart';

/// PC presence under the board. A missing function is one honest line.
class SteamPresenceLines extends ConsumerWidget {
  const SteamPresenceLines({required this.members, super.key});

  final List<Member> members;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(steamBoardProvider).asData?.value;
    if (board == null) return const SizedBox.shrink();
    if (!board.setUp) {
      return const Text(
        'Steam presence not set up yet',
        key: Key('steam-not-set-up'),
      );
    }
    final names = {for (final member in members) member.id: member.displayName};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final member in members)
          _line(member.id, names[member.id] ?? 'Someone', board),
      ].whereType<Widget>().toList(),
    );
  }

  Widget? _line(String userId, String name, SteamBoard board) {
    final status = steamStatusLine(board.forUser(userId), setUp: true);
    if (status == null) return null;
    final key = switch (board.forUser(userId)?.view) {
      SteamView.privateProfile => 'steam-private-$userId',
      SteamView.playing => 'steam-play-$userId',
      _ => 'steam-unlinked-$userId',
    };
    return Semantics(
      label: steamSpokenLine(name, status),
      excludeSemantics: true,
      child: Text(status, key: Key(key)),
    );
  }
}
