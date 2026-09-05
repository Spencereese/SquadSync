import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../chat/screens/components/chat_info_actions.dart';
import '../../services/auth_service_supabase.dart';
import '../../services/lobby_ready_lock.dart';
import '../../services/lobby_seat_status.dart';
import '../../services/matchmaking_queue_machine.dart';
import '../../services/peacock_assignment_machine.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;
import '../../domain/entities/lobby_state.dart';
import '../dialogs/spot_assignment_dialog.dart';
import 'lobby_seat_affordance.dart';
import 'lobby_spot_map_seat.dart';

/// LobbyGrid component - handles the display of spot cards and assignment logic
/// Extracted from the monolithic LobbyTab to improve maintainability
class LobbyGrid extends ConsumerWidget {
  const LobbyGrid({super.key, this.highlightSpotIndex});

  /// Deep-link `spot_index` from chat peacock card / notification taps.
  final int? highlightSpotIndex;

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
              highlightSpotIndex: highlightSpotIndex,
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
  final int? highlightSpotIndex;

  const SpotCard({
    super.key,
    required this.index,
    this.highlightSpotIndex,
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

    // Check if any buttons will be shown
    final hasTimer = index < spotTimers.length && spotTimers[index] != null;
    final isCalling = occupantIsCallingSpot(spotName, occupantStatus);
    final allowLateJoin = emptySpotAllowsLateJoin(readyLock);
    final showEmptyCtas = emptySpotShowsCtas(
      hasOccupant: hasOccupant,
      allowLateJoin: allowLateJoin,
    );
    final hasLockButton = hasOccupant && hasTimer && isCalling && isOwnSeat;
    final hasWalkingButton =
        hasOccupant && hasTimer && isReady && isOwnSeat && !isSeated;
    final hasReadyButton = isSeated && (isOwnSeat || isReady || lobbyLocked);
    final hasAnyButton =
        showEmptyCtas || hasLockButton || hasWalkingButton || hasReadyButton;

    LobbySeatStatus? seatStatus;
    try {
      seatStatus = resolveLobbySeatStatusFromTrackers(
        userId: yourUid,
        lobbyState: squadState,
      );
    } catch (_) {
      seatStatus = null;
    }
    final pulseOffered = pulseOfferedSpotAt(
      index: index,
      status: seatStatus,
      highlightSpotIndex: highlightSpotIndex,
    );
    final kind = lobbySpotMapKindFor(
      hasOccupant: hasOccupant,
      peacockOffered: pulseOffered,
    );
    final timerRemaining =
        hasTimer ? remainingFromSpotTimer(spotTimers[index]) : null;
    final queueAssigned = pulseOffered ||
        (hasOccupant &&
            isCalling &&
            seatStatus?.offerPending == true &&
            seatStatus?.seatIndex == index);
    final timerDisplay = formatTimerExpiryLabel(
      remaining: timerRemaining,
      queueAssigned: queueAssigned,
    );
    final statusLabel = _spotStatusLabel(
      kind: kind,
      timerRemaining: timerRemaining,
      queueAssigned: queueAssigned,
      lobbyLocked: lobbyLocked,
      isSeated: isSeated,
      isReady: isReady,
      occupantStatus: occupantStatus,
    );
    MatchmakingQueuePhase? lfgPhase;
    PeacockAssignmentPhase? peacockPhase;
    if (yourUid != null) {
      try {
        lfgPhase = MatchmakingQueueTracker.instance.stateFor(yourUid).phase;
        peacockPhase =
            PeacockAssignmentTracker.instance.stateFor(yourUid).phase;
      } catch (_) {}
    }
    final queuePending = emptySpotQueuePending(
      lfgPhase: lfgPhase,
      peacockPhase: peacockPhase,
      peacockQueueOccupied: squadState.peacockQueue.isNotEmpty,
    );
    final emptyCtaKind = emptySpotCtaKindFor(
      peacockOffered: pulseOffered || kind == LobbySpotMapKind.peacock,
      queuePending: queuePending,
    );

    return OfferedSpotPulse(
      pulse: pulseOffered,
      child: LobbySpotMapSeat(
        index: index,
        kind: kind,
        statusLabel: statusLabel,
        displayName: spotDisplayName,
        timerLabel: timerDisplay,
        semanticLabel:
            'Spot ${index + 1}: ${spotDisplayName ?? 'Open'}${isOwnSeat && lobbyLocked ? ' (locked)' : isOwnSeat && isReady ? ' (ready)' : isOwnSeat && !isReady ? ' (tap Ready)' : ''}',
        onLongPress: () {
          if (hasOccupant) {
            ref
                .read(ln.lobbyNotifierProvider.notifier)
                .removeSpot(gameName, index);
          } else {
            SpotAssignmentDialog.show(context, ref, index);
          }
        },
        actions: showEmptyCtas
            ? EmptySpotCtaBar(
                primary: emptyCtaKind,
                onInvite: () => _inviteEmptySpot(context, squadState),
                onPeacock: () => _peacockEmptySpot(
                  context,
                  ref,
                  uid: yourUid,
                  squadState: squadState,
                  gameName: gameName,
                  index: index,
                ),
                onQueue: () => _queueEmptySpot(
                  context,
                  ref,
                  uid: yourUid,
                  gameName: gameName,
                ),
              )
            : null,
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
        trailing: hasOccupant
            ? _buildSpotActions(
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
              )
            : null,
      ),
    );
  }

  String _spotStatusLabel({
    required LobbySpotMapKind kind,
    required Duration? timerRemaining,
    required bool queueAssigned,
    required bool lobbyLocked,
    required bool isSeated,
    required bool isReady,
    required String? occupantStatus,
  }) {
    if (timerRemainingIsExpired(timerRemaining)) return 'Expired';
    if (queueAssigned) return 'Assigned';
    switch (kind) {
      case LobbySpotMapKind.peacock:
        return 'Peacock';
      case LobbySpotMapKind.empty:
        return 'Open';
      case LobbySpotMapKind.filled:
        if (lobbyLocked && isSeated) return 'Locked';
        if (isReady) return 'Ready';
        if (occupantStatus == 'Calling') return 'Calling';
        return 'Occupied';
    }
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
        if (hasOccupant && hasTimer && isCalling && isOwnSeat)
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
            timeoutRemaining: isOwnSeat
                ? ref
                    .read(ln.lobbyNotifierProvider.notifier)
                    .readyCheckRemaining()
                : null,
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

  Future<void> _inviteEmptySpot(
    BuildContext context,
    LobbyState squadState,
  ) async {
    final lobbyId = resolveInviteLobbyId(
      squadId: squadState.selectedLobbyId ?? squadState.currentLobby?.id ?? '',
      selectedLobbyId: squadState.selectedLobbyId,
      currentLobby: squadState.currentLobby,
      userLobbies: squadState.userLobbies,
    );
    if (lobbyId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lobby selected')),
        );
      }
      return;
    }
    try {
      await shareEmptySpotInvite(lobbyId: lobbyId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lobby link copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share lobby link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _peacockEmptySpot(
    BuildContext context,
    WidgetRef ref, {
    required String? uid,
    required LobbyState squadState,
    required String gameName,
    required int index,
  }) async {
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to claim peacock')),
        );
      }
      return;
    }
    final lobbyId = squadState.selectedLobbyId ?? squadState.currentLobby?.id;
    if (lobbyId == null || lobbyId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lobby selected')),
        );
      }
      return;
    }
    try {
      final claimed =
          await ref.read(ln.lobbyNotifierProvider.notifier).assignPeacockSpot(
                userId: uid,
                lobbyId: lobbyId,
                gameName: gameName,
                spotIndex: index,
              );
      final lfg = MatchmakingQueueTracker.instance.stateFor(uid);
      if (lfg.phase == MatchmakingQueuePhase.matched) {
        MatchmakingQueueTracker.instance
            .joinMatched(uid, handoffToPeacock: false);
        await MatchmakingQueueTracker.instance.persistCurrent(uid);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(claimSeatCopy(claimed ?? index))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to claim peacock: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _queueEmptySpot(
    BuildContext context,
    WidgetRef ref, {
    required String? uid,
    required String gameName,
  }) async {
    if (uid == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to join the queue')),
        );
      }
      return;
    }
    try {
      await ref
          .read(ln.lobbyNotifierProvider.notifier)
          .addToPeacockQueue(uid, gameName);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Queued for a spot')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join queue: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
