import 'dart:io';
import 'dart:ui';

import 'package:share_plus/share_plus.dart';
import 'package:squadsync/features/invite/data/code_share.dart';

/// Hands a session file to the system share sheet. No calendar permission.
abstract class CalendarExport {
  Future<void> shareIcs({
    required String filename,
    required String body,
    Rect? origin,
  });
}

class MemoryCalendarExport implements CalendarExport {
  String? filename;
  String? body;

  @override
  Future<void> shareIcs({
    required String filename,
    required String body,
    Rect? origin,
  }) async {
    this.filename = filename;
    this.body = body;
  }
}

class PlatformCalendarExport implements CalendarExport {
  @override
  Future<void> shareIcs({
    required String filename,
    required String body,
    Rect? origin,
  }) async {
    final file = File('${Directory.systemTemp.path}/$filename');
    await file.writeAsString(body);
    await Share.shareXFiles([
      XFile(file.path, mimeType: 'text/calendar', name: filename),
    ], sharePositionOrigin: shareOrigin(origin));
  }
}
