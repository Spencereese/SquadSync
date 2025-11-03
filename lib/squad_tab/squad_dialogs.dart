import 'package:flutter/material.dart';
import '../squad_state.dart';
import 'dialogs/block_dialog.dart';
import 'dialogs/complaint_dialog.dart';
import 'dialogs/ratings_dialog.dart';
import 'dialogs/join_lobby_dialog.dart';

/// Service class for showing squad-related dialogs
/// Provides a clean interface for displaying various squad dialogs
class SquadDialogs {
  /// Show block/unblock player dialog
  static void showBlockDialog(
      BuildContext context, String player, SquadState squadState) {
    BlockDialog.show(context, player, squadState);
  }

  /// Show complaint filing dialog
  static void showComplaintDialog(BuildContext context,
      ScaffoldMessengerState messenger, SquadState squadState, String player) {
    ComplaintDialog.show(context, messenger, squadState, player);
  }

  /// Show player rating dialog
  static void showRatingsDialog(BuildContext context,
      ScaffoldMessengerState messenger, SquadState squadState, String player) {
    RatingsDialog.show(context, messenger, squadState, player);
  }

  /// Show join lobby dialog
  static void showJoinLobbyDialog(
      BuildContext context, String player, SquadState squadState) {
    JoinLobbyDialog.show(context, player, squadState);
  }
}
