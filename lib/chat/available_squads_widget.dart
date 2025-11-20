import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../managers/squad_manager.dart';
import '../providers.dart';

class AvailableSquadsWidget extends ConsumerWidget {
  const AvailableSquadsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peacocks')
          .where('timer', isGreaterThan: Timestamp.now())
          .orderBy('timer', descending: false)
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        final localRef = ref;
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final availableSquads = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final maxSpots = data['spots'] ?? 4;
          final filled = (data['filled'] as List<dynamic>?)?.length ?? 0;
          return filled < maxSpots;
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
              ...availableSquads.map((doc) => _buildSquadItem(context, localRef, doc)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSquadItem(BuildContext context, WidgetRef ref, DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final gameName = data['game']?['name'] ?? 'Unknown Game';
    final maxSpots = data['spots'] ?? 4;
    final filled = (data['filled'] as List<dynamic>?) ?? [];
    final currentSpots = filled.length;
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
            onPressed: () => _callSpot(context, ref, doc.id, data),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orangeAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              textStyle: const TextStyle(fontSize: 12),
            ),
            child: Text('Spot $nextSpot'),
          ),
        ],
      ),
    );
  }

  Future<void> _callSpot(BuildContext context, WidgetRef ref, String peacockId,
      Map<String, dynamic> peacockData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      // Call the spot using SquadManager
      final squadManager = p.Provider.of<SquadManager>(context, listen: false);
      await squadManager.joinLobby(peacockId, currentUser.uid);

      // Also call a spot for the joining user to trigger timer logic
      final gameName = peacockData['game']?['name'] ?? 'Unknown Game';

      // Find next available spot
      final filled = List<String>.from(peacockData['filled'] ?? []);
      final maxSpots = peacockData['spots'] ?? 4;
      int nextSpot = 0; // Start from 0 since creator is at spot 0
      while (filled.length > nextSpot && nextSpot < maxSpots) {
        nextSpot++;
      }

      if (nextSpot < maxSpots) {
        // Call the spot to trigger timer logic
        ref
            .read(squadStateNotifierProvider.notifier)
            .callSpotForGame(nextSpot, gameName);
      }

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
