import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/user_notifier.dart';
import '../../utils.dart';
import '../../chat/chat_screen.dart';
import '../../domain/entities/message.dart';

/// Enhanced friend search widget with filters and search history
class FriendSearchWidget extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>)? onUserSelected;
  final bool showDMButton;
  final bool showAddButton;

  const FriendSearchWidget({
    super.key,
    this.onUserSelected,
    this.showDMButton = true,
    this.showAddButton = true,
  });

  @override
  ConsumerState<FriendSearchWidget> createState() => _FriendSearchWidgetState();
}

class _FriendSearchWidgetState extends ConsumerState<FriendSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<String> _searchHistory = [];
  bool _isSearching = false;
  String _selectedFilter = 'all'; // all, online, recent

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.length < 2) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      final results = await userNotifier.searchUsers(
        query,
        filter: _selectedFilter,
      );

      // Add to search history
      if (!_searchHistory.contains(query)) {
        setState(() {
          _searchHistory.insert(0, query);
          if (_searchHistory.length > 5) {
            _searchHistory.removeLast();
          }
        });
      }

      if (mounted) setState(() => _searchResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _sendFriendRequest(String userId, String displayName) async {
    HapticFeedback.lightImpact();
    try {
      final userNotifier = ref.read(userNotifierProvider.notifier);
      await userNotifier.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Friend request sent to $displayName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _startDM(Map<String, dynamic> user) {
    HapticFeedback.lightImpact();
    final userId = user['uid'] as String;
    final displayName = safeDisplayName(user['display_name'] as String?);

    Navigator.of(context).pop(); // Close search dialog

    // Create DM chat
    final chatId =
        'dm_${[userId, ref.read(userNotifierProvider).value?.uid].join('_')}';
    debugPrint('Starting DM with $displayName (chatId: $chatId)');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatGroupId: chatId,
          chatGroupName: displayName,
          chatType: ChatType.dm,
        ),
      ),
    );
  }

  void _clearSearchHistory() {
    setState(() => _searchHistory.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Search history cleared'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text(
            'Filter:',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Users', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Online', 'online'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Recent', 'recent'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (mounted) {
          setState(() => _selectedFilter = value);
          if (_searchController.text.length >= 2) {
            _performSearch(_searchController.text);
          }
        }
      },
      selectedColor: Colors.cyanAccent.withOpacity(0.3),
      labelStyle: TextStyle(
        color: isSelected ? Colors.cyanAccent : Colors.grey[400],
        fontSize: 12,
      ),
      backgroundColor: Colors.grey[800],
      checkmarkColor: Colors.cyanAccent,
    );
  }

  Widget _buildSearchHistory() {
    if (_searchHistory.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Searches',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: _clearSearchHistory,
                child: const Text(
                  'Clear',
                  style: TextStyle(color: Colors.cyanAccent, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchHistory.length,
            itemBuilder: (context, index) {
              final query = _searchHistory[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(query),
                  onPressed: () {
                    _searchController.text = query;
                    _performSearch(query);
                  },
                  backgroundColor: Colors.grey[800],
                  labelStyle:
                      const TextStyle(color: Colors.white, fontSize: 12),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search users by name (min 2 chars)...',
              hintStyle: TextStyle(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.grey[800],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.cyanAccent,
                        ),
                      ),
                    )
                  : _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchResults = []);
                          },
                        )
                      : null,
            ),
            onChanged: (value) {
              if (value.length >= 2) {
                _performSearch(value);
              } else if (_searchResults.isNotEmpty) {
                setState(() => _searchResults = []);
              }
            },
            onSubmitted: _performSearch,
          ),
        ),

        // Filters
        _buildFilterChips(),

        // Search History
        _buildSearchHistory(),

        const Divider(color: Colors.grey, height: 1),

        // Results
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_search,
                        size: 64,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.length < 2
                            ? 'Type at least 2 characters to search'
                            : _isSearching
                                ? 'Searching...'
                                : 'No users found',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    final userId = user['uid'] as String;
                    final displayName =
                        safeDisplayName(user['display_name'] as String?);
                    final photoUrl = user['photo_url'] as String?;
                    final email = user['email'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              photoUrl != null ? NetworkImage(photoUrl) : null,
                          backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                          child: photoUrl == null
                              ? Text(
                                  displayName.isNotEmpty
                                      ? displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18),
                                )
                              : null,
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: email != null
                            ? Text(
                                email,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.showAddButton)
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _sendFriendRequest(userId, displayName),
                                icon: const Icon(Icons.person_add, size: 16),
                                label: const Text('Add'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                ),
                              ),
                            if (widget.showDMButton) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.message,
                                    color: Colors.cyanAccent),
                                onPressed: () => _startDM(user),
                                tooltip: 'Start DM',
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          if (widget.onUserSelected != null) {
                            widget.onUserSelected!(user);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
