import 'package:flutter/material.dart';
import '../squad_state.dart';

class PeacockWidgets {
  static Widget buildPeacockSpot(BuildContext context, SquadState squadState,
      Function() togglePeacockMembers) {
    final yourName = squadState.displayName;
    final youAreAssigned = squadState.squadSpots.contains(yourName);
    final currentGame = squadState.currentGame?['name'] ?? '';
    final youArePeacock = squadState.peacockTimers.containsKey(yourName) ||
        squadState.peacockQueue.contains(yourName);

    return GestureDetector(
      onLongPress: togglePeacockMembers,
      child: Semantics(
        label: 'Peacock Spot',
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPeacockInfo(context, squadState),
                GestureDetector(
                  onLongPress: togglePeacockMembers,
                  child: ElevatedButton(
                    onPressed: () {
                      if (youArePeacock) {
                        togglePeacockMembers();
                      } else if (youAreAssigned) {
                        final currentSpotIndex =
                            squadState.squadSpots.indexOf(yourName);
                        if (currentSpotIndex != -1) {
                          squadState.removeSpot(currentSpotIndex);
                        }
                        if (squadState.preferredPeacockGames
                            .contains(currentGame)) {
                          squadState.startPeacockTimer(context);
                        }
                      } else {
                        if (squadState.preferredPeacockGames
                            .contains(currentGame)) {
                          squadState.startPeacockTimer(context);
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 6,
                    ),
                    child: const Tooltip(
                      message:
                          'Tap to claim/toggle members, hold to toggle members',
                      child: Text('Claim'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildPeacockInfo(BuildContext context, SquadState squadState) {
    return Expanded(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Peacock: ',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              )),
          _buildPeacockStatus(context, squadState),
        ],
      ),
    );
  }

  static Widget _buildPeacockStatus(
      BuildContext context, SquadState squadState) {
    final allPeacockGames = <String, Map<String, dynamic>>{};

    // Collect peacock data by game
    for (final entry in squadState.peacockTimers.entries) {
      final game = entry.value?['game'] ?? 'Unknown';
      if (!allPeacockGames.containsKey(game)) {
        allPeacockGames[game] = {
          'timers': <MapEntry<String, Map<String, dynamic>?>>[],
          'queue': <String>[]
        };
      }
      allPeacockGames[game]!['timers'].add(entry);
    }

    for (final player in squadState.peacockQueue) {
      final game = squadState.getPlayerPreferredGame(player) ?? 'Unknown';
      if (!allPeacockGames.containsKey(game)) {
        allPeacockGames[game] = {
          'timers': <MapEntry<String, Map<String, dynamic>?>>[],
          'queue': <String>[]
        };
      }
      allPeacockGames[game]!['queue'].add(player);
    }

    if (allPeacockGames.isEmpty) {
      return const Text('Open', style: TextStyle(color: Colors.white));
    }

    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: allPeacockGames.entries.map((gameEntry) {
          final game = gameEntry.key;
          final timers = gameEntry.value['timers']
              as List<MapEntry<String, Map<String, dynamic>?>>;
          final queue = gameEntry.value['queue'] as List<String>;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$game:',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              ...timers.where((e) => e.value != null).map(
                  (entry) => _buildPeacockTimerRow(context, entry, squadState)),
              ...queue.map((player) => _buildPeacockQueueRow(context, player)),
            ],
          );
        }).toList(),
      ),
    );
  }

  static Widget _buildPeacockTimerRow(BuildContext context,
      MapEntry<String, Map<String, dynamic>?> entry, SquadState squadState) {
    final timer = entry.value;
    if (timer == null) return const SizedBox.shrink();
    final remainingTime = squadState.getPeacockTimerDisplay(entry.key);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(entry.key, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Strutting'),
        const SizedBox(width: 8),
        Text('($remainingTime)', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  static Widget _buildPeacockQueueRow(BuildContext context, String player) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(player, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(width: 8),
        _buildStatusChip('Waiting'),
      ],
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

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'Strutting':
        return Colors.blueAccent;
      case 'Waiting':
        return Colors.grey[400]!;
      default:
        return Colors.grey[600]!;
    }
  }

  static Widget buildPeacockMembersList(BuildContext context,
      SquadState squadState, Function(String, bool) togglePeacockMember) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // Preferred Games Section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Preferred Peacock Games',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.cyanAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: squadState.availableGames.map((game) {
                    final gameName = game['name'] as String;
                    final isPreferred =
                        squadState.preferredPeacockGames.contains(gameName);
                    return FilterChip(
                      label: Text(gameName),
                      selected: isPreferred,
                      onSelected: (selected) {
                        if (selected) {
                          squadState.addPreferredPeacockGame(gameName);
                        } else {
                          squadState.removePreferredPeacockGame(gameName);
                        }
                      },
                      backgroundColor: Colors.grey[800],
                      selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                      checkmarkColor: Colors.cyanAccent,
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          // Members List
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: squadState.getFilteredMembers.length,
            itemBuilder: (context, index) {
              final member = squadState.getFilteredMembers[index];
              final isInPeacock =
                  squadState.peacockTimers.containsKey(member) ||
                      squadState.peacockQueue.contains(member);
              return ListTile(
                title: Text(member),
                trailing: Icon(
                  isInPeacock ? Icons.remove_circle : Icons.add_circle,
                  color: isInPeacock ? Colors.red : Colors.green,
                  semanticLabel:
                      isInPeacock ? 'Remove from Peacock' : 'Add to Peacock',
                ),
                onTap: () => togglePeacockMember(member, isInPeacock),
              );
            },
          ),
        ],
      ),
    );
  }
}
