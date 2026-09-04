import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/lobby_ready_lock.dart';
import '../../services/lobby_seat_status.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../domain/entities/lobby_state.dart';
import '../dialogs/spot_assignment_dialog.dart';
import 'lobby_seat_affordance.dart';

/// LobbyGrid component - handles the display of spot cards and assignment logic
/// Extracted from the monolithic LobbyTab to improve maintainability
class LobbyGrid extends ConsumerWidget {
  const LobbyGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.when(
      data: (squadState) {
        final currentGame = squadState.currentGame;
        final maxSpots = currentGame?['maxSpots'] ?? 4;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => SpotCard(
              key: ValueKey('spot_$index'),
              index: index,
            ),
            childCount: maxSpots,
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => SliverToBoxAdapter(
        child: Center(child: Text('Error: $error')),
      ),
    );
  }
}

/// SpotCard - Individual spot card widget with optimized rebuilds
class SpotCard extends ConsumerWidget {
  final int index;

  const SpotCard({
    super.key,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadAsync.when(
      data: (squadState) => _buildSpotCard(context, ref, squadState),
      loading: () => const Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Loading spot...'),
        ),
      ),
      error: (error, stack) => Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: const Icon(Icons.error, color: Colors.red),
          title: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildSpotCard(
      BuildContext context, WidgetRef ref, LobbyState squadState) {
    final user = AuthServiceSupabase().currentUser;
    final yourUid = user?.id;

    final gameName = squadState.currentGame?['name'] ?? '';
    final squadSpots = squadState.gameLobbySpots[gameName] ?? [];
    final spotTimers = squadState.gameSpotTimers[gameName] ?? [];

    final spotName = index < squadSpots.length ? squadSpots[index] : null;
    // Strip _calling suffix before looking up display name
    final occupantUid = seatedUidFromOccupant(spotName);
    final cleanSpotName = occupantUid ?? spotName?.replaceAll('_calling', '');
    final spotDisplayName = cleanSpotName != null
        ? squadState.memberDisplayNames[cleanSpotName] ?? cleanSpotName
        : null;
    final hasOccupant = spotName != null;
    final occupantStatus = occupantUid == null
        ? null
        : occupantStatusForUser(
            state: squadState,
            userId: occupantUid,
            gameName: gameName,
          );
    final readyLock = resolveLobbyReadyLockFromState(
      squadState,
      gameName: gameName,
    );
    final isReady = occupantUid != null && readyLock.isReady(occupantUid);
    final isSeated = occupantIsSeated(spotName, occupantStatus);
    final isOwnSeat = occupantUid != null && occupantUid == yourUid;
    final lobbyLocked = readyLock.isLocked;

    final initial = spotDisplayName != null
        ? spotDisplayName[0].toUpperCase()
        : '${index + 1}';

    // Check if any buttons will be shown
    final hasTimer = index < spotTimers.length && spotTimers[index] != null;
    final isCalling = occupantIsCallingSpot(spotName, occupantStatus);
    final hasCallButton = !hasOccupant;
    final hasLockButton = hasOccupant && hasTimer && isCalling && isOwnSeat;
    final hasWalkingButton =
        hasOccupant && hasTimer && isReady && isOwnSeat && !isSeated;
    final hasReadyButton = isSeated && (isOwnSeat || isReady || lobbyLocked);
    final hasAnyButton =
        hasCallButton || hasLockButton || hasWalkingButton || hasReadyButton;

    LobbySeatStatus? seatStatus;
    try {
      seatStatus = resolveLobbySeatStatusFromTrackers(
        userId: yourUid,
        lobbyState: squadState,
      );
    } catch (_) {
      seatStatus = null;
    }
    final pulseOffered =
        seatStatus?.pulseOfferedSpot == true && seatStatus?.seatIndex == index;

    return OfferedSpotPulse(
      pulse: pulseOffered,
      child: GestureDetector(
        onLongPress: () {
          if (hasOccupant) {
            ref
                .read(ln.lobbyNotifierProvider.notifier)
                .removeSpot(gameName, index);
          } else {
            SpotAssignmentDialog.show(context, ref, index);
          }
        },
        onTap: hasAnyButton
            ? null
            : () {
                if (!hasOccupant) {
                  // Claim the empty spot
                  ref
                      .read(ln.lobbyNotifierProvider.notifier)
                      .claimSpot(gameName, index);
                } else if (hasOccupant && isOwnSeat) {
                  if (isReady) {
                    ref
                        .read(ln.lobbyNotifierProvider.notifier)
                        .lockSpot(gameName, index);
                  } else if (!isCalling) {
                    // Allow leaving spot by tapping when not ready and not calling
                    ref
                        .read(ln.lobbyNotifierProvider.notifier)
                        .removeSpot(gameName, index);
                  }
                  // Don't remove spot when calling - let the Lock button handle it
                } else if (hasOccupant && squadSpots.contains(yourUid)) {
                  // You're already in a spot, allow assigning others
                  SpotAssignmentDialog.show(context, ref, index);
                }
              },
        child: Semantics(
          label:
              'Spot ${index + 1}: ${spotDisplayName ?? 'Open'}${isOwnSeat && lobbyLocked ? ' (locked)' : isOwnSeat && isReady ? ' (ready)' : isOwnSeat && !isReady ? ' (tap Ready)' : ''}',
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            color: Colors.white.withValues(alpha: 0.1),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    hasOccupant ? Colors.cyanAccent : Colors.grey[600],
                child: Text(
                  hasOccupant ? initial : '${index + 1}',
                  style: TextStyle(
                      color: hasOccupant ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                'Spot ${index + 1}: ${spotDisplayName ?? 'Open'}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
              subtitle: _buildSpotSubtitle(
                context,
                index,
                spotTimers,
                occupantStatus: occupantStatus,
                isSeated: isSeated,
                isReady: isReady,
                lobbyLocked: lobbyLocked,
                hasOccupant: hasOccupant,
              ),
              trailing: _buildSpotActions(
                context,
                index,
                hasOccupant,
                yourUid,
                spotTimers,
                ref,
                gameName,
                isCalling: isCalling,
                isReady: isReady,
                isSeated: isSeated,
                isOwnSeat: isOwnSeat,
                lobbyLocked: lobbyLocked,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpotSubtitle(
    BuildContext context,
    int index,
    List<Map<String, dynamic>?> spotTimers, {
    required String? occupantStatus,
    required bool isSeated,
    required bool isReady,
    required bool lobbyLocked,
    required bool hasOccupant,
  }) {
    final hasTimer = index < spotTimers.length && spotTimers[index] != null;
    final timerDisplay = hasTimer ? _getTimerDisplay(spotTimers[index]) : null;
    final status = !hasOccupant
        ? 'Open'
        : lobbyLocked && isSeated
            ? 'Locked'
            : isReady
                ? 'Ready'
                : occupantStatus == 'Calling'
                    ? 'Calling'
                    : 'Occupied';
    final statusColor = _getSpotStatusColor(status);

    return Row(
      children: [
        Text(
          status,
          style: TextStyle(color: statusColor),
        ),
        if (timerDisplay != null && timerDisplay != '00:00') ...[
          const SizedBox(width: 8),
          Text(
            '($timerDisplay)',
            style: TextStyle(color: statusColor, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Color _getSpotStatusColor(String status) {
    switch (status) {
      case 'Ready':
        return Colors.greenAccent;
      case 'Locked':
        return Colors.amberAccent;
      case 'Calling':
        return Colors.orangeAccent;
      case 'Occupied':
        return Colors.white70;
      case 'Open':
        return Colors.grey;
      default:
        return Colors.white70;
    }
  }

  String? _getTimerDisplay(Map<String, dynamic>? timer) {
    if (timer == null) return null;
    final remainingSeconds = timer['remaining'] as int?;
    if (remainingSeconds != null) {
      final remaining = Duration(seconds: remainingSeconds);
      if (remaining.isNegative || remaining == Duration.zero) return 'Expired';
      final minutes = remaining.inMinutes;
      final seconds = remaining.inSeconds % 60;
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return 'Timer';
  }

  Widget _buildSpotActions(
    BuildContext context,
    int index,
    bool hasOccupant,
    String? yourUid,
    List<Map<String, dynamic>?> spotTimers,
    WidgetRef ref,
    String gameName, {
    required bool isCalling,
    required bool isReady,
    required bool isSeated,
    required bool isOwnSeat,
    required bool lobbyLocked,
  }) {
    final hasTimer = index < spotTimers.length && spotTimers[index] != null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!hasOccupant)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.tealAccent, Colors.teal],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.tealAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => ref
                  .read(ln.lobbyNotifierProvider.notifier)
                  .claimSpot(gameName, index),
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Call'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else if (hasOccupant && hasTimer && isCalling && isOwnSeat)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.yellowAccent, Colors.orange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.yellowAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => ref
                  .read(ln.lobbyNotifierProvider.notifier)
                  .lockSpot(gameName, index),
              icon: const Icon(Icons.lock, size: 16),
              label: const Text('Lock'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.black,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          )
        else if (isSeated)
          SeatedSpotReadyAffordance(
            isReady: isReady,
            isLocked: lobbyLocked,
            isOwnSeat: isOwnSeat,
            onToggle: isOwnSeat && yourUid != null
                ? () => _toggleSeatedReady(
                      context,
                      ref,
                      userId: yourUid,
                      gameName: gameName,
                      spotIndex: index,
                    )
                : null,
          )
        else if (hasOccupant && hasTimer && isReady && isOwnSeat)
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.redAccent, Colors.red],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => ref
                  .read(ln.lobbyNotifierProvider.notifier)
                  .removeSpot(gameName, index),
              icon: const Icon(Icons.directions_walk, size: 16),
              label: const Text('Leave'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _toggleSeatedReady(
    BuildContext context,
    WidgetRef ref, {
    required String userId,
    required String gameName,
    required int spotIndex,
  }) async {
    final result =
        await ref.read(ln.lobbyNotifierProvider.notifier).toggleSeatedReady(
              userId: userId,
              gameName: gameName,
              spotIndex: spotIndex,
            );
    final message = result?.snackbarMessage;
    if (message != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
}
