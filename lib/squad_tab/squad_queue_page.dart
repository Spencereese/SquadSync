import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat/chat_groups_screen.dart' as chat_groups;
import '../screens/notifications_screen.dart';
import '../profile_tab.dart';
import '../app_theme.dart';
import '../providers.dart';
import 'widgets/bottom_navigation_widget.dart';
import 'widgets/loading_screen_widget.dart';
import 'mixins/keyboard_handler.dart';
import 'managers/page_navigation_manager.dart';

class SquadQueuePage extends ConsumerStatefulWidget {
  const SquadQueuePage({super.key});

  @override
  ConsumerState<SquadQueuePage> createState() => SquadQueuePageState();
}

class SquadQueuePageState extends ConsumerState<SquadQueuePage>
    with KeyboardHandler {
  late PageNavigationManager _navigationManager;

  @override
  void initState() {
    super.initState();
    _navigationManager = PageNavigationManager();
    _navigationManager.onPageChanged = _clearNotification;
  }

  @override
  void dispose() {
    _navigationManager.dispose();
    super.dispose();
  }

  void _onTabTapped(int index) {
    _navigationManager.onTabTapped(index, () => _clearNotification(index));
  }

  void _clearNotification(int index) {
    ref.read(squadStateNotifierProvider.notifier).clearNotifications(index);
  }

  bool _updateNavOpacity(ScrollNotification notification) {
    return updateNavOpacity(notification);
  }

  @override
  Widget build(BuildContext context) {
    final squadState = ref.watch(squadStateNotifierProvider);
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    // Show loading screen while initializing or loading initial data
    if (!squadState.isInitialized || !squadState.isInitialDataLoaded) {
      return const LoadingScreenWidget();
    }

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: Stack(
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(top: 50),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DEBUG: 14 QUEUE',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black,
                    _navigationManager.selectedIndexNotifier.value == 2
                        ? AppTheme.primaryColor.withValues(alpha: 0.8)
                        : AppTheme.primaryColor,
                    if (_navigationManager.selectedIndexNotifier.value == 2)
                      AppTheme.accentColor.withValues(alpha: 0.2),
                  ],
                ),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: _updateNavOpacity,
                child: PageView(
                  controller: _navigationManager.pageController,
                  physics: const ClampingScrollPhysics(),
                  children: _buildPages(context, isKeyboardVisible),
                ),
              ),
            ),
            BottomNavigationWidget(
              selectedIndexNotifier: _navigationManager.selectedIndexNotifier,
              navOpacity: navOpacity,
              navBottomOffset: navBottomOffset,
              squadState: squadState,
              onTabTapped: _onTabTapped,
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
        child: const chat_groups.ChatGroupsScreen(),
      ),
      const NotificationsScreen(),
      const ProfileTab(),
    ];
  }
}
