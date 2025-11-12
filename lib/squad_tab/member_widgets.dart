import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import 'dialogs/join_lobby_dialog.dart';

class MemberWidgets {
  static Widget buildPlayerStatusRow(
      BuildContext context, String player, SquadState squadState) {
    final status = squadState.statuses[player] ?? 'Offline';
    final timerIndex = squadState.squadSpots.indexOf(player);
    final timerDisplay =
        timerIndex != -1 ? squadState.getSpotTimerDisplay(timerIndex) : null;
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);
    final gameName = squadState.currentGame?['name'] ?? '';

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
                style:
                    const TextStyle(color: Colors.yellowAccent, fontSize: 12)),
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
  }

  static Widget _buildStatusChip(String status, {String? gameName}) {
    final displayStatus = gameName != null ? '$status ($gameName)' : status;
    return Chip(
      label: Text(displayStatus, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(color: _getStatusColor(status)),
    );
  }

  static Widget _buildMemberSubtitle(
      BuildContext context, String player, SquadState squadState) {
    final status = squadState.statuses[player] ?? 'Offline';
    final statusColor = _getMemberStatusColor(status);

    return Row(
      children: [
        Text(
          status,
          style: TextStyle(color: statusColor),
        ),
        if (squadState.getPlayerGame(player) != null) ...[
          const SizedBox(width: 8),
          Text(
            'Playing: ${squadState.getPlayerGame(player)}',
            style: TextStyle(color: Colors.blueAccent, fontSize: 12),
          ),
        ],
      ],
    );
  }

  static Widget _buildMemberActions(
      BuildContext context,
      String player,
      SquadState squadState,
      Function(BuildContext, ScaffoldMessengerState, SquadState, String)
          showComplaintDialog,
      {String? circle,
      List<String>? friends}) {
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);

    // Check if player is a friend
    final isFriend = friends?.contains(player) ?? false;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (streak > 0) ...[
          Icon(Icons.star, color: Colors.yellowAccent, size: 16),
          const SizedBox(width: 2),
          Text('$streak',
              style: const TextStyle(color: Colors.yellowAccent, fontSize: 12)),
        ],
        if (banCount > 0) ...[
          const SizedBox(width: 8),
          Icon(Icons.warning, color: Colors.redAccent, size: 16),
          const SizedBox(width: 2),
          Text('$banCount',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
        ],
        if (circle == 'Public' &&
            !isFriend &&
            player != squadState.displayName) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.person_add,
                color: Colors.blueAccent, size: 20),
            tooltip: 'Send Friend Request',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => _sendFriendRequest(context, player, squadState),
          ),
        ],
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.report, color: Colors.redAccent, size: 20),
          tooltip: 'File Complaint',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () {
            final messenger = ScaffoldMessenger.of(context);
            showComplaintDialog(context, messenger, squadState, player);
          },
        ),
      ],
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
      String player,
      SquadState squadState,
      Function(BuildContext, String, SquadState) showBlockDialog,
      Function(BuildContext, ScaffoldMessengerState, SquadState, String)
          showComplaintDialog,
      {String? circle,
      List<String>? friends}) {
    return Semantics(
      label: 'Member: $player',
      child: GestureDetector(
        onLongPress: () {
          if (player == squadState.displayName &&
              squadState.isPlayingSolo(player)) {
            // Stop solo play for current user
            squadState.stopSoloGame();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Stopped solo play'),
                backgroundColor: Colors.orange,
              ),
            );
          } else {
            JoinLobbyDialog.show(context, player, squadState);
          }
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
            ),
            subtitle: _buildMemberSubtitle(context, player, squadState),
            trailing: _buildMemberActions(
                context, player, squadState, showComplaintDialog,
                circle: circle, friends: friends),
          ),
        ),
      ),
    );
  }

  static void _sendFriendRequest(
      BuildContext context, String player, SquadState squadState) async {
    final playerUid = squadState.getUidForDisplayName(player);
    if (playerUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send friend request')),
      );
      return;
    }

    try {
      final userManager = Provider.of<UserManager>(context, listen: false);
      await userManager.sendFriendRequest(playerUid);

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
                          color: Colors.white.withOpacity(0.9),
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
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send friend request: $e')),
        );
      }
    }
  }
}
