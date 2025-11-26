import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/notifiers/user_notifier.dart';

/// Dialog for finding and joining public groups
class FindGroupsDialog extends StatefulWidget {
  const FindGroupsDialog({super.key});

  @override
  State<FindGroupsDialog> createState() => _FindGroupsDialogState();
}

class _FindGroupsDialogState extends State<FindGroupsDialog> {
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

      // Also add the group to the current user's userGroups list
      final groupInfo = {
        'id': groupId,
        'name': groupData['name'] ?? 'Unnamed Group',
        'imageUrl': groupData['imageUrl'],
        'isPublic': groupData['isPublic'] ?? false,
        'memberCount': (groupData['memberCount'] ?? 0) + 1,
        'createdBy': creatorUid,
        'lastMessage': groupData['lastMessage'],
        'lastMessageTime': groupData['lastMessageTime'],
      };

      await _firestore.collection('users').doc(currentUser.uid).update({
        'userGroups': FieldValue.arrayUnion([groupInfo]),
      });

      // Also create a document in the user's chat_groups subcollection
      await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .collection('chat_groups')
          .doc(groupId)
          .set(groupInfo);

      // Update the local user notifier state immediately
      if (context.mounted) {
        final container = ProviderScope.containerOf(context);
        container.read(userNotifierProvider.notifier).addUserGroup(groupInfo);
      }

      if (mounted) {
        Navigator.pop(context); // Close the search dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Joined ${groupData['name'] ?? 'group'} successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Find Public Groups',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  // Search
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search public groups...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.grey[800],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                      ),
                      onChanged: _searchGroups,
                    ),
                  ),
                  // Loading indicator
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent),
                    )
                  // Results
                  else
                    Expanded(
                      child: _searchResults.isEmpty &&
                              _searchController.text.isNotEmpty
                          ? const Center(
                              child: Text(
                                'No public groups found',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final group = _searchResults[index];
                                final groupId = group['id'];
                                final groupData =
                                    group['data'] as Map<String, dynamic>;
                                final name =
                                    groupData['name'] ?? 'Unnamed Group';
                                final memberCount =
                                    groupData['memberCount'] ?? 0;
                                final isUserGroup =
                                    groupData['createdBy'] != null;

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.cyanAccent,
                                    child: Icon(
                                      isUserGroup ? Icons.group : Icons.groups,
                                      color: Colors.black,
                                    ),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    '$memberCount members',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () =>
                                        _joinPublicGroup(groupId, groupData),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.cyanAccent,
                                      foregroundColor: Colors.black,
                                    ),
                                    child: const Text('Join'),
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
