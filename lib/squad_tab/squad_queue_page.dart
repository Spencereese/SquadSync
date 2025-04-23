import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../chat/chat_screen.dart';
import 'squad_tab.dart';
import '../Availability/availability_tab.dart';
import 'package:cod_squad_app/performance_hub_tab.dart';
import '../settings_tab.dart';
import '../app_theme.dart';
import '../squad_state.dart';

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
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(2);
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
    int newIndex = _pageController.page?.round() ?? _selectedIndexNotifier.value;
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
                          _buildTabItem(3, selectedIndex, squadState),
                          _buildTabItem(4, selectedIndex, squadState),
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
      'assets/images/performance.png',
      'assets/images/availability.png',
      'assets/images/squad.png',
      'assets/images/chat.png',
      'assets/images/settings.png',
    ];
    bool hasNotification = !isSelected &&
        ((index == 1 && squadState.hasNewAvailability) ||
            (index == 2 && squadState.hasNewSquadSpot) ||
            (index == 3 && squadState.hasUnreadMessages));

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset(
                  tabs[index],
                  width: 28,
                  height: 28,
                  color: isSelected ? AppTheme.accentColor : Colors.white.withValues(alpha: 0.7),
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
      const PerformanceHubTab(),
      const AvailabilityTab(),
      const SquadTab(),
      AnimatedPadding(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: EdgeInsets.only(bottom: isKeyboardVisible ? 0 : 75),
        child: const ChatScreen(),
      ),
      const SettingsTab(),
    ];
  }
}