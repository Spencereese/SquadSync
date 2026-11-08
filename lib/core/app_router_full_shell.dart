import 'package:flutter/material.dart';

import '../screens/discovery_swipe_screen.dart';

/// Full-shell Discovery swipe host. Friends entrypoints import this graph
/// instead of `discovery_swipe_screen.dart` so the compile-out lease holds.
class FullShellDiscoverySwipePage extends StatelessWidget {
  const FullShellDiscoverySwipePage({super.key});

  @override
  Widget build(BuildContext context) => const DiscoverySwipeScreen();
}
