import 'package:flutter/material.dart';
import '../services/auth_service_supabase.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/poll.dart';
import '../services/poll_service.dart';
import '../domain/entities/message.dart' hide Poll;
import 'poll_message_bubble.dart';

class PollHistoryScreen extends ConsumerStatefulWidget {
  final String? chatGroupId;
  final ChatType chatType;

  const PollHistoryScreen({
    super.key,
    this.chatGroupId,
    required this.chatType,
  });

  @override
  ConsumerState<PollHistoryScreen> createState() => _PollHistoryScreenState();
}

class _PollHistoryScreenState extends ConsumerState<PollHistoryScreen> {
  final PollService _pollService = PollService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _filterStatus = 'all'; // all, active, closed
  String _sortBy = 'newest'; // newest, oldest, most_votes

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Poll History'),
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: _buildFilters(),
        ),
      ),
      body: StreamBuilder<List<Poll>>(
        stream: _pollService.getPollsStream(chatGroupId: widget.chatGroupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading polls: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final allPolls = snapshot.data ?? [];
          final filteredPolls = _filterAndSortPolls(allPolls);

          if (filteredPolls.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredPolls.length,
            itemBuilder: (context, index) {
              final poll = filteredPolls[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: PollMessageBubble(
                  poll: poll,
                  chatGroupId: widget.chatGroupId,
                  isFromCurrentUser:
                      poll.creatorUid == AuthServiceSupabase().currentUser?.id,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search polls...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _searchQuery = value.toLowerCase());
            },
          ),
          const SizedBox(height: 12),
          // Filter and sort options
          Row(
            children: [
              // Status filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _filterStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Polls')),
                    DropdownMenuItem(value: 'active', child: Text('Active')),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (value) {
                    setState(() => _filterStatus = value ?? 'all');
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Sort options
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort by',
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'newest', child: Text('Newest')),
                    DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
                    DropdownMenuItem(
                        value: 'most_votes', child: Text('Most Votes')),
                  ],
                  onChanged: (value) {
                    setState(() => _sortBy = value ?? 'newest');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.poll_outlined,
            size: 64,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No polls found matching "$_searchQuery"'
                : 'No polls found',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              child: const Text('Clear search'),
            ),
          ],
        ],
      ),
    );
  }

  List<Poll> _filterAndSortPolls(List<Poll> polls) {
    // Filter by search query
    var filtered = polls.where((poll) {
      if (_searchQuery.isEmpty) return true;
      return poll.title.toLowerCase().contains(_searchQuery) ||
          poll.creatorName.toLowerCase().contains(_searchQuery);
    }).toList();

    // Filter by status
    filtered = filtered.where((poll) {
      switch (_filterStatus) {
        case 'active':
          return !poll.isClosed;
        case 'closed':
          return poll.isClosed;
        default:
          return true;
      }
    }).toList();

    // Sort
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'oldest':
          return a.createdAt.compareTo(b.createdAt);
        case 'most_votes':
          return b.totalVotes.compareTo(a.totalVotes);
        case 'newest':
        default:
          return b.createdAt.compareTo(a.createdAt);
      }
    });

    return filtered;
  }
}
