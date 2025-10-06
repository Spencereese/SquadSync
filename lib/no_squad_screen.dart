import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../create_squad_screen.dart';
import '../join_squad_screen.dart';
import '../squad_state.dart';

class NoSquadScreen extends StatefulWidget {
  const NoSquadScreen({super.key});

  @override
  _NoSquadScreenState createState() => _NoSquadScreenState();
}

class _NoSquadScreenState extends State<NoSquadScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<SquadState>(
      builder: (context, squadState, child) =>
          _buildContent(context, squadState),
    );
  }

  Widget _buildContent(BuildContext context, SquadState squadState) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_add,
                  size: 60,
                  color: theme.primaryColor,
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                squadState.userSquadIds.isEmpty
                    ? 'Welcome to SquadSync!'
                    : 'Select a Squad',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Subtitle
              Text(
                squadState.userSquadIds.isEmpty
                    ? 'Create or join a squad to start gaming with friends.\nShare chat, spots, timers, and achievements!'
                    : 'Choose a squad to continue or create a new one.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white70 : Colors.black54,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Existing squads list
              if (squadState.userSquadIds.isNotEmpty) ...[
                Text(
                  'Your Squads',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: squadState.userSquadIds.length,
                    itemBuilder: (context, index) {
                      final squadId = squadState.userSquadIds[index];
                      return FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('squads')
                            .doc(squadId)
                            .get(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const ListTile(
                              title: Text('Loading...'),
                            );
                          }
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>?;
                          final name = data?['name'] ?? 'Unknown Squad';
                          final isSelected =
                              squadId == squadState.selectedSquadId;
                          return ListTile(
                            title: Text(name),
                            subtitle: Text('ID: ${squadId.substring(0, 8)}...'),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle,
                                    color: Colors.green)
                                : null,
                            onTap: () {
                              squadState.selectSquad(squadId);
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Buttons
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    // Create Squad Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _showCreateSquad,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Create New Squad',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Join Squad Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _showJoinSquad,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: theme.primaryColor, width: 2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Join Existing Squad',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 32),

              // Additional info
              Text(
                'Squads are private groups for you and your friends.\nInvite codes expire in 30 days.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSquad() {
    showDialog(
      context: context,
      builder: (context) => const CreateSquadScreen(),
    );
  }

  void _showJoinSquad() {
    showDialog(
      context: context,
      builder: (context) => const JoinSquadScreen(),
    );
  }
}
