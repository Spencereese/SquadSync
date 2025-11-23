import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service_refactored.dart';
import '../app_theme.dart';
import '../widgets/async_value_widget.dart';
import '../providers.dart';

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;
  String _currentSearchTerm = '';
  bool _isLoadingMore = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Load initial groups
    _loadInitialGroups();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _loadInitialGroups() {
    final filters = GroupQueryFilters(isPublic: true);
    ref
        .read(suggestedGroupsNotifierProvider.notifier)
        .loadSuggestedGroups(filters);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadNextPage();
    }
  }

  void _loadNextPage() {
    if (!_isLoadingMore) {
      setState(() => _isLoadingMore = true);
      ref
          .read(suggestedGroupsNotifierProvider.notifier)
          .loadNextPage()
          .then((_) {
        if (mounted) {
          setState(() => _isLoadingMore = false);
        }
      }).catchError((error) {
        if (mounted) {
          setState(() => _isLoadingMore = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load more groups: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupsState = ref.watch(suggestedGroupsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Groups'),
        backgroundColor: theme.primaryColor,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: theme.brightness == Brightness.dark
              ? AppTheme.darkGradient
              : AppTheme.lightGradient,
        ),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search groups...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _currentSearchTerm.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _clearSearch,
                            )
                          : null,
                      filled: true,
                      fillColor: theme.cardColor.withValues(alpha: 0.8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  if (_currentSearchTerm.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.smart_toy,
                            size: 16, color: theme.primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Powered by Grok AI',
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Groups List
            Expanded(
              child: AsyncValueWidget<List<Map<String, dynamic>>>(
                value: groupsState.suggestedGroups,
                data: (groups) => groups.isEmpty && _currentSearchTerm.isEmpty
                    ? const Center(child: Text('No public groups available'))
                    : groups.isEmpty
                        ? const Center(
                            child: Text('No groups found for your search'))
                        : ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: groups.length + (_isLoadingMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == groups.length) {
                                return const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                );
                              }

                              final group = groups[index];
                              return GroupCard(
                                group: group,
                                isJoining: _isJoining,
                                onJoin: () => _joinGroup(group),
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearchTerm = '';
    });
    _loadInitialGroups();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _currentSearchTerm = query.trim();
      });

      if (_currentSearchTerm.isNotEmpty) {
        final filters = GroupQueryFilters(
          isPublic: true,
          searchTerm: _currentSearchTerm,
        );
        ref
            .read(suggestedGroupsNotifierProvider.notifier)
            .loadSuggestedGroups(filters);
      } else {
        _loadInitialGroups();
      }
    });
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    setState(() => _isJoining = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please sign in first')),
          );
        }
        return;
      }

      final groupId = group['id'];

      // Check if user is already a member
      final groupDoc = await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .get();

      if (groupDoc.exists) {
        final groupData = groupDoc.data()!;
        final members = List<String>.from(groupData['members'] ?? []);
        if (members.contains(currentUser.uid)) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are already a member')),
            );
          }
          return;
        }
      }

      // Add user to group
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Add group to user's groups list
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'chatGroups': FieldValue.arrayUnion([groupId]),
      });

      if (mounted) {
        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${group['name']}!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join group: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _joinGroup(group),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }
}

class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final bool isJoining;
  final VoidCallback onJoin;

  const GroupCard({
    super.key,
    required this.group,
    required this.isJoining,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final group = this.group;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.primaryColor.withValues(alpha: 0.1),
                  backgroundImage: group['imageUrl'] != null
                      ? NetworkImage(group['imageUrl'])
                      : null,
                  child: group['imageUrl'] == null
                      ? Icon(
                          Icons.group,
                          color: theme.primaryColor,
                          size: 24,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] ?? 'Unnamed Group',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.titleLarge?.color,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${group['memberCount'] ?? 0} members',
                            style: TextStyle(
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                          if (group['gameName'] != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.videogame_asset,
                              size: 16,
                              color: theme.textTheme.bodySmall?.color
                                  ?.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              group['gameName'],
                              style: TextStyle(
                                color: theme.textTheme.bodySmall?.color
                                    ?.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: isJoining ? null : onJoin,
                  style: FilledButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: isJoining
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Join'),
                ),
              ],
            ),
            if (group['description'] != null &&
                group['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                group['description'],
                style: TextStyle(
                  color:
                      theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
