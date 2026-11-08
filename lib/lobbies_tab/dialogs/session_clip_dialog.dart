import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:squad_sync/services/session_rating_machine.dart';
import 'package:uuid/uuid.dart';

/// Gallery pick result from the existing [ImagePicker] hook.
class SessionClipPick {
  const SessionClipPick({
    required this.name,
    this.path,
    this.durationMs,
  });

  final String name;
  final String? path;
  final int? durationMs;
}

typedef PickSessionClip = Future<SessionClipPick?> Function();

/// Existing media hook: gallery video pick (same as clip upload / chat).
Future<SessionClipPick?> pickSessionClipFromGallery() async {
  final picker = ImagePicker();
  final video = await picker.pickVideo(
    source: ImageSource.gallery,
    maxDuration: const Duration(seconds: 60),
  );
  if (video == null) return null;
  return SessionClipPick(name: video.name, path: video.path);
}

/// Follow-up on the existing session-rating path. Skip still keeps the rating.
Future<SessionClip> showSessionClipDialog(
  BuildContext context, {
  PickSessionClip? pickClip,
  String? clipId,
}) async {
  final choice = await showDialog<SessionClip>(
    context: context,
    builder: (dialogContext) => SessionClipDialog(
      pickClip: pickClip ?? pickSessionClipFromGallery,
      clipId: clipId,
    ),
  );
  if (choice != null) return choice;
  return reduceSessionClip(
    current: SessionClip.empty,
    event: SessionClipEvent.skip,
  );
}

class SessionClipDialog extends StatefulWidget {
  const SessionClipDialog({
    super.key,
    required this.pickClip,
    this.clipId,
  });

  final PickSessionClip pickClip;
  final String? clipId;

  @override
  State<SessionClipDialog> createState() => _SessionClipDialogState();
}

class _SessionClipDialogState extends State<SessionClipDialog> {
  SessionClipPick? _picked;
  bool _picking = false;

  Future<void> _select() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picked = await widget.pickClip();
      if (!mounted) return;
      if (picked != null) {
        setState(() => _picked = picked);
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _attach() {
    final picked = _picked;
    if (picked == null) return;
    Navigator.of(context).pop(
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.attach,
        clipId: widget.clipId ?? const Uuid().v4(),
        fileName: picked.name,
        videoUrl: picked.path,
        durationMs: picked.durationMs,
        source: kSessionClipGallerySource,
      ),
    );
  }

  void _skip() {
    Navigator.of(context).pop(
      reduceSessionClip(
        current: SessionClip.empty,
        event: SessionClipEvent.skip,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canAttach = _picked != null;
    return AlertDialog(
      key: const Key('session-clip-dialog'),
      title: const Text('Attach a clip'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Attach a clip to this rated session?'),
          const SizedBox(height: 12),
          if (_picked != null) ...[
            Text(
              _picked!.name,
              key: const Key('session-clip-file'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton(
            key: const Key('session-clip-select'),
            onPressed: _picking ? null : _select,
            child: Text(_picked == null ? 'Select clip' : 'Change clip'),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('session-clip-skip'),
          onPressed: _skip,
          child: const Text('Skip'),
        ),
        FilledButton(
          key: const Key('session-clip-attach'),
          onPressed: canAttach ? _attach : null,
          child: const Text('Attach'),
        ),
      ],
    );
  }
}
