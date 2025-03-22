import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'squad_queue_logic.dart';
import 'chat/chat_screen.dart';
import 'squad_tab.dart';
import 'availability_tab.dart';
import 'performance_hub_tab.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
    statusBarIconBrightness: Brightness.light,
  ));
}

class SquadQueuePage extends StatefulWidget {
  final String yourName;
  const SquadQueuePage({super.key, required this.yourName});

  @override
  SquadQueuePageState createState() => SquadQueuePageState();
}

class SquadQueuePageState extends State<SquadQueuePage> {
  late SquadQueueLogic logic;
  late PageController _pageController;
  int _selectedIndex = 2;
  bool _isNavBarVisible = false;
  bool _isSwiping = false;
  double _navBarBottomPosition = -86; // Off-screen position (height + padding)

  @override
  void initState() {
    super.initState();
    logic = SquadQueueLogic(yourName: widget.yourName);
    logic.initState(context);
    _pageController = PageController(initialPage: _selectedIndex);
    _pageController.addListener(_handlePageChange);
  }

  @override
  void dispose() {
    _pageController.removeListener(_handlePageChange);
    _pageController.dispose();
    logic.dispose();
    super.dispose();
  }

  void _handlePageChange() {
    int newIndex = _pageController.page?.round() ?? _selectedIndex;
    if (newIndex != _selectedIndex) {
      setState(() {
        _selectedIndex = newIndex;
        _isNavBarVisible = true;
        _navBarBottomPosition = 16; // Slide in
      });
      HapticFeedback.lightImpact();
      // Hide the nav bar after a 2-second delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && !_isSwiping) {
          setState(() {
            _isNavBarVisible = false;
            _navBarBottomPosition = -86; // Slide out
          });
        }
      });
    }
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _isNavBarVisible = true;
      _navBarBottomPosition = 16; // Slide in
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    HapticFeedback.lightImpact();
    // Hide the nav bar after a 2-second delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isNavBarVisible = false;
          _navBarBottomPosition = -86; // Slide out
        });
      }
    });
  }

  void _onDragStart(DragStartDetails details) {
    setState(() {
      _isSwiping = true;
      _isNavBarVisible = true;
      _navBarBottomPosition = 16; // Slide in
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isNavBarVisible) {
      setState(() {
        _isNavBarVisible = true;
        _navBarBottomPosition = 16; // Slide in
      });
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _isSwiping = false;
    });
    // Hide the nav bar after a 2-second delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isSwiping) {
        setState(() {
          _isNavBarVisible = false;
          _navBarBottomPosition = -86; // Slide out
        });
      }
    });
  }

  void _onDoubleTap() {
    setState(() {
      _isNavBarVisible = true;
      _navBarBottomPosition = 16; // Slide in
    });
    HapticFeedback.lightImpact();
    // Hide the nav bar after a 2-second delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isSwiping) {
        setState(() {
          _isNavBarVisible = false;
          _navBarBottomPosition = -86; // Slide out
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.black,
                  _selectedIndex == 2
                      ? Colors.indigo.withOpacity(0.8)
                      : Colors.indigo,
                  if (_selectedIndex == 2) Colors.cyanAccent.withOpacity(0.2),
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: GestureDetector(
                onHorizontalDragStart: _onDragStart,
                onHorizontalDragUpdate: _onDragUpdate,
                onHorizontalDragEnd: _onDragEnd,
                onDoubleTap: _onDoubleTap, // Added double-tap gesture
                child: PageView(
                  controller: _pageController,
                  children: _buildPages(),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: 16,
            right: 16,
            bottom: _navBarBottomPosition,
            child: AnimatedOpacity(
              opacity: _isNavBarVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildTabItem(
                      iconPath: 'assets/images/performance.png',
                      index: 0,
                      size: 28,
                    ),
                    _buildTabItem(
                      iconPath: 'assets/images/availability.png',
                      index: 1,
                      size: 28,
                    ),
                    _buildPeacockTabItem(),
                    _buildTabItem(
                      iconPath: 'assets/images/chat.png',
                      index: 3,
                      size: 28,
                    ),
                    _buildTabItem(
                      iconPath: 'assets/images/placeholder.png',
                      index: 4,
                      size: 28,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPages() {
    return [
      PerformanceHubTabWrapper(logic: logic),
      AvailabilityTab(state: this),
      SquadTab(logic: logic),
      ChatScreen(yourName: widget.yourName),
      const PlaceholderTab(),
    ];
  }

  Widget _buildTabItem({
    required String iconPath,
    required int index,
    required double size,
  }) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(
              image: AssetImage(iconPath),
              width: size,
              height: size,
              color: isSelected ? null : Colors.grey[600],
            ),
            if (isSelected)
              AnimatedScale(
                scale: isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: const BoxDecoration(
                    color: Colors.cyanAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeacockTabItem() {
    bool isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => _onTabTapped(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isSelected
                    ? RadialGradient(
                        colors: [
                          Colors.cyanAccent.withOpacity(0.4),
                          Colors.transparent
                        ],
                        radius: 0.8,
                      )
                    : null,
                border: isSelected
                    ? Border.all(color: Colors.cyanAccent, width: 2)
                    : null,
              ),
              child: Center(
                child: Image(
                  image: const AssetImage('assets/images/squad.png'),
                  width: 32,
                  height: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Wrapper for PerformanceHubTab to handle swipe conflicts
class PerformanceHubTabWrapper extends StatefulWidget {
  final SquadQueueLogic logic;
  const PerformanceHubTabWrapper({super.key, required this.logic});

  @override
  State<PerformanceHubTabWrapper> createState() =>
      _PerformanceHubTabWrapperState();
}

class _PerformanceHubTabWrapperState extends State<PerformanceHubTabWrapper> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Allow horizontal swipes to be handled by the parent PageView
      onHorizontalDragStart: (details) {
        // Do nothing here; let the parent handle it
      },
      onHorizontalDragUpdate: (details) {
        // Do nothing here; let the parent handle it
      },
      onHorizontalDragEnd: (details) {
        // Do nothing here; let the parent handle it
      },
      child: PerformanceHubTab(logic: widget.logic),
    );
  }
}

class PerformanceHubTab extends StatelessWidget {
  final SquadQueueLogic logic;
  const PerformanceHubTab({super.key, required this.logic});

  List<Map<String, dynamic>> _calculateLeaderboard(List<dynamic> members) {
    // Placeholder implementation; replace with actual logic
    return members.map((member) {
      return {
        'name': member.toString(),
        'wins': 0, // Replace with actual data
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
        'LeaderboardsView building, squadMembers: ${logic.squadMembers.length}');
    final squadLeaderboard = _calculateLeaderboard(logic.squadMembers);
    // For demo purposes, global uses same data. In real app, fetch from server
    final globalLeaderboard = squadLeaderboard;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Squad Leaderboard',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (squadLeaderboard.isEmpty)
              const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...squadLeaderboard.map(
                (entry) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.cyanAccent),
                  title: Text(entry['name'],
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${entry['wins']} wins',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Global Leaderboard',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            if (globalLeaderboard.isEmpty)
              const Center(
                child: Text(
                  'No data available',
                  style: TextStyle(color: Colors.grey),
                ),
              )
            else
              ...globalLeaderboard.map(
                (entry) => ListTile(
                  leading: const Icon(Icons.person, color: Colors.cyanAccent),
                  title: Text(entry['name'],
                      style: const TextStyle(color: Colors.white)),
                  trailing: Text(
                    '${entry['wins']} wins',
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'we can stop them\nwe can make them suffer',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 24,
          fontWeight: FontWeight.w300,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
