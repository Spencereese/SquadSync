import 'package:flutter/material.dart';
import '../squad_state.dart';

class MemberWidgets {
  static Widget buildPlayerStatusRow(
      BuildContext context, String player, SquadState squadState) {
    final status = squadState.statuses[player] ?? 'Offline';
    final timerIndex = squadState.squadSpots.indexOf(player);
    final timerDisplay =
        timerIndex != -1 ? squadState.getSpotTimerDisplay(timerIndex) : null;
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 8,
        children: [
          _buildStatusChip(status),
          if (timerDisplay != null && status == 'Ready')
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

  static Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(status, style: const TextStyle(fontSize: 12)),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.2),
      labelStyle: TextStyle(color: _getStatusColor(status)),
    );
  }

  static Widget _buildGameBadge(String gameName, {bool isSolo = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Playing: $gameName${isSolo ? ' (Solo)' : ''}',
        style: const TextStyle(
          color: Colors.blueAccent,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  static Widget _buildLobbyBadge(String hostName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Lobby: $hostName',
        style: const TextStyle(
          color: Colors.greenAccent,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
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
      case 'Ready':
        return Colors.yellowAccent;
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
      Function(BuildContext, String, SquadState) showJoinLobbyDialog,
      Function(BuildContext, ScaffoldMessengerState, SquadState, String)
          showComplaintDialog) {
    final streak = squadState.currentStreaks[player] ?? 0;
    final banCount = squadState.getBanCount(player);
    final status = squadState.statuses[player] ?? 'Offline';

    // Check if player is in a lobby and if there are blocked players in that lobby
    final playerLobby = squadState.getPlayerLobby(player);
    final hasBlockedInLobby = playerLobby != null &&
        squadState.hasBlockedPlayersInLobby(
            playerLobby, squadState.displayName ?? '');

    String winIcon = 'assets/images/performance.png';
    if (streak >= 10) {
      winIcon = 'assets/images/chicken.png';
    } else if (streak >= 4) {
      winIcon = 'assets/images/duck.png';
    } else if (streak >= 3) {
      winIcon = 'assets/images/turkey.png';
    }

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
            showJoinLobbyDialog(context, player, squadState);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration:
              BoxDecoration(border: Border.all(color: Colors.grey[800]!)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(player,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        if (hasBlockedInLobby) ...[
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Mixed—Blocked players in lobby',
                            child: Icon(
                              Icons.warning,
                              color: Colors.orangeAccent,
                              size: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildStatusChip(status),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        if (squadState.getPlayerGame(player) != null)
                          _buildGameBadge(
                            squadState.getPlayerGame(player)!,
                            isSolo: squadState.isPlayingSolo(player),
                          ),
                        if (playerLobby != null)
                          _buildLobbyBadge(playerLobby['host'] ?? 'Unknown'),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  if (streak > 0)
                    Row(
                      children: [
                        Image.asset(winIcon,
                            width: 20, height: 20, color: Colors.yellowAccent),
                        const SizedBox(width: 4),
                        Text('$streak',
                            style: const TextStyle(color: Colors.yellowAccent)),
                      ],
                    ),
                  if (banCount > 0) ...[
                    const SizedBox(width: 12),
                    Row(
                      children: [
                        Image.asset('assets/images/sword.png',
                            width: 20, height: 20, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text('$banCount',
                            style: const TextStyle(color: Colors.redAccent)),
                      ],
                    ),
                  ],
                  const SizedBox(width: 12),
                  Semantics(
                    label: 'File complaint against $player',
                    child: IconButton(
                      icon: const Icon(Icons.report, color: Colors.redAccent),
                      tooltip: 'File Complaint',
                      onPressed: () {
                        final messenger = ScaffoldMessenger.of(context);
                        showComplaintDialog(
                            context, messenger, squadState, player);
                      },
                    ),
                  ),
                  Semantics(
                    label: 'Rate $player',
                    child: IconButton(
                      icon: const Icon(Icons.star, color: Colors.yellowAccent),
                      tooltip: 'Rate Member',
                      onPressed: () {
                        // This would need to be passed from parent
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
