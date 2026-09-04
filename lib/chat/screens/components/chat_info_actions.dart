import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/deep_link_routes.dart';
import '../../../screens/voice_room_screen.dart';
import '../../../screens/video_room_screen.dart';
import 'chat_info_widgets.dart';
import '../../../services/auth_service_supabase.dart';
import '../../../services/availability_ping.dart';
import '../../../services/friends_service.dart';
import '../../../services/lobby_seat_status.dart';
import '../../../services/matchmaking_queue_machine.dart';
import '../../../services/peacock_assignment_machine.dart';
import '../../../domain/entities/lobby.dart';
import '../../../presentation/notifiers/lobby_notifier.dart';
import '../../../notification_service.dart';

/// Product order for the Tonight strip. Search is omitted until it searches.
const kTonightOnNowAction = 'on_now';
const kTonightLookingForSquadAction = 'looking_for_squad';
const kTonightInviteAction = 'invite';
const kMoreVoiceAction = 'voice';
const kMoreVideoAction = 'video';
const kDeadSearchAction = 'search';

enum TonightStripSlot { tonight, more }

/// Slot for a chat-info / lobby action. `null` means omit (dead Search).
TonightStripSlot? slotForTonightAction(String actionId) {
  switch (actionId) {
    case kTonightOnNowAction:
    case kTonightLookingForSquadAction:
    case kTonightInviteAction:
      return TonightStripSlot.tonight;
    case kMoreVoiceAction:
    case kMoreVideoAction:
      return TonightStripSlot.more;
    case kDeadSearchAction:
      return null;
    default:
      return null;
  }
}

/// Tonight children in product order: I am on, Looking for Squad, Invite.
List<Widget> tonightStripChildren({
  required Widget onNow,
  required Widget lookingForSquad,
  required Widget invite,
}) =>
    [onNow, lookingForSquad, invite];

/// Resolve a lobby id for Tonight Invite → [shareLobbyLink].
/// Prefers the lobby bound to [squadId], then selected / current, then [squadId].
String resolveInviteLobbyId({
  required String squadId,
  String? selectedLobbyId,
  Lobby? currentLobby,
  Map<String, Lobby> userLobbies = const {},
}) {
  bool matches(Lobby lobby) =>
      lobby.id == squadId || lobby.chatGroupId == squadId;

  if (currentLobby != null &&
      matches(currentLobby) &&
      currentLobby.id.isNotEmpty) {
    return currentLobby.id;
  }
  for (final lobby in userLobbies.values) {
    if (matches(lobby) && lobby.id.isNotEmpty) return lobby.id;
  }
  final selected = selectedLobbyId?.trim();
  if (selected != null && selected.isNotEmpty) return selected;
  if (currentLobby != null && currentLobby.id.isNotEmpty) {
    return currentLobby.id;
  }
  return squadId.trim();
}

/// Primary Tonight block: I am on / Looking for Squad / Invite.
class TonightActionsBlock extends StatelessWidget {
  const TonightActionsBlock({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('tonight-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
          child: Text(
            'Tonight',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          children[i],
        ],
      ],
    );
  }
}

/// Collapsed More bucket for Voice + Video. Search is not a child.
class MoreActionsBlock extends StatefulWidget {
  const MoreActionsBlock({
    super.key,
    required this.children,
  });

  final List<Widget> children;

  @override
  State<MoreActionsBlock> createState() => _MoreActionsBlockState();
}

class _MoreActionsBlockState extends State<MoreActionsBlock> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('more-actions'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          key: const Key('more-actions-toggle'),
          onPressed: () => setState(() => _expanded = !_expanded),
          icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
          label: const Text('More'),
        ),
        if (_expanded) ...widget.children,
      ],
    );
  }
}

/// Chat-info actions: Tonight strip first, Voice + Video under More.
/// Search is gone until it searches (coming-soon snackbar is not a feature).
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
        TonightActionsBlock(
          children: tonightStripChildren(
            onNow: _OnNowButton(
              squadId: squadId,
              neonColor: neonColor,
            ),
            lookingForSquad: LookingForSquadButton(
              key: const Key('tonight-looking-for-squad'),
              squadId: squadId,
              neonColor: neonColor,
            ),
            invite: _InviteButton(
              squadId: squadId,
              neonColor: neonColor,
            ),
          ),
        ),
        const SizedBox(height: 8),
        MoreActionsBlock(
          children: [
            if (slotForTonightAction(kMoreVoiceAction) ==
                    TonightStripSlot.more ||
                slotForTonightAction(kMoreVideoAction) == TonightStripSlot.more)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (slotForTonightAction(kMoreVoiceAction) ==
                        TonightStripSlot.more)
                      ChatInfoBigActionButton(
                        key: const Key('more-voice'),
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
                    if (slotForTonightAction(kMoreVideoAction) ==
                        TonightStripSlot.more)
                      ChatInfoBigActionButton(
                        key: const Key('more-video'),
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
                  ],
                ),
              ),
            // Dead Search stays omitted: slotForTonightAction('search') is null.
            if (slotForTonightAction(kDeadSearchAction) != null)
              const SizedBox.shrink(),
          ],
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
class LookingForSquadButton extends ConsumerStatefulWidget {
  final String squadId;
  final Color neonColor;

  const LookingForSquadButton({
    super.key,
    required this.squadId,
    required this.neonColor,
  });

  @override
  ConsumerState<LookingForSquadButton> createState() =>
      _LookingForSquadButtonState();
}

class _LookingForSquadButtonState extends ConsumerState<LookingForSquadButton> {
  bool _isLoading = false;

  MatchmakingQueueTracker get _tracker => MatchmakingQueueTracker.instance;

  MatchmakingQueueEntry _entryFor(String? uid) =>
      uid == null ? MatchmakingQueueEntry.idle : _tracker.stateFor(uid);

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
      final message = lfgJoinSnackbarMessage(
        claimedSpot: claimedSpot,
        handedOff: handedOff,
      );
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

        final seat = uid == null
            ? null
            : resolveLobbySeatStatus(
                userId: uid,
                peacock: PeacockAssignmentTracker.instance.stateFor(uid),
                lfg: entry,
              );

        String? status;
        if (looking) {
          status = 'In queue — looking for a squad';
        } else if (canJoin) {
          status = 'Matched · ${entry.gameName ?? 'lobby ready'}';
        } else if (matched) {
          status = 'Matched — waiting for a lobby';
        } else if (joined && entry.hasJoinTarget) {
          status = claimSeatCopy(seat?.seatIndex);
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

/// Tonight Invite — live path is [shareLobbyLink] (same helper as lobby header).
class _InviteButton extends ConsumerWidget {
  final String squadId;
  final Color neonColor;

  const _InviteButton({
    required this.squadId,
    required this.neonColor,
  });

  Future<void> _onPressed(BuildContext context, WidgetRef ref) async {
    String? selectedLobbyId;
    Lobby? currentLobby;
    Map<String, Lobby> userLobbies = const {};
    try {
      final state = ref.read(lobbyNotifierProvider).valueOrNull;
      selectedLobbyId = state?.selectedLobbyId;
      currentLobby = state?.currentLobby;
      userLobbies = state?.userLobbies ?? const {};
    } catch (_) {}

    final lobbyId = resolveInviteLobbyId(
      squadId: squadId,
      selectedLobbyId: selectedLobbyId,
      currentLobby: currentLobby,
      userLobbies: userLobbies,
    );
    if (lobbyId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No lobby selected')),
        );
      }
      return;
    }

    try {
      await shareLobbyLink(lobbyId: lobbyId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lobby link copied'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not share lobby link: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    Color buttonColor = neonColor;
    if (neonColor == Colors.white || neonColor.computeLuminance() > 0.8) {
      buttonColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          key: const Key('tonight-invite'),
          onPressed: () => _onPressed(context, ref),
          icon: const Icon(
            Icons.share,
            size: 20,
            color: Colors.black,
          ),
          label: const Text(
            'Invite',
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
