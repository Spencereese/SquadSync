import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:badges/badges.dart' as badges;
import 'chat/chat_groups_screen.dart';
import 'screens/squad_tab_screen.dart';
import 'app_theme.dart';
import 'managers/notification_manager.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    SquadTabScreen(), // Squad management and lobbies
    ChatGroupsScreen(), // Chat groups and messaging
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String label,
    required Stream<int> badgeCountStream,
  }) {
    return StreamBuilder<int>(
      stream: badgeCountStream,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        final hasBadge = count > 0;

        return badges.Badge(
          badgeContent: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          badgeStyle: badges.BadgeStyle(
            badgeColor: Colors.red,
            padding: const EdgeInsets.all(4),
          ),
          showBadge: hasBadge,
          position: badges.BadgePosition.topEnd(top: -8, end: -8),
          child: Icon(icon),
        );
      },
    );
  }

  Stream<int> _getUnreadNotificationCount() {
    return Provider.of<NotificationManager>(context, listen: false)
        .getUnreadNotificationCount();
  }

  Stream<int> _getUnreadChatCount() {
    // TODO: Implement proper chat notification counting
    // For now, return 0 - this should be connected to actual unread message count
    return Stream.value(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
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
        child: BottomNavigationBar(
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: _buildNavigationItem(
                icon: Icons.group,
                label: 'Squad',
                badgeCountStream: _getUnreadNotificationCount(),
              ),
              label: 'Squad',
            ),
            BottomNavigationBarItem(
              icon: _buildNavigationItem(
                icon: Icons.chat,
                label: 'Chat',
                badgeCountStream: _getUnreadChatCount(),
              ),
              label: 'Chat',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: AppTheme.accentColor,
          unselectedItemColor: Colors.white70,
          backgroundColor: Colors.black,
          onTap: _onItemTapped,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
        ),
      ),
    );
  }
}
