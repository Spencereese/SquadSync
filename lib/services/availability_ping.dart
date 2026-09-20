import 'package:flutter/foundation.dart';

import '../core/lobby_chat_bind.dart';
import '../core/notification_cooldowns.dart';
import '../domain/entities/lobby.dart';
import '../managers/notification_manager.dart';
import '../notification_service.dart';
import 'availability_on.dart';
import 'supabase_service.dart';

/// Payload type for an "I'm on now" ping. Taps reuse [NotificationRoutes].
const kAvailabilityPingType = 'availability_ping';

/// In-memory anti-spam for the same sender + lobby. Recipients still go
/// through [NotificationService.sendNotificationToUsers] (no second presenter).
const kAvailabilityPingCooldown = Duration(minutes: 2);

/// Recipients for an availability ping: lobby members except the sender.
/// Empty / whitespace / duplicates dropped. Never FCM-to-self.
List<String> availabilityPingRecipients({
  required Iterable<String> memberUids,
  required String senderUid,
}) {
  final sender = senderUid.trim();
  final seen = <String>{};
  final out = <String>[];
  for (final raw in memberUids) {
    final uid = raw.trim();
    if (uid.isEmpty || uid == sender) continue;
    if (!seen.add(uid)) continue;
    out.add(uid);
  }
  return out;
}

/// Lobby (or squad) members to ping. [lobbyId] routes to `/squad`; when
/// only [squadId] is known the tap falls through to chat.
class AvailabilityPingTarget {
  const AvailabilityPingTarget({
    required this.senderUid,
    required this.memberUids,
    this.lobbyId,
    this.squadId,
    this.gameName,
    this.senderName,
  });

  final String senderUid;
  final List<String> memberUids;
  final String? lobbyId;
  final String? squadId;
  final String? gameName;
  final String? senderName;
}

class AvailabilityPingPlan {
  const AvailabilityPingPlan({
    required this.recipientUids,
    required this.title,
    required this.body,
    required this.data,
  });

  final List<String> recipientUids;
  final String title;
  final String body;
  final Map<String, dynamic> data;
}

enum AvailabilityPingStatus { sent, noMembers, selfOnly, cooldown }

class AvailabilityPingResult {
  const AvailabilityPingResult({
    required this.status,
    this.recipientUids = const [],
  });

  final AvailabilityPingStatus status;
  final List<String> recipientUids;

  bool get sent => status == AvailabilityPingStatus.sent;

  String get snackbarMessage {
    switch (status) {
      case AvailabilityPingStatus.sent:
        final n = recipientUids.length;
        return n == 1
            ? 'On now — pinged 1 member'
            : 'On now — pinged $n members';
      case AvailabilityPingStatus.cooldown:
        return 'Already pinged — try again shortly';
      case AvailabilityPingStatus.selfOnly:
      case AvailabilityPingStatus.noMembers:
        return 'No one else in this lobby';
    }
  }
}

/// Resolve members from in-memory lobby state (LFG / lobby UI).
AvailabilityPingTarget? resolveAvailabilityPingTarget({
  required String senderUid,
  String? lobbyId,
  String? squadId,
  Lobby? currentLobby,
  Map<String, Lobby> userLobbies = const {},
  List<String> lobbyMemberUids = const [],
  String? gameName,
  String? senderName,
}) {
  final wantedLobby = _nonEmpty(lobbyId);
  final wantedSquad = _nonEmpty(squadId);

  Lobby? lobby;
  if (wantedLobby != null) {
    if (currentLobby != null && currentLobby.id == wantedLobby) {
      lobby = currentLobby;
    }
    lobby ??= userLobbies[wantedLobby];
  }
  if (lobby == null && wantedSquad != null) {
    if (currentLobby != null &&
        (currentLobby.chatGroupId == wantedSquad ||
            currentLobby.id == wantedSquad)) {
      lobby = currentLobby;
    }
    if (lobby == null) {
      for (final candidate in userLobbies.values) {
        if (candidate.chatGroupId == wantedSquad ||
            candidate.id == wantedSquad) {
          lobby = candidate;
          break;
        }
      }
    }
  }

  if (lobby != null) {
    return AvailabilityPingTarget(
      senderUid: senderUid,
      memberUids: lobby.memberUids,
      lobbyId: lobby.id,
      squadId: _nonEmpty(lobby.chatGroupId) ?? wantedSquad,
      gameName: _nonEmpty(gameName) ?? _nonEmpty(lobby.gameName),
      senderName: senderName,
    );
  }

  if (lobbyMemberUids.isNotEmpty &&
      (wantedLobby != null || wantedSquad != null)) {
    return AvailabilityPingTarget(
      senderUid: senderUid,
      memberUids: lobbyMemberUids,
      lobbyId: wantedLobby,
      squadId: wantedSquad,
      gameName: gameName,
      senderName: senderName,
    );
  }
  return null;
}

AvailabilityPingPlan planAvailabilityPing(AvailabilityPingTarget target) {
  final recipients = availabilityPingRecipients(
    memberUids: target.memberUids,
    senderUid: target.senderUid,
  );
  final name = _nonEmpty(target.senderName) ?? 'A teammate';
  final game = _nonEmpty(target.gameName);
  final title = '$name is on now';
  final body = game == null
      ? '$name is ready to play'
      : '$name is ready to play $game';
  final data = NotificationManager.payloadFor(
    type: kAvailabilityPingType,
    lobbyId: target.lobbyId,
    gameName: target.gameName,
    payload: {
      'from_uid': target.senderUid,
      if (_nonEmpty(target.squadId) != null) 'squad_id': target.squadId,
      'user_id': target.senderUid,
    },
  );
  return AvailabilityPingPlan(
    recipientUids: recipients,
    title: title,
    body: body,
    data: data,
  );
}

/// "I'm on now" ping. Live path: LFG chat-info + lobby controls.
///
/// Sends through [NotificationService.sendNotificationToUsers] so taps
/// share [NotificationRoutes] with peacock / LFG. Recipients never include
/// the sender (no FCM-to-self). Not a second notification presenter.
class AvailabilityPing {
  AvailabilityPing._();

  static NotificationCooldownStore _cooldowns = NotificationCooldownStore();

  /// Test hook. Production sends via [NotificationService.sendNotificationToUsers].
  @visibleForTesting
  static Future<void> Function({
    required String title,
    required String body,
    required List<String> recipientUids,
    Map<String, dynamic>? data,
  })? sendToUsersHook;

  /// Test hook. Production reads lobbies / chat_groups.
  @visibleForTesting
  static Future<AvailabilityPingTarget?> Function(
    String squadOrLobbyId, {
    required String senderUid,
    String? senderName,
  })? loadMembersHook;

  @visibleForTesting
  static void resetTestHooks() {
    sendToUsersHook = null;
    loadMembersHook = null;
    _cooldowns = NotificationCooldownStore();
    resetAvailabilityOnStore();
  }

  static Future<AvailabilityPingResult> send(
    AvailabilityPingTarget target,
  ) async {
    final original = [
      for (final uid in target.memberUids)
        if (uid.trim().isNotEmpty) uid.trim(),
    ];
    final plan = planAvailabilityPing(target);
    // I-am-on live path: sender is On even when nobody else is in the lobby.
    availabilityOnStore.markOn(target.senderUid);
    if (plan.recipientUids.isEmpty) {
      final status = original.isEmpty
          ? AvailabilityPingStatus.noMembers
          : AvailabilityPingStatus.selfOnly;
      return AvailabilityPingResult(status: status);
    }

    final cooldownKey =
        '${target.senderUid}_${target.lobbyId ?? target.squadId ?? 'none'}';
    if (_cooldowns.isActive(cooldownKey)) {
      return AvailabilityPingResult(
        status: AvailabilityPingStatus.cooldown,
        recipientUids: plan.recipientUids,
      );
    }

    final send =
        sendToUsersHook ?? NotificationService.sendNotificationToUsers;
    await send(
      title: plan.title,
      body: plan.body,
      recipientUids: plan.recipientUids,
      data: plan.data,
    );
    _cooldowns.setExpiry(cooldownKey, kAvailabilityPingCooldown);
    return AvailabilityPingResult(
      status: AvailabilityPingStatus.sent,
      recipientUids: plan.recipientUids,
    );
  }

  /// Resolve in-memory lobby members, then load, then send. Called from
  /// Looking-for-Squad chat info and lobby controls.
  static Future<AvailabilityPingResult> dispatch({
    required String senderUid,
    String? lobbyId,
    String? squadId,
    Lobby? currentLobby,
    Map<String, Lobby> userLobbies = const {},
    List<String> lobbyMemberUids = const [],
    String? gameName,
    String? senderName,
  }) async {
    var target = resolveAvailabilityPingTarget(
      senderUid: senderUid,
      lobbyId: lobbyId,
      squadId: squadId,
      currentLobby: currentLobby,
      userLobbies: userLobbies,
      lobbyMemberUids: lobbyMemberUids,
      gameName: gameName,
      senderName: senderName,
    );
    if (target == null || target.memberUids.isEmpty) {
      final probe = _nonEmpty(lobbyId) ?? _nonEmpty(squadId);
      if (probe != null) {
        target = await loadMembersForSquad(
          probe,
          senderUid: senderUid,
          senderName: senderName,
        );
      }
    }
    if (target == null) {
      return const AvailabilityPingResult(
        status: AvailabilityPingStatus.noMembers,
      );
    }
    return send(target);
  }

  /// Live lookup when in-memory lobby state has no members.
  static Future<AvailabilityPingTarget?> loadMembersForSquad(
    String squadOrLobbyId, {
    required String senderUid,
    String? senderName,
  }) async {
    final hook = loadMembersHook;
    if (hook != null) {
      return hook(
        squadOrLobbyId,
        senderUid: senderUid,
        senderName: senderName,
      );
    }
    return _loadMembersFromSupabase(
      squadOrLobbyId,
      senderUid: senderUid,
      senderName: senderName,
    );
  }
}

Future<AvailabilityPingTarget?> _loadMembersFromSupabase(
  String squadOrLobbyId, {
  required String senderUid,
  String? senderName,
}) async {
  final probe = _nonEmpty(squadOrLobbyId);
  if (probe == null || !SupabaseService.isInitialized) return null;
  try {
    final client = SupabaseService.client;
    Map<String, dynamic>? lobby;
    try {
      final byChat = await client
          .from('lobbies')
          .select('id, member_uids, game_focus, chat_group_id')
          .eq('chat_group_id', probe)
          .limit(1);
      final rows = List<dynamic>.from(byChat);
      if (rows.isNotEmpty) {
        lobby = Map<String, dynamic>.from(rows.first as Map);
      }
    } catch (e) {
      debugPrint('Availability ping lobby-by-chat lookup skipped: $e');
    }
    lobby ??= await _maybeLobbyRow(probe);

    if (lobby != null) {
      return AvailabilityPingTarget(
        senderUid: senderUid,
        memberUids: _parseUidList(lobby['member_uids']),
        lobbyId: _nonEmpty(lobby['id']?.toString()),
        squadId: _nonEmpty(lobby['chat_group_id']?.toString()) ?? probe,
        gameName: _nonEmpty(lobby['game_focus']?.toString()),
        senderName: senderName,
      );
    }

    Map<String, dynamic>? group;
    try {
      group = await client
          .from('chat_groups')
          .select('id, member_uids, lobby_ids')
          .eq('id', probe)
          .maybeSingle();
    } catch (e) {
      debugPrint('Availability ping chat-group lookup skipped: $e');
    }
    if (group == null) return null;

    final lobbyIds = parseLobbyIds(group['lobby_ids']);
    if (lobbyIds.isNotEmpty) {
      final extra = await _maybeLobbyRow(lobbyIds.first);
      if (extra != null) {
        return AvailabilityPingTarget(
          senderUid: senderUid,
          memberUids: _parseUidList(extra['member_uids']),
          lobbyId: _nonEmpty(extra['id']?.toString()),
          squadId: _nonEmpty(extra['chat_group_id']?.toString()) ?? probe,
          gameName: _nonEmpty(extra['game_focus']?.toString()),
          senderName: senderName,
        );
      }
    }

    return AvailabilityPingTarget(
      senderUid: senderUid,
      memberUids: _parseUidList(group['member_uids']),
      squadId: probe,
      senderName: senderName,
    );
  } catch (e) {
    debugPrint('Availability ping member load failed: $e');
    return null;
  }
}

Future<Map<String, dynamic>?> _maybeLobbyRow(String id) async {
  try {
    return await SupabaseService.client
        .from('lobbies')
        .select('id, member_uids, game_focus, chat_group_id')
        .eq('id', id)
        .maybeSingle();
  } catch (e) {
    debugPrint('Availability ping lobby-by-id lookup skipped: $e');
    return null;
  }
}

List<String> _parseUidList(dynamic raw) {
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item != null && item.toString().trim().isNotEmpty)
        item.toString().trim(),
  ];
}

String? _nonEmpty(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}
