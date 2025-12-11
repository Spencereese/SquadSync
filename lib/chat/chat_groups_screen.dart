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
import '../profile_tab.dart';
import '../screens/squad_tab_screen.dart';
import '../screens/clips_screen.dart';

class ChatGroupsScreen extends ConsumerStatefulWidget {
  const ChatGroupsScreen({super.key});

  @override
  ConsumerState<ChatGroupsScreen> createState() => _ChatGroupsScreenState();
}

class _ChatGroupsScreenState extends ConsumerState<ChatGroupsScreen> {
  final AuthServiceSupabase _authService = AuthServiceSupabase();
  late PageController _pageController;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  double _navOpacity = 0.9;
  bool _isScrollingDown = false;
  double _navBottomOffset = 0.0;
  double _lastKeyboardHeight = 0.0;
  bool _isDMView = false;

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
    final labels = ['Chats', 'Squad', 'Clips', 'Profile'];
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
      const SquadTabScreen(),
      const ClipsScreen(),
      const ProfileTab(),
    ];
  }

  Widget _buildChatGroupsPage(LobbyState squadState, WidgetRef ref) {
    return Scaffold(
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
            // Single + button for all group actions
            IconButton(
              icon: const Icon(Icons.add, color: Colors.cyanAccent),
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const GroupActionsDialog(),
              ),
              tooltip: 'Group actions',
            ),
          ],
        ],
      ),
      body: _buildChatContent(squadState),
    );
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
      final squadState = ref.read(ln.lobbyNotifierProvider).maybeWhen(
            data: (data) => data,
            orElse: () => null,
          );

      if (squadState == null || squadState.selectedLobbyId == null) {
        debugPrint('No squad selected, cannot restore last chat group');
        return;
      }

      final response = await SupabaseService.client
          .from('chat_groups')
          .select()
          .eq('id', lastGroupId)
          .eq('squad_id', squadState.selectedLobbyId!)
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
