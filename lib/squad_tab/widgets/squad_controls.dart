import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/squad_notifier.dart';
import '../../presentation/notifiers/user_notifier.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_alerts_display.dart';

/// SquadControls component - handles action buttons and controls
/// Extracted from the monolithic SquadTab to improve maintainability
class SquadControls extends ConsumerWidget {
  const SquadControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SliverToBoxAdapter(
      child: Column(
        children: [
          // Win/Loss/Voice buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _WinButton(),
                _VoiceRoomButton(),
                _LossButton(),
              ],
            ),
          ),
          // Game alert section
          _GameAlertSection(),
        ],
      ),
    );
  }
}

/// Game alert section - allows users to alert squad about wanting to play games
class _GameAlertSection extends ConsumerStatefulWidget {
  const _GameAlertSection();

  @override
  ConsumerState<_GameAlertSection> createState() => _GameAlertSectionState();
}

class _GameAlertSectionState extends ConsumerState<_GameAlertSection> {
  bool _hasActiveAlert = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveAlert();
  }

  Future<void> _checkForActiveAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadStateAsync = ref.watch(squadNotifierProvider);
    final squadNotifier = ref.read(squadNotifierProvider.notifier);

    final selectedSquadId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedSquadId,
      orElse: () => null,
    );

    if (selectedSquadId != null) {
      final alerts = await squadNotifier.getSquadAlerts(selectedSquadId);
      if (mounted) {
        setState(() {
          _hasActiveAlert = alerts.any((alert) => alert['userUid'] == user.uid);
        });
      }
    }
  }

  Future<void> _sendAlert(String alertType,
      {String? specificGame, List<String>? pinnedGames}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadStateAsync = ref.watch(squadNotifierProvider);
    final squadNotifier = ref.read(squadNotifierProvider.notifier);

    final selectedSquadId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedSquadId,
      orElse: () => null,
    );

    if (selectedSquadId == null) return;

    try {
      await squadNotifier.sendGameAlert(
        selectedSquadId,
        user.uid,
        alertType,
        specificGame: specificGame,
        pinnedGames: pinnedGames,
      );

      if (mounted) {
        setState(() {
          _hasActiveAlert = true;
        });
      }

      // Refresh the alerts display
      GameAlertsDisplay.refreshAlerts(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert sent to squad!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send alert: $e')),
        );
      }
    }
  }

  Future<void> _clearAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadStateAsync = ref.watch(squadNotifierProvider);
    final squadNotifier = ref.read(squadNotifierProvider.notifier);

    final selectedSquadId = squadStateAsync.maybeWhen(
      data: (squadState) => squadState.selectedSquadId,
      orElse: () => null,
    );

    if (selectedSquadId == null) return;

    try {
      await squadNotifier.clearGameAlerts(selectedSquadId, user.uid);

      if (mounted) {
        setState(() {
          _hasActiveAlert = false;
        });
      }

      // Refresh the alerts display
      GameAlertsDisplay.refreshAlerts(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert cleared')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to clear alert: $e')),
        );
      }
    }
  }

  void _showAlertDialog() {
    final squadStateAsync = ref.watch(squadNotifierProvider);
    final userStateAsync = ref.watch(userNotifierProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Want to Play?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert for current game
            squadStateAsync.maybeWhen(
              data: (squadState) {
                if (squadState.currentGame != null) {
                  return ListTile(
                    leading: const Icon(Icons.videogame_asset,
                        color: Colors.cyanAccent),
                    title: Text('Play ${squadState.currentGame!['name']}'),
                    subtitle:
                        const Text('Alert squad about this specific game'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _sendAlert('specific',
                          specificGame: squadState.currentGame!['name']);
                    },
                  );
                }
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Alert for pinned games
            userStateAsync.maybeWhen(
              data: (userState) {
                final pinnedGames = userState?.pinnedGames ?? [];
                if (pinnedGames.isNotEmpty) {
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: const Text('Play Pinned Games'),
                    subtitle: Text(
                        'Alert about ${pinnedGames.length} pinned game(s)'),
                    onTap: () {
                      Navigator.of(context).pop();
                      _sendAlert('pinned',
                          pinnedGames: pinnedGames
                              .map((g) => g['name'] as String)
                              .toList());
                    },
                  );
                }
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Alert for any game
            ListTile(
              leading: const Icon(Icons.games, color: Colors.green),
              title: const Text('Play Any Game'),
              subtitle: const Text('Alert squad that you want to play'),
              onTap: () {
                Navigator.of(context).pop();
                _sendAlert('any');
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _hasActiveAlert ? _clearAlert : _showAlertDialog,
                  icon: Icon(_hasActiveAlert
                      ? Icons.notifications_off
                      : Icons.notifications_active),
                  label:
                      Text(_hasActiveAlert ? 'Clear Alert' : 'Want to Play?'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _hasActiveAlert ? Colors.orange : Colors.purpleAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(fontSize: 16),
                    elevation: 4,
                    shadowColor:
                        (_hasActiveAlert ? Colors.orange : Colors.purpleAccent)
                            .withValues(alpha: 0.3),
                  ),
                ),
              ),
            ],
          ),
          if (_hasActiveAlert)
            const Padding(
              padding: EdgeInsets.only(top: 8.0),
              child: Text(
                'Squad members have been alerted!',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

/// Win button widget - extracted for better performance
class _WinButton extends ConsumerWidget {
  const _WinButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(squadNotifierProvider);
    return squadStateAsync.maybeWhen(
      data: (squadState) => ElevatedButton(
        onPressed: () async {
          try {
            await ref.read(squadNotifierProvider.notifier).recordWin([]);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to record win: $e')),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18),
          elevation: 4,
          shadowColor: Colors.green.withValues(alpha: 0.3),
        ),
        child: const Text(
          'Win',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      orElse: () => const ElevatedButton(
        onPressed: null,
        child: Text('Win'),
      ),
    );
  }
}

/// Voice room button widget - extracted for better performance
class _VoiceRoomButton extends ConsumerWidget {
  const _VoiceRoomButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(squadNotifierProvider);

    return squadStateAsync.maybeWhen(
      data: (squadState) => ElevatedButton.icon(
        onPressed: () {
          if (squadState.selectedSquadId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No squad selected')),
            );
            return;
          }

          // Navigate to voice room screen
          // Navigator.of(context).push(
          //   MaterialPageRoute(
          //     builder: (context) => VoiceRoomScreen(
          //       roomId: squadState.selectedSquadId!,
          //       roomName: squadState.currentSquadData?['name'] ?? 'Voice Room',
          //     ),
          //   ),
          // );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Voice room not available')),
          );
        },
        icon: const Icon(Icons.mic, color: Colors.white),
        label: const Text('Voice Room'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16),
          elevation: 4,
          shadowColor: Colors.blueAccent.withValues(alpha: 0.3),
        ),
      ),
      orElse: () => ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.mic),
        label: const Text('Voice Room'),
      ),
    );
  }
}

/// Loss button widget - extracted for better performance
class _LossButton extends ConsumerWidget {
  const _LossButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final squadStateAsync = ref.watch(squadNotifierProvider);
    return squadStateAsync.maybeWhen(
      data: (squadState) => ElevatedButton(
        onPressed: () async {
          try {
            await ref.read(squadNotifierProvider.notifier).recordLoss([]);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to record loss: $e')),
              );
            }
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.redAccent,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 18),
          elevation: 4,
          shadowColor: Colors.redAccent.withValues(alpha: 0.3),
        ),
        child: const Text(
          'Loss',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      orElse: () => ElevatedButton(
        onPressed: null,
        child: const Text('Loss'),
      ),
    );
  }
}
