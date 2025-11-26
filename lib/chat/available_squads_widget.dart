import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/squad_notifier.dart' as sn;
import '../../presentation/notifiers/user_notifier.dart';

class AvailableSquadsWidget extends ConsumerWidget {
  const AvailableSquadsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    final userStateAsync = ref.watch(userNotifierProvider);
    final publicGroups = userStateAsync.maybeWhen(
      data: (state) => state?.publicGroups ?? [],
      orElse: () => <Map<String, dynamic>>[],
    );

    if (publicGroups.isEmpty) {
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
          ...publicGroups
              .take(5)
              .map((group) => _buildSquadItem(context, ref, group)),
        ],
      ),
    );
  }

  Widget _buildSquadItem(
      BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final gameName = data['name'] ?? 'Unknown Game';
    final maxSpots = data['maxSpots'] ?? 4;
    final currentSpots = (data['members'] as List<dynamic>?)?.length ?? 0;
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
            onPressed: () => _joinSquad(context, ref, data),
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

  Future<void> _joinSquad(BuildContext context, WidgetRef ref,
      Map<String, dynamic> squadData) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final code = squadData['code'] as String?;
      if (code == null) return;

      await ref
          .read(sn.squadNotifierProvider.notifier)
          .joinSquad(code, currentUser.uid);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined squad ${squadData['name'] ?? 'squad'}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join squad: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
