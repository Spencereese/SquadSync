import 'dart:convert';

/// sqflite rejects nested [Map]/[List] cells (`Invalid argument {}`).
Object? encodeSqliteCell(Object? value) {
  if (value == null) return null;
  if (value is String || value is num || value is bool) return value;
  if (value is Map || value is List) return jsonEncode(value);
  return jsonEncode(value);
}

/// Inverse of [encodeSqliteCell] for map columns (group metadata/settings).
Map<String, dynamic>? decodeSqliteMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Cipher key-mismatch / exclusive-lock open failures.
bool isSqliteCipherOpenFailure(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('open_failed') ||
      text.contains('file is not a database') ||
      text.contains('not a database') ||
      text.contains('hmac') ||
      text.contains('file is encrypted') ||
      text.contains('code 26') ||
      text.contains('begin exclusive') ||
      text.contains('sqlite_notadb');
}
