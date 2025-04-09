import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'squad_state.dart';
import 'setup_screen.dart';
import 'main.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  bool _preferGameMode = false;
  String? _preferredMode;
  String? _selectedPage;
  String? _severity;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _feedbackController = TextEditingController();
    _animationController =
        AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _fadeAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isDarkTheme = prefs.getBool('isDarkTheme') ?? true;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _soundsEnabled = prefs.getBool('soundsEnabled') ?? true;
      _preferGameMode = prefs.getBool('preferGameMode') ?? false;
      _preferredMode = prefs.getString('preferredMode');
    });
    _animationController.forward();
  }

  Future<void> _saveSettings(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is String?) await prefs.setString(key, value ?? '');
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('yourName');
    await prefs.remove('profileImageUrl');
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => SetupScreen()),
      (route) => false,
    );
  }

  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null || !mounted) return;
    File imageFile = File(pickedFile.path);
    String uid = FirebaseAuth.instance.currentUser!.uid;
    Reference storageRef =
        FirebaseStorage.instance.ref().child('profile_pics/$uid.jpg');
    await storageRef.putFile(imageFile);
    String downloadUrl = await storageRef.getDownloadURL();

    final squadState = Provider.of<SquadState>(context, listen: false);
    squadState.updateProfileImage(downloadUrl);
    await _saveSettings('profileImageUrl', downloadUrl);

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Profile picture updated!')));
    }
  }

  void _updateDisplayName(BuildContext context) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    if (_nameController.text.isNotEmpty && mounted) {
      squadState.updateDisplayName(_nameController.text);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Display name updated!')));
    }
  }

  Future<void> _submitFeedback(String type, String page, String content,
      {String? severity}) async {
    if (content.isEmpty || !mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a page and provide details')));
      return;
    }
    final packageInfo = await PackageInfo.fromPlatform();
    await FirebaseFirestore.instance.collection('feedback').add({
      'type': type,
      'page': page,
      'content': content,
      'severity': severity,
      'userId': FirebaseAuth.instance.currentUser!.uid,
      'appVersion': packageInfo.version,
      'timestamp': FieldValue.serverTimestamp(),
    });
    _feedbackController.clear();
    setState(() {
      _selectedPage = null;
      _severity = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$type submitted successfully!')));
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
                value: _selectedPage,
                decoration: InputDecoration(
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
                hint: Text('Select the page'),
                validator: (value) =>
                    value == null ? 'Please select a page' : null,
              ),
              SizedBox(height: 16),
              TextField(
                controller: _feedbackController,
                decoration: InputDecoration(
                  labelText: 'Details',
                  hintText: 'Describe your $type in detail',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
              if (isBug) ...[
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _severity,
                  decoration: InputDecoration(
                    labelText: 'Severity',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Low', 'Medium', 'High', 'Critical']
                      .map((severity) => DropdownMenuItem(
                          value: severity, child: Text(severity)))
                      .toList(),
                  onChanged: (value) => setState(() => _severity = value),
                  hint: Text('Select severity'),
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
            child: Text('Cancel'),
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
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showPreferredModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Preferred Game Mode'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Duo+'),
              onTap: () => _setPreferredMode('duos'),
            ),
            ListTile(
              title: Text('Trios+'),
              onTap: () => _setPreferredMode('trios'),
            ),
            ListTile(
              title: Text('Quads'),
              onTap: () => _setPreferredMode('quads'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _setPreferredMode(String mode) {
    setState(() {
      _preferredMode = mode;
      _preferGameMode = true;
    });
    _saveSettings('preferredMode', mode);
    _saveSettings('preferGameMode', true);
    final squadState = Provider.of<SquadState>(context, listen: false);
    squadState.updatePreferredMode(squadState.displayName ?? 'User', mode);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Settings'), elevation: 0),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            _buildSectionHeader('Profile'),
            GestureDetector(
              onTap: _updateProfilePicture,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: squadState.profileImage != null
                    ? NetworkImage(squadState.profileImage!)
                    : null,
                child: squadState.profileImage == null
                    ? Icon(Icons.person, size: 50, color: Colors.cyan)
                    : null,
              ),
            ),
            SizedBox(height: 10),
            Center(child: Text('Tap to change profile picture')),
            ListTile(
              leading: Icon(Icons.person, color: Colors.cyan),
              title: Text('Display Name'),
              subtitle: Text(squadState.displayName ?? 'User'),
              trailing: Icon(Icons.edit),
              onTap: () {
                _nameController.text = squadState.displayName ?? '';
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('Edit Display Name'),
                    content: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(hintText: 'Enter new name'),
                    ),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          _updateDisplayName(context);
                          Navigator.pop(context);
                        },
                        child: Text('Save'),
                      ),
                    ],
                  ),
                );
              },
            ),
            Divider(),
            _buildSectionHeader('Appearance'),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_isDarkTheme),
                activeColor: Colors.cyan,
                title: Text('Dark Theme'),
                value: _isDarkTheme,
                onChanged: (value) {
                  setState(() => _isDarkTheme = value);
                  _saveSettings('isDarkTheme', value);
                  Provider.of<ThemeProvider>(context, listen: false)
                      .toggleTheme(value);
                },
                secondary: Icon(Icons.brightness_6),
              ),
            ),
            Divider(),
            _buildSectionHeader('Notifications & Sounds'),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_notificationsEnabled),
                activeColor: Colors.cyan,
                title: Text('Notifications'),
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() => _notificationsEnabled = value);
                  _saveSettings('notificationsEnabled', value);
                  // TODO: Update notification_service.dart
                },
                secondary: Icon(Icons.notifications),
              ),
            ),
            AnimatedSwitcher(
              duration: Duration(milliseconds: 300),
              child: SwitchListTile(
                key: ValueKey(_soundsEnabled),
                activeColor: Colors.cyan,
                title: Text('Sounds'),
                value: _soundsEnabled,
                onChanged: (value) {
                  setState(() => _soundsEnabled = value);
                  _saveSettings('soundsEnabled', value);
                  // TODO: Update sound playback logic
                },
                secondary: Icon(Icons.volume_up),
              ),
            ),
            Divider(),
            _buildSectionHeader('Peacock Preferences'),
            SwitchListTile(
              activeColor: Colors.cyan,
              title: Text('Preferred Game Mode'),
              subtitle: Text(_preferredMode != null
                  ? 'Prefer $_preferredMode'
                  : 'Set preference for joining spots'),
              value: _preferGameMode,
              onChanged: (value) {
                setState(() {
                  _preferGameMode = value;
                  if (!value) _preferredMode = null;
                });
                _saveSettings('preferGameMode', value);
                if (value) {
                  _showPreferredModeDialog();
                } else {
                  _saveSettings('preferredMode', null);
                  final squadState =
                      Provider.of<SquadState>(context, listen: false);
                  squadState.updatePreferredMode(
                      squadState.displayName ?? 'User', null);
                }
              },
              secondary: Icon(Icons.group),
            ),
            Divider(),
            _buildSectionHeader('Feedback & Support'),
            ListTile(
              leading: Icon(Icons.bug_report, color: Colors.cyan),
              title: Text('Report a Bug'),
              onTap: () => _showFeedbackDialog('Bug Report'),
            ),
            ListTile(
              leading: Icon(Icons.lightbulb_outline, color: Colors.cyan),
              title: Text('Suggest a Feature'),
              onTap: () => _showFeedbackDialog('Feature Suggestion'),
            ),
            Divider(),
            _buildSectionHeader('Account'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.exit_to_app),
                label: Text('Logout'),
                onPressed: () => _logout(context),
              ),
            ),
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
        style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold, color: Colors.cyan),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feedbackController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}
