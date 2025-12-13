import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/entities/lobby.dart';
import '../presentation/notifiers/lobby_notifier.dart';
import '../utils.dart';

class SpotsLobbyBar extends ConsumerWidget {
  final Lobby squad;

  const SpotsLobbyBar({super.key, required this.squad});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxSpots = squad.maxSpots;
    if (maxSpots == 0) return const SizedBox.shrink();

    return Container(
      height: 60,
      color: Theme.of(context).colorScheme.surface,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: maxSpots,
        itemBuilder: (context, index) {
          final spotNumber = (index + 1).toString();
          final claimedUid =
              index < squad.spots.length ? squad.spots[index] : null;
          final isClaimed = claimedUid != null;
          final hasTimer = index < squad.spotTimers.length &&
              squad.spotTimers[index] != null;

          return _SpotItem(
            spotNumber: spotNumber,
            isClaimed: isClaimed,
            claimedUid: claimedUid,
            hasPeacockTimer: hasTimer,
            onClaim: () => _claimSpot(ref, index),
            onUnclaim: () => _unclaimSpot(ref, index),
          );
        },
      ),
    );
  }

  void _claimSpot(WidgetRef ref, int spotIndex) {
    // Use unified notifier's simple claim method
    ref.read(lobbyNotifierProvider.notifier).claimSpotSimple(spotIndex);
  }

  void _unclaimSpot(WidgetRef ref, int spotIndex) {
    // Use unified notifier's simple unclaim method
    ref.read(lobbyNotifierProvider.notifier).unclaimSpotSimple(spotIndex);
  }
}

class _SpotItem extends StatelessWidget {
  final String spotNumber;
  final bool isClaimed;
  final String? claimedUid;
  final bool hasPeacockTimer;
  final VoidCallback onClaim;
  final VoidCallback onUnclaim;

  const _SpotItem({
    required this.spotNumber,
    required this.isClaimed,
    required this.claimedUid,
    required this.hasPeacockTimer,
    required this.onClaim,
    required this.onUnclaim,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Spot number
          Text(
            spotNumber,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 4),

          // Avatar/Claim button
          GestureDetector(
            onTap: isClaimed ? onUnclaim : onClaim,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isClaimed
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: isClaimed
                  ? _buildClaimedAvatar(context)
                  : _buildUnclaimedIcon(context),
            ),
          ),

          // Peacock timer indicator
          if (hasPeacockTimer)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'P', // Placeholder for timer
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontSize: 10,
                    ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClaimedAvatar(BuildContext context) {
    // For now, just show initials or icon
    // TODO: Replace with actual user avatar/display name
    final displayName = safeDisplayName(claimedUid); // Will show UID for now
    final initials = displayName.isNotEmpty
        ? displayName.substring(0, min(2, displayName.length)).toUpperCase()
        : '?';

    return Center(
      child: Text(
        initials,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildUnclaimedIcon(BuildContext context) {
    return Icon(
      Icons.add,
      size: 20,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
  }
}
