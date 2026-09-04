import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:squad_sync/widgets/presence_badge_row.dart';

class MemberWidgets {
  static Widget buildPlayerStatusRow(
      BuildContext context, WidgetRef ref, String player) {
    return ref.read(ln.lobbyNotifierProvider).when(
          data: (squadState) {
            final gameName = squadState.currentGame?['name'] ?? '';
            final globalStatuses = squadState.globalStatuses;
            final gameStatuses = squadState.gameStatuses[gameName] ?? {};
            final status =
                gameStatuses[player] ?? globalStatuses[player] ?? 'Offline';
            final squadSpots = squadState.gameLobbySpots[gameName] ?? [];
            final timerIndex = squadSpots.indexOf(player);
            final timerDisplay = timerIndex != -1
                ? 'Timer'
                : null; // Placeholder, need to implement getSpotTimerDisplay
            final streak = 0; // Placeholder, need to implement currentStreaks
            final banCount = 0; // Placeholder, need to implement getBanCount

            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                children: [
                  _buildStatusChip(status,
                      gameName: status == 'Claimed Spot' ? gameName : null),
                  if (timerDisplay != null &&
                      (status == 'Ready' ||
                          status == 'Calling' ||
                          status == 'Claimed Spot' ||
                          status == 'in game'))
                    Text('($timerDisplay)',
                        style: Theme.of(context).textTheme.bodySmall),
                  if (streak > 0) ...[
                    Image.asset(
                      'assets/images/performance.png',
                      width: 16,
                      height: 16,
                      color: Colors.yellowAccent,
                    ),
                    Text('$streak',
                        style: const TextStyle(
                            color: Colors.yellowAccent, fontSize: 12)),
                  ],
                  if (banCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(
                        banCount,
                        (_) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Image.asset(
                            'assets/images/sword.png',
                            width: 16,
                            height: 16,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading squad: $e'),
        );
  }

  static Widget _buildStatusChip(String status, {String? gameName}) {
    final displayStatus = gameName != null ? '$status ($gameName)' : status;
    return Chip(
      label: Text(
        displayStatus,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(color: _getStatusColor(status)),
    );
  }

  static Widget _buildMemberSubtitle(
      BuildContext context, WidgetRef ref, String player) {
    return ref.read(ln.lobbyNotifierProvider).when(
          data: (squadState) {
            final gameName = squadState.currentGame?['name'] ?? '';
            final globalStatuses = squadState.globalStatuses;
            final gameStatuses = squadState.gameStatuses[gameName] ?? {};
            final status =
                gameStatuses[player] ?? globalStatuses[player] ?? 'Offline';
            final statusColor = _getMemberStatusColor(status);

            return Row(
              children: [
                Text(
                  status,
                  style: TextStyle(color: statusColor),
                ),
                // Placeholder for getPlayerGame - need to implement
                // if (getPlayerGame(player) != null) ...[
                //   const SizedBox(width: 8),
                //   Text(
                //     'Playing: ${getPlayerGame(player)}',
                //     style: TextStyle(color: Colors.blueAccent, fontSize: 12),
                //   ),
                // ],
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading squad: $e'),
        );
  }

  static Widget _buildMemberActions(
      BuildContext context,
      WidgetRef ref,
      String player,
      Function(BuildContext, ScaffoldMessengerState, WidgetRef, String)
          showComplaintDialog,
      {String? circle,
      List<String>? friends}) {
    return ref.read(ln.lobbyNotifierProvider).when(
          data: (squadState) {
            final streak = 0; // Placeholder, need to implement currentStreaks
            final banCount = 0; // Placeholder, need to implement getBanCount
            final displayName = squadState.displayName;

            // Check if player is a friend
            final isFriend = friends?.contains(player) ?? false;

            return Wrap(
              spacing: 4,
              runSpacing: 2,
              alignment: WrapAlignment.end,
              children: [
                if (streak > 0) ...[
                  Icon(Icons.star, color: Colors.yellowAccent, size: 16),
                  const SizedBox(width: 2),
                  Text('$streak',
                      style: const TextStyle(
                          color: Colors.yellowAccent, fontSize: 12)),
                ],
                if (banCount > 0) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.warning, color: Colors.redAccent, size: 16),
                  const SizedBox(width: 2),
                  Text('$banCount',
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 12)),
                ],
                if (circle == 'Public' &&
                    !isFriend &&
                    player != displayName) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.person_add,
                        color: Colors.blueAccent, size: 20),
                    tooltip: 'Send Friend Request',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _sendFriendRequest(context, ref, player),
                  ),
                ],
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.report,
                      color: Colors.redAccent, size: 20),
                  tooltip: 'File Complaint',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    final messenger = ScaffoldMessenger.of(context);
                    showComplaintDialog(context, messenger, ref, player);
                  },
                ),
              ],
            );
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading squad: $e'),
        );
  }

  static Color _getMemberStatusColor(String status) {
    switch (status) {
      case 'Ready':
        return Colors.greenAccent;
      case 'Calling':
        return Colors.orangeAccent;
      case 'in game':
        return Colors.blueAccent;
      case 'Offline':
        return Colors.grey;
      default:
        return Colors.white70;
    }
  }

  static Color _getStatusColor(String status) {
    if (status.contains('(Solo)') || status == 'Playing Solo') {
      return Colors.greenAccent; // Solo players are "walking" (active)
    }
    switch (status) {
      case 'Strutting':
        return Colors.blueAccent;
      case 'Walking':
        return Colors.greenAccent;
      case 'in game':
        return Colors.greenAccent;
      case 'Ready':
        return Colors.yellowAccent;
      case 'Calling':
        return Colors.cyanAccent;
      case 'Claimed Spot':
        return Colors.orangeAccent;
      case 'Waiting':
        return Colors.grey[400]!;
      default:
        return Colors.grey[600]!;
    }
  }

  static Widget buildMemberCard(
      BuildContext context,
      WidgetRef ref,
      String player,
      Function(BuildContext, String, WidgetRef) showBlockDialog,
      Function(BuildContext, ScaffoldMessengerState, WidgetRef, String)
          showComplaintDialog,
      {String? circle,
      List<String>? friends}) {
    // final displayName = ref
    //     .read(squadStateNotifierProvider.select((state) => state.displayName));
    // Placeholder for isPlayingSolo - need to implement
    // final isPlayingSolo = false;
    return Semantics(
      label: 'Member: $player',
      child: GestureDetector(
        onLongPress: () {
          // Placeholder for solo play logic - need to implement
          // if (player == displayName && isPlayingSolo) {
          //   // Stop solo play for current user
          //   ScaffoldMessenger.of(context).showSnackBar(
          //     const SnackBar(
          //       content: Text('Stopped solo play'),
          //       backgroundColor: Colors.orange,
          //     ),
          //   );
          // } else {
          // JoinLobbyDialog.show(context, player, ref); // Placeholder, need to update JoinLobbyDialog
          // }
        },
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          color: Colors.white.withValues(alpha: 0.1),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.cyanAccent,
              child: Text(
                player.isNotEmpty ? player[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              player,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMemberSubtitle(context, ref, player),
                PresenceBadgesHost(userId: player),
              ],
            ),
            trailing: _buildMemberActions(
                context, ref, player, showComplaintDialog,
                circle: circle, friends: friends),
          ),
        ),
      ),
    );
  }

  static void _sendFriendRequest(
      BuildContext context, WidgetRef ref, String player) async {
    final asyncState = ref.read(ln.lobbyNotifierProvider);
    if (asyncState is AsyncData) {
      final squadState = asyncState.value!;
      final memberDisplayNames = squadState.memberDisplayNames;
      final playerUid = memberDisplayNames.entries
          .firstWhere((entry) => entry.value == player,
              orElse: () => MapEntry('', ''))
          .key;
      if (playerUid.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send friend request')),
        );
        return;
      }

      // final userManager = ref.read(userManagerProvider); // Placeholder, need to implement userManagerProvider
      // await userManager.sendFriendRequest(playerUid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Friend Request Sent!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Request sent to $player',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}
