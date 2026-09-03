import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/deep_link_routes.dart';
import '../../../screens/voice_room_screen.dart';
import '../../../screens/video_room_screen.dart';
import 'chat_info_widgets.dart';
import '../../../services/auth_service_supabase.dart';
import '../../../services/availability_ping.dart';
import '../../../services/friends_service.dart';
import '../../../services/matchmaking_queue_machine.dart';
import '../../../presentation/notifiers/lobby_notifier.dart';
import '../../../notification_service.dart';

/// Actions section with big circular buttons for squad actions
///
/// Features:
/// - Voice chat navigation
/// - Video chat navigation (with beta badge)
/// - Search functionality
/// - Glassmorphic button design
class ChatInfoActionsSection extends StatelessWidget {
  final String squadId;
  final String squadName;
  final Color neonColor;

  const ChatInfoActionsSection({
    super.key,
    required this.squadId,
    required this.squadName,
    required this.neonColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ChatInfoBigActionButton(
                icon: Icons.headset,
                label: 'Voice Chat',
                neonColor: neonColor,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VoiceRoomScreen(
                        roomId: squadId,
                        squadName: squadName,
                      ),
                    ),
                  );
                },
              ),
              ChatInfoBigActionButton(
                icon: Icons.video_call,
                label: 'Video Chat',
                neonColor: neonColor,
                badge: 'Beta',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoRoomScreen(
                        roomId: squadId,
                        roomName: squadName,
                      ),
                    ),
                  );
                },
              ),
              ChatInfoBigActionButton(
                icon: Icons.search,
                label: 'Search',
                neonColor: neonColor,
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Search feature coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _LookingForSquadButton(
          squadId: squadId,
          neonColor: neonColor,
        ),
        const SizedBox(height: 12),
        _OnNowButton(
          squadId: squadId,
          neonColor: neonColor,
        ),
      ],
    );
  }
}

/// Looking for Squad — product matchmaking queue v1.
///
/// Join/leave looking reduce on [MatchmakingQueueTracker] after the
/// existing LFG notify succeeds. A matched lobby claims a seat through
/// [LobbyNotifier.assignPeacockSpot] (single peacock reduce), then
/// [MatchmakingQueueTracker.joinMatched] with `handoffToPeacock: false`
/// so assign is never reduced twice. Queue rows are in-memory until
/// Spencer applies a `matchmaking_queue` migration.
class _LookingForSquadButton extends ConsumerStatefulWidget {
  final String squadId;
  final Color neonColor;

  const _LookingForSquadButton({
    required this.squadId,
    required this.neonColor,
  });

  @override
  ConsumerState<_LookingForSquadButton> createState() =>
      _LookingForSquadButtonState();
}

class _LookingForSquadButtonState
    extends ConsumerState<_LookingForSquadButton> {
  bool _isLoading = false;

  MatchmakingQueueTracker get _tracker => MatchmakingQueueTracker.instance;

  MatchmakingQueueEntry _entryFor(String? uid) => uid == null
      ? MatchmakingQueueEntry.idle
      : _tracker.stateFor(uid);

  Future<void> _onPressed() async {
    final uid = _currentUidOrNull();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to look for a squad'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final entry = _entryFor(uid);
    switch (entry.phase) {
      case MatchmakingQueuePhase.idle:
      case MatchmakingQueuePhase.joined:
        await _startLooking(uid);
        break;
      case MatchmakingQueuePhase.looking:
        await _cancelLooking(uid);
        break;
      case MatchmakingQueuePhase.matched:
        if (entry.hasJoinTarget) {
          await _joinMatched(uid, entry);
        } else {
          await _cancelLooking(uid);
        }
        break;
    }
  }

  Future<void> _startLooking(String userId) async {
    setState(() => _isLoading = true);
    try {
      final friendsService = FriendsService();
      final friends = await friendsService.getFriendsWithDetails(userId);
      final friendUids = friends
          .map((f) => f['friend']?['uid'] as String?)
          .where((uid) => uid != null)
          .cast<String>()
          .toList();

      await _tracker.startLookingAfter(
        () async {
          if (friendUids.isEmpty) return;
          await NotificationService.sendNotificationToUsers(
            title: '🎮 Friend Looking for Squad!',
            body: 'Your friend is looking for a squad to play with!',
            recipientUids: friendUids,
            data: {
              'type': 'lfg_alert',
              'from_uid': userId,
              'squad_id': widget.squadId,
            },
          );
        },
        userId: userId,
        squadId: widget.squadId,
      );
      _tracker.processQueue();

      if (!mounted) return;
      final next = _entryFor(userId);
      final message = next.phase == MatchmakingQueuePhase.matched
          ? (next.hasJoinTarget
              ? 'Matched — join ${next.gameName ?? 'the lobby'}'
              : 'Matched with a player looking for a squad')
          : (friendUids.isEmpty
              ? 'Looking for a squad'
              : '🎮 ${friendUids.length} friends notified!');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: next.phase == MatchmakingQueuePhase.matched
              ? Colors.green
              : (friendUids.isEmpty ? Colors.orange : Colors.green),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start looking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelLooking(String userId) async {
    setState(() => _isLoading = true);
    try {
      await _tracker.cancelLookingAfter(
        () async {},
        userId: userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No longer looking for squad')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _joinMatched(String userId, MatchmakingQueueEntry entry) async {
    setState(() => _isLoading = true);
    try {
      final lobbyId = entry.lobbyId;
      int? claimedSpot;
      var handedOff = false;
      if (lobbyId != null && lobbyId.isNotEmpty) {
        claimedSpot =
            await ref.read(lobbyNotifierProvider.notifier).assignPeacockSpot(
                  userId: userId,
                  lobbyId: lobbyId,
                  gameName: entry.gameName,
                  notificationId: entry.notificationId,
                );
        handedOff = true;
      }
      final handoff = _tracker.joinMatched(userId, handoffToPeacock: false);
      if (!mounted) return;
      if (handoff.state.hasJoinTarget) {
        openPeacockCard(
          lobbyId: handoff.state.lobbyId,
          gameName: handoff.state.gameName,
        );
      }
      final String message;
      if (claimedSpot != null) {
        message = 'Joined ${handoff.state.gameName ?? 'squad'}';
      } else if (handedOff) {
        message = 'Handed off — claim spot in lobby';
      } else {
        message = 'Squad joined';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join matched lobby: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = _currentUidOrNull();

    return ListenableBuilder(
      listenable: _tracker,
      builder: (context, _) {
        final entry = _entryFor(uid);
        final looking = entry.phase == MatchmakingQueuePhase.looking;
        final matched = entry.phase == MatchmakingQueuePhase.matched;
        final joined = entry.phase == MatchmakingQueuePhase.joined;
        final canJoin = matched && entry.hasJoinTarget;

        final Color buttonColor;
        if (joined) {
          buttonColor = Colors.green;
        } else if (matched) {
          buttonColor = Colors.green;
        } else if (looking) {
          buttonColor = Colors.orange;
        } else if (widget.neonColor == Colors.white ||
            widget.neonColor.computeLuminance() > 0.8) {
          buttonColor = theme.colorScheme.primary;
        } else {
          buttonColor = widget.neonColor;
        }

        final String label;
        if (joined) {
          label = entry.gameName != null
              ? 'In ${entry.gameName} squad'
              : 'In squad';
        } else if (canJoin) {
          label = entry.gameName != null
              ? 'Join ${entry.gameName}'
              : 'Join matched squad';
        } else if (matched) {
          label = 'Cancel match';
        } else if (looking) {
          label = 'Cancel Looking for Squad';
        } else {
          label = 'Looking for Squad';
        }

        final IconData icon;
        if (joined || canJoin) {
          icon = Icons.group;
        } else if (looking || matched) {
          icon = Icons.notifications_off;
        } else {
          icon = Icons.notifications_active;
        }

        String? status;
        if (looking) {
          status = 'In queue — looking for a squad';
        } else if (canJoin) {
          status = 'Matched · ${entry.gameName ?? 'lobby ready'}';
        } else if (matched) {
          status = 'Matched — waiting for a lobby';
        } else if (joined && entry.hasJoinTarget) {
          status = 'Handed off to lobby';
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading || joined ? null : _onPressed,
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 20,
                          color: Colors.black,
                        ),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: buttonColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: buttonColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              if (status != null) ...[
                const SizedBox(height: 8),
                Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// "I'm on now" — pings lobby members through [AvailabilityPing.dispatch]
/// → [NotificationService.sendNotificationToUsers]. Same LFG chat-info
/// entry as Looking for Squad. No second notification presenter.
class _OnNowButton extends ConsumerStatefulWidget {
  final String squadId;
  final Color neonColor;

  const _OnNowButton({
    required this.squadId,
    required this.neonColor,
  });

  @override
  ConsumerState<_OnNowButton> createState() => _OnNowButtonState();
}

class _OnNowButtonState extends ConsumerState<_OnNowButton> {
  bool _isLoading = false;

  Future<void> _onPressed() async {
    final uid = _currentUidOrNull();
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in to ping your squad'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      final state = ref.read(lobbyNotifierProvider).valueOrNull;
      final result = await AvailabilityPing.dispatch(
        senderUid: uid,
        squadId: widget.squadId,
        currentLobby: state?.currentLobby,
        userLobbies: state?.userLobbies ?? const {},
        lobbyMemberUids: state?.lobbyMemberUids ?? const [],
        gameName: state?.currentGame?['name'] as String? ??
            state?.currentLobby?.gameName,
        senderName: state?.displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.snackbarMessage),
          backgroundColor: result.sent ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ping: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color buttonColor = widget.neonColor;
    if (widget.neonColor == Colors.white ||
        widget.neonColor.computeLuminance() > 0.8) {
      buttonColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('availability-on-now'),
          onPressed: _isLoading ? null : _onPressed,
          icon: _isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  ),
                )
              : const Icon(
                  Icons.campaign,
                  size: 20,
                  color: Colors.black,
                ),
          label: const Text(
            "I'm on now",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: buttonColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: buttonColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// AuthService claims never-throw; dotenv can still assert in unit harnesses.
String? _currentUidOrNull() {
  try {
    return AuthServiceSupabase().currentUser?.id;
  } catch (_) {
    return null;
  }
}


