import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/poll.dart';
import '../../services/poll_service.dart';

class PollMessageBubble extends StatefulWidget {
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
  State<PollMessageBubble> createState() => _PollMessageBubbleState();
}

class _PollMessageBubbleState extends State<PollMessageBubble> {
  final _pollService = PollService();
  late Poll _currentPoll;
  bool _isVoting = false;

  @override
  void initState() {
    super.initState();
    _currentPoll = widget.poll;
  }

  @override
  void didUpdateWidget(PollMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.poll.id != widget.poll.id ||
        oldWidget.poll.totalVotes != widget.poll.totalVotes) {
      _currentPoll = widget.poll;
    }
  }

  Future<void> _vote(List<String> optionIds) async {
    if (_isVoting) return;

    setState(() => _isVoting = true);

    try {
      final success = await _pollService.voteOnPoll(
        pollId: _currentPoll.id,
        optionIds: optionIds,
        chatGroupId: widget.chatGroupId,
      );

      if (success && mounted) {
        // Refresh poll data
        final updatedPoll = await _pollService.getPoll(
          _currentPoll.id,
          chatGroupId: widget.chatGroupId,
        );
        if (updatedPoll != null) {
          setState(() => _currentPoll = updatedPoll);
        }
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
    try {
      final success = await _pollService.closePoll(
        pollId: _currentPoll.id,
        chatGroupId: widget.chatGroupId,
      );

      if (success && mounted) {
        final updatedPoll = await _pollService.getPoll(
          _currentPoll.id,
          chatGroupId: widget.chatGroupId,
        );
        if (updatedPoll != null) {
          setState(() => _currentPoll = updatedPoll);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close poll: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isCreator = user?.uid == _currentPoll.creatorUid;
    final hasVoted = user != null && _currentPoll.hasUserVoted(user.uid);
    final userVotes = user != null ? _currentPoll.getUserVotes(user.uid) : [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isFromCurrentUser
            ? Colors.cyanAccent.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyanAccent.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poll header
          Row(
            children: [
              const Icon(Icons.poll, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentPoll.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_currentPoll.isClosed)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'CLOSED',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Poll metadata
          Row(
            children: [
              Text(
                'by ${_currentPoll.creatorName}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_currentPoll.totalVotes} vote${_currentPoll.totalVotes != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
              if (_currentPoll.isMultipleChoice) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.check_circle,
                  color: Colors.cyanAccent.withValues(alpha: 0.7),
                  size: 14,
                ),
                Text(
                  'Multiple choice',
                  style: TextStyle(
                    color: Colors.cyanAccent.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),

          // Poll options
          ..._currentPoll.options.map((option) {
            final isSelected = userVotes.contains(option.id);
            final percentage = _currentPoll.totalVotes > 0
                ? (option.voteCount / _currentPoll.totalVotes * 100).round()
                : 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: (_currentPoll.isClosed || _isVoting)
                    ? null
                    : () => _vote([option.id]),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.cyanAccent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? Colors.cyanAccent
                          : Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
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
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                          if (hasVoted || _currentPoll.isClosed) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$percentage%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (isSelected) ...[
                            const SizedBox(width: 4),
                            Icon(
                              Icons.check_circle,
                              color: Colors.cyanAccent,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      if (hasVoted || _currentPoll.isClosed) ...[
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: _currentPoll.totalVotes > 0
                              ? option.voteCount / _currentPoll.totalVotes
                              : 0,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isSelected
                                ? Colors.cyanAccent
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Action buttons
          if (isCreator && !_currentPoll.isClosed) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _closePoll,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
                child: const Text('Close Poll'),
              ),
            ),
          ],

          // Poll status
          if (_currentPoll.isClosed && _currentPoll.closedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Poll closed',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
