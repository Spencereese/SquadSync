import 'package:flutter/material.dart';
import 'squad_queue_logic.dart';
import 'chat/chat_screen.dart';
import 'squad_tab.dart';
import 'availability_tab.dart';
import 'performance_hub_tab.dart';

class SquadQueuePage extends StatefulWidget {
  final String yourName;
  const SquadQueuePage({super.key, required this.yourName});

  @override
  SquadQueuePageState createState() => SquadQueuePageState();
}

class SquadQueuePageState extends State<SquadQueuePage> {
  late SquadQueueLogic logic;
  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    logic = SquadQueueLogic(yourName: widget.yourName);
    logic.initState(context);
  }

  @override
  void dispose() {
    logic.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.black, Colors.indigo],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height:
                    MediaQuery.of(context).size.height - kToolbarHeight - 64,
                child: _buildPages()[_selectedIndex],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 64,
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildTabItem(
                      iconPath: 'assets/images/performance.png',
                      index: 0,
                      size: 32),
                  _buildTabItem(
                      iconPath: 'assets/images/availability.png',
                      index: 1,
                      size: 32),
                  _buildPeacockTabItem(),
                  _buildTabItem(
                      iconPath: 'assets/images/chat.png', index: 3, size: 32),
                  _buildTabItem(
                      iconPath: 'assets/images/placeholder.png',
                      index: 4,
                      size: 32),
                ],
              ),
            ),
          ),
        ],
      ),
      appBar: AppBar(title: const Text('SquadSync')),
    );
  }

  List<Widget> _buildPages() {
    return [
      PerformanceHubTab(logic: logic),
      AvailabilityTab(state: this),
      SquadTab(logic: logic), // Ensure ONLY logic is passed
      ChatScreen(yourName: widget.yourName),
      const PlaceholderTab(),
    ];
  }

  Widget _buildTabItem(
      {required String iconPath, required int index, required double size}) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
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
            Container(
              width: size,
              height: 2,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.5),
                    blurRadius: 4,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeacockTabItem() {
    bool isSelected = _selectedIndex == 2;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: Image(
              image: AssetImage('assets/images/squad.png'),
              fit: BoxFit.contain,
            ),
          ),
          if (isSelected)
            Container(
              width: 52,
              height: 2,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: Colors.cyanAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withValues(alpha: 0.6),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class PlaceholderTab extends StatelessWidget {
  const PlaceholderTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'we can stop them\nwe can make them suffer',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}
