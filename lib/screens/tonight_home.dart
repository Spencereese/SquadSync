import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lobby_state.dart';
import '../presentation/notifiers/lobby_notifier.dart';
import '../services/presence_badges.dart';

/// Friends empty Tonight: presence → card → LFG → last locked (if any).
/// Start a lobby is Slice A [createLobby] bind, not Discovery.
class TonightEmptyHome extends ConsumerWidget {
  const TonightEmptyHome({
    super.key,
    this.chatGroupId,
    this.gameName,
  });

  final String? chatGroupId;
  final String? gameName;

  static bool hasLastLockedSession(LobbyState state) {
    return state.gameHistory.isNotEmpty ||
        state.dailyRatings.isNotEmpty ||
        state.allTimeRatings.isNotEmpty;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state =
        ref.watch(lobbyNotifierProvider).valueOrNull ?? LobbyState.initial();
    final showLastLocked = hasLastLockedSession(state);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0E14),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TonightPresenceRow(),
              const SizedBox(height: 20),
              _TonightNothingCard(
                chatGroupId: chatGroupId,
                gameName: gameName,
              ),
              const SizedBox(height: 16),
              const _TonightLfgRow(),
              if (showLastLocked) ...[
                const SizedBox(height: 16),
                const _TonightLastLocked(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TonightPresenceRow extends StatelessWidget {
  const _TonightPresenceRow();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('tonight-presence-row'),
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final kind in const [
          PresenceBadgeKind.on,
          PresenceBadgeKind.looking,
          PresenceBadgeKind.inLobby,
        ])
          _PresenceChip(label: presenceBadgeLabel(kind)),
      ],
    );
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TonightNothingCard extends ConsumerWidget {
  const _TonightNothingCard({
    this.chatGroupId,
    this.gameName,
  });

  final String? chatGroupId;
  final String? gameName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      key: const Key('tonight-card-nothing'),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF141821),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Nothing tonight',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            key: const Key('tonight-start-lobby'),
            onPressed: () {
              final name = gameName?.trim();
              ref.read(lobbyNotifierProvider.notifier).createLobby(
                    chatGroupId: chatGroupId?.trim() ?? '',
                    gameName: (name != null && name.isNotEmpty) ? name : 'Squad',
                    maxSpots: 8,
                    isPublic: false,
                  );
            },
            child: const Text('Start a lobby'),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('tonight-im-on'),
            onPressed: () {},
            child: const Text("I'm on"),
          ),
        ],
      ),
    );
  }
}

class _TonightLfgRow extends StatelessWidget {
  const _TonightLfgRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('tonight-lfg-row'),
      children: [
        Icon(Icons.group_add, color: Colors.white54, size: 18),
        SizedBox(width: 8),
        Text(
          'LFG / peacock',
          style: TextStyle(color: Colors.white54, fontSize: 13),
        ),
      ],
    );
  }
}

class _TonightLastLocked extends StatelessWidget {
  const _TonightLastLocked();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Last locked session',
      key: Key('tonight-last-locked'),
      style: TextStyle(color: Colors.white54, fontSize: 13),
    );
  }
}
