import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../managers/user_manager.dart';
import '../../squad_state.dart';
import '../../utils.dart';

/// Enhanced dialog for inviting members to group chats
class InviteMembersDialog extends StatefulWidget {
  final String chatGroupId;
  final String chatGroupName;
  final bool isSquadGroup;

  const InviteMembersDialog({
    super.key,
    required this.chatGroupId,
    required this.chatGroupName,
    this.isSquadGroup = false,
  });

  @override
  State<InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends State<InviteMembersDialog>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _inviteCodeController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentContacts = [];
  bool _isLoading = false;
  late TabController _tabController;
  String? _inviteCode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentContacts();
    _generateInviteCode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _inviteCodeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentContacts() async {
    // Load recent interactions or friends list
    // For now, we'll load some sample contacts
    setState(() {
      _recentContacts = [
        {
          'uid': 'sample1',
          'displayName': 'Alex Chen',
          'profileImage': null,
          'lastSeen': '2 hours ago',
        },
        {
          'uid': 'sample2',
          'displayName': 'Sarah Johnson',
          'profileImage': null,
          'lastSeen': '1 day ago',
        },
        {
          'uid': 'sample3',
          'displayName': 'Mike Wilson',
          'profileImage': null,
          'lastSeen': '3 days ago',
        },
      ];
    });
  }

  Future<void> _generateInviteCode() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Generate a unique invite code
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final code =
          '${widget.chatGroupId.substring(0, 6)}${timestamp.toString().substring(timestamp.toString().length - 4)}';

      // Store the invite code in Firestore
      await FirebaseFirestore.instance
          .collection('chat_groups')
          .doc(widget.chatGroupId)
          .collection('invites')
          .doc(code)
          .set({
        'code': code,
        'createdBy': currentUser.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt':
            DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'maxUses': 50, // Allow up to 50 people to join
        'uses': 0,
      });

      setState(() {
        _inviteCode = code;
        _inviteCodeController.text = code;
      });
    } catch (e) {
      debugPrint('Error generating invite code: $e');
      if (mounted) {
        showSnackBar(context, 'Failed to generate invite code');
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userManager = Provider.of<UserManager>(context, listen: false);
      final results = await userManager.searchUsers(query);

      // Filter out users who are already in the group
      final squadState = Provider.of<SquadState>(context, listen: false);
      final existingMembers = squadState.squadMemberUids;

      final filteredResults = results.where((user) {
        return !existingMembers.contains(user['uid']);
      }).toList();

      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error searching users: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteUser(Map<String, dynamic> user) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Create an invitation notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user['uid'])
          .collection('notifications')
          .add({
        'type': 'group_invite',
        'fromUserId': currentUser.uid,
        'fromUserName': currentUser.displayName ?? 'Unknown',
        'groupId': widget.chatGroupId,
        'groupName': widget.chatGroupName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // pending, accepted, declined
      });

      if (mounted) {
        showSnackBar(context, 'Invitation sent to ${user['displayName']}');
      }
    } catch (e) {
      debugPrint('Error sending invitation: $e');
      if (mounted) {
        showSnackBar(context, 'Failed to send invitation');
      }
    }
  }

  Future<void> _shareInviteLink() async {
    if (_inviteCode == null) return;

    final inviteLink =
        'codsquadapp://join/${widget.chatGroupId}?code=$_inviteCode';
    final message =
        'Join "${widget.chatGroupName}" on SquadSync! Use code: $_inviteCode or tap: $inviteLink';

    try {
      await Share.share(message, subject: 'Join ${widget.chatGroupName}');
    } catch (e) {
      // Fallback to clipboard
      await Clipboard.setData(ClipboardData(text: message));
      if (mounted) {
        showSnackBar(context, 'Invite link copied to clipboard');
      }
    }
  }

  Future<void> _copyInviteCode() async {
    if (_inviteCode != null) {
      await Clipboard.setData(ClipboardData(text: _inviteCode!));
      if (mounted) {
        showSnackBar(context, 'Invite code copied: $_inviteCode');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    'Invite to ${widget.chatGroupName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Search', icon: Icon(Icons.search)),
                Tab(text: 'Contacts', icon: Icon(Icons.contacts)),
                Tab(text: 'Share', icon: Icon(Icons.share)),
              ],
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor:
                  Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),

            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Search Tab
                  _buildSearchTab(),

                  // Contacts Tab
                  _buildContactsTab(),

                  // Share Tab
                  _buildShareTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    return Column(
      children: [
        // Search Field
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: 'Search users by name or email...',
              hintStyle: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () => _searchUsers(_searchController.text.trim()),
              ),
            ),
            onSubmitted: _searchUsers,
          ),
        ),

        // Results
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty && _searchController.text.isNotEmpty
                  ? Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6)),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return _buildUserListTile(user, 'Invite');
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildContactsTab() {
    return _recentContacts.isEmpty
        ? Center(
            child: Text(
              'No recent contacts',
              style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6)),
            ),
          )
        : ListView.builder(
            itemCount: _recentContacts.length,
            itemBuilder: (context, index) {
              final contact = _recentContacts[index];
              return _buildUserListTile(contact, 'Invite');
            },
          );
  }

  Widget _buildShareTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // QR Code
          if (_inviteCode != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data:
                    'codsquadapp://join/${widget.chatGroupId}?code=$_inviteCode',
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),

          const SizedBox(height: 20),

          // Invite Code
          Text(
            'Invite Code',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _inviteCode ?? 'Generating...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copyInviteCode,
                  tooltip: 'Copy code',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Share Options
          Text(
            'Share Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _shareInviteLink,
            icon: const Icon(Icons.share),
            label: const Text('Share Invite Link'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _copyInviteCode,
            icon: const Icon(Icons.copy),
            label: const Text('Copy Invite Code'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to join:',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Share the invite code or QR code with friends\n'
                  '2. They can paste the code in the "Join Group" section\n'
                  '3. Or scan the QR code to join instantly\n'
                  '4. Invite expires in 7 days or after 50 uses',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserListTile(Map<String, dynamic> user, String actionText) {
    final displayName = user['displayName'] ?? 'Unknown';
    final profileImage = user['profileImage'];
    final lastSeen = user['lastSeen'];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            profileImage != null ? NetworkImage(profileImage) : null,
        child: profileImage == null
            ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
            : null,
      ),
      title: Text(displayName),
      subtitle: lastSeen != null ? Text('Last seen: $lastSeen') : null,
      trailing: ElevatedButton(
        onPressed: () => _inviteUser(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
        ),
        child: Text(actionText),
      ),
    );
  }
}
