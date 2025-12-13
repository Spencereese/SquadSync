import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:squad_sync/presentation/notifiers/user_notifier.dart';
import '../core/injection.dart';
import 'widgets/peacock_modal_header.dart';
import 'widgets/group_settings_card.dart';
import 'widgets/launch_lobby_button.dart';

class PeacockModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialGame;

  const PeacockModal({super.key, this.initialGame});

  @override
  _PeacockModalState createState() => _PeacockModalState();
}

class _PeacockModalState extends ConsumerState<PeacockModal> {
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
        'Lobby'; // TODO: Implement alert circles in new architecture

    // Pre-fill game if provided
    if (widget.initialGame != null) {
      _gameController.text = widget.initialGame!['name'] ?? '';
      _selectedGame = widget.initialGame;
      if (widget.initialGame!['maxSpots'] != null) {
        _spots = (widget.initialGame!['maxSpots'] as int).toDouble();
      }
    }

    // Fetch pinned games - not needed, UserNotifier loads them
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
      final user = AuthServiceSupabase().currentUser;
      if (user == null) return;

      final squadState = ref.read(ln.lobbyNotifierProvider).value;
      if (squadState == null) return;
      final userState = ref.read(userNotifierProvider).value;
      final displayName = userState?.displayName ?? 'Unknown';
      final gameName = _gameController.text;

      // Init gameSpotTimers
      final currentSpotTimers = Map<String, List<Map<String, dynamic>?>>.from(
          squadState.gameSpotTimers);
      currentSpotTimers[gameName] ??=
          List.of(List.filled(_spots.toInt(), null));

      // Assign creator to spot 1 as caller with 5-minute countdown
      // Use direct assignment instead of callSpotForGame since creator gets longer timer
      final currentLobbySpots =
          Map<String, List<String?>>.from(squadState.gameLobbySpots);
      currentLobbySpots[gameName] ??=
          List.of(List.filled(_spots.toInt(), null));
      final currentSpotTimers2 =
          Map<String, List<Map<String, dynamic>?>>.from(currentSpotTimers);
      currentSpotTimers2[gameName] ??=
          List.of(List.filled(_spots.toInt(), null));

      // Check if player is solo to determine timer duration
      final isSoloPlayer =
          squadState.globalStatuses[displayName]?.contains('(Solo)') == true ||
              squadState.globalStatuses[displayName] == 'Playing Solo';
      final timerDuration = isSoloPlayer
          ? 3600
          : 300; // 60 minutes for solo, 5 minutes for groups

      // Set creator in spot 1 with calling timer
      currentLobbySpots[gameName]![0] = '${user.id}_calling';
      currentSpotTimers2[gameName]![0] = {
        'startTime': DateTime.now().millisecondsSinceEpoch,
        'duration': timerDuration, // Dynamic duration based on solo status
        'calling': true,
        'peacockCreated':
            true, // Flag to distinguish from regular calling spots
      };

      // Update global statuses
      final currentGlobalStatuses =
          Map<String, String>.from(squadState.globalStatuses);
      currentGlobalStatuses[displayName] = 'Calling';

      // Update state
      // Note: State updates should be handled by notifier methods, but for migration we'll skip for now

      // Create peacock document in Supabase for lobby visibility
      final timerEnd = DateTime.now()
          .add(Duration(seconds: timerDuration))
          .toIso8601String();
      final now = DateTime.now().toIso8601String();

      // Start voice room for the squad
      final voiceRoomId =
          'voice_${user.id}_${DateTime.now().millisecondsSinceEpoch}';

      final peacockData = {
        'host_uid': user.id,
        'host_name': displayName,
        'game_name': gameName,
        'spots': _spots.toInt(),
        'filled': [
          {'uid': user.id, 'spot': 1, 'status': 'ready'}
        ],
        'viewers': <String>[],
        'timer': timerEnd,
        'created_at': now,
        'circle': _selectedCircle,
        'voice_room_id': voiceRoomId,
      };

      await ref.read(lobbyRepositoryProvider).createPeacock(peacockData);

      // Update user peacock status via repository
      await ref.read(lobbyRepositoryProvider).updateUserPeacock(user.id, {
        'game': gameName,
        'spots': _spots.toInt(),
        'timer': DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
        'circle': _selectedCircle,
      });

      // Update user status to indicate they're looking for squad
      // Note: Status updates should be handled by notifier methods, but for migration we'll skip for now

      // TODO: Show peacock notification via NotificationService

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
          final quickStartGame = {
            ..._selectedGame!,
            'maxSpots': _spots.toInt(),
            'alertCircle': _selectedCircle,
            'alertBackups': _alertBackups,
          };
          await ref
              .read(userNotifierProvider.notifier)
              .addPinnedGame(quickStartGame);
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
                          child: Card(
                            child: ListTile(
                              title:
                                  Text(_selectedGame?['name'] ?? 'Select Game'),
                              subtitle: const Text('Tap to select a game'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                // TODO: Show game selection sheet
                                HapticFeedback.lightImpact();
                              },
                            ),
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
                          child: LaunchLobbyButton(
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
