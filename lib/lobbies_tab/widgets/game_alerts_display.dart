import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/auth_service_supabase.dart';
import '../../presentation/notifiers/lobby_notifier.dart' as ln;

/// GameAlertsDisplay component - shows active game alerts from squad members
class GameAlertsDisplay extends ConsumerStatefulWidget {
  const GameAlertsDisplay({super.key});

  // Static method to refresh all instances
  static void refreshAlerts(BuildContext context) {
    final state = context.findAncestorStateOfType<GameAlertsDisplayState>();
    state?._loadAlerts();
  }

  @override
  ConsumerState<GameAlertsDisplay> createState() => GameAlertsDisplayState();
}

class GameAlertsDisplayState extends ConsumerState<GameAlertsDisplay> {
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    // _loadAlerts() is called in didChangeDependencies
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);
    final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);

    final selectedLobbyId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedLobbyId,
      orElse: () => null,
    );

    if (selectedLobbyId != null) {
      final alerts = await lobbyNotifier.getSquadAlerts(selectedLobbyId);
      if (mounted) {
        setState(() {
          _alerts = alerts;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_alerts.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final user = AuthServiceSupabase().currentUser;
    final squadStateAsync = ref.watch(ln.lobbyNotifierProvider);

    return squadStateAsync.maybeWhen(
      data: (squadState) {
        // Filter out current user's alerts (they see their own in the controls)
        final otherAlerts =
            _alerts.where((alert) => alert['userUid'] != user?.id).toList();

        if (otherAlerts.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.orangeAccent,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...otherAlerts
                        .map((alert) => _buildAlertItem(context, alert)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      orElse: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  Widget _buildAlertItem(BuildContext context, Map<String, dynamic> alert) {
    final displayName = ref
        .read(ln.lobbyNotifierProvider.notifier)
        .getDisplayNameForUid(alert['userUid']);

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
