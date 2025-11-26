import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../domain/entities/squad_state.dart';

class BottomNavigationWidget extends StatelessWidget {
  final ValueNotifier<int> selectedIndexNotifier;
  final double navOpacity;
  final double navBottomOffset;
  final SquadState squadState;
  final Function(int) onTabTapped;

  const BottomNavigationWidget({
    super.key,
    required this.selectedIndexNotifier,
    required this.navOpacity,
    required this.navBottomOffset,
    required this.squadState,
    required this.onTabTapped,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      left: 0,
      right: 0,
      bottom: navBottomOffset,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        opacity: navOpacity,
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
            valueListenable: selectedIndexNotifier,
            builder: (context, selectedIndex, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TabItemWidget(
                    index: 0,
                    selectedIndex: selectedIndex,
                    squadState: squadState,
                    onTap: onTabTapped,
                  ),
                  TabItemWidget(
                    index: 1,
                    selectedIndex: selectedIndex,
                    squadState: squadState,
                    onTap: onTabTapped,
                  ),
                  TabItemWidget(
                    index: 2,
                    selectedIndex: selectedIndex,
                    squadState: squadState,
                    onTap: onTabTapped,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class TabItemWidget extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final SquadState squadState;
  final Function(int) onTap;

  const TabItemWidget({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.squadState,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    bool isSelected = selectedIndex == index;
    final tabs = [
      'assets/images/chat.png',
      Icons.notifications,
      Icons.menu,
    ];
    bool hasNotification =
        !isSelected && (index == 0 && squadState.hasUnreadMessages);

    return GestureDetector(
      onTap: () => onTap(index),
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
}
