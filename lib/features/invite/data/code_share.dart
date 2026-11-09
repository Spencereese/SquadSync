import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copies or opens the system share sheet. Tests replace this.
abstract class CodeShare {
  Future<void> copy(String text);

  Future<void> share(String text, {Rect? origin});
}

/// iOS rejects a zero popover rect. A missing button rect still has to be
/// non-zero or the share sheet throws.
Rect shareOrigin(Rect? origin) {
  if (origin != null && origin.width > 0 && origin.height > 0) {
    return origin;
  }
  return const Rect.fromLTWH(1, 1, 1, 1);
}

class PlatformCodeShare implements CodeShare {
  @override
  Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<void> share(String text, {Rect? origin}) async {
    await Share.share(text, sharePositionOrigin: shareOrigin(origin));
  }
}

class MemoryCodeShare implements CodeShare {
  String? copied;
  String? shared;
  Rect? origin;

  @override
  Future<void> copy(String text) async {
    copied = text;
  }

  @override
  Future<void> share(String text, {Rect? origin}) async {
    shared = text;
    this.origin = origin;
  }
}
