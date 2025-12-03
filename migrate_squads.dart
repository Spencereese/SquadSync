import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io';

/// Migration script to add new fields to existing Squad documents in Firestore
/// Run this script once after deploying the updated Squad model
///
/// New fields added:
/// - isPublic: bool (default: false)
/// - tags: List<String> (inferred from gameName)
/// - lookingForMore: bool (true if maxSpots > current occupied spots)
/// - description: String (default: gameName)
/// - bumpTimestamp: Timestamp (null for existing squads)
void main() async {
  print('Starting Squad migration...');

  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;
  final squadsCollection = firestore.collection('squads');

  try {
    // Get all existing squads
    final snapshot = await squadsCollection.get();
    print('Found ${snapshot.docs.length} squads to migrate');

    int migratedCount = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final updates = <String, dynamic>{};

      // Add isPublic field (default: false)
      if (!data.containsKey('isPublic')) {
        updates['isPublic'] = false;
      }

      // Add tags field (infer from gameName)
      if (!data.containsKey('tags') && data['gameName'] != null) {
        final gameName = data['gameName'] as String;
        updates['tags'] = _inferTagsFromGameName(gameName);
      }

      // Add lookingForMore field (true if spots available)
      if (!data.containsKey('lookingForMore')) {
        final maxSpots = data['maxSpots'] as int? ?? 4;
        final spots = List<String?>.from(data['spots'] ?? []);
        final occupiedSpots = spots.where((spot) => spot != null).length;
        updates['lookingForMore'] = occupiedSpots < maxSpots;
      }

      // Add description field (default to gameName)
      if (!data.containsKey('description') && data['gameName'] != null) {
        updates['description'] = data['gameName'] as String;
      }

      // Add bumpTimestamp field (null for existing squads)
      if (!data.containsKey('bumpTimestamp')) {
        updates['bumpTimestamp'] = null;
      }

      // Update the document if there are changes
      if (updates.isNotEmpty) {
        await doc.reference.update(updates);
        migratedCount++;
        print('Migrated squad: ${doc.id}');
      }
    }

    print('Migration completed successfully!');
    print('Migrated $migratedCount out of ${snapshot.docs.length} squads');
  } catch (e) {
    print('Migration failed: $e');
    exit(1);
  }
}

/// Infer tags from game name
List<String> _inferTagsFromGameName(String gameName) {
  final tags = <String>[];
  final lowerGameName = gameName.toLowerCase();

  // Common game categories
  if (lowerGameName.contains('warzone') || lowerGameName.contains('cod')) {
    tags.add('fps');
    tags.add('battle-royale');
  }

  if (lowerGameName.contains('valorant')) {
    tags.add('fps');
    tags.add('tactical');
  }

  if (lowerGameName.contains('league') || lowerGameName.contains('lol')) {
    tags.add('moba');
  }

  if (lowerGameName.contains('apex')) {
    tags.add('fps');
    tags.add('battle-royale');
  }

  if (lowerGameName.contains('overwatch')) {
    tags.add('fps');
    tags.add('hero-shooter');
  }

  if (lowerGameName.contains('rocket league')) {
    tags.add('sports');
    tags.add('racing');
  }

  if (lowerGameName.contains('fortnite')) {
    tags.add('battle-royale');
    tags.add('building');
  }

  // Add competitive tag for most games
  if (!tags.contains('casual')) {
    tags.add('competitive');
  }

  // Ensure we have at least one tag
  if (tags.isEmpty) {
    tags.add('gaming');
  }

  return tags;
}
