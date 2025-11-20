import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';
import '../managers/lobby_service.dart';
import '../managers/squad_data_manager.dart';
import '../managers/squad_persistence_service.dart';
import 'widgets/peacock_modal_header.dart';
import 'widgets/game_selection_card.dart';
import 'widgets/group_settings_card.dart';
import 'widgets/launch_squad_button.dart';

class PeacockModal extends StatefulWidget {
  final Map<String, dynamic>? initialGame;

  const PeacockModal({super.key, this.initialGame});

  @override
  _PeacockModalState createState() => _PeacockModalState();
}

class _PeacockModalState extends State<PeacockModal> {
  final TextEditingController _gameController = TextEditingController();
  double _spots = 4;
  String? _selectedCircle;
  bool _alertBackups = false;
  bool _isLoading = false;
  Map<String, dynamic>? _selectedGame;

  @override
  void initState() {
    super.initState();
    _selectedCircle =
        Provider.of<UserManager>(context, listen: false).alertCircles.first;

    // Pre-fill game if provided
    if (widget.initialGame != null) {
      _gameController.text = widget.initialGame!['name'] ?? '';
      _selectedGame = widget.initialGame;
      if (widget.initialGame!['maxSpots'] != null) {
        _spots = (widget.initialGame!['maxSpots'] as int).toDouble();
      }
    }

    // Fetch pinned games
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchPinnedGames();
    });
  }

  @override
  void dispose() {
    _gameController.dispose();
    super.dispose();
  }

  Future<void> _submitPeacock() async {
    if (_gameController.text.isEmpty || _selectedCircle == null) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final squadState = Provider.of<SquadState>(context, listen: false);
      final gameName = _gameController.text;

      // Init gameSpotTimers in SquadManager
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(_spots.toInt(), null);

      // Assign creator to spot 1 as caller with 5-minute countdown
      // Use direct assignment instead of callSpotForGame since creator gets longer timer
      squadState.dataManager.gameSquadSpots[gameName] ??=
          List.filled(_spots.toInt(), null);
      squadState.dataManager.gameSpotTimers[gameName] ??=
          List.filled(_spots.toInt(), null);

      // Check if player is solo to determine timer duration
      final isSoloPlayer =
          squadState.isPlayingSolo(squadState.displayName ?? '');
      final timerDuration = isSoloPlayer
          ? 3600
          : 300; // 60 minutes for solo, 5 minutes for groups

      // Set creator in spot 1 with calling timer
      squadState.dataManager.gameSquadSpots[gameName]![0] =
          '${user.uid}_calling';
      squadState.dataManager.gameSpotTimers[gameName]![0] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': timerDuration, // Dynamic duration based on solo status
        'calling': true,
        'peacockCreated':
            true, // Flag to distinguish from regular calling spots
      };
      squadState.dataManager
              .globalStatuses[squadState.displayName ?? 'Unknown Player'] =
          'Calling';

      // Mark fields as changed for persistence
      squadState.persistenceManager.markFieldChanged('squadSpots');
      squadState.persistenceManager.markFieldChanged('spotTimers');
      squadState.persistenceManager.markFieldChanged('globalStatuses');
      squadState.uiManager.setNewSquadSpot(true, gameName);
      squadState.updateFirestoreAsync(force: true);

      // Create peacock document in Firestore for lobby visibility
      final peacockData = {
        'hostUid': user.uid,
        'hostName': squadState.displayName ?? 'Unknown Player',
        'game': {'name': gameName},
        'spots': _spots.toInt(),
        'filled': [
          {'uid': user.uid, 'spot': 1, 'status': 'ready'}
        ], // Creator auto-assigned to spot 1 with ready status
        'viewers': <String>[], // Start with empty viewers list
        'timer': Timestamp.fromDate(DateTime.now()
            .add(Duration(seconds: timerDuration))), // Dynamic timer for lobby
        'createdAt': Timestamp.now(),
        'circle': _selectedCircle,
      };

      await FirebaseFirestore.instance.collection('peacocks').add(peacockData);

      // Start voice room for the squad
      final lobbyService = LobbyService(
        dataManager: squadState.dataManager,
        persistenceService: squadState.persistenceService,
      );
      final voiceRoomId = lobbyService.startVoiceRoom(user.uid, gameName);

      // Add voice room info to peacock data
      peacockData['voiceRoomId'] = voiceRoomId;

      await FirebaseFirestore.instance.collection('peacocks').add(peacockData);

      // Update Firestore user doc
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'peacock': {
          'game': gameName,
          'spots': _spots.toInt(),
          'timer': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'circle': _selectedCircle,
        }
      }, SetOptions(merge: true));

      // Update user status to indicate they're looking for squad
      squadState.dataManager.setStatus(user.uid, 'Looking for squad');

      // Trigger notification
      final notificationManager =
          Provider.of<NotificationManager>(context, listen: false);
      await notificationManager.showNotification(
        title: 'Peacock Alert',
        body: 'Looking for ${_spots.toInt()} spots in $gameName',
      );

      // Ask if user wants to pin the game for quick access
      if (_selectedGame != null && mounted) {
        final shouldPin = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Text(
              'Pin Game',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            content: Text(
              'Pin this game with current settings for quick access?',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Yes',
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
        );

        if (shouldPin == true) {
          final userManager = Provider.of<UserManager>(context, listen: false);
          final quickStartGame = {
            ..._selectedGame!,
            'maxSpots': _spots.toInt(),
            'alertCircle': _selectedCircle,
            'alertBackups': _alertBackups,
          };
          await userManager.addPinnedGame(quickStartGame);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create peacock: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 1.0,
      snap: true,
      snapSizes: const [0.9, 1.0],
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 25,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            children: [
              // Modern drag handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Modern header
              PeacockModalHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: AnimatedOpacity(
                    opacity: 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 32),
                        // Game selection section
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: GameSelectionCard(
                            controller: _gameController,
                            selectedGame: _selectedGame,
                            onGameSelected: (game) {
                              setState(() {
                                _selectedGame = game;
                                if (game != null && game['maxSpots'] != null) {
                                  _spots = (game['maxSpots'] as int).toDouble();
                                } else if (game == null) {
                                  _spots = 4.0;
                                }
                              });
                              HapticFeedback.lightImpact();
                            },
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Group settings section
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: GroupSettingsCard(
                            spots: _spots.toInt(),
                            selectedCircle: _selectedCircle,
                            alertBackups: _alertBackups,
                            maxSpots: _selectedGame?['maxSpots'],
                            onSpotsChanged: (spots) {
                              setState(() => _spots = spots.toDouble());
                            },
                            onCircleChanged: (circle) {
                              setState(() => _selectedCircle = circle);
                            },
                            onAlertBackupsChanged: (alert) {
                              setState(() => _alertBackups = alert);
                            },
                          ),
                        ),
                        const SizedBox(height: 40),

                        // Launch button
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          child: LaunchSquadButton(
                            isLoading: _isLoading,
                            isEnabled: _gameController.text.isNotEmpty &&
                                _selectedCircle != null,
                            onPressed: _submitPeacock,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
