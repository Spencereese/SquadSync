import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

import '../models/squad.dart';

Future<void> main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('Starting migration to Squad documents...');

  // Get all users
  final usersSnapshot = await firestore.collection('users').get();
  final users = usersSnapshot.docs;

  print('Found ${users.length} users to process');

  int processed = 0;
  int squadsCreated = 0;

  for (final userDoc in users) {
    processed++;
    final userData = userDoc.data();
    final uid = userDoc.id;
    final displayName = userData['displayName'] as String? ?? 'User';

    print('Processing user $processed/${users.length}: $displayName ($uid)');

    // Check if user has old global squad data
    final gameSquadSpots = userData['gameSquadSpots'] as Map<String, dynamic>?;
    final gameSpotTimers = userData['gameSpotTimers'] as Map<String, dynamic>?;
    final gameStatuses = userData['gameStatuses'] as Map<String, dynamic>?;

    if (gameSquadSpots == null || gameSquadSpots.isEmpty) {
      print('  No old squad spots found, skipping');
      continue;
    }

    final createdSquadIds = <String>[];
    final batch = firestore.batch(); // Create batch for this user

    // Create one squad per game that has spots
    for (final gameEntry in gameSquadSpots.entries) {
      final gameName = gameEntry.key;
      final spotsData = gameEntry.value as List<dynamic>?;
      if (spotsData == null || spotsData.isEmpty) continue;

      // Get game info
      final gameInfo = (userData['games'] as Map<String, dynamic>?)?[gameName]
          as Map<String, dynamic>?;
      final gameId = gameInfo?['id'] as String?;
      final maxSpots = gameInfo?['maxSpots'] as int? ?? spotsData.length;

      // Collect member UIDs from spots
      final memberUids = <String>{uid};
      final spotClaims = <String, String?>{};

      for (int i = 0; i < spotsData.length; i++) {
        final spotUid = spotsData[i] as String?;
        if (spotUid != null) {
          memberUids.add(spotUid);
          spotClaims['${i + 1}'] = spotUid;
        } else {
          spotClaims['${i + 1}'] = null;
        }
      }

      // Migrate timers for this game
      final peacockTimers = <String, PeacockTimer>{};
      final timersData = (gameSpotTimers?[gameName] as List<dynamic>?);
      if (timersData != null) {
        for (int i = 0; i < timersData.length; i++) {
          final timerData = timersData[i] as Map<String, dynamic>?;
          if (timerData != null) {
            final endTime = timerData['endTime'] as Timestamp?;
            final isActive = timerData['isActive'] as bool? ?? false;
            if (endTime != null) {
              final spotUid = spotClaims['${i + 1}'];
              if (spotUid != null) {
                peacockTimers[spotUid] = PeacockTimer(
                  endTime: endTime,
                  isActive: isActive,
                );
              }
            }
          }
        }
      }

      // Migrate statuses for this game
      final userStatuses = <String, String>{};
      final statusesData = (gameStatuses?[gameName] as Map<String, dynamic>?);
      if (statusesData != null) {
        statusesData.forEach((userId, status) {
          if (status is String) {
            userStatuses[userId] = status;
            memberUids.add(userId);
          }
        });
      }

      // Create squad
      final squadName = displayName.isNotEmpty
          ? "$displayName's $gameName Squad"
          : '$gameName Squad';
      final squad = Squad(
        id: '',
        name: squadName,
        primaryGameId: gameId,
        primaryGameName: gameName,
        maxSpots: maxSpots,
        creatorUid: uid,
        createdAt: Timestamp.now(),
        isPublic: false,
        inviteCode: null,
        memberUids: memberUids.toList(),
        lastActivity: Timestamp.now(),
        spotClaims: spotClaims,
        peacockTimers: peacockTimers,
        userStatuses: userStatuses,
        tags: [],
        lookingForMore: false,
        description: '',
      );

      // Add to batch
      final squadRef = firestore.collection('squads').doc();
      batch.set(squadRef, squad.toFirestore());
      createdSquadIds.add(squadRef.id);

      print(
          '    Created squad for $gameName with ${memberUids.length} members');
    }

    if (createdSquadIds.isEmpty) continue;

    // Update user document
    final userRef = firestore.collection('users').doc(uid);
    batch.update(userRef, {
      'squadIds': FieldValue.arrayUnion(createdSquadIds),
      'pinnedSquadId': createdSquadIds.first, // Pin the first one
      // Delete old fields
      'currentGame': FieldValue.delete(),
      'gameSquadSpots': FieldValue.delete(),
      'gameSpotTimers': FieldValue.delete(),
      'gameStatuses': FieldValue.delete(),
    });

    // Commit batch
    await batch.commit();

    squadsCreated += createdSquadIds.length;
    print('  Created ${createdSquadIds.length} squads for user');
  }

  print('Migration completed!');
  print('Processed $processed users');
  print('Created $squadsCreated squads');

  // Now fix existing squads
  print('Fixing existing squad documents...');
  final squadsSnapshot = await firestore.collection('squads').get();
  for (var doc in squadsSnapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('memberUids') || data['memberUids'] == null)
      updates['memberUids'] = <String>[];
    if (!data.containsKey('tags')) updates['tags'] = <String>[];
    if (!data.containsKey('spotClaims'))
      updates['spotClaims'] = <String, String?>{};
    if (!data.containsKey('peacockTimers'))
      updates['peacockTimers'] = <String, dynamic>{};
    if (!data.containsKey('userStatuses'))
      updates['userStatuses'] = <String, String>{};

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      print('Fixed ${doc.id}');
    }
  }
  print('Fixed existing squads');

  // Now fix existing user documents
  print('Fixing existing user documents...');
  final allUsersSnapshot = await firestore.collection('users').get();
  for (var doc in allUsersSnapshot.docs) {
    final data = doc.data();
    final updates = <String, dynamic>{};

    if (!data.containsKey('squadIds') || data['squadIds'] == null) {
      updates['squadIds'] = <String>[];
    }

    if (updates.isNotEmpty) {
      await doc.reference.update(updates);
      print('Fixed user ${doc.id}');
    }
  }
  print('Fixed existing users');
}
