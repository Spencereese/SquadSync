import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';

/// Bottom sheet showing squad roster, alert circles, and active spots summary
class SquadSheet extends StatelessWidget {
  const SquadSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SquadSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                // Header with drag handle
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.1),
                        Colors.white.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Title
                      Text(
                        'Squad Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Active Spots Summary
                      _buildActiveSpotsSection(squadState),
                      const SizedBox(height: 24),
                      // Roster
                      _buildRosterSection(squadState),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActiveSpotsSection(SquadState squadState) {
    final activeGames = squadState.availableGames.where((game) {
      final spots = squadState.gameSquadSpots[game['name']] ?? [];
      return spots.where((spot) => spot != null).isNotEmpty;
    }).toList();

    if (activeGames.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active Spots',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gamepad,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'No active games',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Active Spots',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...activeGames.map((game) {
          final spots = squadState.gameSquadSpots[game['name']] ?? [];
          final filledCount = spots.where((spot) => spot != null).length;
          final maxSpots = game['maxSpots'] as int? ?? 4;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.gamepad,
                  color: Colors.cyanAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game['name'] as String,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$filledCount/$maxSpots spots filled',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildRosterSection(SquadState squadState) {
    final members = squadState.getFilteredMembers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Squad Roster',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${members.length} members',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...members.map((member) {
          final status = squadState.statuses[member] ?? 'Offline';
          final game = squadState.getPlayerGame(member);
          final isOnline = ['Strutting', 'Walking', 'Ready'].contains(status);

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: isOnline ? Colors.green : Colors.grey,
                  child: Text(
                    member.isNotEmpty ? member[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        game != null ? 'Playing: $game' : status,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
