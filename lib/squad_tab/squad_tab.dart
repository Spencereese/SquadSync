import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import 'spot_widgets.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';
import '../no_squad_screen.dart';

class SquadTab extends StatelessWidget {
  const SquadTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const _SquadTabContent();
  }
}

class _SquadTabContent extends StatefulWidget {
  const _SquadTabContent();

  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends State<_SquadTabContent> {
  bool _showPeacockMembers = false;
  late BuildContext _currentContext;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentContext = context;
    final squadState = Provider.of<SquadState>(_currentContext, listen: false);
    if (squadState.context == null) {
      squadState.initialize(_currentContext);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        if (squadState.selectedSquadId == null) {
          return const NoSquadScreen();
        }
        return Scaffold(
          appBar: AppBar(
            title: _buildSquadSelector(squadState),
            backgroundColor: Colors.black,
            elevation: 0,
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              // Force a state refresh if needed; currently, Firestore listener handles updates
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: _buildHeader(context, squadState),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => SpotWidgets.buildSpotCard(
                        context,
                        index,
                        squadState,
                        _showSpotAssignmentMenu,
                        _assignOtherMember),
                    childCount: squadState.currentGame?['maxSpots'] ?? 4,
                  ),
                ),
                SliverToBoxAdapter(
                  child: PeacockWidgets.buildPeacockSpot(
                      context, squadState, _togglePeacockMembers),
                ),
                if (_showPeacockMembers)
                  SliverToBoxAdapter(
                    child: PeacockWidgets.buildPeacockMembersList(
                        context, squadState, _togglePeacockMember),
                  ),
                SliverToBoxAdapter(
                  child: _buildActionButtons(context, squadState),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Semantics(
                      label: 'Squad Members List',
                      child: Text(
                        'Squad Members:',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(color: Colors.cyanAccent),
                      ),
                    ),
                  ),
                ),
                if (squadState.getFilteredMembers.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('No squad members yet',
                          style: TextStyle(color: Colors.grey)),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.grey[900],
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: squadState.getFilteredMembers.length,
                        itemBuilder: (context, index) {
                          final player = squadState.getFilteredMembers[index];
                          return MemberWidgets.buildMemberCard(
                              context,
                              player,
                              squadState,
                              _showBlockDialog,
                              _showJoinLobbyDialog,
                              _showComplaintDialog);
                        },
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 80.0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SquadState squadState) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Semantics(
              label: 'Squad Title',
              child: Text(
                'Squad',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
              ),
            ),
            // Centered game logo
            Expanded(
              child: Center(
                child: _buildGameDropdown(context, squadState),
              ),
            ),
            Semantics(
              label: 'Open squad settings',
              child: IconButton(
                icon: Image.asset(
                  'assets/images/settings_gear.png',
                  width: 28,
                  height: 28,
                  color: Colors.grey[400],
                ),
                onPressed: () =>
                    SquadDialogs.showSettingsDialog(context, squadState),
                tooltip: 'Settings',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSquadSelector(SquadState squadState) {
    if (squadState.userSquadIds.length <= 1) {
      return Text(
        squadState.currentSquad?['name'] ?? 'Squad',
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 20),
      );
    }

    return DropdownButton<String>(
      value: squadState.selectedSquadId,
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.cyanAccent, fontSize: 20),
      underline: Container(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
      items: squadState.userSquadIds.map((squadId) {
        final squad = squadState.getSquadById(squadId);
        return DropdownMenuItem<String>(
          value: squadId,
          child: Text(squad?['name'] ?? 'Unknown Squad'),
        );
      }).toList(),
      onChanged: (String? newSquadId) {
        if (newSquadId != null && newSquadId != squadState.selectedSquadId) {
          squadState.selectSquad(newSquadId);
        }
      },
    );
  }

  Widget _buildGameDropdown(BuildContext context, SquadState squadState) {
    return GestureDetector(
      onTap: () => _showGameSelectionMenu(context, squadState),
      child: SizedBox(
        width: 160,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Current game logo
            squadState.currentGame?['logo'] != null
                ? Image.asset(
                    squadState.currentGame!['logo'],
                    width: 160,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.gamepad,
                        size: 100,
                        color: Colors.cyanAccent),
                  )
                : const Icon(
                    Icons.gamepad,
                    size: 100,
                    color: Colors.cyanAccent,
                  ),
            // Arrow indicator positioned at bottom center of logo
            Positioned(
              bottom: 0,
              child: Icon(
                Icons.keyboard_arrow_down,
                color: Colors.cyanAccent,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGameSelectionMenu(BuildContext context, SquadState squadState) {
    // Deduplicate games while preserving order
    List<Map<String, dynamic>> uniqueGames = [];
    Set<String> seenKeys = <String>{};
    for (final game in squadState.availableGames) {
      final key = '${game['name']}_${game['maxSpots']}';
      if (seenKeys.add(key)) {
        uniqueGames.add(game);
      }
    }

    // Sort games: active games (with players) first, then by player count descending
    uniqueGames.sort((a, b) {
      final aName = a['name'] as String;
      final bName = b['name'] as String;
      final aPlayers = squadState.gameSquadSpots[aName]
              ?.where((spot) => spot != null)
              .length ??
          0;
      final bPlayers = squadState.gameSquadSpots[bName]
              ?.where((spot) => spot != null)
              .length ??
          0;

      // Active games first
      if (aPlayers > 0 && bPlayers == 0) return -1;
      if (aPlayers == 0 && bPlayers > 0) return 1;

      // Then by player count descending
      if (aPlayers != bPlayers) return bPlayers.compareTo(aPlayers);

      // Finally by name
      return aName.compareTo(bName);
    });

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          builder: (_, controller) => Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    colors: [Colors.grey, Colors.black],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '🎮 Select Game',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.white, size: 28),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              // Game list
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: uniqueGames.length +
                      2, // +1 for "Solo Gaming", +1 for "Add Game" option
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      // Solo Gaming option
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.greenAccent.withValues(alpha: 0.3),
                                  Colors.green.withValues(alpha: 0.3)
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.greenAccent,
                              size: 28,
                            ),
                          ),
                          title: const Text(
                            'Solo Gaming',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Play solo without selecting a game',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          onTap: () {
                            squadState.startSoloGame();
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Started solo gaming!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          },
                        ),
                      );
                    } else if (index == uniqueGames.length + 1) {
                      // Add game option
                      return Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.greenAccent.withValues(alpha: 0.3),
                                  Colors.green.withValues(alpha: 0.3)
                                ],
                              ),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.greenAccent,
                              size: 28,
                            ),
                          ),
                          title: const Text(
                            'Add a Game',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: const Text(
                            'Create a new custom game',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          trailing: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.greenAccent,
                            size: 16,
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            SquadDialogs.showAddGameDialog(context, squadState);
                          },
                        ),
                      );
                    }

                    final game = uniqueGames[index - 1];
                    final isSelected =
                        game['name'] == squadState.currentGame?['name'];
                    final isMuted = squadState.isGameMuted(game['name']);

                    // Extract game type from description
                    String gameType = 'Custom Game';
                    final description = game['description'] ?? '';
                    if (description.contains(' - ')) {
                      gameType = description.split(' - ').last;
                    } else if (description.isNotEmpty) {
                      // If no " - " separator, use the whole description as type
                      gameType = description;
                    }

                    // Get current player count
                    final gameName = game['name'] as String;
                    final currentPlayers = squadState.gameSquadSpots[gameName]
                            ?.where((spot) => spot != null)
                            .length ??
                        0;
                    final maxPlayers = game['maxSpots'] as int;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.cyanAccent.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.cyanAccent
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Tooltip(
                        message: 'Tap to select game',
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.grey,
                                width: 2,
                              ),
                              gradient: LinearGradient(
                                colors: isSelected
                                    ? [
                                        Colors.cyanAccent
                                            .withValues(alpha: 0.3),
                                        Colors.blueAccent.withValues(alpha: 0.3)
                                      ]
                                    : [
                                        Colors.grey.withValues(alpha: 0.3),
                                        Colors.grey.withValues(alpha: 0.5)
                                      ],
                              ),
                            ),
                            child: Icon(
                              Icons.gamepad,
                              size: 24,
                              color: Colors.cyanAccent,
                            ),
                          ),
                          title: Text(
                            game['name'],
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              shadows: [
                                Shadow(
                                  color:
                                      Colors.cyanAccent.withValues(alpha: 0.5),
                                  offset: const Offset(0, 0),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$currentPlayers/$maxPlayers Players',
                                style: TextStyle(
                                  color: currentPlayers > 0
                                      ? Colors.greenAccent
                                      : Colors.cyanAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                gameType,
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(
                                  isMuted
                                      ? Icons.notifications_off
                                      : Icons.notifications,
                                  color:
                                      isMuted ? Colors.redAccent : Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () {
                                  if (isMuted) {
                                    squadState.unmuteGame(game['name']);
                                  } else {
                                    squadState.muteGame(game['name']);
                                  }
                                  setModalState(() {}); // Trigger UI update
                                },
                                tooltip: isMuted
                                    ? 'Unmute notifications'
                                    : 'Mute notifications',
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Colors.cyanAccent),
                            ],
                          ),
                          onTap: () {
                            squadState.selectGame(game);
                            // Defer navigation to avoid _debugLocked assertion
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (Navigator.canPop(dialogContext)) {
                                Navigator.pop(dialogContext);
                              }
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, SquadState squadState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(
            onPressed: squadState.recordWin,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Win'),
          ),
          ElevatedButton(
            onPressed: squadState.recordLoss,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Loss'),
          ),
        ],
      ),
    );
  }

  void _togglePeacockMembers() {
    setState(() {
      _showPeacockMembers = !_showPeacockMembers;
    });
  }

  void _togglePeacockMember(String member, bool isInPeacock) {
    if (isInPeacock) {
      Provider.of<SquadState>(_currentContext, listen: false)
          .removeFromPeacock(member);
    } else {
      Provider.of<SquadState>(_currentContext, listen: false)
          .addToPeacock(member);
    }
    setState(() {});
  }

  void _showBlockDialog(
      BuildContext context, String player, SquadState squadState) {
    SquadDialogs.showBlockDialog(context, player, squadState);
  }

  void _showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, SquadState squadState, String player) {
    SquadDialogs.showComplaintDialog(context, messenger, squadState, player);
  }

  void _showJoinLobbyDialog(
      BuildContext context, String player, SquadState squadState) {
    SquadDialogs.showJoinLobbyDialog(context, player, squadState);
  }

  void _showSpotAssignmentMenu(
      BuildContext context, SquadState squadState, int index) {
    SquadDialogs.showSpotAssignmentMenu(context, squadState, index);
  }

  void _assignOtherMember(
      BuildContext context, SquadState squadState, int index) {
    final yourName = squadState.displayName;
    final availablePlayers = squadState.getFilteredMembers
        .where((player) =>
            player != yourName && !squadState.squadSpots.contains(player))
        .toList();

    if (availablePlayers.isNotEmpty) {
      _showSpotAssignmentMenu(context, squadState, index);
    }
  }
}
