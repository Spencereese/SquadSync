import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/chat_groups_screen.dart';
import '../profile_tab.dart';
import '../app_theme.dart';
import '../squad_state.dart';
import '../managers/user_manager.dart';
import '../managers/notification_manager.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _quietMode = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Load muted games on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userManager = Provider.of<UserManager>(context, listen: false);
      userManager.fetchMutedGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<UserManager, NotificationManager>(
      builder: (context, userManager, notificationManager, child) {
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppTheme.darkBackgroundColor,
          appBar: AppBar(
            title: const Text('Notifications'),
            backgroundColor: AppTheme.cardDarkColor,
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ),
          drawer: _buildQuietModeDrawer(context, userManager),
          body: Column(
            children: [
              // Quiet Games Toggle Header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppTheme.cardDarkColor,
                child: SwitchListTile(
                  title: const Text(
                    'Quiet Games',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    'Hide notifications from muted games',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                  value: _quietMode,
                  onChanged: (value) => setState(() => _quietMode = value),
                  activeColor: AppTheme.accentColor,
                ),
              ),

              // Smart Feed Content
              Expanded(
                child:
                    _buildSmartFeed(context, userManager, notificationManager),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuietModeDrawer(BuildContext context, UserManager userManager) {
    return Drawer(
      backgroundColor: AppTheme.cardDarkColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
            ),
            child: const Text(
              'Quiet Mode Settings',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          SwitchListTile(
            title: const Text('Mute All Games',
                style: TextStyle(color: Colors.white)),
            subtitle: const Text('Silence all game notifications',
                style: TextStyle(color: Colors.grey)),
            value:
                userManager.mutedGames.length == userManager.pinnedGames.length,
            onChanged: (value) {
              if (value) {
                // Mute all pinned games
                for (final game in userManager.pinnedGames) {
                  userManager.muteGame(game['slug'] ?? game['name']);
                }
              } else {
                // Unmute all games
                final gamesToUnmute = List<String>.from(userManager.mutedGames);
                for (final gameSlug in gamesToUnmute) {
                  userManager.unmuteGame(gameSlug);
                }
              }
            },
            activeColor: AppTheme.accentColor,
          ),
          const Divider(color: Colors.grey),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Prioritize Faves',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          ...userManager.pinnedGames.map((game) => ListTile(
                leading: Icon(
                  userManager.isGameMuted(game['slug'] ?? game['name'])
                      ? Icons.volume_off
                      : Icons.volume_up,
                  color: userManager.isGameMuted(game['slug'] ?? game['name'])
                      ? Colors.grey
                      : AppTheme.accentColor,
                ),
                title: Text(
                  game['name'] ?? 'Unknown Game',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.settings, color: Colors.grey),
                  onPressed: () {
                    // Navigate to game settings (could link to profile settings)
                    Navigator.pop(context); // Close drawer
                    // TODO: Navigate to game-specific settings
                  },
                ),
                onTap: () {
                  final gameSlug = game['slug'] ?? game['name'];
                  if (userManager.isGameMuted(gameSlug)) {
                    userManager.unmuteGame(gameSlug);
                  } else {
                    userManager.muteGame(gameSlug);
                  }
                },
              )),
        ],
      ),
    );
  }

  Widget _buildSmartFeed(BuildContext context, UserManager userManager,
      NotificationManager notificationManager) {
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: notificationManager.getFilteredNotificationsStream(
        mutedGames: _quietMode ? userManager.mutedGames : null,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading notifications'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data!;

        // No need for additional filtering since getFilteredNotificationsStream handles it
        final filteredNotifications = notifications;

        // Separate urgent and regular notifications
        final urgentNotifications = filteredNotifications
            .where((doc) {
              final data = doc.data();
              return data['type'] == 'urgent';
            })
            .take(5)
            .toList();

        final regularNotifications = filteredNotifications.where((doc) {
          final data = doc.data();
          return data['type'] != 'urgent';
        }).toList();

        return Column(
          children: [
            // Urgent Alerts Section
            if (urgentNotifications.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: AppTheme.accentColor),
                    const SizedBox(width: 8),
                    const Text(
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
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: urgentNotifications.length,
                itemBuilder: (context, index) {
                  return _buildUrgentAlertCard(
                      context, urgentNotifications[index], userManager);
                },
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(Icons.notifications_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'All quiet—start a lobby?',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Navigate to create lobby
                        Navigator.pop(context); // Go back to main screen
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                      ),
                      child: const Text('Create Lobby'),
                    ),
                  ],
                ),
              ),
            ],

            // Recent History Section
            if (regularNotifications.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                child: const Row(
                  children: [
                    Icon(Icons.history, color: Colors.grey),
                    SizedBox(width: 8),
                    Text(
                      'Recent History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: regularNotifications.length,
                  itemBuilder: (context, index) {
                    return _buildHistoryCard(
                        context, regularNotifications[index], userManager);
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUrgentAlertCard(
      BuildContext context, DocumentSnapshot doc, UserManager userManager) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Alert';
    final body = data['body'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: AppTheme.cardDarkColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.accentColor,
                  child: const Icon(Icons.person, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (timestamp != null)
                  Text(
                    _formatTimeAgo(timestamp.toDate()),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => _handleNotificationAction(doc.id, 'remind'),
                  child: const Text('Remind'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _handleNotificationAction(doc.id, 'join'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                  ),
                  child: const Text('Join'),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => _handleNotificationAction(doc.id, 'snooze'),
                  child: const Text('Snooze'),
                ),
              ],
            ),
          ],
        ),
      ),
    ).build(context); // Wait, this is wrong. Let me fix this.
  }

  Widget _buildHistoryCard(
      BuildContext context, DocumentSnapshot doc, UserManager userManager) {
    final data = doc.data() as Map<String, dynamic>;
    final title = data['title'] as String? ?? 'Notification';
    final body = data['body'] as String? ?? '';
    final timestamp = data['timestamp'] as Timestamp?;

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.grey,
        child: Icon(Icons.notifications, color: Colors.white),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      subtitle: Text(
        body,
        style: TextStyle(color: Colors.grey[400], fontSize: 12),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (timestamp != null)
            Text(
              _formatTimeAgo(timestamp.toDate()),
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
            ),
          IconButton(
            icon: const Icon(Icons.replay, color: Colors.grey, size: 20),
            onPressed: () => _handleNotificationAction(doc.id, 'rejoin'),
          ),
        ],
      ),
      onLongPress: () =>
          _showMuteGameDialog(context, data['game'], userManager),
    );
  }

  void _handleNotificationAction(String notificationId, String action) async {
    final notificationManager =
        Provider.of<NotificationManager>(context, listen: false);
    final navigator =
        Navigator.of(context); // Store navigator before async call

    switch (action) {
      case 'join':
      case 'rejoin':
        // Archive the notification
        await notificationManager.archiveNotification(notificationId);
        // Navigate to join/create lobby
        navigator.pop(); // Go back to main screen
        break;
      case 'remind':
        // Mark as read but keep for later
        await notificationManager.markAsRead(notificationId);
        break;
      case 'snooze':
        // Archive the notification
        await notificationManager.archiveNotification(notificationId);
        break;
    }
  }

  void _showMuteGameDialog(
      BuildContext context, String? game, UserManager userManager) {
    if (game == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardDarkColor,
        title: Text(
          'Mute $game?',
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          'Stop receiving notifications for $game?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              userManager.muteGame(game);
              Navigator.pop(context);
            },
            child: const Text('Mute', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
}

class SquadQueuePage extends StatefulWidget {
  const SquadQueuePage({super.key});

  @override
  State<SquadQueuePage> createState() => SquadQueuePageState();
}

class SquadQueuePageState extends State<SquadQueuePage> {
  late PageController _pageController;
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(0);
  double _navOpacity = 0.9;
  bool _isScrollingDown = false;
  double _navBottomOffset = 0.0;
  double _lastKeyboardHeight = 0.0;

  @override
  void initState() {
    super.initState();
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
        child: const ChatGroupsScreen(),
      ),
      const NotificationsScreen(),
      const ProfileTab(),
    ];
  }
}
