import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/base_dialog.dart';

/// Dialog for finding and joining public groups using BaseDialog
class FindGroupsDialog extends BaseDialog {
  const FindGroupsDialog({super.key});

  @override
  BaseDialogState<BaseDialog> createState() => _FindGroupsDialogState();

  @override
  String? get title => 'Find Public Groups';

  @override
  bool get showCloseButton => true;

  @override
  bool get dismissible => true;

  @override
  double? get maxWidth => 600;

  @override
  List<Widget>? buildActions(BuildContext context) => null;

  @override
  Widget buildContent(BuildContext context) {
    final state = context.findAncestorStateOfType<_FindGroupsDialogState>();
    if (state == null) return const SizedBox.shrink();

    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: state._searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search public groups...',
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              filled: true,
              fillColor:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            onChanged: state._searchGroups,
          ),
        ),

        const SizedBox(height: 16),

        // Loading indicator or Results
        Expanded(
          child: state._isLoading
              ? const Center(child: CircularProgressIndicator())
              : state._searchResults.isEmpty &&
                      state._searchController.text.isNotEmpty
                  ? Center(
                      child: Text(
                        'No public groups found',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: state._searchResults.length,
                      itemBuilder: (context, index) {
                        final group = state._searchResults[index];
                        return state._buildGroupListTile(group);
                      },
                    ),
        ),
      ],
    );
  }
}

class _FindGroupsDialogState extends BaseDialogState<FindGroupsDialog> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchGroups(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await _searchPublicGroups(query.trim());
      setState(() {
        _searchResults = results;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching groups: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _searchPublicGroups(String query) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    try {
      // Search for public user groups
      final userGroupsQuery = _firestore
          .collectionGroup('chat_groups')
          .where('isPublic', isEqualTo: true)
          .where('name', isGreaterThanOrEqualTo: query)
          .where('name', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(20);

      final userGroupsSnapshot = await userGroupsQuery.get();

      final results = <Map<String, dynamic>>[];

      for (var doc in userGroupsSnapshot.docs) {
        final data = doc.data();
        final members = List<String>.from(data['members'] ?? []);
        final isAlreadyMember = members.contains(currentUser.uid);

        // Only show groups the user is not already a member of
        if (!isAlreadyMember) {
          results.add({
            'id': doc.id,
            'data': data,
            'type': 'user_group',
          });
        }
      }

      return results;
    } catch (e) {
      debugPrint('Error searching public groups: $e');
      return [];
    }
  }

  Future<void> _joinPublicGroup(
      String groupId, Map<String, dynamic> groupData) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    try {
      // For user groups, we need to find the creator's user document
      // and add the current user to the members array
      final creatorUid = groupData['createdBy'];
      if (creatorUid == null) return;

      await _firestore
          .collection('users')
          .doc(creatorUid)
          .collection('chat_groups')
          .doc(groupId)
          .update({
        'members': FieldValue.arrayUnion([currentUser.uid]),
        'memberCount': FieldValue.increment(1),
      });

      if (mounted) {
        Navigator.pop(context); // Close the search dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Joined ${groupData['name'] ?? 'group'} successfully!'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join group: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Widget _buildGroupListTile(Map<String, dynamic> group) {
    final groupId = group['id'];
    final groupData = group['data'] as Map<String, dynamic>;
    final name = groupData['name'] ?? 'Unnamed Group';
    final memberCount = groupData['memberCount'] ?? 0;
    final isUserGroup = groupData['createdBy'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withOpacity(0.2),
          child: Icon(
            isUserGroup ? Icons.group : Icons.groups,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '$memberCount members',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
        trailing: ElevatedButton(
          onPressed: () => _joinPublicGroup(groupId, groupData),
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Join'),
        ),
      ),
    );
  }
}
