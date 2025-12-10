import 'package:flutter/material.dart';

mixin KeyboardHandler<T extends StatefulWidget> on State<T> {
  double navOpacity = 0.9;
  double navBottomOffset = 0.0;
  double lastKeyboardHeight = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Monitor keyboard height changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
      if (keyboardHeight != lastKeyboardHeight) {
        setState(() {
          if (keyboardHeight > 0) {
            navBottomOffset = -75.0;
            navOpacity = 0.0;
          } else {
            navBottomOffset = 0.0;
            navOpacity = 0.9;
          }
          lastKeyboardHeight = keyboardHeight;
        });
      }
    });
  }

  bool updateNavOpacity(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      setState(() {
        if (delta > 10 && !_isScrollingDown) {
          _isScrollingDown = true;
          navOpacity = 0.6;
        } else if (delta <= 0 && _isScrollingDown) {
          _isScrollingDown = false;
          navOpacity = 0.9;
        }
      });
    } else if (notification is ScrollEndNotification) {
      setState(() {
        _isScrollingDown = false;
        navOpacity = 0.9;
      });
    }
    return true;
  }

  bool _isScrollingDown = false;
}
