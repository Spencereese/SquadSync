import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squad_sync/presentation/notifiers/lobby_notifier.dart' as ln;
import 'dialogs/block_dialog.dart';
import 'dialogs/complaint_dialog.dart';
import 'dialogs/ratings_dialog.dart';
import 'dialogs/join_lobby_dialog.dart';

/// Service class for showing squad-related dialogs
/// Provides a clean interface for displaying various squad dialogs
class LobbyDialogs {
  /// Show block/unblock player dialog
  static void showBlockDialog(
      BuildContext context, String player, WidgetRef ref) {
    BlockDialog.show(context, player);
  }

  /// Show complaint filing dialog
  static void showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, WidgetRef ref, String player) {
    ComplaintDialog.show(context, messenger, player);
  }

  /// Show player rating dialog
  static void showRatingsDialog(BuildContext context,
      ScaffoldMessengerState messenger, WidgetRef ref, String player) {
    final squadState = ref.read(ln.lobbyNotifierProvider).maybeWhen(
          data: (data) => data,
          orElse: () => null,
        );
    if (squadState != null) {
      RatingsDialog.show(context, messenger, squadState, player);
    }
  }

  /// Show join lobby dialog
  static void showJoinLobbyDialog(
      BuildContext context, String player, WidgetRef ref) {
    JoinLobbyDialog.show(context, player);
  }
}
