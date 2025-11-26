import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart' as p;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../chat/chat_state.dart';
import '../chat/chat_groups_screen.dart';
import 'package:flutter/services.dart';
import 'presentation/notifiers/user_notifier.dart';
import 'presentation/notifiers/squad_notifier.dart' as sn;
import 'domain/entities/squad_state.dart';

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _feedbackController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isDarkTheme = true;
  bool _notificationsEnabled = true;
  bool _soundsEnabled = true;
  bool _tiltEnabled = true; // New tilt toggle
  // Privacy settings
  bool _onlineStatusVisible = true;
  late TextEditingController _blockUserController;
  // Friends section
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _feedbackController = TextEditingController();
    _blockUserController = TextEditingController();
    _searchController = TextEditingController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!context.mounted) return;
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
      _tiltEnabled = prefs.getBool('tiltEnabled') ?? true; // Load tilt setting
      // Load privacy settings
      _onlineStatusVisible = prefs.getBool('onlineStatusVisible') ?? true;
    });
    ref
        .read(sn.squadNotifierProvider.notifier)
        .updateTiltEnabled(_tiltEnabled); // Sync with SquadState
    _animationController.forward();
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'tiltEnabled') {
        ref
            .read(sn.squadNotifierProvider.notifier)
            .updateTiltEnabled(value); // Update SquadState
      }
    }
    if (value is String?) await prefs.setString(key, value ?? '');
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !context.mounted) return;
    File imageFile = File(pickedFile.path);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    Reference storageRef =
        FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    await storageRef.putFile(imageFile);
    String downloadUrl = await storageRef.getDownloadURL();
    // Update both local state and persist to Firebase
    ref.read(sn.squadNotifierProvider.notifier).updateProfileImage(downloadUrl);
    await ref
        .read(userNotifierProvider.notifier)
        .updateProfileImage(downloadUrl);
    await _saveSettings('profileImageUrl', downloadUrl);

    if (!context.mounted) return;
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated!')),
    );
  }

  Future<void> _updateDisplayName() async {
    if (_nameController.text.isNotEmpty && context.mounted) {
      try {
        // Update both local state and persist to Firebase
        ref
            .read(sn.squadNotifierProvider.notifier)
            .updateDisplayName(_nameController.text);
        await ref
            .read(userNotifierProvider.notifier)
            .updateDisplayName(_nameController.text);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Display name updated!')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update display name: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(sn.squadNotifierProvider);

    return squadAsync.when(
      data: (squadState) => Scaffold(
        appBar: AppBar(
          title: const Text('Profile'),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => _showSettingsSheet(context),
              tooltip: 'Settings',
            ),
          ],
        ),
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildProfileCard(squadState),
              const SizedBox(height: 24),
              _buildFriendsSection(),
              const SizedBox(height: 24),
              _buildPendingRequestsSection(),
            ],
          ),
        ),
      ),
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Error: $error')),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
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
                      'Settings',
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
              // Settings content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionHeader('Appearance'),
                    SwitchListTile(
                      activeThumbColor: Colors.cyan,
                      title: const Text('Dark Theme',
                          style: TextStyle(color: Colors.white)),
                      value: _isDarkTheme,
                      onChanged: (value) {
                        setState(() => _isDarkTheme = value);
                        _saveSettings('isDarkTheme', value);
                      },
                      secondary:
                          const Icon(Icons.brightness_6, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeThumbColor: Colors.cyan,
                      title: const Text('Enable Tab Tilt',
                          style: TextStyle(color: Colors.white)),
                      value: _tiltEnabled,
                      onChanged: (value) {
                        setState(() => _tiltEnabled = value);
                        _saveSettings('tiltEnabled', value);
                      },
                      secondary:
                          const Icon(Icons.threed_rotation, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Notifications'),
                    SwitchListTile(
                      activeThumbColor: Colors.cyan,
                      title: const Text('Push Notifications',
                          style: TextStyle(color: Colors.white)),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSettings('notificationsEnabled', value);
                      },
                      secondary:
                          const Icon(Icons.notifications, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeThumbColor: Colors.cyan,
                      title: const Text('Sound Effects',
                          style: TextStyle(color: Colors.white)),
                      value: _soundsEnabled,
                      onChanged: (value) {
                        setState(() => _soundsEnabled = value);
                        _saveSettings('soundsEnabled', value);
                      },
                      secondary:
                          const Icon(Icons.volume_up, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeThumbColor: Colors.cyan,
                      title: const Text('Show Online Status',
                          style: TextStyle(color: Colors.white)),
                      value: _onlineStatusVisible,
                      onChanged: (value) {
                        setState(() => _onlineStatusVisible = value);
                        _saveSettings('onlineStatusVisible', value);
                      },
                      secondary:
                          const Icon(Icons.access_time, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Data & Privacy'),
                    ListTile(
                      leading: const Icon(Icons.storage, color: Colors.cyan),
                      title: const Text('Clear Cache',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Free up storage space',
                          style: TextStyle(color: Colors.grey)),
                      onTap: () => _clearCache(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.feedback, color: Colors.cyan),
                      title: const Text('Send Feedback',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Help us improve the app',
                          style: TextStyle(color: Colors.grey)),
                      onTap: () => _showFeedbackDialog(context),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info, color: Colors.cyan),
                      title: const Text('About',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('App version and info',
                          style: TextStyle(color: Colors.grey)),
                      onTap: () => _showAboutDialog(context),
                    ),
                    _buildSectionHeader('Account'),
                    ListTile(
                      leading:
                          const Icon(Icons.logout, color: Colors.redAccent),
                      title: const Text('Sign Out',
                          style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Sign out of your account',
                          style: TextStyle(color: Colors.grey)),
                      onTap: () => _signOut(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard(SquadState squadState) {
    return Card(
      color: Colors.grey[900],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Your Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _updateProfilePicture,
              child: CircleAvatar(
                radius: 40,
                backgroundImage: squadState.profileImage != null
                    ? NetworkImage(squadState.profileImage!)
                    : null,
                child: squadState.profileImage == null
                    ? const Icon(Icons.person, size: 40, color: Colors.cyan)
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to change profile picture',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.cyan),
              title: const Text('Display Name',
                  style: TextStyle(color: Colors.white)),
              subtitle: Text(squadState.displayName,
                  style: TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.edit, color: Colors.cyan),
              onTap: () {
                _nameController.text = squadState.displayName;
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Edit Display Name'),
                    content: TextField(
                      controller: _nameController,
                      decoration:
                          const InputDecoration(hintText: 'Enter new name'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          await _updateDisplayName();
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Add Peacock status if active
            // TODO: Add peacock status when selectedPeacockId is available
            // if (squadState.selectedPeacockId != null)
            //   ListTile(
            //     leading: const Icon(Icons.flag, color: Colors.cyan),
            //     title: const Text('Active Alert', style: TextStyle(color: Colors.white)),
            //     subtitle: Text('Peacock: ${squadState.selectedPeacockId}', style: TextStyle(color: Colors.grey)),
            //   ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Friends',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        // Search bar
        TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search friends...',
            hintStyle: TextStyle(color: Colors.grey[400]),
            filled: true,
            fillColor: Colors.grey[800],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
          ),
          onChanged: (value) {
            setState(() {
              // Trigger rebuild to show search results
            });
          },
        ),
        const SizedBox(height: 16),
        // Friends list or search results
        Consumer(
          builder: (context, ref, child) {
            final searchQuery = _searchController.text.trim();

            if (searchQuery.isNotEmpty) {
              // Show search results
              return FutureBuilder<List<Map<String, dynamic>>>(
                future: ref
                    .read(userNotifierProvider.notifier)
                    .searchUsers(searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.cyanAccent));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error searching users: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final searchResults = snapshot.data ?? [];

                  if (searchResults.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      child: const Column(
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return _buildUserSearchTile(context, user);
                    },
                  );
                },
              );
            } else {
              // Show friends list
              return StreamBuilder<List<Map<String, dynamic>>>(
                stream:
                    ref.watch(userNotifierProvider.notifier).streamFriends(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Colors.cyanAccent));
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading friends: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  }

                  final friends = snapshot.data ?? [];

                  if (friends.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      child: const Column(
                        children: [
                          Icon(Icons.people, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No friends yet—add via DMs tab!',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return _buildFriendTile(context, friend);
                    },
                  );
                },
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildUserSearchTile(BuildContext context, Map<String, dynamic> user) {
    final displayName = user['displayName'] ?? 'Unknown';
    final profileImage = user['profileImage'];
    final isOnline = user['isOnline'] ?? false;

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                : null,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(displayName, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(color: isOnline ? Colors.green : Colors.grey),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.person_add, color: Colors.cyan),
        onPressed: () => _sendFriendRequest(context, user['uid'], displayName),
        tooltip: 'Add Friend',
      ),
    );
  }

  void _sendFriendRequest(
      BuildContext context, String userId, String displayName) async {
    try {
      await ref.read(userNotifierProvider.notifier).sendFriendRequest(userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Friend Request Sent!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Request sent to $displayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: Colors.white,
              onPressed: () {
                // TODO: Implement undo functionality if needed
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Failed to Send Request',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Could not send request to $displayName',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 230),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Widget _buildFriendTile(BuildContext context, Map<String, dynamic> friend) {
    final displayName = friend['displayName'] ?? 'Unknown';
    final isOnline = friend['isOnline'] ?? false;
    final profileImage = friend['profileImage'];

    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                : null,
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(displayName, style: const TextStyle(color: Colors.white)),
      subtitle: Text(
        isOnline ? 'Online' : 'Offline',
        style: TextStyle(color: isOnline ? Colors.green : Colors.grey),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.message, color: Colors.cyan),
            onPressed: () => _startDMWithFriend(context, friend['uid']),
            tooltip: 'DM',
          ),
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.cyan),
            onPressed: () => _sendAlertToFriend(context, friend['uid']),
            tooltip: 'Alert',
          ),
          IconButton(
            icon: const Icon(Icons.person_remove, color: Colors.red),
            onPressed: () => _removeFriend(context, friend['uid']),
            tooltip: 'Remove',
          ),
        ],
      ),
    );
  }

  Widget _buildPendingRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pending Requests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Consumer(
          builder: (context, ref, child) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref
                  .watch(userNotifierProvider.notifier)
                  .streamPendingRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading requests: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                final requests = snapshot.data ?? [];

                if (requests.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: const Text(
                      'No pending requests',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    final request = requests[index];
                    return _buildPendingRequestTile(context, request);
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildPendingRequestTile(
      BuildContext context, Map<String, dynamic> request) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: ref
          .read(userNotifierProvider.notifier)
          .getCachedSenderDetails(request['senderId']),
      builder: (context, snapshot) {
        final displayName = snapshot.data?['displayName'] ?? 'Unknown';
        final profileImage = snapshot.data?['profileImage'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage:
                profileImage != null ? NetworkImage(profileImage) : null,
            child: profileImage == null
                ? Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
                : null,
          ),
          title: Text(displayName, style: const TextStyle(color: Colors.white)),
          subtitle: const Text('Wants to be friends',
              style: TextStyle(color: Colors.grey)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.check, color: Colors.green),
                onPressed: request['senderId'] != null
                    ? () => _acceptFriendRequest(context, request['senderId'])
                    : null,
                tooltip: 'Accept',
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red),
                onPressed: request['senderId'] != null
                    ? () => _declineFriendRequest(context, request['senderId'])
                    : null,
                tooltip: 'Decline',
              ),
            ],
          ),
        );
      },
    );
  }

  void _startDMWithFriend(BuildContext context, String friendId) async {
    final chatId = // ignore: unused_local_variable
        await ref.read(userNotifierProvider.notifier).startDMThread(friendId);
    if (context.mounted) {
      // Navigate to Chat tab with DM filter
      final chatState = p.Provider.of<ChatState>(context, listen: false);
      chatState.setDMView(true);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatGroupsScreen(),
        ),
      );
    }
  }

  void _sendAlertToFriend(BuildContext context, String friendId) {
    // TODO: Implement alert sending
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Alert feature coming soon!')),
    );
  }

  void _removeFriend(BuildContext context, String friendId) async {
    await ref.read(userNotifierProvider.notifier).removeFriend(friendId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend removed')),
    );
  }

  void _acceptFriendRequest(BuildContext context, String requesterId) async {
    await ref
        .read(userNotifierProvider.notifier)
        .acceptFriendRequest(requesterId);
    if (!context.mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request accepted')),
    );
  }

  void _declineFriendRequest(BuildContext context, String requesterId) async {
    await ref
        .read(userNotifierProvider.notifier)
        .declineFriendRequest(requesterId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request declined')),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Sign Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Reset SquadState before signing out to prevent state persistence
      ref.read(sn.squadNotifierProvider.notifier).reset();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profileImageUrl');
      await FirebaseAuth.instance.signOut();
      // Navigation will be handled automatically by the StreamBuilder in main.dart
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Clear Cache', style: TextStyle(color: Colors.white)),
        content: const Text('This will clear cached images and data. Continue?',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear image cache
        // Note: In a real app, you'd clear more cache types
        final prefs = await SharedPreferences.getInstance();
        // Clear any cached data we store
        await prefs.remove('cached_user_data');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cache cleared successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to clear cache: $e')),
          );
        }
      }
    }
  }

  void _showFeedbackDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Send Feedback', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _feedbackController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Tell us what you think...',
                hintStyle: TextStyle(color: Colors.grey),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.cyan)),
          ),
          TextButton(
            onPressed: () {
              // TODO: Implement actual feedback sending
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Send', style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'SquadSync',
      applicationVersion: '1.0.0',
      applicationIcon: const Icon(Icons.games, color: Colors.cyan, size: 48),
      applicationLegalese: '© 2025 SquadSync Team',
      children: [
        const SizedBox(height: 16),
        const Text(
          'SquadSync is a gaming squad management app that helps you coordinate with your gaming friends and manage squad activities.',
          style: TextStyle(color: Colors.white),
        ),
        const SizedBox(height: 16),
        const Text(
          'Features include:\n'
          '• Real-time chat with groups and DMs\n'
          '• Squad lobby management\n'
          '• Friend system\n'
          '• Game integration\n'
          '• Push notifications',
          style: TextStyle(color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.cyan,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feedbackController.dispose();
    _blockUserController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
