import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../chat/chat_screen.dart';
import 'squad_tab.dart';
import '../Availability/availability_tab.dart';
import 'package:cod_squad_app/performance_hub_tab.dart';
import '../settings_tab.dart';
import '../app_theme.dart';
import 'package:cod_squad_app/squad_state.dart';

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
  SquadQueuePageState createState() => SquadQueuePageState();
}

class SquadQueuePageState extends State<SquadQueuePage> {
  late PageController _pageController;
  final ScrollController _tabController = ScrollController();
  final ValueNotifier<int> _selectedIndexNotifier = ValueNotifier<int>(2);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndexNotifier.value);
    _pageController.addListener(_handlePageChange);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    _tabController.dispose();
    _selectedIndexNotifier.dispose();
    super.dispose();
  }

  void _handlePageChange() {
    int newIndex =
        _pageController.page?.round() ?? _selectedIndexNotifier.value;
    if (newIndex != _selectedIndexNotifier.value) {
      _selectedIndexNotifier.value = newIndex;
      _scrollToTab(newIndex);
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
      _scrollToTab(index);
      HapticFeedback.lightImpact();
      _clearNotification(index);
    }
  }

  void _scrollToTab(int index) {
    double offset =
        index * 80.0 - (MediaQuery.of(context).size.width - 130) / 2;
    _tabController.animateTo(
      offset.clamp(0, _tabController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutSine,
    );
  }

  void _clearNotification(int index) {
    final squadState = Provider.of<SquadState>(context, listen: false);
    squadState.clearNotifications(index);
  }

  @override
  Widget build(BuildContext context) {
    final squadState = Provider.of<SquadState>(context);
    final double screenHeight = MediaQuery.of(context).size.height;
    final double navHeight = screenHeight < 600
        ? 90
        : screenHeight > 800
            ? 120
            : 90 + (screenHeight - 600) / (800 - 600) * (120 - 90);
    const double selectedWidth = 130;
    const double inactiveWidth = 75;

    return Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        body: AnimatedContainer(
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
          child: SafeArea(
            child: Column(
              children: [
                Container(
                  height: navHeight,
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.8, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _selectedIndexNotifier,
                      builder: (context, selectedIndex, child) {
                        return ListView.builder(
                          controller: _tabController,
                          scrollDirection: Axis.horizontal,
                          itemCount: 5,
                          itemBuilder: (context, index) => _buildTabCard(
                            index,
                            selectedIndex: selectedIndex,
                            selectedWidth: selectedWidth,
                            inactiveWidth: inactiveWidth,
                            navHeight: navHeight,
                            squadState: squadState,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    children: _buildPages(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabCard(int index,
      {required int selectedIndex,
      required double selectedWidth,
      required double inactiveWidth,
      required double navHeight,
      required SquadState squadState}) {
    bool isSelected = selectedIndex == index;
    final tabs = [
      {'icon': 'assets/images/performance.png', 'label': 'Performance'},
      {'icon': 'assets/images/availability.png', 'label': 'Availability'},
      {'icon': 'assets/images/squad.png', 'label': 'Squad'},
      {'icon': 'assets/images/chat.png', 'label': 'Chat'},
      {'icon': 'assets/images/settings.png', 'label': 'Settings'},
    ];
    bool hasNotification = !isSelected &&
        ((index == 1 && squadState.hasNewAvailability) ||
            (index == 2 && squadState.hasNewSquadSpot) ||
            (index == 3 && squadState.hasUnreadMessages));

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutSine,
        width: isSelected ? selectedWidth : inactiveWidth,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Transform.rotate(
          angle: isSelected && squadState.tiltEnabled ? 4 * math.pi / 180 : 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.backgroundColor.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentColor.withValues(alpha: 1.0)
                        : AppTheme.hintColor.withValues(alpha: 0.5),
                    width: isSelected ? 1 : 0.5,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: AppTheme.accentColor.withValues(alpha: 0.2),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 2,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: HexPatternPainter(),
                          child: Container(),
                        ),
                      ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: isSelected
                                    ? AppTheme.accentColor
                                        .withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.1),
                                blurRadius: 2,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            tabs[index]['icon']!,
                            width: isSelected ? 36 : 24,
                            height: isSelected ? 36 : 24,
                            color: isSelected
                                ? AppTheme.accentColor
                                : AppTheme.hintColor,
                          ),
                        ),
                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              tabs[index]['label']!,
                              style: AppTheme.darkTheme.textTheme.titleLarge!
                                  .copyWith(
                                fontSize: navHeight > 100 ? 15 : 13,
                                color: AppTheme.textColor,
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
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context) {
    return [
      const PerformanceHubTab(),
      const AvailabilityTab(),
      const SquadTab(),
      const ChatScreen(),
      const SettingsTab(),
    ];
  }
}

class HexPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.accentColor.withValues(alpha: 0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    const double hexSize = 10;
    final double hexWidth = hexSize * 1.732;
    final double hexHeight = hexSize * 2;

    for (double y = -hexSize;
        y < size.height + hexSize;
        y += hexHeight * 0.75) {
      for (double x = -hexSize; x < size.width + hexSize; x += hexWidth) {
        final offsetX =
            x + (y % (hexHeight * 1.5) < hexHeight * 0.75 ? hexWidth / 2 : 0);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = (math.pi / 3) * i + (math.pi / 6);
          final pointX = offsetX + hexSize * math.cos(angle);
          final pointY = y + hexSize * math.sin(angle);
          if (i == 0) {
            path.moveTo(pointX, pointY);
          } else {
            path.lineTo(pointX, pointY);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
