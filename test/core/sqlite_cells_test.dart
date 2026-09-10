import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';
import 'package:squad_sync/core/sqlite_cells.dart';

void main() {
  test('nested metadata map is JSON-encoded for sqflite', () {
    final nested = {
      'reply': {'id': 'm1', 'text': 'hi'},
      'empty': <String, dynamic>{},
    };

    final encoded = encodeSqliteCell(nested);
    expect(encoded, isA<String>());
    expect(encoded, isNot(nested));
    final decoded = jsonDecode(encoded as String) as Map<String, dynamic>;
    expect(decoded['reply'], {'id': 'm1', 'text': 'hi'});
    expect(decoded['empty'], isEmpty);
  });

  test('encode then decodeSqliteMap returns a Map', () {
    final nested = {
      'theme': 'dark',
      'flags': {'muted': true},
    };
    final encoded = encodeSqliteCell(nested);
    expect(encoded, isA<String>());
    final decoded = decodeSqliteMap(encoded);
    expect(decoded, isA<Map<String, dynamic>>());
    expect(decoded!['theme'], 'dark');
    expect(decoded['flags'], {'muted': true});
  });

  test('decodeSqliteMap accepts an already-decoded Map', () {
    expect(decodeSqliteMap({'a': 1}), {'a': 1});
    expect(decodeSqliteMap(null), isNull);
    expect(decodeSqliteMap(''), isNull);
  });

  test('scalars pass through', () {
    expect(encodeSqliteCell('plain'), 'plain');
    expect(encodeSqliteCell(3), 3);
    expect(encodeSqliteCell(null), isNull);
  });

  test('cipher open_failed is recognized', () {
    expect(isSqliteCipherOpenFailure('open_failed'), isTrue);
    expect(isSqliteCipherOpenFailure('BEGIN EXCLUSIVE'), isTrue);
    expect(isSqliteCipherOpenFailure('file is not a database'), isTrue);
    expect(isSqliteCipherOpenFailure('network timeout'), isFalse);
  });

  test('sqlite chat key is CSPRNG and non-deterministic across calls', () {
    final a = SQLiteHelper.generateSecureKey();
    final b = SQLiteHelper.generateSecureKey();
    final hex64 = RegExp(r'^[0-9a-f]{64}$');
    expect(hex64.hasMatch(a), isTrue);
    expect(hex64.hasMatch(b), isTrue);
    expect(a, isNot(b));
    expect(a.contains('fallback_key_'), isFalse);
    expect(b.contains('fallback_key_'), isFalse);
  });

  test('deterministic OS/locale sqlite fallback is absent in release', () {
    expect(SQLiteHelper.usesDeterministicFallback, isFalse);
    if (kReleaseMode) {
      expect(SQLiteHelper.usesDeterministicFallback, isFalse);
    }
    final key = SQLiteHelper.generateSecureKey();
    expect(key.contains('fallback_key_'), isFalse);
    expect(key.contains(Platform.operatingSystem), isFalse);
  });
}
