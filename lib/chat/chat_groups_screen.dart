import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service_supabase.dart';
import '../services/supabase_service.dart';
import '../domain/entities/message.dart';
import '../domain/entities/lobby_state.dart';
import '../domain/entities/chat_group.dart';
import 'chat_screen.dart';
import '../core/app_theme.dart';
import '../core/layout.dart';
import '../widgets/chat_surface_feedback.dart';
import 'widgets/user_groups_tab.dart';
import 'widgets/direct_messages_tab.dart';
import 'widgets/group_chat_context_menu.dart';
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
    // Removed _checkLastChatGroup() - now handled by GoRouter redirect for better UX
    _pageController = PageController(initialPage: _selectedIndexNotifier.value);
    _pageController.addListener(_handlePageChange);

    // Load user's groups first, then load discover groups
    // This ensures discover filtering works correctly
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        // Only load if groups haven't been loaded yet
        final chatState = ref.read(chatNotifierProvider);
        final hasLoadedGroups = chatState.whenOrNull(
              data: (state) =>
                  state.chatGroups.isNotEmpty ||
                  state.userChatGroups.isNotEmpty,
            ) ??
            false;

        if (!hasLoadedGroups) {
          debugPrint(
              '🔴 ChatGroupsScreen: Calling loadUserGroups() (no cached data)');
          await ref.read(chatNotifierProvider.notifier).loadUserGroups();
        } else {
          debugPrint(
              '🟢 ChatGroupsScreen: Using cached groups (${chatState.value?.chatGroups.length ?? 0} groups)');
        }

        // Now initialize discover groups AFTER user groups are loaded
        if (mounted) {
          setState(() {
            _discoverGroupsFuture =
                ref.read(chatNotifierProvider.notifier).discoverGroups();
          });
        }
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
      if (!mounted) return;
      final keyboardHeight = MediaQuery.viewInsetsOf(context).bottom;
      if (keyboardHeight != _lastKeyboardHeight) {
        setState(() {
          if (keyboardHeight > 0) {
            _navBottomOffset = -mainTabClearanceOf(context);
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
      _pageController.jumpToPage(index);
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
          backgroundColor: const Color(0xFF0B0E14),
          foregroundColor: Colors.white,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
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
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const GroupActionsDialog(),
                    ),
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

        final state = chatState.valueOrNull;
        final groups = state?.chatGroups.values.toList() ?? [];
        final error = chatState.error ?? state?.syncError;
        final isOffline = state?.isOnline == false;
        final phase = resolveChatSurfacePhase(
          isLoading: chatState.isLoading && state == null,
          error: error,
          isEmpty: groups.isEmpty,
          isOffline: isOffline,
          itemCount: groups.length,
        );
        if (phase != ChatSurfacePhase.data) {
          return ChatSurfaceFeedback(
            kind: ChatSurfaceKind.list,
            phase: phase,
            error: error,
            isOffline: isOffline,
            onRetry: () {
              ref.read(chatNotifierProvider.notifier).loadUserGroups();
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];

            return InkWell(
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
              onLongPress: () async {
                HapticFeedback.mediumImpact();
                final currentUser = AuthServiceSupabase().currentUser;
                if (currentUser == null) return;

                try {
                  // Fetch group metadata from users.user_groups
                  final userData = await SupabaseService.client
                      .from('users')
                      .select('user_groups')
                      .eq('uid', currentUser.id)
                      .maybeSingle();

                  final userGroups = List<Map<String, dynamic>>.from(
                      userData?['user_groups'] ?? []);
                  final groupMeta = userGroups.firstWhere(
                    (g) => g['id'] == group.id,
                    orElse: () => <String, dynamic>{},
                  );

                  final isMuted = groupMeta['is_muted'] as bool? ?? false;
                  final isPinned = groupMeta['is_pinned'] as bool? ?? false;

                  // Check if user is creator
                  final groupData = await SupabaseService.client
                      .from('chat_groups')
                      .select('created_by')
                      .eq('id', group.id)
                      .maybeSingle();
                  final createdBy = groupData?['created_by'] as String? ?? '';
                  final isCreator = createdBy == currentUser.id;

                  if (!context.mounted) return;

                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (context) => GroupChatContextMenu(
                      groupId: group.id,
                      groupName: group.name,
                      createdBy: createdBy,
                      isMuted: isMuted,
                      isPinned: isPinned,
                      onMarkUnread: () async {
                        await ref
                            .read(chatNotifierProvider.notifier)
                            .markGroupAsUnread(group.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      onTogglePinned: () async {
                        await ref
                            .read(chatNotifierProvider.notifier)
                            .togglePinGroup(group.id, isPinned);
                        if (context.mounted) Navigator.pop(context);
                      },
                      onToggleMute: () async {
                        await ref
                            .read(chatNotifierProvider.notifier)
                            .toggleMuteGroup(group.id, isMuted);
                        if (context.mounted) Navigator.pop(context);
                      },
                      onIgnore: () async {
                        await ref
                            .read(chatNotifierProvider.notifier)
                            .ignoreGroup(group.id);
                        if (context.mounted) Navigator.pop(context);
                      },
                      onLeave: () async {
                        Navigator.pop(context);
                        _showLeaveGroupDialog(context, group.id, group.name);
                      },
                      onDelete: isCreator
                          ? () async {
                              try {
                                await ref
                                    .read(chatNotifierProvider.notifier)
                                    .deleteGroup(group.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Deleted "${group.name}"'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to delete: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          : null,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error showing context menu: $e');
                }
              },
              child: ListTile(
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
                  _formatLastMessage(group),
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            );
          },
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
                  return const ChatSurfaceFeedback(
                    kind: ChatSurfaceKind.list,
                    phase: ChatSurfacePhase.loading,
                  );
                }

                if (snapshot.hasError) {
                  return ChatSurfaceFeedback(
                    kind: ChatSurfaceKind.list,
                    phase: ChatSurfacePhase.error,
                    error: snapshot.error,
                    onRetry: _refreshDiscoverGroups,
                  );
                }

                final groups = snapshot.data ?? [];

                if (groups.isEmpty) {
                  return const ChatSurfaceFeedback(
                    kind: ChatSurfaceKind.list,
                    phase: ChatSurfacePhase.empty,
                    message: 'No public groups available',
                    hint: 'Check back later for groups to discover',
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

      // Switch to "My Groups" tab after successful join
      if (mounted && _selectedIndexNotifier.value != 0) {
        _onTabTapped(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join group: $e')),
        );
      }
    }
  }

  void _showLeaveGroupDialog(
      BuildContext context, String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Leave Group',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to leave "$groupName"?',
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(dialogContext).pop(); // Close dialog first
                try {
                  await ref
                      .read(chatNotifierProvider.notifier)
                      .leaveGroup(groupId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('You left "$groupName"'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to leave group: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Leave',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatLastMessage(ChatGroup group) {
    final senderName = group.metadata?['last_message_sender'] as String?;
    final messageText = group.metadata?['last_message_text'] as String?;
    final lastActivity = group.lastActivity;

    if (lastActivity == null || senderName == null || messageText == null) {
      return 'No activity';
    }

    final timestamp = _formatTimestamp(lastActivity);
    final prefix = '$senderName: ';
    final suffix = ' $timestamp';

    // Approximate max characters that can fit (adjust based on font size)
    // At fontSize 12, roughly 50-60 chars fit comfortably
    const maxLength = 55;
    final availableLength = maxLength - prefix.length - suffix.length;

    String displayMessage = messageText;
    if (messageText.length > availableLength) {
      // Truncate and add .. before timestamp
      displayMessage = '${messageText.substring(0, availableLength - 2)}..';
    }

    return '$prefix$displayMessage$suffix';
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);
    final difference = today.difference(messageDay).inDays;

    if (difference == 0) {
      // Same day - show military time (22:22)
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (difference < 7) {
      // Within a week - show day of week
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[time.weekday - 1];
    } else {
      // Over a week - show "Jan 4" format
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[time.month - 1]} ${time.day}';
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
                        child: Builder(
                          builder: (context) {
                            final bottomSafe =
                                MediaQuery.viewPaddingOf(context).bottom;
                            final neon = Theme.of(context).colorScheme.primary;
                            return Container(
                              height: mainTabClearance(bottomSafe),
                              padding: EdgeInsets.only(bottom: bottomSafe),
                              decoration: BoxDecoration(
                                color: const Color(0xE60B0E14),
                                border: Border(
                                  top: BorderSide(
                                    color: neon.withValues(alpha: 0.28),
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: neon.withValues(alpha: 0.12),
                                    blurRadius: 16,
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
                                      _buildTabItem(
                                          0, selectedIndex, squadState),
                                      _buildTabItem(
                                          1, selectedIndex, squadState),
                                      _buildTabItem(
                                          2, selectedIndex, squadState),
                                      _buildTabItem(
                                          3, selectedIndex, squadState),
                                    ],
                                  );
                                },
                              ),
                            );
                          },
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

  // Removed _checkLastChatGroup() - navigation to last chat now handled by GoRouter
  // This eliminates the flash of the groups screen on startup
}
