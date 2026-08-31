import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
}
