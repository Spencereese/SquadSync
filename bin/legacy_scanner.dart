import 'dart:io';

void main() async {
  final libDir = Directory('lib');
  final legacyManagers = [
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
    'availability_manager',
    'squad_membership_service',
    'spot_management_service',
    'peacock_service',
    'achievement_service',
    'lobby_service',
  ];

  final legacyServices = [
    'voice_service',
    'media_service',
    'poll_service',
    'ai_service',
    'grok_service',
    'igdb_service',
    'igdb_auth_service',
    'message_service',
  ];

  final legacyScreens = [
    'voice_room_screen',
    'voice_chat',
  ];

  final allLegacyRefs = [
    ...legacyManagers,
    ...legacyServices,
    ...legacyScreens
  ];

  final filesWithRefs = <String, List<String>>{};

  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip files in managers directory (they're the legacy files themselves)
      if (entity.path.contains('/managers/')) continue;

      // Skip test files
      if (entity.path.contains('/test/') ||
          entity.path.contains('/integration_test/')) continue;

      try {
        final content = await entity.readAsString();
        final lines = content.split('\n');
        final foundRefs = <String>[];

        for (final line in lines) {
          final trimmedLine = line.trim();

          // Skip comment lines
          if (trimmedLine.startsWith('//') ||
              trimmedLine.startsWith('/*') ||
              trimmedLine.startsWith('*') ||
              trimmedLine.contains('///')) {
            continue;
          }

          // Skip import/export lines
          if (trimmedLine.startsWith('import') ||
              trimmedLine.startsWith('export') ||
              trimmedLine.contains('from ')) {
            continue;
          }

          // Skip string literals (basic check)
          if (trimmedLine.contains('"') || trimmedLine.contains("'")) {
            // Only skip if the entire reference is in quotes
            bool skipLine = false;
            for (final ref in allLegacyRefs) {
              if (trimmedLine.contains('"$ref"') ||
                  trimmedLine.contains("'$ref'")) {
                skipLine = true;
                break;
              }
            }
            if (skipLine) continue;
          }

          // Check for legacy references in actual code
          for (final ref in allLegacyRefs) {
            if (trimmedLine.contains(ref) &&
                !trimmedLine.contains(
                    'Provider.of<$ref') && // Skip Provider.of patterns
                !trimmedLine.contains(
                    '$ref.') && // Skip method calls on the manager itself
                !trimmedLine.contains('$ref(')) {
              // Skip constructor calls

              // Additional check: only flag if it's likely actual usage
              if (trimmedLine.contains('$ref.') ||
                  trimmedLine.contains('$ref(') ||
                  trimmedLine.contains('Provider.of<$ref') ||
                  trimmedLine.contains('$ref!') ||
                  trimmedLine.contains('$ref?')) {
                if (!foundRefs.contains(ref)) {
                  foundRefs.add(ref);
                }
              }
            }
          }
        }

        if (foundRefs.isNotEmpty) {
          filesWithRefs[entity.path] = foundRefs;
        }
      } catch (e) {
        print('Error reading ${entity.path}: $e');
      }
    }
  }

  print(
      'Files with actual legacy manager/service usage (excluding imports, comments, tests):');
  print('=' * 80);

  if (filesWithRefs.isEmpty) {
    print('🎉 No files found with legacy references! Migration complete!');
    return;
  }

  int totalFiles = 0;
  for (final entry in filesWithRefs.entries) {
    totalFiles++;
    print('${totalFiles}. ${entry.key}');
    print('   References: ${entry.value.join(', ')}');
    print('');
  }

  print('Total files with legacy references: $totalFiles');
  print('');
  print('Note: This scanner only detects likely problematic usage.');
  print('Files in /managers/ and test files are excluded.');
  print('Review each file manually before making changes.');
}
