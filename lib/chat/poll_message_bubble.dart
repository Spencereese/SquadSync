import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';
import '../../presentation/notifiers/user_notifier.dart';

class PollMessageBubble extends ConsumerWidget {
  final Poll poll;
  final String? chatGroupId;
  final bool isFromCurrentUser;

  const PollMessageBubble({
    super.key,
    required this.poll,
    this.chatGroupId,
    this.isFromCurrentUser = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pollService = PollService();

    return StreamBuilder<Poll?>(
      stream: pollService.getPollStream(poll.id, chatGroupId: chatGroupId),
      initialData: poll,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final currentPoll = snapshot.data ?? poll;

        return _PollBubbleContent(
          poll: currentPoll,
          chatGroupId: chatGroupId,
          isFromCurrentUser: isFromCurrentUser,
        );
      },
    );
  }
}

class _PollBubbleContent extends ConsumerStatefulWidget {
  final Poll poll;
  final String? chatGroupId;
  final bool isFromCurrentUser;

  const _PollBubbleContent({
    required this.poll,
    this.chatGroupId,
    this.isFromCurrentUser = false,
  });

  @override
  ConsumerState<_PollBubbleContent> createState() => _PollBubbleContentState();
}

class _PollBubbleContentState extends ConsumerState<_PollBubbleContent>
    with TickerProviderStateMixin {
  final _pollService = PollService();
  bool _isVoting = false;
  Timer? _countdownTimer; // ignore: unused_field
  final Duration _remainingTime = Duration.zero; // ignore: unused_field
  late AnimationController _pulseController; // ignore: unused_field

  @override
  void initState() {
    super.initState();
    // No initialization needed since we're using StreamBuilder
  }

  @override
  void didUpdateWidget(_PollBubbleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // No need to update local state since we're using StreamBuilder now
  }

  Future<void> _vote(List<String> optionIds) async {
    if (_isVoting) return;

    setState(() => _isVoting = true);

    try {
      final success = await ref.read(userNotifierProvider.notifier).voteOnPoll(
            pollId: widget.poll.id,
            optionIds: optionIds,
            chatGroupId: widget.chatGroupId,
          );

      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to vote')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to vote: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isVoting = false);
      }
    }
  }

  Future<void> _closePoll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Close Poll',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to close this poll? No more votes will be accepted.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
            child: const Text('Close Poll'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _pollService.closePoll(
          pollId: widget.poll.id,
          chatGroupId: widget.chatGroupId,
        );

        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Failed to close poll. Please try again.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error closing poll. Please try again.')),
          );
        }
      }
    }
  }

  String _calculateEngagementRate() {
    // Simple engagement calculation: percentage of options that received votes
    if (widget.poll.options.isEmpty) return '0';

    final optionsWithVotes =
        widget.poll.options.where((option) => option.voteCount > 0).length;
    final rate = (optionsWithVotes / widget.poll.options.length * 100).round();
    return rate.toString();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isCreator = user?.uid == widget.poll.creatorUid;
    final hasVoted = user != null && widget.poll.hasUserVoted(user.uid);
    final userVotes = user != null ? widget.poll.getUserVotes(user.uid) : [];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.isFromCurrentUser
              ? [
                  Colors.cyanAccent.withValues(alpha: 0.15),
                  Colors.cyanAccent.withValues(alpha: 0.08),
                ]
              : [
                  Colors.white.withValues(alpha: 0.08),
                  Colors.white.withValues(alpha: 0.04),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.poll.isClosed
              ? Colors.redAccent.withValues(alpha: 0.4)
              : Colors.cyanAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll header with enhanced styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.cyanAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.poll.isClosed ? Icons.lock : Icons.poll,
                    color: Colors.cyanAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.poll.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (widget.poll.isClosed) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.redAccent.withValues(alpha: 0.8),
                          Colors.red.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'CLOSED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Poll metadata with better layout
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'by ${ref.watch(userNotifierProvider.select((asyncValue) => ref.read(userNotifierProvider.notifier).getDisplayNameForUid(widget.poll.creatorUid) ?? widget.poll.creatorName))}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.how_to_vote,
                  color: Colors.white.withValues(alpha: 0.6),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.poll.totalVotes} vote${widget.poll.totalVotes != 1 ? 's' : ''}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.poll.isMultipleChoice) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.cyanAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Multiple',
                          style: TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // Poll engagement analytics
                if (widget.poll.totalVotes > 0) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.greenAccent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.greenAccent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_calculateEngagementRate()}%',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Poll options with enhanced design
          ...widget.poll.options.map((option) {
            final isSelected = userVotes.contains(option.id);
            final percentage = widget.poll.totalVotes > 0
                ? (option.voteCount / widget.poll.totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                child: InkWell(
                  onTap: (widget.poll.isClosed || _isVoting)
                      ? null
                      : () => _vote([option.id]),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                Colors.cyanAccent.withValues(alpha: 0.3),
                                Colors.cyanAccent.withValues(alpha: 0.15),
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.08),
                                Colors.white.withValues(alpha: 0.04),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.cyanAccent.withValues(alpha: 0.8)
                            : Colors.white.withValues(alpha: 0.2),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: Colors.cyanAccent.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                option.text,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            if (hasVoted || widget.poll.isClosed) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$percentage%',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: Colors.black,
                                  size: 14,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (hasVoted || widget.poll.isClosed) ...[
                          const SizedBox(height: 10),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOut,
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: FractionallySizedBox(
                              alignment: Alignment.centerLeft,
                              widthFactor: widget.poll.totalVotes > 0
                                  ? option.voteCount / widget.poll.totalVotes
                                  : 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isSelected
                                        ? [
                                            Colors.cyanAccent,
                                            Colors.cyanAccent
                                                .withValues(alpha: 0.8),
                                          ]
                                        : [
                                            Colors.white.withValues(alpha: 0.6),
                                            Colors.white.withValues(alpha: 0.4),
                                          ],
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (!widget.poll.isAnonymous &&
                            option.voterUids.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Voters: ${option.voterUids.map((uid) => ref.watch(userNotifierProvider.select((asyncValue) => ref.read(userNotifierProvider.notifier).getDisplayNameForUid(uid) ?? 'Unknown'))).join(', ')}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // Action buttons with modern design
          if (isCreator && !widget.poll.isClosed) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.redAccent.withValues(alpha: 0.8),
                      Colors.red.withValues(alpha: 0.6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: _closePoll,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Close Poll',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Poll status with enhanced styling
          if (widget.poll.isClosed && widget.poll.closedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lock_clock,
                    color: Colors.redAccent.withValues(alpha: 0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Poll closed',
                    style: TextStyle(
                      color: Colors.redAccent.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
