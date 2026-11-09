import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Copies or opens the system share sheet. Tests replace this.
abstract class CodeShare {
  Future<void> copy(String text);

  Future<void> share(String text);
}

class PlatformCodeShare implements CodeShare {
  @override
  Future<void> copy(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<void> share(String text) async {
    await Share.share(text);
  }
}

class MemoryCodeShare implements CodeShare {
  String? copied;
  String? shared;

  @override
  Future<void> copy(String text) async {
    copied = text;
  }

  @override
  Future<void> share(String text) async {
    shared = text;
  }
}
