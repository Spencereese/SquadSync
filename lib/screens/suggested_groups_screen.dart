import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firestore_service_refactored.dart';
import '../widgets/async_value_widget.dart';
import '../providers.dart';

/// Example widget demonstrating the refactored FirestoreService usage
class SuggestedGroupsScreen extends ConsumerStatefulWidget {
  const SuggestedGroupsScreen({super.key});

  @override
  ConsumerState<SuggestedGroupsScreen> createState() =>
      _SuggestedGroupsScreenState();
}

class _SuggestedGroupsScreenState extends ConsumerState<SuggestedGroupsScreen> {
  final TextEditingController _searchController = TextEditingController();
  GroupQueryFilters _currentFilters = const GroupQueryFilters(isPublic: true);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilters() {
    setState(() {
      _currentFilters = GroupQueryFilters(
        isPublic: true,
        searchTerm: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
      );
    });
    _loadGroups();
  }

  void _loadGroups() {
    ref
        .read(suggestedGroupsNotifierProvider.notifier)
        .loadSuggestedGroups(_currentFilters);
  }

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(suggestedGroupsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Groups'),
      ),
      body: Column(
        children: [
          // Search and Filter Controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search groups...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _updateFilters(),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('Filters: Public groups'),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _updateFilters,
                      child: const Text('Search'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Groups List
          Expanded(
            child: AsyncValueWidget<List<Map<String, dynamic>>>(
              value: groupsState.suggestedGroups,
              data: (groups) => groups.isEmpty
                  ? const Center(child: Text('No groups found'))
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return GroupCard(
                          group: group,
                          onJoin: () => _joinGroup(group),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinGroup(Map<String, dynamic> group) async {
    // Implementation for joining a group
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Joining ${group['name']}...')),
    );
  }
}

/// Individual group card widget
class GroupCard extends StatelessWidget {
  final Map<String, dynamic> group;
  final VoidCallback onJoin;

  const GroupCard({
    super.key,
    required this.group,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: group['imageUrl'] != null
                      ? NetworkImage(group['imageUrl'])
                      : null,
                  child: group['imageUrl'] == null
                      ? const Icon(Icons.group)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        group['name'] ?? 'Unnamed Group',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${group['memberCount'] ?? 0} members',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: onJoin,
                  child: const Text('Join'),
                ),
              ],
            ),
            if (group['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                group['description'],
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
