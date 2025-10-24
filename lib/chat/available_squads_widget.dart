import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../managers/squad_manager.dart';
import '../squad_state.dart';

class AvailableSquadsWidget extends StatelessWidget {
  const AvailableSquadsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peacocks')
          .where('hostUid', isNotEqualTo: currentUser.uid)
          .where('timer', isGreaterThan: Timestamp.now())
          .orderBy('timer', descending: false)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final availableSquads = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final claimed = (data['claimed'] as List<dynamic>?) ?? [];
          final maxSpots = data['spots'] ?? 4;
          // Only show if there's space available
          return claimed.length < maxSpots;
        }).toList();

        if (availableSquads.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orangeAccent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orangeAccent.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.group_add, color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Available Squads',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...availableSquads.map((doc) => _buildSquadItem(context, doc)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquadItem(BuildContext context, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final gameName = data['game']?['name'] ?? 'Unknown Game';
    final maxSpots = data['spots'] ?? 4;
    final claimed = (data['claimed'] as List<dynamic>?) ?? [];
    final currentSpots = claimed.length;
    final nextSpot = currentSpots + 1;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$gameName - $currentSpots/$maxSpots',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _callSpot(context, doc.id, data),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 32),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              '$nextSpot/$maxSpots',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _callSpot(BuildContext context, String peacockId,
      Map<String, dynamic> peacockData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Call the spot using SquadManager
      final squadManager = Provider.of<SquadManager>(context, listen: false);
      await squadManager.joinLobby(peacockId, currentUser.uid);

      // Update local status to reflect joining the lobby
      final squadState = Provider.of<SquadState>(context, listen: false);
      squadState.dataManager.globalStatuses[squadState.displayName ?? ''] =
          'Ready';

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Called spot in ${peacockData['game']?['name'] ?? 'squad'}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to call spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
