import 'dart:io';

/// Legacy Code Scanner and Refactor Tool
/// Scans the codebase for legacy manager references and optionally refactors imports

void main(List<String> args) async {
  print('Legacy Code Scanner Starting...');

  // List of legacy references to scan for
  final legacyReferences = [
    'user_manager',
    'achievement_manager',
    // Add more as needed
  ];

  // Check for refactor flag
  final shouldRefactor = args.contains('--refactor');

  if (shouldRefactor) {
    print('⚠️  WARNING: Automatic refactoring is DANGEROUS!');
    print('It will change imports without migrating the code.');
    print('Use manual migration instead. See MIGRATION_GUIDE.md');
    print('Proceeding anyway in 3 seconds...');
    await Future.delayed(const Duration(seconds: 3));
  }

  // Scan the lib directory
  final libDir = Directory('lib');
  if (!libDir.existsSync()) {
    print('Error: lib directory not found');
    return;
  }

  final files = libDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList();

  print('Scanning ${files.length} Dart files...');

  final findings = <String, List<String>>{};

  for (final file in files) {
    final content = await file.readAsString();
    final relativePath = file.path.replaceFirst('lib/', '');

    for (final ref in legacyReferences) {
      if (content.contains(ref)) {
        findings.putIfAbsent(relativePath, () => []).add(ref);
      }
    }
  }

  if (findings.isEmpty) {
    print('No legacy references found!');
    return;
  }

  print('\nFound legacy references in the following files:');
  findings.forEach((file, refs) {
    print('- $file: ${refs.join(', ')}');
  });

  // Refactor simple imports if enabled
  if (shouldRefactor) {
    print('\nRefactoring simple imports...');
    for (final entry in findings.entries) {
      final filePath = 'lib/${entry.key}';
      final file = File(filePath);
      var content = await file.readAsString();
      var modified = false;

      // Simple import replacements
      final replacements = {
        "import 'user_notifier.dart';": "import 'user_notifier.dart';",
        "import '../providers/user_notifier.dart';":
            "import '../providers/user_notifier.dart';",
        "import 'achievement_notifier.dart';":
            "import 'achievement_notifier.dart';",
        "import '../providers/achievement_notifier.dart';":
            "import '../providers/achievement_notifier.dart';",
        // Add more patterns as needed
      };

      for (final pattern in replacements.entries) {
        if (content.contains(pattern.key)) {
          content = content.replaceAll(pattern.key, pattern.value);
          modified = true;
          print(
              'Updated import in $filePath: ${pattern.key} -> ${pattern.value}');
        }
      }

      if (modified) {
        await file.writeAsString(content);
        print('Saved changes to $filePath');
      }
    }
  }

  // Prompt for deletion (simplified - in real tool, use proper CLI)
  print('\nReview the findings above.');
  print(
      '⚠️  DO NOT delete legacy files until ALL references are manually migrated!');
  print('See MIGRATION_GUIDE.md for safe migration steps.');
  print('Use --refactor ONLY after manual migration is complete.');

  print('\nScan complete.');
}
