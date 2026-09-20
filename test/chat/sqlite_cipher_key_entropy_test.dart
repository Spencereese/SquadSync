import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Slice CIPHER reds: SQLCipher key entropy. No product in this commit.
/// Loop greens later in `lib/chat/sqlite_helper.dart` only.
///
/// Smell: `DateTime.now().millisecondsSinceEpoch` + charset loop.
/// That is not CSPRNG. Do not implement the fix here.
///
/// Contract:
/// 1. New key material is at least 32 bytes
/// 2. Two consecutive generations are not equal
/// 3. Generator does not call DateTime.now as the entropy source
/// 4. Key is stored via flutter_secure_storage, not SharedPreferences
/// 5. Opening the DB still uses the sqlcipher password path
const _kHelperSrc = 'lib/chat/sqlite_helper.dart';

String _helperSource() => File(_kHelperSrc).readAsStringSync();

/// Production key mint (`_getEncryptionKey`). Cache timestamps elsewhere
/// in the file are not entropy for the cipher key.
String _encryptionKeyMintSource() {
  return _extractMethod(_helperSource(), '_getEncryptionKey');
}

String _openDatabaseSource() {
  return _extractMethod(_helperSource(), '_initDatabase');
}

String _extractMethod(String src, String name) {
  final start = src.indexOf(RegExp('(?:Future<[^>]+>|String|void)\\s+$name\\s*\\('));
  expect(start, isNonNegative, reason: 'missing $name in $_kHelperSrc');
  final brace = src.indexOf('{', start);
  expect(brace, isNonNegative, reason: '$name has no body');
  var depth = 0;
  for (var i = brace; i < src.length; i++) {
    final ch = src[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return src.substring(start, i + 1);
    }
  }
  fail('unbalanced body for $name');
}

bool _mintsAtLeast32Bytes(String mint) {
  return RegExp(r'generate\(\s*32\b').hasMatch(mint) ||
      RegExp(r'Uint8List\s*\(\s*32\s*\)').hasMatch(mint) ||
      RegExp(r'List<int>\.generate\(\s*32\b').hasMatch(mint) ||
      mint.contains('length: 32') ||
      mint.contains('32, (_) =>');
}

bool _usesCsprng(String mint) => mint.contains('Random.secure()');

bool _usesDatetimeEntropy(String mint) {
  return mint.contains('DateTime.now()') ||
      mint.contains('millisecondsSinceEpoch');
}

void main() {
  group('Slice CIPHER — sqlcipher key entropy', () {
    test('new key material is at least 32 bytes', () {
      final mint = _encryptionKeyMintSource();
      expect(
        _mintsAtLeast32Bytes(mint),
        isTrue,
        reason: 'New SQLCipher key material must be at least 32 bytes. '
            'DateTime hex is ~11 chars and is not enough entropy.',
      );
    });

    test('two consecutive generations are not equal', () {
      final mint = _encryptionKeyMintSource();
      expect(
        _usesCsprng(mint),
        isTrue,
        reason: 'Consecutive keys must come from CSPRNG so they differ. '
            'A single DateTime.now() tick can collide.',
      );
      expect(
        _usesDatetimeEntropy(mint),
        isFalse,
        reason: 'Clock-derived keys are not unique across consecutive calls '
            'in the same millisecond.',
      );
    });

    test('generator does not call DateTime.now as the entropy source', () {
      final mint = _encryptionKeyMintSource();
      expect(
        _usesDatetimeEntropy(mint),
        isFalse,
        reason: 'Generator must not call DateTime.now as entropy. '
            'Smell: DateTime.now().millisecondsSinceEpoch + charset loop.',
      );
      expect(
        _usesCsprng(mint),
        isTrue,
        reason: 'Entropy source must be Random.secure / CSPRNG.',
      );
    });

    test('key is stored via flutter_secure_storage, not SharedPreferences', () {
      final src = _helperSource();
      final mint = _encryptionKeyMintSource();
      expect(
        src.contains('package:flutter_secure_storage/flutter_secure_storage.dart'),
        isTrue,
        reason: 'Persist the SQLCipher key with flutter_secure_storage '
            '(or the existing secure-storage wrapper).',
      );
      expect(
        src.contains('FlutterSecureStorage') || mint.contains('_secureStorage'),
        isTrue,
        reason: 'Key must be stored via FlutterSecureStorage, not plaintext.',
      );
      expect(
        mint.contains('_secureStorage.write') ||
            mint.contains('secureStorage.write') ||
            mint.contains('FlutterSecureStorage'),
        isTrue,
        reason: '_getEncryptionKey must persist via secure storage write.',
      );
      expect(
        src.contains('SharedPreferences') || mint.contains('shared_preferences'),
        isFalse,
        reason: 'Do not store the SQLCipher key in SharedPreferences plaintext.',
      );
    });

    test('opening the DB still uses sqlcipher password path', () {
      final src = _helperSource();
      final open = _openDatabaseSource();
      expect(
        src.contains("import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher"),
        isTrue,
        reason: 'Do not drop SQLCipher encryption.',
      );
      expect(
        open.contains('sqlcipher.openDatabase'),
        isTrue,
        reason: 'Open path must stay on sqlcipher, not plaintext sqflite.',
      );
      expect(
        RegExp(r'password:\s*encryptionKey').hasMatch(open),
        isTrue,
        reason: 'sqlcipher.openDatabase must still pass the encryption password.',
      );
    });
  });
}
