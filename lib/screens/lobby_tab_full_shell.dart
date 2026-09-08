import 'package:flutter/material.dart';

import 'discovery_screen.dart';

/// Full-shell lobby dashboard. [LobbyTabScreen] imports this graph instead
/// of `discovery_screen.dart` so the friends path compile-out lease holds.
class FullShellLobbyDashboard extends StatelessWidget {
  const FullShellLobbyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const KeyedSubtree(
      key: Key('lobby-discovery'),
      child: DiscoveryScreen(),
    );
  }
}
