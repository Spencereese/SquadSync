import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../squad_state.dart';
import 'chat_screen.dart';

class ChatGroupsScreen extends StatefulWidget {
  const ChatGroupsScreen({super.key});

  @override
  State<ChatGroupsScreen> createState() => _ChatGroupsScreenState();
}

class _ChatGroupsScreenState extends State<ChatGroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Removed automatic group opening to allow users to browse groups list
    // _checkLastChatGroup();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Groups'),
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.cyanAccent),
            onPressed: _createNewGroup,
            tooltip: 'Create new group',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black, Colors.indigo],
            stops: [0.0, 1.0],
          ),
        ),
        child: Consumer<SquadState>(
          builder: (context, squadState, child) {
            // Check if user is authenticated
            final currentUser = FirebaseAuth.instance.currentUser;
            if (currentUser == null) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }

            if (squadState.selectedSquadId == null) {
              return const Center(
                child: Text(
                  'No squad selected',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('squads')
                  .doc(squadState.selectedSquadId)
                  .collection('chat_groups')
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  );
                }

                final groups = snapshot.data?.docs ?? [];

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No chat groups yet',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first group to start chatting!',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _createNewGroup,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Group'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    final groupData = group.data() as Map<String, dynamic>;
                    final groupName = groupData['name'] ?? 'Unnamed Group';
                    final lastMessage = groupData['lastMessage'] ?? '';
                    final lastMessageTime =
                        groupData['lastMessageTime'] as Timestamp?;
                    final memberCount = groupData['memberCount'] ?? 0;
                    final isPublic = groupData['isPublic'] ?? false;
                    final createdBy = groupData['createdBy'];
                    final isOwner = createdBy == _auth.currentUser?.uid;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          backgroundColor:
                              isPublic ? Colors.green : Colors.cyanAccent,
                          child: Icon(
                            isPublic ? Icons.public : Icons.lock,
                            color: Colors.black,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                groupName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            if (isOwner)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Owner',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lastMessage.isNotEmpty)
                              Text(
                                lastMessage,
                                style: const TextStyle(color: Colors.grey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '$memberCount members',
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                                if (lastMessageTime != null) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTime(lastMessageTime.toDate()),
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        onTap: () => _openChatGroup(group.id, groupName),
                        onLongPress: () =>
                            _showGroupOptions(group.id, groupData),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _createNewGroup() {
    showDialog(
      context: context,
      builder: (context) => _CreateGroupDialog(
        onGroupCreated: (groupId, groupName) {
          Navigator.pop(context); // Close dialog
          _openChatGroup(groupId, groupName);
        },
      ),
    );
  }

  void _openChatGroup(String groupId, String groupName) async {
    // Check membership for private groups
    final squadState = Provider.of<SquadState>(context, listen: false);
    final groupDoc = await _firestore
        .collection('squads')
        .doc(squadState.selectedSquadId)
        .collection('chat_groups')
        .doc(groupId)
        .get();

    if (groupDoc.exists) {
      final groupData = groupDoc.data() as Map<String, dynamic>;
      final isPublic = groupData['isPublic'] ?? false;
      final members = List<String>.from(groupData['members'] ?? []);

      if (!isPublic && !members.contains(_auth.currentUser?.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('You are not a member of this private group')),
          );
        }
        return;
      }
    }

    // Save last opened chat group
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('last_chat_group', groupId);
    }).then((_) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatGroupId: groupId,
              chatGroupName: groupName,
            ),
          ),
        );
      }
    });
  }

  void _showGroupOptions(String groupId, Map<String, dynamic> groupData) {
    final createdBy = groupData['createdBy'];
    final isOwner = createdBy == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwner) ...[
            ListTile(
              leading: const Icon(Icons.settings, color: Colors.cyanAccent),
              title: const Text('Group Settings',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showGroupSettings(groupId, groupData);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Group',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteGroup(groupId);
              },
            ),
          ] else ...[
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.orange),
              title: const Text('Leave Group',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _leaveGroup(groupId, groupData);
              },
            ),
          ],
        ],
      ),
    );
  }

  void _leaveGroup(String groupId, Map<String, dynamic> groupData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final squadId =
        Provider.of<SquadState>(context, listen: false).selectedSquadId;
    if (squadId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Leave Group', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to leave this group?',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore
            .collection('squads')
            .doc(squadId)
            .collection('chat_groups')
            .doc(groupId)
            .update({
          'members': FieldValue.arrayRemove([user.uid]),
          'memberCount': FieldValue.increment(-1),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Left group successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error leaving group: $e')),
          );
        }
      }
    }
  }

  void _showGroupSettings(String groupId, Map<String, dynamic> groupData) {
    // TODO: Implement group settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group settings coming soon')),
    );
  }

  void _deleteGroup(String groupId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title:
            const Text('Delete Group', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this group? This action cannot be undone.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final squadId = Provider.of<SquadState>(context, listen: false)
                  .selectedSquadId;
              if (squadId == null) return;

              try {
                await _firestore
                    .collection('squads')
                    .doc(squadId)
                    .collection('chat_groups')
                    .doc(groupId)
                    .delete();

                // Also delete all messages in the group
                final messages = await _firestore
                    .collection('squads')
                    .doc(squadId)
                    .collection('chat_groups')
                    .doc(groupId)
                    .collection('messages')
                    .get();
                for (var message in messages.docs) {
                  await message.reference.delete();
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Group deleted')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting group: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}

class _CreateGroupDialog extends StatefulWidget {
  final Function(String, String) onGroupCreated;

  const _CreateGroupDialog({required this.onGroupCreated});

  @override
  State<_CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<_CreateGroupDialog> {
  final _nameController = TextEditingController();
  bool _isPublic = false;
  bool _isLoading = false;
  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text('Create Chat Group',
          style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Group name',
              hintStyle: TextStyle(color: Colors.grey),
            ),
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _pickGroupImage,
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyanAccent, width: 2),
              ),
              child: _selectedImage != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(_selectedImage!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.add_photo_alternate,
                      color: Colors.cyanAccent, size: 40),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap to select group image (optional)',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Public group:',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              Switch(
                value: _isPublic,
                onChanged: (value) => setState(() => _isPublic = value),
                activeColor: Colors.cyanAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isPublic
                ? 'Anyone in the app can join this group'
                : 'Only invited members can join this group',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createGroup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Create'),
        ),
      ],
    );
  }

  void _pickGroupImage() async {
    print('=== _pickGroupImage called ===');
    try {
      final picker = ImagePicker();
      print('=== About to call image picker ===');
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        print('=== Image picker returned: image selected ===');
        print('Image selected: ${pickedFile.path}');
        setState(() {
          _selectedImage = File(pickedFile.path);
        });

        // Upload the image immediately and store the URL
        final imageUrl = await _uploadImage();
        if (mounted) {
          setState(() {
            _uploadedImageUrl = imageUrl;
          });
        }
      } else {
        print('=== Image picker returned: no image selected ===');
      }
    } catch (e) {
      print('=== ERROR in _pickGroupImage: $e ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      // Check if file exists and is readable
      if (!await _selectedImage!.exists()) {
        print(
            'ERROR: Selected image file does not exist: ${_selectedImage!.path}');
        return null;
      }

      final fileSize = await _selectedImage!.length();
      print('File exists, size: $fileSize bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'group_${timestamp}.jpg';
      print('Starting upload for file: $fileName');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('chat_group_images')
          .child(fileName);

      print('Storage reference: ${storageRef.fullPath}'); // Debug log

      print('Starting upload task...'); // Debug log
      final uploadTask = storageRef.putFile(_selectedImage!);

      // Monitor upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        print(
            'Upload progress: ${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes');
      });

      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      print('Upload completed successfully. Download URL: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('Upload task error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading image: $e')),
        );
      }
      return null;
    }
  }

  void _createGroup() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final squadState = Provider.of<SquadState>(context, listen: false);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || squadState.selectedSquadId == null) return;

      // Upload image if selected (should already be uploaded in _pickGroupImage)
      String? imageUrl = _uploadedImageUrl;

      final groupId = FirebaseFirestore.instance
          .collection('squads')
          .doc(squadState.selectedSquadId)
          .collection('chat_groups')
          .doc()
          .id;

      final groupData = {
        'name': _nameController.text.trim(),
        'createdBy': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'isPublic': _isPublic,
        'memberCount': 1,
        'members': [user.uid],
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      };

      if (imageUrl != null) {
        groupData['imageUrl'] = imageUrl;
      }

      await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadState.selectedSquadId)
          .collection('chat_groups')
          .doc(groupId)
          .set(groupData);

      widget.onGroupCreated(groupId, _nameController.text.trim());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating group: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _GroupSettingsDialog extends StatefulWidget {
  final String groupId;
  final Map<String, dynamic> initialData;

  const _GroupSettingsDialog({
    required this.groupId,
    required this.initialData,
  });

  @override
  State<_GroupSettingsDialog> createState() => _GroupSettingsDialogState();
}

class _GroupSettingsDialogState extends State<_GroupSettingsDialog> {
  late bool _isPublic;
  late String _groupName;
  late bool _canModifySettings;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.initialData['isPublic'] ?? false;
    _groupName = widget.initialData['name'] ?? '';

    // Only the creator can modify privacy settings and group name
    final currentUser = FirebaseAuth.instance.currentUser;
    _canModifySettings = widget.initialData['createdBy'] == currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title:
          const Text('Group Settings', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: TextEditingController(text: _groupName),
            decoration: InputDecoration(
              hintText: 'Group name',
              hintStyle: const TextStyle(color: Colors.grey),
              enabled: _canModifySettings,
            ),
            style: const TextStyle(color: Colors.white),
            enabled: _canModifySettings,
            onChanged:
                _canModifySettings ? (value) => _groupName = value : null,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Public group:',
                  style: TextStyle(color: Colors.white)),
              const SizedBox(width: 8),
              Switch(
                value: _isPublic,
                onChanged: _canModifySettings
                    ? (value) => setState(() => _isPublic = value)
                    : null,
                activeColor: Colors.cyanAccent,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _canModifySettings
                ? (_isPublic
                    ? 'Anyone in the app can join this group'
                    : 'Only invited members can join this group')
                : 'Only the group creator can modify these settings',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saveSettings,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _saveSettings() async {
    if (!_canModifySettings) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Only the group creator can modify settings')),
        );
      }
      return;
    }

    try {
      final squadState = Provider.of<SquadState>(context, listen: false);

      await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadState.selectedSquadId)
          .collection('chat_groups')
          .doc(widget.groupId)
          .update({
        'name': _groupName,
        'isPublic': _isPublic,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }
}
