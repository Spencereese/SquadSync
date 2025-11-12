import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../squad_state.dart';
import '../managers/game_manager.dart';
import '../managers/squad_manager.dart';
import '../managers/user_manager.dart';
import 'peacock_widgets.dart';
import 'member_widgets.dart';
import 'squad_dialogs.dart';
import 'widgets/squad_grid.dart';
import 'widgets/squad_controls.dart';
import 'widgets/squad_header.dart';
import 'widgets/game_alerts_display.dart';

class MembersSection extends StatelessWidget {
  final SquadState squadState;
  final String? chatGroupId;
  final List<String> chatGroupMembers;
  final String? circle;
  final List<String>? friends;
  final Function(BuildContext, String, SquadState) showBlockDialog;
  final Function(BuildContext, ScaffoldMessengerState, SquadState, String)
      showComplaintDialog;

  const MembersSection({
    Key? key,
    required this.squadState,
    this.chatGroupId,
    required this.chatGroupMembers,
    this.circle,
    this.friends,
    required this.showBlockDialog,
    required this.showComplaintDialog,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use provided members list (computed based on circle), otherwise fall back to squad members
    final membersToShow = chatGroupMembers.isNotEmpty
        ? chatGroupMembers
        : squadState.getFilteredMembers;

    if (membersToShow.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('No members yet', style: TextStyle(color: Colors.grey)),
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
            itemCount: membersToShow.length,
            itemBuilder: (context, index) {
              final player = membersToShow[index];
              return MemberWidgets.buildMemberCard(context, player, squadState,
                  showBlockDialog, showComplaintDialog,
                  circle: circle, friends: friends);
            },
          ),
        ),
      );
    }
  }
}

class ClaimSpotFAB extends StatelessWidget {
  final String? lobbyId;
  final Function(BuildContext, SquadState) callSpot;
  final Function(BuildContext, SquadState) lockSpot;

  const ClaimSpotFAB({
    Key? key,
    required this.lobbyId,
    required this.callSpot,
    required this.lockSpot,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lobbyId == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('peacocks')
          .doc(lobbyId)
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
              onPressed: () => lockSpot(
                  context, Provider.of<SquadState>(context, listen: false)),
              backgroundColor: Colors.yellowAccent,
              icon: const Icon(Icons.lock),
              label: const Text('Lock Spot'),
            );
          } else if (status == 'ready') {
            return FloatingActionButton.extended(
              onPressed: () => callSpot(
                  context, Provider.of<SquadState>(context, listen: false)),
              backgroundColor: Colors.orangeAccent,
              icon: const Icon(Icons.call),
              label: const Text('Call Spot'),
            );
          }
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class SquadTab extends StatelessWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const SquadTab(
      {super.key, this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  Widget build(BuildContext context) {
    return _SquadTabContent(
        lobbyId: lobbyId,
        gameName: gameName,
        game: game,
        chatGroupId: chatGroupId);
  }
}

class _SquadTabContent extends StatefulWidget {
  final String? lobbyId;
  final String? gameName;
  final Map<String, dynamic>? game;
  final String? chatGroupId;

  const _SquadTabContent(
      {this.lobbyId, this.gameName, this.game, this.chatGroupId});

  @override
  _SquadTabContentState createState() => _SquadTabContentState();
}

class _SquadTabContentState extends State<_SquadTabContent> {
  final bool _showPeacockMembers = false;
  late BuildContext _currentContext;
  List<String> _chatGroupMembers = [];
  String? _circle;
  List<String> _friends = [];

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

    // Fetch chat group members if chatGroupId is provided
    if (widget.chatGroupId != null && _chatGroupMembers.isEmpty) {
      _fetchChatGroupMembers();
    }

    // Fetch circle if lobbyId is provided
    if (widget.lobbyId != null && _circle == null) {
      _fetchCircle();
    }

    // Fetch friends
    if (_friends.isEmpty) {
      _fetchFriends();
    }
  }

  Future<void> _fetchChatGroupMembers() async {
    if (widget.chatGroupId == null) return;

    try {
      final squadState =
          Provider.of<SquadState>(_currentContext, listen: false);
      final chatGroupDoc = await FirebaseFirestore.instance
          .collection('squads')
          .doc(squadState.selectedSquadId)
          .collection('chat_groups')
          .doc(widget.chatGroupId)
          .get();

      if (chatGroupDoc.exists && mounted) {
        final data = chatGroupDoc.data();
        final members = List<String>.from(data?['members'] ?? []);
        setState(() {
          _chatGroupMembers = members;
        });
      }
    } catch (e) {
      print('Error fetching chat group members: $e');
    }
  }

  Future<void> _fetchCircle() async {
    if (widget.lobbyId == null) return;

    try {
      final peacockDoc = await FirebaseFirestore.instance
          .collection('peacocks')
          .doc(widget.lobbyId)
          .get();

      if (peacockDoc.exists && mounted) {
        final data = peacockDoc.data();
        final circle = data?['circle'] as String?;
        setState(() {
          _circle = circle;
        });
      }
    } catch (e) {
      print('Error fetching circle: $e');
    }
  }

  Future<void> _fetchFriends() async {
    final userManager =
        Provider.of<UserManager>(_currentContext, listen: false);
    final friendsStream = userManager.streamFriends();

    friendsStream.listen((friends) {
      if (mounted) {
        final friendNames = friends
            .map((f) => f['displayName'] as String? ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        setState(() {
          _friends = friendNames;
        });
      }
    });
  }

  List<String> _getMembersForCircle() {
    if (_circle == null) {
      // Default to chat group members if circle not loaded yet
      return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
    }

    switch (_circle) {
      case 'Squad':
        return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
      case 'Friends':
        return _friends;
      case 'Public':
        // Show friends plus anyone who has joined spots
        final squadState =
            Provider.of<SquadState>(_currentContext, listen: false);
        final gameName = widget.gameName ?? '';
        final gameSquadSpots = squadState.gameSquadSpots[gameName] ?? [];
        final joinedUsers = gameSquadSpots
            .where((spot) => spot != null)
            .map((spot) => squadState.getDisplayNameForUid(spot!.split('_')[0]))
            .where((name) => name.isNotEmpty)
            .toList();
        return {..._friends, ...joinedUsers}.toList();
      default:
        return _chatGroupMembers.isNotEmpty ? _chatGroupMembers : [];
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
                // Header with navigation and game selector
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: SquadHeader(lobbyId: widget.lobbyId),
                  ),
                ),

                // Squad spots grid
                SquadGrid(),

                // Peacock members section (conditionally shown)
                SliverToBoxAdapter(
                  child: _showPeacockMembers
                      ? PeacockWidgets.buildPeacockMembersList(
                          context, squadState, _togglePeacockMember)
                      : const SizedBox.shrink(),
                ),

                // Action buttons (Win/Loss)
                SquadControls(),

                // Game alerts display
                const GameAlertsDisplay(),

                // Members section header
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

                // Members list
                MembersSection(
                  squadState: squadState,
                  chatGroupId: widget.chatGroupId,
                  chatGroupMembers: _getMembersForCircle(),
                  circle: _circle,
                  friends: _friends,
                  showBlockDialog: _showBlockDialog,
                  showComplaintDialog: _showComplaintDialog,
                ),

                // Bottom spacing
                SliverToBoxAdapter(
                  child: const SizedBox(height: 80.0),
                ),
              ],
            ),
          ),
          floatingActionButton: widget.lobbyId != null
              ? ClaimSpotFAB(
                  lobbyId: widget.lobbyId,
                  callSpot: _callSpot,
                  lockSpot: _lockSpot,
                )
              : null,
        );
      },
    );
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
