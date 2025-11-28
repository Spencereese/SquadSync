import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat/chat_groups_screen.dart' as chat_groups;
import '../screens/notifications_screen.dart';
import '../app_theme.dart';
import '../presentation/notifiers/squad_notifier.dart' as sn;
import 'widgets/bottom_navigation_widget.dart';
import 'widgets/loading_screen_widget.dart';
import 'mixins/keyboard_handler.dart';
import 'managers/page_navigation_manager.dart';
import '../profile_tab.dart';

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
    ref.read(sn.squadNotifierProvider.notifier).clearNotifications(index);
  }

  bool _updateNavOpacity(ScrollNotification notification) {
    return updateNavOpacity(notification);
  }

  @override
  Widget build(BuildContext context) {
    final squadAsync = ref.watch(sn.squadNotifierProvider);
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return squadAsync.when(
      data: (squadState) {
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
                  selectedIndexNotifier:
                      _navigationManager.selectedIndexNotifier,
                  navOpacity: navOpacity,
                  navBottomOffset: navBottomOffset,
                  squadState: squadState,
                  onTabTapped: _onTabTapped,
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const LoadingScreenWidget(),
      error: (error, stack) => Center(child: Text('Error: $error')),
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
