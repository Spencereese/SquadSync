import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/message.dart';
import '../domain/entities/lobby_state.dart';
import 'chat_screen.dart';
import '../core/app_theme.dart';
import 'widgets/user_groups_tab.dart';
import 'widgets/direct_messages_tab.dart';
import 'dialogs/group_actions_dialog.dart';
import 'dialogs/add_friend_dialog.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import '../presentation/notifiers/user_notifier.dart';
import '../presentation/notifiers/chat_notifier.dart';
import '../profile_tab.dart';
import '../screens/lobby_tab_screen.dart';
import '../screens/clips_screen.dart';
// Removed: import '../presentation/widgets/group_create_sheet.dart';
import '../widgets/group_preview_card.dart';

class ChatGroupsScreen extends ConsumerStatefulWidget {
  const ChatGroupsScreen({super.key});

  @override
  ConsumerState<ChatGroupsScreen> createState() => _ChatGroupsScreenState();
}

class _ChatGroupsScreenState extends ConsumerState<ChatGroupsScreen> {
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  late PageController _pageController;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  final TextEditingController _codeController = TextEditingController();
  double _navOpacity = 0.9;
  bool _isScrollingDown = false;
  double _navBottomOffset = 0.0;
  double _lastKeyboardHeight = 0.0;
  bool _isDMView = false;
  Future<List<dynamic>>? _discoverGroupsFuture;

  @override
  void initState() {
    super.initState();
    _checkLastChatGroup();
    _pageController = PageController(initialPage: _selectedIndexNotifier.value);
    _pageController.addListener(_handlePageChange);

    // Initialize discover groups future
    _discoverGroupsFuture =
        ref.read(chatNotifierProvider.notifier).discoverGroups();

    // Load user's groups on initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        debugPrint('🔴 ChatGroupsScreen: Calling loadUserGroups()');
        ref.read(chatNotifierProvider.notifier).loadUserGroups();
      } else {
        debugPrint(
            '🔴 ChatGroupsScreen: NOT calling loadUserGroups (not mounted)');
      }
    });
  }

  void _refreshDiscoverGroups() {
    setState(() {
      _discoverGroupsFuture =
          ref.read(chatNotifierProvider.notifier).discoverGroups();
    });
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
    _codeController.dispose();
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
    ref.read(ln.lobbyNotifierProvider.notifier).clearNotifications(index);
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

  Widget _buildTabItem(int index, int selectedIndex, LobbyState squadState) {
    bool isSelected = selectedIndex == index;
    final tabs = [
      'assets/images/chat.png',
      Icons.group,
      Icons.video_library,
      Icons.person,
    ];
    final labels = ['Chats', 'Lobby', 'Clips', 'Profile'];
    bool hasNotification =
        !isSelected && (index == 0 && squadState.hasUnreadMessages);

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.only(top: 8, bottom: 20),
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
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.7),
                  )
                else
                  Icon(
                    tabs[index] as IconData,
                    size: 28,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    labels[index],
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
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
                    color: Theme.of(context).colorScheme.primary,
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

  List<Widget> _buildPages(
      BuildContext context, bool isKeyboardVisible, LobbyState squadState) {
    return [
      _buildChatGroupsPage(squadState, ref),
      const LobbyTabScreen(),
      const ClipsScreen(),
      const ProfileTab(),
    ];
  }

  Widget _buildChatGroupsPage(LobbyState squadState, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Chats'),
          backgroundColor: Colors.black,
          elevation: 0,
          leading: _isDMView
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                  onPressed: () => setState(() => _isDMView = false),
                  tooltip: 'Back to all chats',
                )
              : null,
          actions: [
            if (_isDMView)
              // Add friend button with pending requests badge
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: ref
                    .watch(userNotifierProvider.notifier)
                    .streamPendingRequests(),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data?.length ?? 0;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.person_add,
                            color: Colors.cyanAccent),
                        onPressed: () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const AddFriendDialog(),
                        ),
                        tooltip: 'Add friend',
                      ),
                      if (pendingCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              pendingCount > 9 ? '9+' : '$pendingCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              )
            else ...[
              // Single + button for creating groups
              IconButton(
                icon: const Icon(Icons.add, color: Colors.cyanAccent),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showDialog(
                    context: context,
                    builder: (context) => const GroupActionsDialog(),
                  );
                },
                tooltip: 'Create group',
              ),
            ],
          ],
          bottom: _isDMView
              ? null
              : TabBar(
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.white.withOpacity(0.6),
                  indicatorWeight: 3,
                  tabs: const [
                    Tab(text: 'My Groups'),
                    Tab(text: 'Discover'),
                  ],
                ),
        ),
        body: _isDMView
            ? _buildChatContent(squadState)
            : TabBarView(
                children: [
                  _buildMyGroupsTab(squadState),
                  _buildDiscoverTab(),
                ],
              ),
        // Removed: FloatingActionButton replaced with + button in AppBar
      ),
    );
  }

  Widget _buildMyGroupsTab(LobbyState squadState) {
    return Consumer(
      builder: (context, ref, child) {
        final chatState = ref.watch(chatNotifierProvider);

        return chatState.when(
          data: (state) {
            final groups = state.chatGroups.values.toList();

            if (groups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 64,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No groups yet',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create or join a group to get started',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                    backgroundImage: group.avatarUrl != null
                        ? NetworkImage(group.avatarUrl!)
                        : null,
                    child: group.avatarUrl == null
                        ? Icon(
                            Icons.group,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : null,
                  ),
                  title: Text(
                    group.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Last: ${group.lastActivity != null ? _formatLastActivity(group.lastActivity!) : "No activity"}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(chatNotifierProvider.notifier)
                        .loadMessages(group.id);
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatGroupId: group.id,
                            chatGroupName: group.name,
                            chatType: ChatType.userGroup,
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
          error: (error, stack) => Center(
            child: Text(
              'Error loading groups: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Invite code input section
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  decoration: InputDecoration(
                    hintText: 'Paste code here...',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                    ),
                    labelText: 'Enter Invite Code',
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    prefixIcon: Icon(
                      Icons.vpn_key,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF00F5FF),
                        width: 2,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: const Color(0xFF00F5FF).withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF00F5FF),
                        width: 2,
                      ),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _joinByInviteCode(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Join',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Discover groups list
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _refreshDiscoverGroups();
              await _discoverGroupsFuture;
            },
            color: Theme.of(context).colorScheme.primary,
            child: FutureBuilder<List<dynamic>>(
              future: _discoverGroupsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading groups: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final groups = snapshot.data ?? [];

                if (groups.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.explore_outlined,
                          size: 64,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No public groups available',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Check back later for groups to discover',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14,
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

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GroupPreviewCard(
                        group: group,
                        onJoin: () => _joinGroup(group.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _isValidUUID(String code) {
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(code.trim());
  }

  Future<void> _joinByInviteCode() async {
    final code = _codeController.text.trim();

    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter an invite code')),
        );
      }
      return;
    }

    if (!_isValidUUID(code)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Invalid invite code format. Please check and try again.')),
        );
      }
      return;
    }

    try {
      HapticFeedback.lightImpact();
      await ref.read(chatNotifierProvider.notifier).joinGroupWithConfirmation(
            context,
            code,
          );
      _codeController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  Future<void> _joinGroup(String groupId) async {
    try {
      HapticFeedback.lightImpact();
      await ref.read(chatNotifierProvider.notifier).joinGroupWithConfirmation(
            context,
            groupId,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  String _formatLastActivity(DateTime time) {
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

  @override
  Widget build(BuildContext context) {
    return ref.watch(ln.lobbyNotifierProvider).when(
          data: (squadState) {
            final bool isKeyboardVisible =
                MediaQuery.of(context).viewInsets.bottom > 0;

            // Show loading screen while initializing or loading initial data
            if (!squadState.isInitialized || !squadState.isInitialDataLoaded) {
              return Theme(
                data: AppTheme.dark(),
                child: Scaffold(
                  backgroundColor: Colors.black,
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                            color: Colors.cyanAccent),
                        const SizedBox(height: 24),
                        Text(
                          'Loading your lobby...',
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
              data: AppTheme.dark(),
              child: Scaffold(
                body: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      color: Colors.black,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: _updateNavOpacity,
                        child: PageView(
                          controller: _pageController,
                          physics: const ClampingScrollPhysics(),
                          children: _buildPages(
                              context, isKeyboardVisible, squadState),
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildTabItem(0, selectedIndex, squadState),
                                  _buildTabItem(1, selectedIndex, squadState),
                                  _buildTabItem(2, selectedIndex, squadState),
                                  _buildTabItem(3, selectedIndex, squadState),
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
          },
          loading: () => const CircularProgressIndicator(),
          error: (e, s) => Text('Error loading squad: $e'),
        );
  }

  Widget _buildChatContent(LobbyState squadState) {
    // Check if user is authenticated
    final currentUser = AuthServiceSupabase().currentUser;
    if (currentUser == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }

    if (squadState.selectedLobbyId == null) {
      // Show user-specific groups instead of squad groups
      if (_isDMView) {
        // Show DMs
        return const DirectMessagesTab();
      } else {
        // Show user groups with DM card
        return UserGroupsTab(onTapDM: () => setState(() => _isDMView = true));
      }
    } else {
      // Also show user groups when squad is selected (unified approach)
      if (_isDMView) {
        // Show DMs
        return const DirectMessagesTab();
      } else {
        // Show user groups with DM card
        return UserGroupsTab(onTapDM: () => setState(() => _isDMView = true));
      }
    }
  }

  void _checkLastChatGroup() async {
    try {
      // Wait a moment for the screen to be fully mounted and data loaded
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final lastGroupId = prefs.getString('last_chat_group');

      if (lastGroupId == null || lastGroupId.isEmpty) {
        debugPrint('No last chat group saved');
        return;
      }

      debugPrint('Attempting to restore last chat group: $lastGroupId');

      // Check if the group still exists and user has access
      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('id', lastGroupId)
          .maybeSingle();

      if (response != null && mounted) {
        final members = List<String>.from(response['member_uids'] ?? []);
        final isPrivate = response['is_private'] ?? false;
        final currentUserId = _authService.currentUser?.id;

        if (currentUserId != null &&
            (!isPrivate || members.contains(currentUserId))) {
          debugPrint('Navigating to last chat group: ${response['name']}');

          // Use addPostFrameCallback to ensure navigation happens after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    chatGroupId: lastGroupId,
                    chatGroupName: response['name'] ?? 'Unknown Group',
                    chatType: ChatType.userGroup,
                  ),
                ),
              );
            }
          });
        } else {
          debugPrint('User does not have access to last chat group');
        }
      } else {
        debugPrint('Last chat group not found or user has no access');
      }
    } catch (e) {
      debugPrint('Error restoring last chat group: $e');
    }
  }
}
