import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/services/fill_pin_poll.dart';
import 'package:squad_sync/services/peacock_self_notify.dart';

/// PIN WAVE — PIN POLL OPENS PollCreationDialog (RED, Harness).
///
/// P3A-wire CLOSED: friend tap on the live pin header already calls
/// [attachOrResolveFillPinPoll] / [attachPollToPin]
/// (`lib/chat/fill_pin_thread_header.dart`). The tap still
/// synthesizes `poll-$pinId` only. It does **not** open the
/// existing [PollCreationDialog]
/// (`lib/chat/poll_creation_dialog.dart`).
///
/// Friend tap: Poll on pin header opens existing
/// `poll_creation_dialog` (not synthetic poll-$pinId only). On
/// create success call [attachPollToPin] /
/// [attachOrResolveFillPinPoll] with the **real** pollId.
/// [FillPinPoll.chatMessageId] stays null. No message_bubble
/// rewrite.
///
/// FAIL-until-green contracts (source-scan / call-contract):
///
/// 1. Header (or thin glue) imports + opens
///    `poll_creation_dialog` / [PollCreationDialog] on the poll
///    chrome tap (`kFillPinPollKey` / `_FillPinPollButton`).
/// 2. Friend tap is **not** `attachOrResolveFillPinPoll(pinId)`
///    as the only attach (that path synthesizes `poll-$pinId`
///    when pollId is empty).
/// 3. Create-success callback ([onPollCreated] / `poll.id`)
///    attaches via [attachPollToPin] /
///    [attachOrResolveFillPinPoll] with that real pollId.
/// 4. [FillPinPoll.chatMessageId] stays null.
/// 5. No lobby_notifier / message_bubble dual-edit. XOR stays
///    [planPeacockSelfNotify].
///
/// Existing dialog (`lib/chat/poll_creation_dialog.dart`):
/// [PollCreationDialog] already has `onPollCreated`.
/// [PollCreationDialog.show] does not forward it yet — Loop may
/// construct the widget with the callback, or add `onPollCreated`
/// to `show` (thin glue). Prefer ChatType.userGroup for the
/// friends pin thread. Do not rewrite message_bubble.
///
/// Loop lease (Harness does not edit `lib/**` or bump pubspec;
/// still 3.4.186+188 until Loop greens → 3.4.187+189):
/// 1. `lib/chat/fill_pin_thread_header.dart` — primary; poll tap
///    opens [PollCreationDialog]; on create success
///    [attachPollToPin] / [attachOrResolveFillPinPoll] with real
///    pollId (`poll.id`)
/// 2. Thin glue if needed:
///    `lib/chat/poll_creation_dialog.dart` (forward
///    `onPollCreated` through `show`) and/or
///    `lib/chat/fill_pin_poll_create.dart`
///    `lib/services/fill_pin_poll.dart` prefer untouched
/// 3. `pubspec.yaml` bump to exactly `3.4.187+189` when Loop greens
///
/// Never dual-edit `lobby_notifier.dart`. No `message_bubble` /
/// `chat_info_screen` rewrite. No GATES / AASA / Tonight /
/// merge / device.
///
/// Out of scope: GATES / AASA / Tonight / merge / device claim /
/// pubspec bump (Harness).
const _kHeader = 'lib/chat/fill_pin_thread_header.dart';
const _kPoll = 'lib/services/fill_pin_poll.dart';
const _kDialog = 'lib/chat/poll_creation_dialog.dart';
const _kLobbyNotifier = 'lib/presentation/notifiers/lobby_notifier.dart';
const _kMessageBubble = 'lib/chat/message_bubble.dart';
const _kChatInfo = 'lib/chat/screens/chat_info_screen.dart';
const _kHelperCandidates = [
  'lib/chat/fill_pin_poll_create.dart',
  'lib/services/fill_pin_poll_create.dart',
  'lib/chat/fill_pin_poll_dialog.dart',
];

String _read(String path) => File(path).readAsStringSync();

/// Header plus optional thin create-glue under lease.
String _createLeaseSource() {
  final chunks = [_read(_kHeader)];
  for (final path in _kHelperCandidates) {
    if (File(path).existsSync()) {
      chunks.add(_read(path));
    }
  }
  return chunks.join('\n');
}

bool _importsPollCreationDialog(String src) {
  return src.contains('poll_creation_dialog') ||
      src.contains('poll_creation_dialog.dart');
}

bool _opensPollCreationDialog(String src) {
  return src.contains('PollCreationDialog');
}

/// Bare attachOrResolveFillPinPoll(pinId) — empty pollId → poll-$pinId.
bool _tapAttachesSyntheticOnly(String src) {
  return RegExp(r'attachOrResolveFillPinPoll\(\s*pinId\s*\)').hasMatch(src);
}

bool _wiresCreateSuccessAttach(String src) {
  final callback = src.contains('onPollCreated');
  final realId = src.contains('poll.id') ||
      src.contains('createdPoll.id') ||
      src.contains('created.pollId');
  return callback && realId;
}

void main() {
  setUp(resetFillPinPollStore);
  tearDown(resetFillPinPollStore);

  group('pin-header poll opens PollCreationDialog', () {
    test('header, poll store, and poll_creation_dialog exist', () {
      expect(File(_kHeader).existsSync(), isTrue);
      expect(File(_kPoll).existsSync(), isTrue);
      expect(File(_kDialog).existsSync(), isTrue);
    });

    test('live caller is still the pin header poll chrome', () {
      final src = _read(_kHeader);
      expect(src.contains('FillPinThreadHeader'), isTrue);
      expect(src.contains('kFillPinPollKey'), isTrue);
      expect(src.contains('_FillPinPollButton'), isTrue);
      expect(src.contains('attachOrResolveFillPinPoll'), isTrue);
    });

    test('existing dialog is PollCreationDialog (not a new poll UI)', () {
      final dialog = _read(_kDialog);
      expect(dialog.contains('class PollCreationDialog'), isTrue);
      expect(dialog.contains('onPollCreated'), isTrue);
    });

    test(
      'header (or thin glue) imports poll_creation_dialog',
      () {
        final src = _createLeaseSource();
        expect(
          _importsPollCreationDialog(src),
          isTrue,
          reason:
              'Loop lease: import poll_creation_dialog.dart from '
              '$_kHeader (or thin glue) so friend tap on the pin '
              'poll chrome opens PollCreationDialog — not only '
              'synthetic poll-\$pinId.',
        );
      },
    );

    test(
      'friend tap opens PollCreationDialog, not synthetic poll-\$pinId only',
      () {
        final src = _createLeaseSource();
        expect(
          _opensPollCreationDialog(src),
          isTrue,
          reason:
              'App Tester + CoS: poll chrome tap must open '
              'PollCreationDialog (lib/chat/poll_creation_dialog.dart). '
              'Do not attach only via synthetic poll-\$pinId.',
        );
        expect(
          _tapAttachesSyntheticOnly(src),
          isFalse,
          reason:
              'Friend tap must not call attachOrResolveFillPinPoll(pinId) '
              'with no pollId (that synthesizes poll-\$pinId). Open the '
              'create dialog first; attach on create success with the '
              'real pollId.',
        );
      },
    );

    test(
      'on create success attach with real pollId via '
      'attachPollToPin / attachOrResolveFillPinPoll',
      () {
        final src = _createLeaseSource();
        expect(
          _wiresCreateSuccessAttach(src),
          isTrue,
          reason:
              'Loop lease: on PollCreationDialog create success '
              '(onPollCreated / poll.id) call attachPollToPin or '
              'attachOrResolveFillPinPoll with the real pollId. '
              'chatMessageId stays null. No message_bubble rewrite.',
        );
        expect(
          src.contains('attachPollToPin') ||
              src.contains('attachOrResolveFillPinPoll'),
          isTrue,
        );
      },
    );

    test(
      'lobby_notifier / message_bubble are not the poll-create lease',
      () {
        final notifier = _read(_kLobbyNotifier);
        expect(notifier.contains('poll_creation_dialog'), isFalse);
        expect(notifier.contains('attachPollToPin'), isFalse);
        expect(notifier.contains('attachOrResolveFillPinPoll'), isFalse);

        final bubble = _read(_kMessageBubble);
        expect(bubble.contains('attachPollToPin'), isFalse);
        expect(bubble.contains('attachOrResolveFillPinPoll'), isFalse);
        expect(bubble.contains('fill_pin_poll.dart'), isFalse);

        final info = _read(_kChatInfo);
        expect(info.contains('attachPollToPin'), isFalse);
        expect(info.contains('attachOrResolveFillPinPoll'), isFalse);
      },
    );
  });

  group('create-success attach stays pin-scoped — chatMessageId null', () {
    test(
      'attachOrResolveFillPinPoll with real pollId keeps chatMessageId null',
      () {
        final attached = attachOrResolveFillPinPoll(
          'pin-1',
          pollId: 'poll-real-from-dialog',
        );
        expect(attached.pinId, 'pin-1');
        expect(attached.pollId, 'poll-real-from-dialog');
        expect(attached.pollId, isNot('poll-pin-1'));
        expect(
          attached.chatMessageId,
          isNull,
          reason: 'Pin poll is not a chat-message poll.',
        );
        expect(resolvePollForPin('pin-1')?.chatMessageId, isNull);
      },
    );

    test('attachPollToPin with real pollId keeps chatMessageId null', () {
      final attached = attachPollToPin(
        pinId: 'lobby-42',
        pollId: 'poll-created-abc',
      );
      expect(attached.pollId, 'poll-created-abc');
      expect(attached.chatMessageId, isNull);
      expect(
        const FillPinPoll(pinId: 'pin-x', pollId: 'poll-x').chatMessageId,
        isNull,
      );
    });

    test('XOR stays planPeacockSelfNotify — no second self-notify path', () {
      expect(
        planPeacockSelfNotify(
          notificationId: 'n1',
          currentUid: 'u1',
          isForeground: true,
          locallyPresentedIds: {},
        ).wouldDoubleNotifySelf,
        isFalse,
      );

      final live = _read(_kHeader);
      expect(live.contains('sendNotificationToUsers'), isFalse);
      expect(live.contains('FirebaseMessaging'), isFalse);
      expect(live.contains('NotificationService'), isFalse);
    });
  });
}
