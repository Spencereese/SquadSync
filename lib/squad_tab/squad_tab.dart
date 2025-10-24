import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../squad_state.dart';
import '../managers/game_manager.dart';
import '../managers/squad_manager.dart';
import 'spot_widgets.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';
import '../no_squad_screen.dart';
import '../create_squad_screen.dart';

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

    // Set currentGame if gameName is provided but currentGame is not set or doesn't match
    if (widget.gameName != null) {
      final gameManager =
          Provider.of<GameManager>(_currentContext, listen: false);
      if (squadState.currentGame == null ||
          squadState.currentGame!['name'] != widget.gameName) {
        // Try to find the game in available games
        final game = gameManager.availableGames.firstWhere(
          (g) => g['name'] == widget.gameName,
          orElse: () => {'name': widget.gameName, 'maxSpots': 4},
        );
        squadState.currentGame = game;
      }
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
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.indigo],
              ),
            ),
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
                  child: _showPeacockMembers
                      ? PeacockWidgets.buildPeacockMembersList(
                          context, squadState, _togglePeacockMember)
                      : const SizedBox.shrink(),
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
                _buildMembersSection(squadState),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 80.0),
                ),
              ],
            ),
          ),
          floatingActionButton: widget.lobbyId != null
              ? _buildClaimSpotFAB(context, squadState)
              : null,
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SquadState squadState) {
    return Padding(
      padding: const EdgeInsets.only(
          top: 40.0), // Add top padding to avoid phone settings/clock
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Go back to lobby selection',
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.cyanAccent),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Back to lobbies',
                ),
              ),
              // Centered game logo - clickable to show lobby options
              Expanded(
                child: Center(
                  child: _buildGameLogo(context, squadState),
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
      ),
    );
  }

  Widget _buildGameLogo(BuildContext context, SquadState squadState) {
    Widget logo;
    final currentGame = squadState.currentGame;

    // Try to use coverUrl from IGDB API first
    if (currentGame?['coverUrl'] != null) {
      logo = Image.network(
        currentGame!['coverUrl'],
        width: 160,
        height: 100,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return const SizedBox(
            width: 160,
            height: 100,
            child: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.gamepad, size: 100, color: Colors.cyanAccent),
      );
    } else if (widget.gameName != null) {
      // Fallback to asset logo
      logo = Image.asset(
        'assets/images/${widget.gameName!.toLowerCase()}_logo.png',
        width: 160,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.gamepad, size: 100, color: Colors.cyanAccent),
      );
    } else if (currentGame?['logo'] != null) {
      // Fallback to old asset logo field
      logo = Image.asset(
        currentGame!['logo'],
        width: 160,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.gamepad, size: 100, color: Colors.cyanAccent),
      );
    } else {
      logo = const Icon(
        Icons.gamepad,
        size: 100,
        color: Colors.cyanAccent,
      );
    }

    return GestureDetector(
      onTap: () {
        if (currentGame?['igdbId'] != null || currentGame?['summary'] != null) {
          _showGameInfo(context, currentGame!);
        } else {
          _showLobbyOptions(context);
        }
      },
      child: SizedBox(
        width: 160,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [logo],
        ),
      ),
    );
  }

  void _showLobbyOptions(BuildContext context) {
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
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          builder: (_, controller) => Column(
            children: [
              // Header
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
                    const Text(
                      'Lobby Options',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: Colors.white.withValues(alpha: 0.8),
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('lobbies')
                        .where('members',
                            arrayContains:
                                FirebaseAuth.instance.currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Error loading lobbies',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7)),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                              color: Colors.cyanAccent),
                        );
                      }

                      final lobbies = snapshot.data?.docs ?? [];

                      return Column(
                        children: [
                          // Active Lobbies
                          if (lobbies.isNotEmpty) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Active Lobbies',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: ListView.builder(
                                controller: controller,
                                itemCount: lobbies.length,
                                itemBuilder: (context, index) {
                                  final lobby = lobbies[index].data()
                                      as Map<String, dynamic>;
                                  final lobbyId = lobbies[index].id;
                                  final gameName =
                                      lobby['gameName'] ?? 'Unknown Game';
                                  final memberCount =
                                      (lobby['members'] as List?)?.length ?? 0;

                                  return ListTile(
                                    leading: Image.asset(
                                      'assets/images/${gameName.toLowerCase()}_logo.png',
                                      width: 40,
                                      height: 40,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(Icons.gamepad,
                                                  color: Colors.cyanAccent),
                                    ),
                                    title: Text(
                                      gameName,
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                    subtitle: Text(
                                      '$memberCount members',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7)),
                                    ),
                                    onTap: () {
                                      Navigator.pop(dialogContext);
                                      // Navigate to the lobby
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => SquadTab(
                                            lobbyId: lobbyId,
                                            gameName: gameName,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                          // Create New Lobby Button
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                // Navigate to create new lobby screen
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const CreateSquadScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Create New Lobby'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
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

  void _showGameInfo(BuildContext context, Map<String, dynamic> game) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: Text(
          game['name'] ?? 'Game Info',
          style: const TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (game['coverUrl'] != null) ...[
                Center(
                  child: Image.network(
                    game['coverUrl'],
                    height: 150,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.gamepad,
                        size: 100,
                        color: Colors.cyanAccent),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (game['summary'] != null && game['summary'].isNotEmpty) ...[
                const Text(
                  'Description:',
                  style: TextStyle(
                    color: Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  game['summary'],
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
              ],
              if (game['releaseDate'] != null) ...[
                Text(
                  'Release Date: ${game['releaseDate'].year}-${game['releaseDate'].month.toString().padLeft(2, '0')}-${game['releaseDate'].day.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
              ],
              if (game['genres'] != null &&
                  (game['genres'] as List).isNotEmpty) ...[
                Text(
                  'Genres: ${(game['genres'] as List).join(', ')}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:
                const Text('Close', style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
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

  Widget _buildMembersSection(SquadState squadState) {
    if (squadState.getFilteredMembers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('No squad members yet',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    } else {
      return SliverToBoxAdapter(
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
              return MemberWidgets.buildMemberCard(context, player, squadState,
                  _showBlockDialog, _showJoinLobbyDialog, _showComplaintDialog);
            },
          ),
        ),
      );
    }
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

  Widget _buildClaimSpotFAB(BuildContext context, SquadState squadState) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peacocks')
          .doc(widget.lobbyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final peacockData = snapshot.data!.data() as Map<String, dynamic>;
        final filled =
            List<Map<String, dynamic>>.from(peacockData['filled'] ?? []);
        final userSpot = filled.firstWhere(
          (f) => f['uid'] == FirebaseAuth.instance.currentUser?.uid,
          orElse: () => <String, dynamic>{},
        );

        if (userSpot.isNotEmpty) {
          final status = userSpot['status'];
          if (status == 'ready') {
            return FloatingActionButton.extended(
              onPressed: () => _lockSpot(context, squadState),
              backgroundColor: Colors.yellowAccent,
              icon: const Icon(Icons.lock),
              label: const Text('Lock Spot'),
            );
          }
          return const SizedBox.shrink();
        } else {
          // Show Claim Spot button
          return FloatingActionButton.extended(
            onPressed: () => _claimSpot(context, squadState),
            backgroundColor: Colors.cyanAccent,
            icon: const Icon(Icons.add),
            label: const Text('Claim Spot'),
          );
        }
      },
    );
  }

  Future<void> _claimSpot(BuildContext context, SquadState squadState) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.lobbyId == null) return;

    try {
      final squadManager = Provider.of<SquadManager>(context, listen: false);
      await squadManager.claimPeacockSpot(
          widget.lobbyId!, user.uid, widget.gameName!);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot claimed!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to claim spot: $e')),
      );
    }
  }

  Future<void> _lockSpot(BuildContext context, SquadState squadState) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.lobbyId == null) return;

    try {
      final squadManager = Provider.of<SquadManager>(context, listen: false);
      await squadManager.lockPeacockSpot(
          widget.lobbyId!, user.uid, widget.gameName!);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot locked!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to lock spot: $e')),
      );
    }
  }
}
