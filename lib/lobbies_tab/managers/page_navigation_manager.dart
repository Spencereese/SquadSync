import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PageNavigationManager {
  late PageController pageController;
  final ValueNotifier<int> selectedIndexNotifier = ValueNotifier<int>(0);

  PageNavigationManager() {
    pageController = PageController(initialPage: selectedIndexNotifier.value);
    pageController.addListener(_handlePageChange);
  }

  void dispose() {
    pageController.removeListener(_handlePageChange);
    pageController.dispose();
    selectedIndexNotifier.dispose();
  }

  void _handlePageChange() {
    int newIndex = pageController.page?.round() ?? selectedIndexNotifier.value;
    if (newIndex != selectedIndexNotifier.value) {
      selectedIndexNotifier.value = newIndex;
      HapticFeedback.lightImpact();
      onPageChanged?.call(newIndex);
    }
  }

  void onTabTapped(int index, VoidCallback? onPageChanged) {
    if (index != selectedIndexNotifier.value) {
      selectedIndexNotifier.value = index;
      pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutSine,
      );
      HapticFeedback.lightImpact();
      onPageChanged?.call();
    }
  }

  Function(int)? onPageChanged;
}
