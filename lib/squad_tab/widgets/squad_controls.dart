import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import '../../squad_state.dart';
import '../../managers/squad_manager.dart';
import '../../managers/user_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'game_alerts_display.dart';
import '../../chat/voice_room_screen.dart';

/// SquadControls component - handles action buttons and controls
/// Extracted from the monolithic SquadTab to improve maintainability
class SquadControls extends StatelessWidget {
  const SquadControls({super.key});

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<SquadState>(
      builder: (context, squadState, child) {
        return SliverToBoxAdapter(
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
      },
    );
  }
}

/// Game alert section - allows users to alert squad about wanting to play games
class _GameAlertSection extends StatefulWidget {
  const _GameAlertSection();

  @override
  _GameAlertSectionState createState() => _GameAlertSectionState();
}

class _GameAlertSectionState extends State<_GameAlertSection> {
  bool _hasActiveAlert = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveAlert();
  }

  Future<void> _checkForActiveAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    final squadManager =
        provider.Provider.of<SquadManager>(context, listen: false);

    if (squadState.selectedSquadId != null) {
      final alerts =
          await squadManager.getSquadAlerts(squadState.selectedSquadId!);
      setState(() {
        _hasActiveAlert = alerts.any((alert) => alert['userUid'] == user.uid);
      });
    }
  }

  Future<void> _sendAlert(String alertType,
      {String? specificGame, List<String>? pinnedGames}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    final squadManager =
        provider.Provider.of<SquadManager>(context, listen: false);

    if (squadState.selectedSquadId == null) return;

    try {
      await squadManager.sendGameAlert(
        squadState.selectedSquadId!,
        user.uid,
        alertType,
        specificGame: specificGame,
        pinnedGames: pinnedGames,
      );

      setState(() {
        _hasActiveAlert = true;
      });

      // Refresh the alerts display
      GameAlertsDisplay.refreshAlerts(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert sent to squad!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send alert: $e')),
      );
    }
  }

  Future<void> _clearAlert() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    final squadManager =
        provider.Provider.of<SquadManager>(context, listen: false);

    if (squadState.selectedSquadId == null) return;

    try {
      await squadManager.clearGameAlerts(squadState.selectedSquadId!, user.uid);

      setState(() {
        _hasActiveAlert = false;
      });

      // Refresh the alerts display
      GameAlertsDisplay.refreshAlerts(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert cleared')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to clear alert: $e')),
      );
    }
  }

  void _showAlertDialog() {
    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    final userManager =
        provider.Provider.of<UserManager>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Want to Play?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Alert for current game
            if (squadState.currentGame != null)
              ListTile(
                leading:
                    const Icon(Icons.videogame_asset, color: Colors.cyanAccent),
                title: Text('Play ${squadState.currentGame!['name']}'),
                subtitle: const Text('Alert squad about this specific game'),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendAlert('specific',
                      specificGame: squadState.currentGame!['name']);
                },
              ),

            // Alert for pinned games
            if (userManager.pinnedGames.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.star, color: Colors.amber),
                title: const Text('Play Pinned Games'),
                subtitle: Text(
                    'Alert about ${userManager.pinnedGames.length} pinned game(s)'),
                onTap: () {
                  Navigator.of(context).pop();
                  _sendAlert('pinned',
                      pinnedGames: userManager.pinnedGames
                          .map((g) => g['name'] as String)
                          .toList());
                },
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
class _WinButton extends StatelessWidget {
  const _WinButton();

  @override
  Widget build(BuildContext context) {
    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    return ElevatedButton(
      onPressed: squadState.recordWin,
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
    );
  }
}

/// Voice room button widget - extracted for better performance
class _VoiceRoomButton extends StatelessWidget {
  const _VoiceRoomButton();

  @override
  Widget build(BuildContext context) {
    final squadState = provider.Provider.of<SquadState>(context, listen: false);

    return ElevatedButton.icon(
      onPressed: () {
        if (squadState.selectedSquadId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No squad selected')),
          );
          return;
        }

        // Navigate to voice room screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VoiceRoomScreen(
              roomId: squadState.selectedSquadId!,
              roomName: squadState.currentSquad?['name'] ?? 'Voice Room',
            ),
          ),
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
    );
  }
}

/// Loss button widget - extracted for better performance
class _LossButton extends StatelessWidget {
  const _LossButton();

  @override
  Widget build(BuildContext context) {
    final squadState = provider.Provider.of<SquadState>(context, listen: false);
    return ElevatedButton(
      onPressed: squadState.recordLoss,
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
    );
  }
}
