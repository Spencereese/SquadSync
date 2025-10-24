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
import '../managers/notification_manager.dart';
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
                    _selectedIndexNotifier.value == 2
                        ? AppTheme.primaryColor.withValues(alpha: 0.8)
                        : AppTheme.primaryColor,
                    if (_selectedIndexNotifier.value == 2)
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
              Row(
                children: [
                  const Text(
                    'Privacy:',
                    style: TextStyle(color: Colors.white),
                  ),
                  const SizedBox(width: 16),
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
                  const SizedBox(width: 8),
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

class _NotificationsScreenState extends State<NotificationsScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _quietGames = false;

  @override
  void initState() {
    super.initState();
    // Load quiet games preference
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchMutedGames();
      setState(() {
        _quietGames = userManager.mutedGames.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<NotificationManager, UserManager>(
      builder: (context, notificationManager, userManager, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppTheme.darkBackgroundColor,
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: AppTheme.cardDarkColor,
            actions: [
              // Quiet Games toggle
              SwitchListTile(
                title: const Text(
                  'Quiet Games',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                value: _quietGames,
                onChanged: (value) {
                  setState(() {
                    _quietGames = value;
                  });
                  if (!value) {
                    // Clear all muted games when turning off quiet mode
                    userManager.clearMutedGames();
                  }
                },
                activeColor: Colors.cyanAccent,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
              // Drawer button
              IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          endDrawer: _buildDrawer(context, userManager),
          body: _buildNotificationsFeed(notificationManager, userManager),
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context, UserManager userManager) {
    return Drawer(
      backgroundColor: AppTheme.cardDarkColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.darkBackgroundColor,
            child: const Text(
              'Quiet Mode Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                // Mute All Games toggle
                SwitchListTile(
                  title: const Text(
                    'Mute All Games',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Silence all game notifications',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  value: userManager.mutedGames.length ==
                      userManager.pinnedGames.length,
                  onChanged: (value) {
                    if (value) {
                      // Mute all pinned games
                      for (final game in userManager.pinnedGames) {
                        userManager.muteGame(game['slug'] ?? '');
                      }
                    } else {
                      // Unmute all games
                      userManager.clearMutedGames();
                    }
                    setState(() {
                      _quietGames = userManager.mutedGames.isNotEmpty;
                    });
                  },
                  activeColor: Colors.cyanAccent,
                ),
                const Divider(color: Colors.grey),
                // Prioritize Faves section
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Prioritize Favorites',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Show pinned games that are not muted
                ...userManager.pinnedGames
                    .where(
                        (game) => !userManager.isGameMuted(game['slug'] ?? ''))
                    .map((game) => ListTile(
                          leading: game['image'] != null
                              ? Image.network(
                                  game['image'],
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.videogame_asset,
                                    color: Colors.cyanAccent,
                                  ),
                                )
                              : const Icon(
                                  Icons.videogame_asset,
                                  color: Colors.cyanAccent,
                                ),
                          title: Text(
                            game['name'] ?? 'Unknown Game',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: const Text(
                            'Notifications enabled',
                            style: TextStyle(color: Colors.green, fontSize: 12),
                          ),
                        )),
                // Link to Profile settings
                ListTile(
                  leading: const Icon(Icons.settings, color: Colors.grey),
                  title: const Text(
                    'Game Preferences',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: const Text(
                    'Fine-tune per-game settings',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.pop(context); // Close drawer
                    // Navigate to profile/settings tab
                    // This would need to be implemented based on your navigation structure
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsFeed(
      NotificationManager notificationManager, UserManager userManager) {
    final mutedGames = _quietGames ? userManager.mutedGames : null;

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: notificationManager.getFilteredNotificationsStream(
          mutedGames: mutedGames),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading notifications: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final notifications = snapshot.data ?? [];
        final urgentNotifications = notifications
            .where((doc) => (doc.data()['type'] == 'urgent'))
            .take(5)
            .toList();

        return Column(
          children: [
            // Urgent Alerts Section
            if (urgentNotifications.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.cardDarkColor,
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Text(
                      'Urgent Alerts',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: urgentNotifications.length,
                  itemBuilder: (context, index) {
                    final doc = urgentNotifications[index];
                    final data = doc.data();
                    return _buildUrgentAlertCard(
                        context, doc.id, data, notificationManager);
                  },
                ),
              ),
            ] else ...[
              // Empty urgent state
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(
                      Icons.notifications_off,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'All quiet—start a lobby?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to peacock modal or lobby creation
                        // This would need to be implemented based on your navigation
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyanAccent,
                        foregroundColor: Colors.black,
                      ),
                      child: const Text('Launch Game'),
                    ),
                  ],
                ),
              ),
            ],

            // Recent History Section
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.cardDarkColor,
              child: const Row(
                children: [
                  Icon(Icons.history, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Recent History',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? const Center(
                      child: Text(
                        'No notifications yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final doc = notifications[index];
                        final data = doc.data();
                        return _buildHistoryCard(context, doc.id, data,
                            notificationManager, userManager);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUrgentAlertCard(BuildContext context, String notificationId,
      Map<String, dynamic> data, NotificationManager notificationManager) {
    final title = data['title'] as String? ?? 'Alert';
    final body = data['body'] as String? ?? '';

    return Card(
      color: AppTheme.cardDarkColor,
      margin: const EdgeInsets.all(8),
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.cyanAccent,
                  child: Icon(Icons.person, color: Colors.black),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: Colors.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      // Handle join action
                      notificationManager.markAsRead(notificationId);
                      // Navigate to game lobby
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Handle remind action
                      notificationManager.markAsRead(notificationId);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.blue),
                    ),
                    child: const Text('Remind',
                        style: TextStyle(color: Colors.blue)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      // Handle snooze action
                      notificationManager.markAsRead(notificationId);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                    ),
                    child: const Text('Snooze',
                        style: TextStyle(color: Colors.grey)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
      BuildContext context,
      String notificationId,
      Map<String, dynamic> data,
      NotificationManager notificationManager,
      UserManager userManager) {
    final game = data['game'] as String?;
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;
    final isRead = data['read'] as bool? ?? false;

    return Dismissible(
      key: Key(notificationId),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        notificationManager.archiveNotification(notificationId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification archived')),
        );
      },
      child: Card(
        color: isRead
            ? AppTheme.cardDarkColor
            : AppTheme.cardDarkColor.withOpacity(0.8),
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: InkWell(
          onLongPress: game != null
              ? () => _showMuteGameDialog(context, game, userManager)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isRead ? Colors.grey : Colors.cyanAccent,
              child: Icon(
                isRead ? Icons.notifications : Icons.notifications_active,
                color: isRead ? Colors.white : Colors.black,
              ),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  body,
                  style: const TextStyle(color: Colors.grey),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (timestamp != null)
                  Text(
                    _formatTimestamp(timestamp),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
              ],
            ),
            trailing: game != null
                ? const Icon(Icons.more_vert, color: Colors.grey)
                : null,
            onTap: () {
              if (!isRead) {
                notificationManager.markAsRead(notificationId);
              }
              // Handle navigation based on notification type
            },
          ),
        ),
      ),
    );
  }

  void _showMuteGameDialog(
      BuildContext context, String gameSlug, UserManager userManager) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDarkColor,
        title: const Text(
          'Mute this game?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Stop receiving notifications for $gameSlug?',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              userManager.muteGame(gameSlug);
              setState(() {
                _quietGames = userManager.mutedGames.isNotEmpty;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$gameSlug muted')),
              );
            },
            child: const Text('Mute', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
