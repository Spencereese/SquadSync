import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'squad_state.dart';
import '../managers/user_manager.dart';
import '../chat/chat_state.dart';
import '../chat/chat_groups_screen.dart';
import 'package:flutter/services.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab>
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
  bool _profileVisible = true;
  bool _onlineStatusVisible = true;
  bool _allowMessagesFromAnyone = true;
  bool _dataSharingEnabled = false;
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
    if (!mounted) return;
    final squadState = Provider.of<SquadState>(context, listen: false);
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
      _tiltEnabled = prefs.getBool('tiltEnabled') ?? true; // Load tilt setting
      // Load privacy settings
      _profileVisible = prefs.getBool('profileVisible') ?? true;
      _onlineStatusVisible = prefs.getBool('onlineStatusVisible') ?? true;
      _allowMessagesFromAnyone =
          prefs.getBool('allowMessagesFromAnyone') ?? true;
      _dataSharingEnabled = prefs.getBool('dataSharingEnabled') ?? false;
    });
    squadState.updateTiltEnabled(_tiltEnabled); // Sync with SquadState
    _animationController.forward();
  }

  Future<void> _saveSettings(
      String key, dynamic value, SquadState squadState) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'tiltEnabled') {
        squadState.updateTiltEnabled(value); // Update SquadState
      }
    }
    if (value is String?) await prefs.setString(key, value ?? '');
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;
    final squadState = Provider.of<SquadState>(context, listen: false);
    File imageFile = File(pickedFile.path);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    Reference storageRef =
        FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    await storageRef.putFile(imageFile);
    String downloadUrl = await storageRef.getDownloadURL();
    squadState.updateProfileImage(downloadUrl);
    await _saveSettings('profileImageUrl', downloadUrl, squadState);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile picture updated!')),
      );
    }
  }

  void _updateDisplayName(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    if (_nameController.text.isNotEmpty && mounted) {
      squadState.updateDisplayName(_nameController.text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);

    return Scaffold(
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
                      activeColor: Colors.cyan,
                      title: const Text('Dark Theme',
                          style: TextStyle(color: Colors.white)),
                      value: _isDarkTheme,
                      onChanged: (value) {
                        setState(() => _isDarkTheme = value);
                        _saveSettings('isDarkTheme', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.brightness_6, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Enable Tab Tilt',
                          style: TextStyle(color: Colors.white)),
                      value: _tiltEnabled,
                      onChanged: (value) {
                        setState(() => _tiltEnabled = value);
                        _saveSettings('tiltEnabled', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.threed_rotation, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Notifications'),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Push Notifications',
                          style: TextStyle(color: Colors.white)),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSettings('notificationsEnabled', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.notifications, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Sound Effects',
                          style: TextStyle(color: Colors.white)),
                      value: _soundsEnabled,
                      onChanged: (value) {
                        setState(() => _soundsEnabled = value);
                        _saveSettings('soundsEnabled', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.volume_up, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Privacy'),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Public Profile',
                          style: TextStyle(color: Colors.white)),
                      value: _profileVisible,
                      onChanged: (value) {
                        setState(() => _profileVisible = value);
                        _saveSettings('profileVisible', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.visibility, color: Colors.cyan),
                    ),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Show Online Status',
                          style: TextStyle(color: Colors.white)),
                      value: _onlineStatusVisible,
                      onChanged: (value) {
                        setState(() => _onlineStatusVisible = value);
                        _saveSettings('onlineStatusVisible', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.access_time, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Circles'),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Allow Messages from Anyone',
                          style: TextStyle(color: Colors.white)),
                      value: _allowMessagesFromAnyone,
                      onChanged: (value) {
                        setState(() => _allowMessagesFromAnyone = value);
                        _saveSettings('allowMessagesFromAnyone', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary: const Icon(Icons.message, color: Colors.cyan),
                    ),
                    _buildSectionHeader('Theme'),
                    SwitchListTile(
                      activeColor: Colors.cyan,
                      title: const Text('Data Sharing',
                          style: TextStyle(color: Colors.white)),
                      value: _dataSharingEnabled,
                      onChanged: (value) {
                        setState(() => _dataSharingEnabled = value);
                        _saveSettings('dataSharingEnabled', value,
                            Provider.of<SquadState>(context, listen: false));
                      },
                      secondary:
                          const Icon(Icons.analytics, color: Colors.cyan),
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
              subtitle: Text(squadState.displayName ?? 'User',
                  style: TextStyle(color: Colors.grey)),
              trailing: const Icon(Icons.edit, color: Colors.cyan),
              onTap: () {
                _nameController.text = squadState.displayName ?? '';
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
                        onPressed: () {
                          _updateDisplayName(context);
                          Navigator.pop(context);
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
            // Filter friends based on search
            setState(() {
              // TODO: Implement filtering
            });
          },
        ),
        const SizedBox(height: 16),
        // Friends list
        Consumer<UserManager>(
          builder: (context, userManager, child) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: userManager.streamFriends(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Colors.cyanAccent));
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
          },
        ),
      ],
    );
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
        Consumer<UserManager>(
          builder: (context, userManager, child) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: userManager.streamPendingRequests(),
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
    final displayName = request['displayName'] ?? 'Unknown';
    final profileImage = request['profileImage'];

    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            profileImage != null ? NetworkImage(profileImage) : null,
        child: profileImage == null
            ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?')
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
            onPressed: () => _acceptFriendRequest(context, request['uid']),
            tooltip: 'Accept',
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () => _declineFriendRequest(context, request['uid']),
            tooltip: 'Decline',
          ),
        ],
      ),
    );
  }

  void _startDMWithFriend(BuildContext context, String friendId) async {
    final userManager = Provider.of<UserManager>(context, listen: false);
    final chatId = await userManager.startDMThread(friendId);
    if (chatId != null && mounted) {
      // Navigate to Chat tab with DM filter
      final chatState = Provider.of<ChatState>(context, listen: false);
      chatState.setDMView(true);
      // ignore: use_build_context_synchronously
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
    final userManager = Provider.of<UserManager>(context, listen: false);
    await userManager.removeFriend(friendId);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend removed')),
    );
  }

  void _acceptFriendRequest(BuildContext context, String requesterId) async {
    final userManager = Provider.of<UserManager>(context, listen: false);
    await userManager.acceptFriendRequest(requesterId);
    HapticFeedback.lightImpact();
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request accepted')),
    );
  }

  void _declineFriendRequest(BuildContext context, String requesterId) async {
    final userManager = Provider.of<UserManager>(context, listen: false);
    await userManager.declineFriendRequest(requesterId);
    // ignore: use_build_context_synchronously
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Friend request declined')),
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
