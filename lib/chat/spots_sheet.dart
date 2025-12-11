import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../presentation/notifiers/current_lobby_notifier.dart';
import '../widgets/rating_widgets.dart';
import '../services/message_service.dart';
import '../domain/entities/message.dart';

class SpotsSheet extends ConsumerStatefulWidget {
  final String gameName;
  final int maxSpots;
  final String chatGroupId;
  final ChatType chatType;

  const SpotsSheet({
    super.key,
    required this.gameName,
    required this.maxSpots,
    required this.chatGroupId,
    required this.chatType,
  });

  static void show(
    BuildContext context, {
    required String gameName,
    required int maxSpots,
    required String chatGroupId,
    required ChatType chatType,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SpotsSheet(
        gameName: gameName,
        maxSpots: maxSpots,
        chatGroupId: chatGroupId,
        chatType: chatType,
      ),
    );
  }

  @override
  ConsumerState<SpotsSheet> createState() => _SpotsSheetState();
}

class _SpotsSheetState extends ConsumerState<SpotsSheet> {
  bool _isClaiming = false;
  late RatingNudge _ratingNudge;
  bool _isLoadingLobbyData = true;
  bool _isCreator = false;
  bool _isPublic = false;
  String? _lobbyId;

  @override
  void initState() {
    super.initState();
    _ratingNudge = RatingNudge(
      gameName: widget.gameName,
      chatGroupId: widget.chatGroupId,
      chatType: widget.chatType,
      onRatingSubmitted: () {
        // Could add additional logic here if needed
      },
    );
    _loadLobbyData();
  }

  Future<void> _loadLobbyData() async {
    try {
      final currentUser = AuthServiceSupabase().currentUser;
      if (currentUser == null) return;

      // Query lobby by chat_group_id
      final response = await SupabaseService.client
          .from('lobbies')
          .select('id, created_by, is_public')
          .eq('chat_group_id', widget.chatGroupId)
          .maybeSingle();

      if (response != null && mounted) {
        final lobbyId = response['id'] as String?;

        // Set the current lobby ID in CurrentLobbyNotifier for realtime updates
        if (lobbyId != null) {
          ref.read(currentLobbyIdProvider.notifier).state = lobbyId;
        }

        setState(() {
          _lobbyId = lobbyId;
          _isCreator = response['created_by'] == currentUser.id;
          _isPublic = response['is_public'] as bool? ?? false;
          _isLoadingLobbyData = false;
        });
      } else if (mounted) {
        setState(() => _isLoadingLobbyData = false);
      }
    } catch (e) {
      debugPrint('Error loading lobby data: $e');
      if (mounted) {
        setState(() => _isLoadingLobbyData = false);
      }
    }
  }

  Future<void> _updateIsPublic(bool value) async {
    if (_lobbyId == null) return;

    try {
      setState(() => _isPublic = value);
      HapticFeedback.selectionClick();

      await SupabaseService.client
          .from('lobbies')
          .update({'is_public': value}).eq('id', _lobbyId!);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lobby is now ${value ? "public" : "private"}'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } catch (e) {
      // Revert on error
      setState(() => _isPublic = !value);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update lobby: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          action: SnackBarAction(
            label: 'Retry',
            textColor: Colors.white,
            onPressed: () => _updateIsPublic(value),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header with drag handle
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[600],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // Use CurrentLobbyNotifier for realtime updates
                ref.watch(currentLobbyProvider).when(
                      data: (currentLobby) {
                        if (currentLobby == null) {
                          return const Text(
                            'No active lobby',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          );
                        }

                        // Get display names from LobbyNotifier
                        final lobbyState =
                            ref.read(ln.lobbyNotifierProvider).value;
                        final filledSpots = currentLobby.spots
                            .where((uid) => uid != null)
                            .length;
                        final names = currentLobby.spots
                            .where((uid) => uid != null)
                            .map((uid) =>
                                lobbyState?.memberDisplayNames[uid!] ??
                                'Unknown')
                            .join(', ');

                        return Text(
                          'Current: $names ($filledSpots/${currentLobby.maxSpots} ${currentLobby.gameName})',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        );
                      },
                      loading: () => const Text(
                        'Loading...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      error: (error, _) => Text(
                        'Error: $error',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
              ],
            ),
          ),

          // Public toggle (only for creators)
          if (_isCreator && !_isLoadingLobbyData)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: const Text(
                  'Public Lobby',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                subtitle: const Text(
                  'Allow others to discover and join this lobby',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                value: _isPublic,
                onChanged: _updateIsPublic,
                activeColor: Theme.of(context).colorScheme.primary,
                contentPadding: EdgeInsets.zero,
              ),
            ),

          // Spots list
          Expanded(
            child: ref.watch(currentLobbyProvider).when(
                  data: (currentLobby) {
                    if (currentLobby == null) {
                      return const Center(
                        child: Text(
                          'No active lobby',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    }

                    // Get display names from LobbyNotifier
                    final lobbyState = ref.read(ln.lobbyNotifierProvider).value;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: currentLobby.maxSpots,
                      itemBuilder: (context, index) {
                        final isOccupied = index < currentLobby.spots.length &&
                            currentLobby.spots[index] != null;
                        final spotValue =
                            isOccupied ? currentLobby.spots[index] : null;
                        final isCalling =
                            spotValue?.endsWith('_calling') ?? false;
                        final occupantUid = isCalling
                            ? spotValue!.replaceAll('_calling', '')
                            : spotValue;
                        final occupantName = occupantUid != null
                            ? lobbyState?.memberDisplayNames[occupantUid] ??
                                'Unknown'
                            : null;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOccupied
                                  ? (isCalling
                                      ? Colors.orange
                                      : Colors.cyanAccent)
                                  : Colors.grey[700]!,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Spot ${index + 1}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              if (isOccupied) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCalling
                                        ? Colors.orange.withValues(alpha: 0.2)
                                        : Colors.cyanAccent
                                            .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCalling
                                        ? 'Calling'
                                        : (occupantName ?? 'Unknown'),
                                    style: TextStyle(
                                      color: isCalling
                                          ? Colors.orange
                                          : Colors.cyanAccent,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ),
          ),

          // Rating nudge (only shown for first-time users)
          _ratingNudge,

          // FAB for claiming spot or creating lobby
          Container(
            padding: const EdgeInsets.all(16),
            child: ref.watch(currentLobbyProvider).maybeWhen(
              data: (currentLobby) {
                final hasLobby = currentLobby != null;
                debugPrint(
                    '📊 SpotsSheet FAB: hasLobby=$hasLobby, _isClaiming=$_isClaiming');
                final buttonText = _isClaiming
                    ? (hasLobby ? 'Claiming...' : 'Creating...')
                    : (hasLobby ? 'Claim Spot' : 'Create Lobby');

                return FloatingActionButton.extended(
                  onPressed: _isClaiming
                      ? null
                      : () {
                          debugPrint('🔘 FAB pressed: hasLobby=$hasLobby');
                          if (hasLobby) {
                            _claimSpot();
                          } else {
                            _createLobby();
                          }
                        },
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  icon: _isClaiming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : Icon(hasLobby ? Icons.add : Icons.rocket_launch),
                  label: Text(buttonText),
                );
              },
              loading: () {
                debugPrint('🔄 CurrentLobbyProvider loading...');
                return FloatingActionButton.extended(
                  onPressed: null,
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text('Loading...'),
                );
              },
              error: (error, stack) {
                debugPrint('❌ CurrentLobbyProvider error: $error');
                // Even on error, show create button (no lobby exists)
                return FloatingActionButton.extended(
                  onPressed: _isClaiming ? null : _createLobby,
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  icon: _isClaiming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Icon(Icons.rocket_launch),
                  label: Text(_isClaiming ? 'Creating...' : 'Create Lobby'),
                );
              },
              orElse: () {
                debugPrint('⚠️ CurrentLobbyProvider orElse state');
                return FloatingActionButton.extended(
                  onPressed: null,
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.black,
                  icon: const Icon(Icons.hourglass_empty),
                  label: const Text('Loading...'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _claimSpot() async {
    final currentLobby = ref.read(currentLobbyProvider).value;
    final user = AuthServiceSupabase().currentUser;
    if (user == null || currentLobby == null) return;

    setState(() => _isClaiming = true);

    try {
      // Check current spots
      final filledCount =
          currentLobby.spots.where((spot) => spot != null).length;

      if (filledCount >= currentLobby.maxSpots) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Spots filled—next time!'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // Find first available spot
      final availableIndex =
          currentLobby.spots.indexWhere((spot) => spot == null);
      if (availableIndex == -1) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Spots filled—next time!'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      // Claim the spot using CurrentLobbyNotifier
      await ref.read(currentLobbyProvider.notifier).claimSpot(availableIndex);

      // Send message to chat thread
      final chatService = MessageService();
      final lobbyState = ref.read(ln.lobbyNotifierProvider).value;
      final displayName = lobbyState?.memberDisplayNames[user.id] ?? 'Unknown';

      await chatService.sendMessage(
        ref,
        senderUid: user.id,
        text:
            '$displayName claimed spot ${availableIndex + 1} in ${currentLobby.gameName}!',
        chatGroupId: widget.chatGroupId,
        chatType: widget.chatType,
      );

      // Check if user has rated this game before
      final hasRated = ref.read(userNotifierProvider).maybeWhen(
            data: (state) =>
                (state?.hasRatedGame ?? {})[widget.gameName] ?? false,
            orElse: () => false,
          );
      if (!hasRated) {
        // Show rating dialog after a brief delay to let the spot claim settle
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => ReviewSubmitDialog(
                gameName: widget.gameName,
                chatGroupId: widget.chatGroupId,
                chatType: widget.chatType,
              ),
            );
          }
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming spot: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }

  Future<void> _createLobby() async {
    debugPrint('🚀 SpotsSheet._createLobby called');
    final user = AuthServiceSupabase().currentUser;
    if (user == null) {
      debugPrint('❌ Cannot create lobby: user is null');
      return;
    }
    debugPrint('✅ User authenticated: ${user.id}, creating lobby...');

    setState(() => _isClaiming = true);

    try {
      // Create lobby using LobbyNotifier
      final lobbyNotifier = ref.read(ln.lobbyNotifierProvider.notifier);
      await lobbyNotifier.createLobby(
        chatGroupId: widget.chatGroupId,
        gameName: widget.gameName,
        maxSpots: widget.maxSpots,
        isPublic: false,
      );

      // Reload lobby data to get the new lobby ID
      await _loadLobbyData();

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lobby created for ${widget.gameName}!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );

        // After creating, automatically claim the first spot
        await Future.delayed(const Duration(milliseconds: 500));
        await _claimSpot();
      }
    } catch (e) {
      debugPrint('❌ Error creating lobby: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create lobby: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _createLobby,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaiming = false);
      }
    }
  }
}
