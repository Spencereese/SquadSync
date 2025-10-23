import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../squad_state.dart';
import 'spot_widgets.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';
import '../no_squad_screen.dart';

class SquadTab extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;

  const SquadTab({super.key, this.lobbyId, this.gameName});

  @override
  Widget build(BuildContext context) {
    return _SquadTabContent(lobbyId: lobbyId, gameName: gameName);
  }
}

class _SquadTabContent extends StatefulWidget {
  final String? lobbyId;
  final String? gameName;

  const _SquadTabContent({this.lobbyId, this.gameName});

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
    return Consumer<SquadState>(builder: (context, squadState, child) {
      if (squadState.selectedSquadId == null) {
        return const NoSquadScreen();
      }
      return Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
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
        ),
      );
    });
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
            squadState.currentGame?['coverUrl'] != null
                ? Image.network(
                    squadState.currentGame!['coverUrl'],
                    width: 160,
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        squadState.currentGame?['logo'] != null
                            ? Image.asset(
                                squadState.currentGame!['logo'],
                                width: 160,
                                height: 100,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.gamepad,
                                        size: 100, color: Colors.cyanAccent),
                              )
                            : const Icon(
                                Icons.gamepad,
                                size: 100,
                                color: Colors.cyanAccent,
                              ),
                  )
                : squadState.currentGame?['logo'] != null
                    ? Image.asset(
                        squadState.currentGame!['logo'],
                        width: 160,
                        height: 100,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.gamepad,
                                size: 100, color: Colors.cyanAccent),
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
    // Deduplicate games while preserving order and filter out muted games
    List<Map<String, dynamic>> uniqueGames = [];
    Set<String> seenKeys = <String>{};
    for (final game in squadState.availableGames) {
      final key = '${game['name']}_${game['maxSpots']}';
      if (seenKeys.add(key) && !squadState.isGameMuted(game['name'])) {
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
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, controller) => Column(
            children: [
              // Modern iOS-style header
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.1),
                      Colors.white.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Choose Game',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${uniqueGames.length} games available',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.close,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 24,
                        ),
                        onPressed: () => Navigator.pop(dialogContext),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              // Game grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    controller: controller,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.85,
                    ),
                    itemCount:
                        uniqueGames.length + 2, // +1 for Solo, +1 for Add Game
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        // Solo Gaming card
                        return _buildGameCard(
                          context: context,
                          title: 'Solo Gaming',
                          subtitle: 'Play alone',
                          icon: Icons.person,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () {
                            squadState.startSoloGame();
                            Navigator.pop(dialogContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Started solo gaming!'),
                                backgroundColor:
                                    Colors.green.withValues(alpha: 0.9),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );
                          },
                        );
                      } else if (index == uniqueGames.length + 1) {
                        // Add Game card
                        return _buildGameCard(
                          context: context,
                          title: 'Add Game',
                          subtitle: 'Create custom',
                          icon: Icons.add,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          onTap: () {
                            Navigator.pop(dialogContext);
                            SquadDialogs.showAddGameDialog(context, squadState);
                          },
                        );
                      }

                      final game = uniqueGames[index - 1];
                      final isSelected =
                          game['name'] == squadState.currentGame?['name'];

                      // Get current player count
                      final gameName = game['name'] as String;
                      final currentPlayers = squadState.gameSquadSpots[gameName]
                              ?.where((spot) => spot != null)
                              .length ??
                          0;
                      final maxPlayers = game['maxSpots'] as int;

                      // Extract game type
                      String gameType = 'Custom';
                      final description = game['description'] ?? '';
                      if (description.contains(' - ')) {
                        gameType = description.split(' - ').last;
                      }

                      return _buildGameCard(
                        context: context,
                        title: game['name'],
                        subtitle: '$currentPlayers/$maxPlayers • $gameType',
                        icon: Icons.gamepad,
                        gradient: isSelected
                            ? const LinearGradient(
                                colors: [Color(0xFF06B6D4), Color(0xFF0891B2)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.1),
                                  Colors.white.withValues(alpha: 0.05),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        isSelected: isSelected,
                        imageUrl: game['coverUrl'],
                        onTap: () {
                          squadState.selectGame(game);
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (Navigator.canPop(dialogContext)) {
                              Navigator.pop(dialogContext);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required LinearGradient gradient,
    required VoidCallback onTap,
    bool isSelected = false,
    String? imageUrl,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: -20,
              child: Icon(
                icon,
                size: 80,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon or Image
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imageUrl != null
                        ? Image.network(
                            imageUrl,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              icon,
                              color: Colors.white,
                              size: 28,
                            ),
                          )
                        : Icon(
                            icon,
                            color: Colors.white,
                            size: 28,
                          ),
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Subtitle
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            // Selection indicator
            if (isSelected)
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 16,
                  ),
                ),
              ),
          ],
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
