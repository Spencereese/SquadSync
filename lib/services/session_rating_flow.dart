import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/lobbies_tab/dialogs/session_rating_dialog.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/session_rating_machine.dart';

/// Collect a 1–5 star rating (or skip) after a session is recorded.
Future<SessionRatingState> collectSessionRating(
  BuildContext context, {
  required String lobbyId,
  String? result,
  String? gameName,
}) async {
  String? uid;
  try {
    uid = AuthServiceSupabase().currentUser?.id;
  } catch (_) {
    uid = null;
  }
  if (!context.mounted) return SessionRatingState.unrated;
  return showSessionRatingDialog(
    context,
    lobbyId: lobbyId,
    raterUid: uid,
    result: result,
    gameName: gameName,
  );
}

/// Persist an ended session through [LobbyNotifier.recordWin] / [recordLoss],
/// encoding a rating into existing `match_history.notes` when submitted.
Future<void> recordEndedSquadSession({
  required WidgetRef ref,
  required String lobbyId,
  required String result,
  SessionRatingState sessionRating = SessionRatingState.unrated,
}) async {
  final notifier = ref.read(ln.lobbyNotifierProvider.notifier);
  if (result == 'win') {
    await notifier.recordWin(lobbyId, sessionRating: sessionRating);
  } else {
    await notifier.recordLoss(lobbyId, sessionRating: sessionRating);
  }
}

/// Prompt then record. Live path: lobby Win/Loss and stats Record win/loss.
Future<SessionRatingState> promptAndRecordEndedSession({
  required BuildContext context,
  required WidgetRef ref,
  required String lobbyId,
  required String result,
  String? gameName,
}) async {
  final rating = await collectSessionRating(
    context,
    lobbyId: lobbyId,
    result: result,
    gameName: gameName,
  );
  if (!context.mounted) return rating;
  await recordEndedSquadSession(
    ref: ref,
    lobbyId: lobbyId,
    result: result,
    sessionRating: rating,
  );
  return rating;
}
