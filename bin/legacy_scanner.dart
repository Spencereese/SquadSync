import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  final legacyRefs = [
    'squad_manager',
    'user_manager',
    'game_manager',
    'achievement_manager',
    'notification_manager',
    'peacock_manager',
    'review_manager',
    'timer_state',
    'squad_data_manager',
    'squad_ui_manager',
    'squad_persistence_manager',
    'game_manager',
    'availability_manager',
    'squad_membership_service',
    'spot_management_service',
    'peacock_service',
    'achievement_service',
    'lobby_service',
    'voice_service',
    'media_service',
    'poll_service',
    'ai_service',
    'grok_service',
    'igdb_service',
    'igdb_auth_service',
    'message_service',
    'voice_room_screen',
    'voice_chat',
  ];

  final filesWithRefs = <String>{};

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      try {
        final content = await entity.readAsString();
        for (final ref in legacyRefs) {
          if (content.contains(ref)) {
            filesWithRefs.add(entity.path);
            break;
          }
        }
      } catch (e) {
        print('Error reading ${entity.path}: $e');
      }
    }
  }

  print('Files with legacy manager references:');
  for (final file in filesWithRefs) {
    print(file);
  }

  if (filesWithRefs.isNotEmpty) {
    await deleteFiles(filesWithRefs.toList());
  } else {
    print('No files found with legacy references.');
  }
}

Future<void> deleteFiles(List<String> files) async {
  print(
      '\nEnter the indices of files to delete (comma separated, e.g., 1,3,5) or "all" to delete all:');
  for (int i = 0; i < files.length; i++) {
    print('${i + 1}: ${files[i]}');
  }

  final input = stdin.readLineSync()?.trim();
  if (input == null || input.isEmpty) return;

  List<String> toDelete;
  if (input.toLowerCase() == 'all') {
    toDelete = files;
  } else {
    final indices = input
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((i) => i > 0 && i <= files.length)
        .map((i) => i - 1)
        .toList();
    toDelete = indices.map((i) => files[i]).toList();
  }

  if (toDelete.isEmpty) {
    print('No valid files selected.');
    return;
  }

  print('Confirm deletion of the following files? (y/n)');
  for (final file in toDelete) {
    print(file);
  }

  final confirm = stdin.readLineSync()?.trim().toLowerCase();
  if (confirm == 'y' || confirm == 'yes') {
    for (final path in toDelete) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        print('Deleted: $path');
      } else {
        print('File does not exist: $path');
      }
    }
  } else {
    print('Deletion cancelled.');
  }
}
