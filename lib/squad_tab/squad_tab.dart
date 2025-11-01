import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../squad_state.dart';
import '../managers/game_manager.dart';
import '../managers/squad_manager.dart';
import '../managers/user_manager.dart';
import 'spot_widgets.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';

class SquadTab extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;

  const SquadTab({super.key, this.lobbyId, this.gameName, this.game});

  @override
  Widget build(BuildContext context) {
    return _SquadTabContent(lobbyId: lobbyId, gameName: gameName, game: game);
  }
}

class _SquadTabContent extends StatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;

  const _SquadTabContent({this.lobbyId, this.gameName, this.game});

  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends State<_SquadTabContent> {
  final bool _showPeacockMembers = false;
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
    if (widget.game != null) {
      // If we have the full game object, use it directly
      WidgetsBinding.instance.addPostFrameCallback((_) {
        squadState.currentGame = widget.game;
      });
    } else if (widget.gameName != null) {
      final gameManager =
          Provider.of<GameManager>(_currentContext, listen: false);
      final userManager =
          Provider.of<UserManager>(_currentContext, listen: false);
      if (squadState.currentGame == null ||
          squadState.currentGame!['name'] != widget.gameName) {
        // First, try to find the game in pinned games (most likely source for quick start)
        Map<String, dynamic>? game =
            userManager.pinnedGames.cast<Map<String, dynamic>?>().firstWhere(
                  (g) => g?['name'] == widget.gameName,
                  orElse: () => null,
                );

        // If not found, try case-insensitive match in pinned games
        game ??= userManager.pinnedGames
            .cast<Map<String, dynamic>?>()
            .firstWhere(
              (g) =>
                  g?['name']?.toLowerCase() == widget.gameName?.toLowerCase(),
              orElse: () => null,
            );

        // If still not found, try partial match in pinned games
        game ??=
            userManager.pinnedGames.cast<Map<String, dynamic>?>().firstWhere(
                  (g) =>
                      g?['name']
                          ?.toLowerCase()
                          .contains(widget.gameName!.toLowerCase()) ==
                      true,
                  orElse: () => null,
                );

        // If still not found, search for the game asynchronously
        if (game == null) {
          // Trigger async search without awaiting
          gameManager.searchGames(widget.gameName!).then((searchResults) {
            if (searchResults.isNotEmpty && mounted) {
              final squadState =
                  Provider.of<SquadState>(_currentContext, listen: false);
              // Only update if currentGame is still the basic fallback (has empty summary)
              if (squadState.currentGame?['summary'] == '' &&
                  squadState.currentGame?['name'] == widget.gameName) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  squadState.currentGame = searchResults.first;
                });
              }
            }
          }).catchError((e) {
            print('Error searching for game ${widget.gameName}: $e');
          });
        }

        // Use found game or create fallback
        game ??= {
          'name': widget.gameName,
          'maxSpots': 4,
          'description': 'Custom Game',
          'summary':
              '', // Ensure summary is empty so _showGameInfo doesn't show wrong description
        };

        WidgetsBinding.instance.addPostFrameCallback((_) {
          squadState.currentGame = game;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) {
        // Always show the squad spots interface, regardless of selectedSquadId
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

    // Helper to get asset name from game name
    String? getAssetName(String? gameName) {
      if (gameName == null) return null;
      final lower = gameName.toLowerCase();
      if (lower.contains('call of duty')) return 'codwarzone.png';
      if (lower.contains('battlefield')) return 'Battlefield.png';
      if (lower.contains('satisfactory')) return 'satisfactory.png';
      // Add more mappings as needed
      return '${gameName.replaceAll(' ', '').toLowerCase()}.png';
    }

    // Try to use coverUrl from IGDB API first
    if (currentGame?['coverUrl'] != null) {
      logo = Container(
        width: 160,
        height: 100,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: NetworkImage(currentGame!['coverUrl']),
            fit: BoxFit.contain,
          ),
        ),
      );
    } else {
      final assetName =
          getAssetName(currentGame?['name']) ?? getAssetName(widget.gameName);
      if (assetName != null) {
        logo = Image.asset(
          'assets/images/$assetName',
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
    }

    return GestureDetector(
      onTap: () => _showGameSelectionDialog(context, squadState),
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

  void _showGameSelectionDialog(BuildContext context, SquadState squadState) {
    final TextEditingController gameController = TextEditingController();
    Map<String, dynamic>? selectedGame;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.black.withValues(alpha: 0.9),
          title: const Text(
            'Switch Game',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: gameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Search for a game...',
                    hintStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      final gameManager =
                          Provider.of<GameManager>(context, listen: false);
                      final results = await gameManager.searchGames(value);
                      if (results.isNotEmpty) {
                        setState(() {
                          selectedGame = results.first;
                        });
                      }
                    }
                  },
                ),
                if (selectedGame != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        if (selectedGame!['coverUrl'] != null)
                          Image.network(
                            selectedGame!['coverUrl'],
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.gamepad,
                                    color: Colors.cyanAccent),
                          )
                        else
                          const Icon(Icons.gamepad,
                              color: Colors.cyanAccent, size: 50),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedGame!['name'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (selectedGame!['genres'] != null)
                                Text(
                                  (selectedGame!['genres'] as List).join(', '),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: selectedGame != null
                  ? () {
                      // Update the current game
                      squadState.currentGame = selectedGame;
                      // Mark fields as changed for persistence
                      squadState.persistenceManager
                          .markFieldChanged('currentGame');
                      squadState.updateFirestoreAsync(force: true);
                      Navigator.pop(dialogContext);
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content:
                                Text('Switched to ${selectedGame!['name']}')),
                      );
                    }
                  : null,
              child: const Text('Switch',
                  style: TextStyle(color: Colors.cyanAccent)),
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

        final data = snapshot.data!.data();
        if (data is! Map<String, dynamic>) {
          return const SizedBox.shrink();
        }
        final peacockData = data;
        final filledRaw = peacockData['filled'];
        final filled = (filledRaw is List<dynamic>)
            ? filledRaw.whereType<Map<String, dynamic>>().toList()
            : <Map<String, dynamic>>[];
        final userSpot = filled.firstWhere(
          (f) => f['uid'] == FirebaseAuth.instance.currentUser?.uid,
          orElse: () => <String, dynamic>{},
        );

        if (userSpot.isNotEmpty) {
          final status = userSpot['status'];
          if (status == 'called') {
            return FloatingActionButton.extended(
              onPressed: () => _lockSpot(context, squadState),
              backgroundColor: Colors.yellowAccent,
              icon: const Icon(Icons.lock),
              label: const Text('Lock Spot'),
            );
          } else if (status == 'ready') {
            return FloatingActionButton.extended(
              onPressed: () => _callSpot(context, squadState),
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.call),
              label: const Text('Call Spot'),
            );
          }
          return const SizedBox.shrink();
        } else {
          // Claim Spot button removed
          return const SizedBox.shrink();
        }
      },
    );
  }

  Future<void> _callSpot(BuildContext context, SquadState squadState) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || widget.lobbyId == null) return;

    try {
      final squadManager = Provider.of<SquadManager>(context, listen: false);
      await squadManager.claimPeacockSpot(
          widget.lobbyId!, user.uid, widget.gameName!);

      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spot called!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to call spot: $e')),
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
