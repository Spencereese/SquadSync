import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../squad_state.dart';
import '../../managers/squad_manager.dart';

/// GameAlertsDisplay component - shows active game alerts from squad members
class GameAlertsDisplay extends StatefulWidget {
  const GameAlertsDisplay({super.key});

  // Static method to refresh all instances
  static void refreshAlerts(BuildContext context) {
    final state = context.findAncestorStateOfType<GameAlertsDisplayState>();
    state?._loadAlerts();
  }

  @override
  GameAlertsDisplayState createState() => GameAlertsDisplayState();
}

class GameAlertsDisplayState extends State<GameAlertsDisplay> {
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final squadState = Provider.of<SquadState>(context, listen: false);
    final squadManager = Provider.of<SquadManager>(context, listen: false);

    if (squadState.selectedSquadId != null) {
      final alerts =
          await squadManager.getSquadAlerts(squadState.selectedSquadId!);
      setState(() {
        _alerts = alerts;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alerts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final user = FirebaseAuth.instance.currentUser;
    final squadState = Provider.of<SquadState>(context, listen: false);

    // Filter out current user's alerts (they see their own in the controls)
    final otherAlerts =
        _alerts.where((alert) => alert['userUid'] != user?.uid).toList();

    if (otherAlerts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Card(
          color: Colors.white.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications,
                        color: Colors.orangeAccent, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Game Alerts',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...otherAlerts.map(
                    (alert) => _buildAlertItem(context, alert, squadState)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertItem(
      BuildContext context, Map<String, dynamic> alert, SquadState squadState) {
    final displayName = squadState.getDisplayNameForUid(alert['userUid']);

    String alertText;
    IconData alertIcon;
    Color alertColor;

    switch (alert['type']) {
      case 'specific':
        alertText = '$displayName wants to play ${alert['specificGame']}';
        alertIcon = Icons.videogame_asset;
        alertColor = Colors.cyanAccent;
        break;
      case 'pinned':
        final pinnedCount =
            (alert['pinnedGames'] as List<dynamic>?)?.length ?? 0;
        alertText =
            '$displayName wants to play one of their $pinnedCount pinned games';
        alertIcon = Icons.star;
        alertColor = Colors.amber;
        break;
      case 'any':
        alertText = '$displayName wants to play any game!';
        alertIcon = Icons.games;
        alertColor = Colors.green;
        break;
      default:
        alertText = '$displayName has an alert';
        alertIcon = Icons.notifications;
        alertColor = Colors.grey;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(alertIcon, color: alertColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              alertText,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
