import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../squad_state.dart';
import 'chat_screen.dart';
import 'chat_state.dart';
import '../managers/user_manager.dart';
import '../profile_tab.dart';
import '../app_theme.dart';

class ChatGroupsScreen extends StatefulWidget {
  const ChatGroupsScreen({super.key});

  @override
  State<ChatGroupsScreen> createState() => _ChatGroupsScreenState();
}

class _ChatGroupsScreenState extends State<ChatGroupsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late PageController _pageController;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  double _navOpacity = 0.9;
  bool _isScrollingDown = false;
  double _navBottomOffset = 0.0;
  double _lastKeyboardHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _checkLastChatGroup();
    _pageController = PageController(initialPage: _selectedIndexNotifier.value);
    _pageController.addListener(_handlePageChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Monitor keyboard height changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      if (keyboardHeight != _lastKeyboardHeight) {
        setState(() {
          if (keyboardHeight > 0) {
            _navBottomOffset = -75.0;
            _navOpacity = 0.0;
          } else {
            _navBottomOffset = 0.0;
            _navOpacity = 0.9;
          }
          _lastKeyboardHeight = keyboardHeight;
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _handlePageChange() {
    int newIndex =
        _pageController.page?.round() ?? _selectedIndexNotifier.value;
    if (newIndex != _selectedIndexNotifier.value) {
      _selectedIndexNotifier.value = newIndex;
      HapticFeedback.lightImpact();
      _clearNotification(newIndex);
    }
  }

  void _onTabTapped(int index) {
    if (index != _selectedIndexNotifier.value) {
      _selectedIndexNotifier.value = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutSine,
      );
      HapticFeedback.lightImpact();
      _clearNotification(index);
    }
  }

  void _clearNotification(int index) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    squadState.clearNotifications(index);
  }

  bool _updateNavOpacity(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      setState(() {
        if (delta > 10 && !_isScrollingDown) {
          _isScrollingDown = true;
          _navOpacity = 0.6;
        } else if (delta <= 0 && _isScrollingDown) {
          _isScrollingDown = false;
          _navOpacity = 0.9;
        }
      });
    } else if (notification is ScrollEndNotification) {
      setState(() {
        _isScrollingDown = false;
        _navOpacity = 0.9;
      });
    }
    return true;
  }

  Widget _buildTabItem(int index, int selectedIndex, SquadState squadState) {
    bool isSelected = selectedIndex == index;
    final tabs = [
      'assets/images/chat.png',
      Icons.notifications,
      Icons.menu,
    ];
    bool hasNotification =
        !isSelected && (index == 0 && squadState.hasUnreadMessages);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.only(top: 12, bottom: 16),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                if (tabs[index] is String)
                  Image.asset(
                    tabs[index] as String,
                    width: 28,
                    height: 28,
                    color: isSelected
                        ? AppTheme.accentColor
                        : Colors.white.withValues(alpha: 0.7),
                  )
                else
                  Icon(
                    tabs[index] as IconData,
                    size: 28,
                    color: isSelected
                        ? AppTheme.accentColor
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                if (index == 2)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (index == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Chats',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                if (index == 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Alerts',
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.accentColor
                            : Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
            if (hasNotification)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context, bool isKeyboardVisible) {
    return [
      AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(bottom: isKeyboardVisible ? 0 : 75),
        child: _buildChatGroupsPage(),
      ),
      const NotificationsScreen(),
      const ProfileTab(),
    ];
  }

  Widget _buildChatGroupsPage() {
    return Consumer<ChatState>(
      builder: (context, chatState, child) => Scaffold(
        appBar: AppBar(
          title: Text(chatState.isDMView ? 'DMs' : 'Chats'),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: chatState.isDMView
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                  onPressed: () => chatState.setDMView(false),
                  tooltip: 'Back to all chats',
                )
              : null,
          actions: [
            if (chatState.isDMView)
              IconButton(
                icon: const Icon(Icons.person_add, color: Colors.cyanAccent),
                onPressed: _showAddFriendDialog,
                tooltip: 'Add friend',
              )
            else
              IconButton(
                icon: const Icon(Icons.add, color: Colors.cyanAccent),
                onPressed: _createNewGroup,
                tooltip: 'Create new group',
              ),
          ],
        ),
        body: Container(
          color: Colors.black,
          child: Column(
            children: [
              Expanded(
                child: Consumer<SquadState>(
                  builder: (context, squadState, child) {
                    // Check if user is authenticated
                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser == null) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: Colors.cyanAccent),
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

                    return Consumer<ChatState>(
                      builder: (context, chatState, child) {
                        if (chatState.isDMView) {
                          // Show DMs
                          return _buildDMList(context, squadState, currentUser);
                        } else {
                          // Show groups with DM card
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

                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.cyanAccent),
                                );
                              }

                              return _buildGroupsList(
                                  context, squadState, currentUser, snapshot);
                            },
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Show loading screen while initializing or loading initial data
    if (!squadState.isInitialized || !squadState.isInitialDataLoaded) {
      return Theme(
        data: AppTheme.darkTheme,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.cyanAccent),
                const SizedBox(height: 24),
                Text(
                  'Loading your squad...',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black,
                    AppTheme.primaryColor,
                    AppTheme.accentColor.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _updateNavOpacity,
                child: PageView(
                  controller: _pageController,
                  physics: const ClampingScrollPhysics(),
                  children: _buildPages(context, isKeyboardVisible),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              left: 0,
              right: 0,
              bottom: _navBottomOffset,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                opacity: _navOpacity,
                child: Container(
                  height: 75,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<int>(
                    valueListenable: _selectedIndexNotifier,
                    builder: (context, selectedIndex, child) {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildTabItem(0, selectedIndex, squadState),
                          _buildTabItem(1, selectedIndex, squadState),
                          _buildTabItem(2, selectedIndex, squadState),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupsList(BuildContext context, SquadState squadState,
      User currentUser, AsyncSnapshot<QuerySnapshot> snapshot) {
    final groups = snapshot.data?.docs ?? [];

    return Container(
      color: Colors.black,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: groups.length + 1, // +1 for DM card
        separatorBuilder: (context, index) => const Divider(
          color: Colors.grey,
          height: 0.5,
          indent: 72,
          thickness: 0.5,
        ),
        itemBuilder: (context, index) {
          if (index == 0) {
            // DM card
            return _buildDMCard(context);
          }

          final groupIndex = index - 1;
          final group = groups[groupIndex];
          final groupData = group.data() as Map<String, dynamic>;
          final groupName = groupData['name'] ?? 'Unnamed Group';
          final lastMessage = groupData['lastMessage'] ?? '';
          final lastMessageTime = groupData['lastMessageTime'] as Timestamp?;
          final memberCount = groupData['memberCount'] ?? 0;
          final isPublic = groupData['isPublic'] ?? false;
          final imageUrl = groupData['imageUrl'];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[800],
              backgroundImage: imageUrl != null ? NetworkImage(imageUrl) : null,
              child: imageUrl == null
                  ? Icon(
                      isPublic ? Icons.public : Icons.group,
                      color: Colors.cyanAccent,
                      size: 24,
                    )
                  : null,
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    groupName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (lastMessageTime != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      _formatTime(lastMessageTime.toDate()),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      lastMessage.isNotEmpty
                          ? lastMessage
                          : '$memberCount members',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            onTap: () => _openChatGroup(group.id, groupName),
            onLongPress: () => _showGroupOptions(group.id, groupData),
          );
        },
      ),
    );
  }

  Widget _buildDMCard(BuildContext context) {
    return Consumer<ChatState>(
      builder: (context, chatState, child) {
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey[800],
            child: const Icon(
              Icons.message,
              color: Colors.cyanAccent,
              size: 24,
            ),
          ),
          title: const Text(
            'Direct Messages',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          subtitle: const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              'Private conversations',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          trailing: chatState.dmUnreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    chatState.dmUnreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : null,
          onTap: () => chatState.setDMView(true),
        );
      },
    );
  }

  void _createNewGroup() {
    final nameController = TextEditingController();
    bool isPublic = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Create New Group',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  labelStyle: TextStyle(color: Colors.cyanAccent),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyanAccent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  const Text(
                    'Privacy:',
                    style: TextStyle(color: Colors.white),
                  ),
                  ChoiceChip(
                    label: const Text('Public'),
                    selected: isPublic,
                    onSelected: (selected) {
                      setState(() => isPublic = selected);
                    },
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    backgroundColor: Colors.grey[700],
                    labelStyle: TextStyle(
                      color: isPublic ? Colors.cyanAccent : Colors.white,
                    ),
                  ),
                  ChoiceChip(
                    label: const Text('Private'),
                    selected: !isPublic,
                    onSelected: (selected) {
                      setState(() => isPublic = !selected);
                    },
                    selectedColor: Colors.cyanAccent.withValues(alpha: 0.3),
                    backgroundColor: Colors.grey[700],
                    labelStyle: TextStyle(
                      color: !isPublic ? Colors.cyanAccent : Colors.white,
                    ),
                  ),
                ],
              ),
              if (!isPublic) ...[
                const SizedBox(height: 16),
                const Text(
                  'Private groups require manual member approval',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final groupName = nameController.text.trim();
                if (groupName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a group name')),
                  );
                  return;
                }

                try {
                  final squadState =
                      Provider.of<SquadState>(context, listen: false);
                  final currentUser = _auth.currentUser;
                  if (currentUser == null) return;

                  // Create group document
                  final groupRef = _firestore
                      .collection('squads')
                      .doc(squadState.selectedSquadId)
                      .collection('chat_groups')
                      .doc();

                  await groupRef.set({
                    'name': groupName,
                    'isPublic': isPublic,
                    'createdBy': currentUser.uid,
                    'createdAt': FieldValue.serverTimestamp(),
                    'lastMessage': '',
                    'lastMessageTime': FieldValue.serverTimestamp(),
                    'memberCount': 1,
                    'members': [currentUser.uid],
                    'imageUrl': null,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Group created successfully!')),
                    );

                    // Navigate to the new group
                    _openChatGroup(groupRef.id, groupName);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating group: $e')),
                    );
                  }
                }
              },
              child: const Text('Create',
                  style: TextStyle(color: Colors.cyanAccent)),
            ),
          ],
        ),
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
    // Placeholder - implement group settings dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group settings not implemented yet')),
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

  void _showAddFriendDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> searchResults = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => DraggableScrollableSheet(
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
                        'Add Friend',
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
                // Search
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search users...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[800],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send, color: Colors.cyanAccent),
                        onPressed: () async {
                          final query = searchController.text.trim();
                          if (query.length >= 2) {
                            final userManager = Provider.of<UserManager>(
                                context,
                                listen: false);
                            final results =
                                await userManager.searchUsers(query);
                            setState(() => searchResults = results);
                          }
                        },
                      ),
                    ),
                    onSubmitted: (query) async {
                      if (query.length >= 2) {
                        final userManager =
                            Provider.of<UserManager>(context, listen: false);
                        final results = await userManager.searchUsers(query);
                        setState(() => searchResults = results);
                      }
                    },
                  ),
                ),
                // Results
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      final displayName = user['displayName'] ?? 'Unknown';
                      final profileImage = user['profileImage'];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: profileImage != null
                              ? NetworkImage(profileImage)
                              : null,
                          child: profileImage == null
                              ? Text(displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?')
                              : null,
                        ),
                        title: Text(displayName,
                            style: const TextStyle(color: Colors.white)),
                        subtitle: Text('@${user['uid']}',
                            style: TextStyle(color: Colors.grey[400])),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close search
                            final userManager = Provider.of<UserManager>(
                                context,
                                listen: false);
                            final chatId =
                                await userManager.startDMThread(user['uid']);
                            if (chatId != null && mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ChatScreen(
                                    chatGroupId: chatId,
                                    chatGroupName: displayName,
                                  ),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('Start DM'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDMList(
      BuildContext context, SquadState squadState, User currentUser) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: currentUser.uid)
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

        final chats = snapshot.data?.docs ?? [];
        final dmChats = chats.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final participants = List<String>.from(data['participants'] ?? []);
          return participants.length == 2;
        }).toList();

        // Sort by lastMessageTime in memory since we can't use orderBy with arrayContains
        dmChats.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['lastMessageTime']
              as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['lastMessageTime']
              as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // Descending order
        });

        if (dmChats.isEmpty) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.message,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No direct messages yet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a friend to start chatting!',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.cyanAccent,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: InkWell(
                      onTap: _showAddFriendDialog,
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_add,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Add Friend',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          color: Colors.black,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            itemCount: dmChats.length,
            separatorBuilder: (context, index) => const Divider(
              color: Colors.grey,
              height: 0.5,
              indent: 72,
              thickness: 0.5,
            ),
            itemBuilder: (context, index) {
              final chat = dmChats[index];
              final chatData = chat.data() as Map<String, dynamic>;
              final participants =
                  List<String>.from(chatData['participants'] ?? []);
              final otherUserId =
                  participants.firstWhere((id) => id != currentUser.uid);
              final lastMessage = chatData['lastMessage'] ?? '';
              final lastMessageTime = chatData['lastMessageTime'] as Timestamp?;
              final unreadCount =
                  chatData['unreadCount']?[currentUser.uid] ?? 0;

              return FutureBuilder<Map<String, dynamic>?>(
                future: _getUserProfile(otherUserId),
                builder: (context, userSnapshot) {
                  final userData = userSnapshot.data;
                  final displayName =
                      userData?['displayName'] ?? 'Unknown User';
                  final profileImage = userData?['profileImage'];

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.grey[800],
                      backgroundImage: profileImage != null
                          ? NetworkImage(profileImage)
                          : null,
                      child: profileImage == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 16),
                            )
                          : null,
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lastMessageTime != null) ...[
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(
                              _formatTime(lastMessageTime.toDate()),
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        lastMessage.isNotEmpty
                            ? lastMessage
                            : 'Start a conversation',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: unreadCount > 0
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Colors.cyanAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () => _openDMChat(chat.id, displayName),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _getUserProfile(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      return doc.data();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  void _openDMChat(String chatId, String displayName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatGroupId: chatId,
          chatGroupName: displayName,
        ),
      ),
    );
  }

  void _checkLastChatGroup() async {
    final prefs = await SharedPreferences.getInstance();
    final lastGroupId = prefs.getString('last_chat_group');
    if (lastGroupId != null && mounted) {
      // Check if the group still exists and user has access
      final squadState = Provider.of<SquadState>(context, listen: false);
      final groupDoc = await _firestore
          .collection('squads')
          .doc(squadState.selectedSquadId)
          .collection('chat_groups')
          .doc(lastGroupId)
          .get();

      if (groupDoc.exists && mounted) {
        final groupData = groupDoc.data();
        final members = List<String>.from(groupData?['members'] ?? []);
        final isPrivate = groupData?['isPrivate'] ?? false;

        if (!isPrivate || members.contains(_auth.currentUser?.uid)) {
          // Navigate to the last chat group
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatGroupId: lastGroupId,
                chatGroupName: groupData?['name'] ?? 'Unknown Group',
              ),
            ),
          );
        }
      }
    }
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  // Notification settings
  bool _pushNotifications = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _showPreviews = true;
  bool _quietHoursEnabled = false;
  TimeOfDay _quietStartTime = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEndTime = const TimeOfDay(hour: 8, minute: 0);

  // Game-specific settings
  Set<String> _mutedGames = {};

  // Alert preferences
  bool _urgentAlertsOnly = false;
  bool _lobbyInvites = true;
  bool _friendRequests = true;
  bool _gameUpdates = false;
  bool _achievementAlerts = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('pushNotifications') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _showPreviews = prefs.getBool('showPreviews') ?? true;
      _quietHoursEnabled = prefs.getBool('quietHoursEnabled') ?? false;

      // Load quiet hours times
      final quietStart = prefs.getString('quietStartTime');
      final quietEnd = prefs.getString('quietEndTime');
      if (quietStart != null) {
        final parts = quietStart.split(':');
        _quietStartTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
      if (quietEnd != null) {
        final parts = quietEnd.split(':');
        _quietEndTime =
            TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }

      // Alert preferences
      _urgentAlertsOnly = prefs.getBool('urgentAlertsOnly') ?? false;
      _lobbyInvites = prefs.getBool('lobbyInvites') ?? true;
      _friendRequests = prefs.getBool('friendRequests') ?? true;
      _gameUpdates = prefs.getBool('gameUpdates') ?? false;
      _achievementAlerts = prefs.getBool('achievementAlerts') ?? true;
    });

    // Load muted games from UserManager
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchMutedGames();
      setState(() {
        _mutedGames = userManager.mutedGames.toSet();
      });
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _quietStartTime : _quietEndTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: AppTheme.cardDarkColor,
              hourMinuteTextColor: Colors.white,
              dialHandColor: AppTheme.accentColor,
              dialBackgroundColor: AppTheme.darkBackgroundColor,
              entryModeIconColor: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _quietStartTime = picked;
          _saveSetting('quietStartTime', '${picked.hour}:${picked.minute}');
        } else {
          _quietEndTime = picked;
          _saveSetting('quietEndTime', '${picked.hour}:${picked.minute}');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackgroundColor,
      appBar: AppBar(
        title: const Text('Notification Settings'),
        backgroundColor: AppTheme.cardDarkColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentColor,
          labelColor: AppTheme.accentColor,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'General', icon: Icon(Icons.settings)),
            Tab(text: 'Games', icon: Icon(Icons.videogame_asset)),
            Tab(text: 'Schedule', icon: Icon(Icons.schedule)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGeneralSettings(),
          _buildGameSettings(),
          _buildScheduleSettings(),
        ],
      ),
    );
  }

  Widget _buildGeneralSettings() {
    return Consumer<UserManager>(
      builder: (context, userManager, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Push Notifications'),
            _buildSwitchTile(
              title: 'Push Notifications',
              subtitle: 'Receive notifications on your device',
              value: _pushNotifications,
              onChanged: (value) {
                setState(() => _pushNotifications = value);
                _saveSetting('pushNotifications', value);
              },
              icon: Icons.notifications,
            ),
            _buildSwitchTile(
              title: 'Sound',
              subtitle: 'Play notification sounds',
              value: _soundEnabled,
              onChanged: (value) {
                setState(() => _soundEnabled = value);
                _saveSetting('soundEnabled', value);
              },
              icon: Icons.volume_up,
              enabled: _pushNotifications,
            ),
            _buildSwitchTile(
              title: 'Vibration',
              subtitle: 'Vibrate for notifications',
              value: _vibrationEnabled,
              onChanged: (value) {
                setState(() => _vibrationEnabled = value);
                _saveSetting('vibrationEnabled', value);
              },
              icon: Icons.vibration,
              enabled: _pushNotifications,
            ),
            _buildSwitchTile(
              title: 'Show Previews',
              subtitle: 'Display message content in notifications',
              value: _showPreviews,
              onChanged: (value) {
                setState(() => _showPreviews = value);
                _saveSetting('showPreviews', value);
              },
              icon: Icons.visibility,
              enabled: _pushNotifications,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Alert Types'),
            _buildSwitchTile(
              title: 'Urgent Alerts Only',
              subtitle: 'Only show critical notifications',
              value: _urgentAlertsOnly,
              onChanged: (value) {
                setState(() => _urgentAlertsOnly = value);
                _saveSetting('urgentAlertsOnly', value);
              },
              icon: Icons.warning,
            ),
            _buildSwitchTile(
              title: 'Lobby Invites',
              subtitle: 'Notifications for game lobby invites',
              value: _lobbyInvites,
              onChanged: (value) {
                setState(() => _lobbyInvites = value);
                _saveSetting('lobbyInvites', value);
              },
              icon: Icons.group_add,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Friend Requests',
              subtitle: 'Notifications for new friend requests',
              value: _friendRequests,
              onChanged: (value) {
                setState(() => _friendRequests = value);
                _saveSetting('friendRequests', value);
              },
              icon: Icons.person_add,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Game Updates',
              subtitle: 'Notifications about game patches and news',
              value: _gameUpdates,
              onChanged: (value) {
                setState(() => _gameUpdates = value);
                _saveSetting('gameUpdates', value);
              },
              icon: Icons.new_releases,
              enabled: !_urgentAlertsOnly,
            ),
            _buildSwitchTile(
              title: 'Achievements',
              subtitle: 'Notifications for unlocked achievements',
              value: _achievementAlerts,
              onChanged: (value) {
                setState(() => _achievementAlerts = value);
                _saveSetting('achievementAlerts', value);
              },
              icon: Icons.emoji_events,
              enabled: !_urgentAlertsOnly,
            ),
            const SizedBox(height: 24),
            _buildSectionHeader('Quick Actions'),
            Card(
              color: AppTheme.cardDarkColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quiet Mode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Temporarily mute all game notifications',
                      style: TextStyle(color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _mutedGames = userManager
                                  .pinnedGames
                                  .map((g) => g['slug'] ?? '')
                                  .toSet()
                                  .cast<String>());
                              userManager.mutedGames.clear();
                              for (final game in userManager.pinnedGames) {
                                userManager.muteGame(game['slug'] ?? '');
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All games muted')),
                              );
                            },
                            icon: const Icon(Icons.volume_off),
                            label: const Text('Mute All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() => _mutedGames.clear());
                              userManager.clearMutedGames();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('All games unmuted')),
                              );
                            },
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Unmute All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[700],
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGameSettings() {
    return Consumer<UserManager>(
      builder: (context, userManager, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Game-Specific Settings'),
            const Text(
              'Control notifications for individual games',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            if (userManager.pinnedGames.isEmpty)
              Card(
                color: AppTheme.cardDarkColor,
                child: const Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.videogame_asset, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No pinned games',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Pin games in your profile to customize notifications',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...userManager.pinnedGames.map((game) {
                final gameSlug = game['slug'] ?? '';
                final isMuted = _mutedGames.contains(gameSlug);

                return Card(
                  color: AppTheme.cardDarkColor,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: game['image'] != null
                        ? Image.network(
                            game['image'],
                            width: 40,
                            height: 40,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.videogame_asset,
                              color: Colors.cyanAccent,
                            ),
                          )
                        : const Icon(
                            Icons.videogame_asset,
                            color: Colors.cyanAccent,
                            size: 40,
                          ),
                    title: Text(
                      game['name'] ?? 'Unknown Game',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      isMuted ? 'Muted' : 'Notifications enabled',
                      style: TextStyle(
                        color: isMuted ? Colors.red[400] : Colors.green[400],
                      ),
                    ),
                    trailing: Switch(
                      value: !isMuted,
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            _mutedGames.remove(gameSlug);
                            userManager.unmuteGame(gameSlug);
                          } else {
                            _mutedGames.add(gameSlug);
                            userManager.muteGame(gameSlug);
                          }
                        });
                      },
                      activeColor: AppTheme.accentColor,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            _buildSectionHeader('Advanced Settings'),
            Card(
              color: AppTheme.cardDarkColor,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notification Priority',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Choose which games get priority notifications',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    // This could be expanded to allow reordering games by priority
                    const Text(
                      'Coming soon: Priority ordering',
                      style: TextStyle(
                          color: Colors.grey, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScheduleSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionHeader('Quiet Hours'),
        Card(
          color: AppTheme.cardDarkColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Quiet Hours',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Switch(
                      value: _quietHoursEnabled,
                      onChanged: (value) {
                        setState(() => _quietHoursEnabled = value);
                        _saveSetting('quietHoursEnabled', value);
                      },
                      activeColor: AppTheme.accentColor,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Automatically mute notifications during specified hours',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                if (_quietHoursEnabled) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Quiet Hours Schedule',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Start Time',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context, true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.cyanAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _quietStartTime.format(context),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'End Time',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _selectTime(context, false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.darkBackgroundColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[600]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Colors.cyanAccent, size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      _quietEndTime.format(context),
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[900]!.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[700]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notifications will be silenced from ${_quietStartTime.format(context)} to ${_quietEndTime.format(context)}',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Do Not Disturb'),
        Card(
          color: AppTheme.cardDarkColor,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Focus Mode',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Temporarily disable all notifications',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement focus mode
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Focus mode activated for 1 hour')),
                          );
                        },
                        icon: const Icon(Icons.do_not_disturb),
                        label: const Text('1 Hour'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // TODO: Implement focus mode
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Focus mode activated for 2 hours')),
                          );
                        },
                        icon: const Icon(Icons.do_not_disturb),
                        label: const Text('2 Hours'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    bool enabled = true,
  }) {
    return Card(
      color: AppTheme.cardDarkColor,
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(
          title,
          style: TextStyle(
            color: enabled ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: enabled ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        secondary: Icon(
          icon,
          color: enabled ? AppTheme.accentColor : Colors.grey,
        ),
        value: value,
        onChanged: enabled ? onChanged : null,
        activeColor: AppTheme.accentColor,
      ),
    );
  }
}
