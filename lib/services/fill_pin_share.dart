// PIN WAVE P2 — Share Fill PIN, not chat history.
//
// Share-sheet payload is this pin only: game + n/max + sit-here deep
// link. Recipients open the thread/pin via locationForDeepLink.
// Message bodies are never copied into the payload.
//
// Pin starts in THIS group. Explicit share to another group or public,
// unshared-group visibility, AASA / OG preview title, and poll-on-pin
// are P3 stubs — this file does not start them.
//
// One notify pipeline; do not invent a second.
import 'package:share_plus/share_plus.dart';

import '../core/deep_link_routes.dart';
import 'fill_pin_link_preview.dart';

/// Cheap P3 preview stub. Live OG title / AASA card is later.
const kFillPinShareSitHereSuffix = 'sit here';

typedef FillPinShareFn = Future<void> Function(String payload);

/// Tests inject the sheet. Live path uses [SharePlus].
FillPinShareFn? fillPinShareOverride;

void resetFillPinShareHooks() {
  fillPinShareOverride = null;
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// Sit-here URL: same table as Live Activity
/// (`codsquadapp://chat/<thread>?pin_id=&lobby_id=`).
/// [locationForDeepLink] lands on `/chat/<thread>`.
String fillPinShareSitHereLink({
  required String chatGroupId,
  String? pinId,
  String? lobbyId,
}) {
  final thread = chatGroupId.trim();
  if (thread.isEmpty) {
    return Uri(scheme: kSimulatorDeepLinkScheme, host: 'chat').toString();
  }
  return Uri(
    scheme: kSimulatorDeepLinkScheme,
    host: 'chat',
    pathSegments: [thread],
    queryParameters: {
      if (_nonEmpty(pinId) != null) 'pin_id': pinId!.trim(),
      if (_nonEmpty(lobbyId) != null) 'lobby_id': lobbyId!.trim(),
    },
  ).toString();
}

/// Share / OG title stub — reuses [fillPinLinkPreviewTitle].
String fillPinSharePreviewTitle({
  required String gameName,
  required int seated,
  required int maxSpots,
}) {
  return fillPinLinkPreviewTitle(
    game: gameName,
    seated: seated,
    max: maxSpots,
  );
}

/// Pin-scoped share text. No message list. No chat history body.
String fillPinSharePayload({
  required String chatGroupId,
  required String gameName,
  required int seated,
  required int maxSpots,
  String? pinId,
  String? lobbyId,
}) {
  final thread = chatGroupId.trim();
  if (thread.isEmpty) return '';
  final title = fillPinSharePreviewTitle(
    gameName: gameName,
    seated: seated,
    maxSpots: maxSpots,
  );
  final link = fillPinShareSitHereLink(
    chatGroupId: thread,
    pinId: pinId,
    lobbyId: lobbyId,
  );
  return '$title\n$link';
}

/// Open the system share sheet with [payload]. Empty text is a no-op.
/// Tests inject [share] / [fillPinShareOverride].
Future<void> shareFillPin({
  required String payload,
  Future<void> Function(String text)? share,
}) async {
  final text = payload.trim();
  if (text.isEmpty) return;
  final run = share ?? fillPinShareOverride ?? _shareFillPinSheet;
  await run(text);
}

Future<void> _shareFillPinSheet(String payload) async {
  await SharePlus.instance.share(ShareParams(text: payload));
}
