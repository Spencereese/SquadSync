import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'squad_state.dart';
import 'firebase_storage_test.dart';
import 'chat/poll_history_screen.dart';
import 'chat/media_history_screen.dart';
import 'chat/pinned_messages_screen.dart';
import 'services/ai_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab>
    with SingleTickerProviderStateMixin {
  late TextEditingController _nameController;
  late TextEditingController _feedbackController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isDarkTheme = true;
  bool _notificationsEnabled = true;
  bool _soundsEnabled = true;
  bool _tiltEnabled = true; // New tilt toggle
  bool _preferGameMode = false;
  String? _preferredMode;
  String? _selectedPage;
  String? _severity;
  // Privacy settings
  bool _profileVisible = true;
  bool _onlineStatusVisible = true;
  bool _allowMessagesFromAnyone = true;
  bool _dataSharingEnabled = false;
  late TextEditingController _blockUserController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _feedbackController = TextEditingController();
    _blockUserController = TextEditingController();
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
      _preferGameMode = prefs.getBool('preferGameMode') ?? false;
      _preferredMode = prefs.getString('preferredMode');
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

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImageUrl');
    await FirebaseAuth.instance.signOut();
    // Navigation will be handled automatically by the StreamBuilder in main.dart
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

  Future<void> _submitFeedback(String type, String page, String content,
      {String? severity}) async {
    if (content.isEmpty || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a page and provide details')),
      );
      return;
    }

    final squadState = Provider.of<SquadState>(context, listen: false);
    await squadState.userManager.submitFeedback(
      type: type,
      page: page,
      content: content,
      severity: severity ?? 'medium',
    );

    _feedbackController.clear();
    setState(() {
      _selectedPage = null;
      _severity = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$type submitted successfully!')),
      );
    }
  }

  void _showFeedbackDialog(String type) {
    bool isBug = type == 'Bug Report';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submit $type'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _selectedPage,
                decoration: const InputDecoration(
                  labelText: 'Page',
                  border: OutlineInputBorder(),
                ),
                items: [
                  'Squad Queue',
                  'Availability',
                  'Squad',
                  'Chat',
                  'Settings',
                  'Other',
                ]
                    .map((page) =>
                        DropdownMenuItem(value: page, child: Text(page)))
                    .toList(),
                onChanged: (value) => setState(() => _selectedPage = value),
                hint: const Text('Select the page'),
                validator: (value) =>
                    value == null ? 'Please select a page' : null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'Describe your $type in detail',
                  border: const OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              if (isBug) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _severity,
                  decoration: const InputDecoration(
                    labelText: 'Severity',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map((severity) => DropdownMenuItem(
                          value: severity, child: Text(severity)))
                      .toList(),
                  onChanged: (value) => setState(() => _severity = value),
                  hint: const Text('Select severity'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _feedbackController.clear();
              setState(() {
                _selectedPage = null;
                _severity = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _submitFeedback(
                type,
                _selectedPage ?? '',
                _feedbackController.text,
                severity: isBug ? _severity : null,
              );
              Navigator.pop(context);
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showPreferredModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Preferred Game Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Duo+'),
              onTap: () => _setPreferredMode('duos'),
            ),
            ListTile(
              title: const Text('Trios+'),
              onTap: () => _setPreferredMode('trios'),
            ),
            ListTile(
              title: const Text('Quads'),
              onTap: () => _setPreferredMode('quads'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _setPreferredMode(String mode) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    setState(() {
      _preferredMode = mode;
      _preferGameMode = true;
    });
    _saveSettings('preferredMode', mode, squadState);
    _saveSettings('preferGameMode', true, squadState);
    squadState.updatePreferredMode(squadState.displayName, mode);
    Navigator.pop(context);
  }

  void _showBlockedUsersDialog(BuildContext context, SquadState squadState) {
    final blockedUsers = squadState.getBlockedUsers;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Blocked Users'),
        content: SizedBox(
          width: double.maxFinite,
          child: blockedUsers.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      'No blocked users',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = blockedUsers[index];
                    return ListTile(
                      leading:
                          const Icon(Icons.person, color: Colors.redAccent),
                      title: Text(user),
                      subtitle:
                          const Text('Blocked - mutual visibility hidden'),
                      trailing: TextButton(
                        onPressed: () {
                          squadState.unblockUser(user);
                          // Refresh the dialog by popping and showing again
                          Navigator.pop(dialogContext);
                          _showBlockedUsersDialog(context, squadState);
                        },
                        child: const Text('Unblock'),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showBlockUserDialog(BuildContext context, SquadState squadState) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Block User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _blockUserController,
              decoration: const InputDecoration(
                labelText: 'Username',
                hintText: 'Enter the username to block',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Blocking a user will hide their messages and prevent them from seeing your activity.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _blockUserController.clear();
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final username = _blockUserController.text.trim();
              if (username.isNotEmpty) {
                squadState.blockUser(username);
                _blockUserController.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$username has been blocked')),
                );
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  void _showFirebaseStorageTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FirebaseStorageTestWidget(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 0),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG: 8 SETTINGS',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            _buildSectionHeader('Profile'),
            GestureDetector(
              onTap: _updateProfilePicture,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: squadState.profileImage != null
                    ? NetworkImage(squadState.profileImage!)
                    : null,
                child: squadState.profileImage == null
                    ? const Icon(Icons.person, size: 50, color: Colors.cyan)
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            const Center(child: Text('Tap to change profile picture')),
            ListTile(
              leading: const Icon(Icons.person, color: Colors.cyan),
              title: const Text('Display Name'),
              subtitle: Text(squadState.displayName),
              trailing: const Icon(Icons.edit),
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
            const Divider(),
            _buildSectionHeader('Appearance'),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_isDarkTheme),
                activeThumbColor: Colors.cyan,
                title: const Text('Dark Theme'),
                value: _isDarkTheme,
                onChanged: (value) {
                  setState(() => _isDarkTheme = value);
                  _saveSettings('isDarkTheme', value, squadState);
                  // Note: No ThemeProvider, app must handle theme elsewhere
                },
                secondary: const Icon(Icons.brightness_6),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_tiltEnabled),
                activeThumbColor: Colors.cyan,
                title: const Text('Enable Tab Tilt'),
                value: _tiltEnabled,
                onChanged: (value) {
                  setState(() => _tiltEnabled = value);
                  _saveSettings('tiltEnabled', value, squadState);
                },
                secondary: const Icon(Icons.threed_rotation),
              ),
            ),
            const Divider(),
            _buildSectionHeader('Notifications & Sounds'),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_notificationsEnabled),
                activeThumbColor: Colors.cyan,
                title: const Text('Notifications'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSettings('notificationsEnabled', value, squadState);
                  // TODO: Update notification_service.dart
                },
                secondary: const Icon(Icons.notifications),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_soundsEnabled),
                activeThumbColor: Colors.cyan,
                title: const Text('Sounds'),
                value: _soundsEnabled,
                onChanged: (value) {
                  setState(() => _soundsEnabled = value);
                  _saveSettings('soundsEnabled', value, squadState);
                  // TODO: Update sound playback logic
                },
                secondary: const Icon(Icons.volume_up),
              ),
            ),
            const Divider(),
            _buildSectionHeader('Peacock Preferences'),
            SwitchListTile(
              activeThumbColor: Colors.cyan,
              title: const Text('Preferred Game Mode'),
              subtitle: Text(_preferredMode != null
                  ? 'Prefer $_preferredMode'
                  : 'Set preference for joining spots'),
              value: _preferGameMode,
              onChanged: (value) {
                setState(() {
                  _preferGameMode = value;
                  if (!value) _preferredMode = null;
                });
                _saveSettings('preferGameMode', value, squadState);
                if (value) {
                  _showPreferredModeDialog();
                } else {
                  _saveSettings('preferredMode', '', squadState);
                  squadState.updatePreferredMode(squadState.displayName, '');
                }
              },
              secondary: const Icon(Icons.group),
            ),
            const Divider(),
            _buildSectionHeader('Privacy'),
            SwitchListTile(
              activeThumbColor: Colors.cyan,
              title: const Text('Profile Visibility'),
              subtitle: const Text('Allow others to see your profile'),
              value: _profileVisible,
              onChanged: (value) {
                setState(() => _profileVisible = value);
                _saveSettings('profileVisible', value, squadState);
              },
              secondary: const Icon(Icons.visibility),
            ),
            SwitchListTile(
              activeThumbColor: Colors.cyan,
              title: const Text('Online Status'),
              subtitle: const Text('Show when you\'re online'),
              value: _onlineStatusVisible,
              onChanged: (value) {
                setState(() => _onlineStatusVisible = value);
                _saveSettings('onlineStatusVisible', value, squadState);
              },
              secondary: const Icon(Icons.circle),
            ),
            SwitchListTile(
              activeThumbColor: Colors.cyan,
              title: const Text('Allow Messages from Anyone'),
              subtitle: const Text('Receive messages from non-friends'),
              value: _allowMessagesFromAnyone,
              onChanged: (value) {
                setState(() => _allowMessagesFromAnyone = value);
                _saveSettings('allowMessagesFromAnyone', value, squadState);
              },
              secondary: const Icon(Icons.message),
            ),
            SwitchListTile(
              activeThumbColor: Colors.cyan,
              title: const Text('Data Sharing'),
              subtitle: const Text('Share usage data for improvements'),
              value: _dataSharingEnabled,
              onChanged: (value) {
                setState(() => _dataSharingEnabled = value);
                _saveSettings('dataSharingEnabled', value, squadState);
              },
              secondary: const Icon(Icons.analytics),
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.cyan),
              title: const Text('Blocked Users'),
              subtitle: Text('${squadState.getBlockedUsers.length} blocked'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showBlockedUsersDialog(context, squadState),
            ),
            ListTile(
              leading:
                  const Icon(Icons.person_add_disabled, color: Colors.cyan),
              title: const Text('Block User'),
              subtitle: const Text('Enter username to block'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _showBlockUserDialog(context, squadState),
            ),
            const Divider(),
            _buildSectionHeader('Chat History'),
            ListTile(
              leading: const Icon(Icons.poll, color: Colors.cyan),
              title: const Text('Poll History'),
              subtitle: const Text('View and manage past polls'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _navigateToHistoryScreen(PollHistoryScreen(
                chatGroupId: squadState.selectedSquadId,
                chatType: ChatType.dm,
              )),
            ),
            ListTile(
              leading: const Icon(Icons.perm_media, color: Colors.cyan),
              title: const Text('Media History'),
              subtitle: const Text('View images, videos, and audio'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _navigateToHistoryScreen(MediaHistoryScreen(
                chatGroupId: squadState.selectedSquadId,
                chatType: ChatType.dm,
              )),
            ),
            ListTile(
              leading: const Icon(Icons.push_pin, color: Colors.cyan),
              title: const Text('Pinned Messages'),
              subtitle: const Text('View and manage pinned messages'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _navigateToHistoryScreen(PinnedMessagesScreen(
                chatGroupId: squadState.selectedSquadId,
                chatType: ChatType.dm,
              )),
            ),
            const Divider(),
            _buildSectionHeader('Feedback & Support'),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.cyan),
              title: const Text('Report a Bug'),
              onTap: () => _showFeedbackDialog('Bug Report'),
            ),
            ListTile(
              leading: const Icon(Icons.lightbulb_outline, color: Colors.cyan),
              title: const Text('Suggest a Feature'),
              onTap: () => _showFeedbackDialog('Feature Suggestion'),
            ),
            ListTile(
              leading: const Icon(Icons.storage, color: Colors.cyan),
              title: const Text('Test Firebase Storage'),
              subtitle: const Text('Debug image upload functionality'),
              onTap: () => _showFirebaseStorageTest(),
            ),
            const Divider(),
            _buildSectionHeader('Account'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Logout'),
                onPressed: () => _logout(context),
              ),
            ),
            const SizedBox(height: 80.0),
          ],
        ),
      ),
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

  void _navigateToHistoryScreen(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => screen),
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
