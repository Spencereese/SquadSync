import 'dart:io';

String? _resolveRelativePath(String currentDir, String relativePath) {
  // If it starts with package: or dart:, skip
  if (relativePath.startsWith('package:') || relativePath.startsWith('dart:')) {
    return null;
  }

  // Find the lib/ part
  final libIndex = currentDir.indexOf('/lib/');
  if (libIndex == -1) return null;

  final basePath = currentDir.substring(libIndex + 1); // e.g., lib/chat

  final parts = relativePath.split('/');
  final baseParts = basePath.split('/');

  for (final part in parts) {
    if (part == '..') {
      if (baseParts.isNotEmpty) {
        baseParts.removeLast();
      }
    } else if (part != '.' && part.isNotEmpty) {
      baseParts.add(part);
    }
  }

  final resolved = baseParts.join('/');
  if (!resolved.startsWith('lib/')) {
    return 'lib/$resolved';
  }
  return resolved;
}

void main() async {
  final libDir = Directory('lib');
  final allDartFiles = <String>[];
  final importedFiles = <String>{};

  // Collect all Dart files
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip test files
      if (entity.path.contains('/test/') ||
          entity.path.contains('/integration_test/')) continue;

      final relativePath =
          entity.path.replaceFirst('${Directory.current.path}/', '');
      allDartFiles.add(relativePath);
    }
  }

  // Collect all imports from Dart files
  await for (final entity in libDir.list(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      // Skip test files
      if (entity.path.contains('/test/') ||
          entity.path.contains('/integration_test/')) continue;

      try {
        final content = await entity.readAsString();
        final lines = content.split('\n');

        for (final line in lines) {
          final trimmedLine = line.trim();

          // Skip comments
          if (trimmedLine.startsWith('//') ||
              trimmedLine.startsWith('/*') ||
              trimmedLine.startsWith('*') ||
              trimmedLine.contains('///')) {
            continue;
          }

          // Check for import statements
          if (trimmedLine.startsWith('import')) {
            // Extract the path from import 'package:squad_sync/...'; or relative
            final startQuote = trimmedLine.indexOf("'");
            final endQuote = trimmedLine.indexOf("'", startQuote + 1);
            if (startQuote != -1 && endQuote != -1) {
              final importPath =
                  trimmedLine.substring(startQuote + 1, endQuote);
              if (importPath.startsWith('package:squad_sync/')) {
                final relativePath =
                    importPath.replaceFirst('package:squad_sync/', 'lib/') +
                        '.dart';
                importedFiles.add(relativePath);
              } else if (!importPath.startsWith('package:') &&
                  !importPath.startsWith('dart:')) {
                // Relative import
                final currentDir = entity.parent.path;
                final resolvedPath =
                    _resolveRelativePath(currentDir, importPath);
                if (resolvedPath != null) {
                  final finalPath = resolvedPath.endsWith('.dart')
                      ? resolvedPath
                      : '$resolvedPath.dart';
                  importedFiles.add(finalPath);
                }
              }
            }
          }

          // Also check for part statements (for generated files)
          if (trimmedLine.startsWith('part')) {
            final startQuote = trimmedLine.indexOf("'");
            final endQuote = trimmedLine.indexOf("'", startQuote + 1);
            if (startQuote != -1 && endQuote != -1) {
              final partPath = trimmedLine.substring(startQuote + 1, endQuote);
              if (partPath.startsWith('package:squad_sync/')) {
                final relativePath =
                    partPath.replaceFirst('package:squad_sync/', 'lib/') +
                        '.dart';
                importedFiles.add(relativePath);
              } else if (!partPath.contains('/')) {
                // Relative part
                final dir = entity.parent.path;
                final fullPath = '$dir/$partPath';
                importedFiles.add(fullPath);
              } else {
                // Relative part with path
                final currentDir = entity.parent.path;
                final resolvedPath = _resolveRelativePath(currentDir, partPath);
                if (resolvedPath != null) {
                  final finalPath = resolvedPath.endsWith('.dart')
                      ? resolvedPath
                      : '$resolvedPath.dart';
                  importedFiles.add(finalPath);
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error reading ${entity.path}: $e');
      }
    }
  }

  // Entry points that are always used
  final entryPoints = [
    'lib/main.dart',
    'lib/firebase_options.dart', // Used in main.dart
    'lib/app_theme.dart', // Used in main.dart
    'lib/utils.dart', // Likely used widely
  ];

  // Files that are referenced in pubspec.yaml or other config
  final configReferenced = [
    // Add any files referenced in pubspec.yaml assets, etc.
  ];

  final usedFiles = <String>{
    ...importedFiles,
    ...entryPoints,
    ...configReferenced
  };

  // Find unused files
  final unusedFiles = <String>[];
  for (final file in allDartFiles) {
    if (!usedFiles.contains(file)) {
      unusedFiles.add(file);
    }
  }

  print('Unused Dart files in lib/ (excluding test files):');
  print('=' * 80);

  if (unusedFiles.isEmpty) {
    print('🎉 No unused files found!');
    return;
  }

  unusedFiles.sort();
  for (final file in unusedFiles) {
    print(file.replaceFirst('lib/', ''));
  }

  print('');
  print('Total unused files: ${unusedFiles.length}');
  print('');
  print('Note: This scanner may have false positives.');
  print('Some files might be used dynamically or through reflection.');
  print('Always verify before deleting files.');
}
