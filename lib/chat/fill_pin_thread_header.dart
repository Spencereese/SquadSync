import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/lobby.dart';
import '../domain/entities/lobby_state.dart';
import '../presentation/notifiers/lobby_notifier.dart' as ln;
import '../services/fill_pin_share.dart';
import '../services/fill_pin_visibility.dart';

const kFillPinThreadHeaderKey = Key('fill-pin-thread-header');
const kFillPinThreadHeaderSeatKey = Key('fill-pin-thread-header-seats');
const kFillPinShareKey = Key('fill-pin-share');
const kFillPinPublicSwitchKey = Key('fill-pin-public-switch');

/// Compact pin header height when a this-group pin is live.
const double kFillPinThreadHeaderHeight = 40;

/// Coming-hold countdown chrome is a later slice. Resolver leaves this null.
typedef FillPinComingStub = String?;

class FillPinSnapshot {
  const FillPinSnapshot({
    required this.lobbyId,
    required this.gameName,
    required this.seated,
    required this.maxSpots,
    required this.seatedUids,
    this.displayNames = const {},
    this.avatarUrls = const {},
    this.comingCountdown,
  });

  final String lobbyId;
  final String gameName;
  final int seated;
  final int maxSpots;
  final List<String> seatedUids;
  final Map<String, String> displayNames;
  final Map<String, String> avatarUrls;

  /// Optional Coming countdown label. Stub — machine exists, UI later.
  final FillPinComingStub comingCountdown;

  String get seatLabel => '$seated/$maxSpots';

  String get seatedNames {
    if (seatedUids.isEmpty) return '';
    return seatedUids
        .map((uid) => displayNames[uid] ?? _shortUid(uid))
        .join(', ');
  }
}

/// Active Fill PIN for THIS [chatGroupId] only. Other-group / inactive
/// lobbies do not count. Live seat count prefers [LobbyState.gameLobbySpots]
/// when the matched lobby is the selected/current one.
FillPinSnapshot? resolveFillPinForThread({
  required LobbyState? state,
  required String? chatGroupId,
}) {
  final threadId = (chatGroupId ?? '').trim();
  if (state == null || threadId.isEmpty) return null;

  final lobby = _thisGroupPin(state, threadId);
  if (lobby == null) return null;

  final liveSpots = _liveSpots(state, lobby);
  var seatedUids = _seatedUids(liveSpots);
  if (seatedUids.isEmpty) {
    seatedUids = lobby.memberUids
        .map(_seatUid)
        .where((uid) => uid.isNotEmpty)
        .toList(growable: false);
  }

  final avatars = <String, String>{};
  final images = state.memberProfileImages;
  if (images != null) {
    for (final uid in seatedUids) {
      final url = images[uid];
      if (url != null && url.isNotEmpty) avatars[uid] = url;
    }
  }

  return FillPinSnapshot(
    lobbyId: lobby.id,
    gameName: lobby.gameName.trim().isEmpty ? 'Lobby' : lobby.gameName.trim(),
    seated: seatedUids.length,
    maxSpots: lobby.maxSpots,
    seatedUids: seatedUids,
    displayNames: state.memberDisplayNames,
    avatarUrls: avatars,
  );
}

/// Header above the thread. Shrinks to nothing when this group has no pin.
Widget wrapFillPinThreadHeader({
  required String? chatGroupId,
  required Widget child,
}) {
  return Column(
    children: [
      FillPinThreadHeaderHost(chatGroupId: chatGroupId),
      Expanded(child: child),
    ],
  );
}

class FillPinThreadHeaderHost extends ConsumerWidget {
  const FillPinThreadHeaderHost({super.key, this.chatGroupId});

  final String? chatGroupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ln.lobbyNotifierProvider).valueOrNull;
    final snapshot =
        resolveFillPinForThread(state: state, chatGroupId: chatGroupId);
    if (snapshot == null) return const SizedBox.shrink();
    return FillPinThreadHeader(
      snapshot: snapshot,
      chatGroupId: chatGroupId,
    );
  }
}

/// Presentational pin header. No bubble / theme rewrite.
class FillPinThreadHeader extends StatelessWidget {
  const FillPinThreadHeader({
    super.key,
    required this.snapshot,
    this.chatGroupId,
  });

  final FillPinSnapshot snapshot;
  final String? chatGroupId;

  @override
  Widget build(BuildContext context) {
    final names = snapshot.seatedNames;
    return Material(
      key: kFillPinThreadHeaderKey,
      color: Colors.black.withValues(alpha: 0.35),
      child: SizedBox(
        height: kFillPinThreadHeaderHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.push_pin_outlined, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  snapshot.gameName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                snapshot.seatLabel,
                key: kFillPinThreadHeaderSeatKey,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (snapshot.seatedUids.isNotEmpty) ...[
                const SizedBox(width: 8),
                _SeatedAvatars(snapshot: snapshot),
                if (names.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      names,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ],
              if (snapshot.comingCountdown != null) ...[
                const SizedBox(width: 8),
                Text(
                  snapshot.comingCountdown!,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
              _FillPinPublicSwitch(snapshot: snapshot),
              _FillPinShareButton(
                chatGroupId: chatGroupId,
                snapshot: snapshot,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact public switch on the pin header. Friends tap to flip this
/// pin group | public (XOR, never both). Default is group. Pin-scoped.
class _FillPinPublicSwitch extends StatefulWidget {
  const _FillPinPublicSwitch({required this.snapshot});

  final FillPinSnapshot snapshot;

  @override
  State<_FillPinPublicSwitch> createState() => _FillPinPublicSwitchState();
}

class _FillPinPublicSwitchState extends State<_FillPinPublicSwitch> {
  void _flipGroupPublic() {
    final pinId = widget.snapshot.lobbyId;
    final current = resolveFillPinVisibility(pinId);
    final next = current == FillPinVisibility.public
        ? FillPinVisibility.group
        : FillPinVisibility.public;
    setFillPinVisibility(pinId, next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pinId = widget.snapshot.lobbyId.trim();
    if (pinId.isEmpty) return const SizedBox.shrink();
    final isPublic =
        resolveFillPinVisibility(pinId) == FillPinVisibility.public;
    return Semantics(
      label: isPublic ? 'Public pin' : 'Group pin',
      child: IconButton(
        key: kFillPinPublicSwitchKey,
        icon: Icon(
          isPublic ? Icons.public : Icons.groups_outlined,
          size: 16,
          color: Colors.white70,
        ),
        tooltip: isPublic ? 'Public' : 'Group',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        visualDensity: VisualDensity.compact,
        onPressed: _flipGroupPublic,
      ),
    );
  }
}

/// Compact share on the pin header. Payload is pin-scoped — not chat.
class _FillPinShareButton extends StatelessWidget {
  const _FillPinShareButton({
    required this.chatGroupId,
    required this.snapshot,
  });

  final String? chatGroupId;
  final FillPinSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final thread = (chatGroupId ?? '').trim();
    if (thread.isEmpty) return const SizedBox.shrink();
    return Semantics(
      label: 'Share pin',
      child: IconButton(
        key: kFillPinShareKey,
        icon: const Icon(Icons.share, size: 16, color: Colors.white70),
        tooltip: 'Share pin',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 28, height: 28),
        visualDensity: VisualDensity.compact,
        onPressed: () {
          final payload = fillPinSharePayload(
            chatGroupId: thread,
            gameName: snapshot.gameName,
            seated: snapshot.seated,
            maxSpots: snapshot.maxSpots,
            pinId: snapshot.lobbyId,
            lobbyId: snapshot.lobbyId,
          );
          shareFillPin(payload: payload);
        },
      ),
    );
  }
}

class _SeatedAvatars extends StatelessWidget {
  const _SeatedAvatars({required this.snapshot});

  final FillPinSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final uids = snapshot.seatedUids.take(4).toList(growable: false);
    return SizedBox(
      width: 12.0 + (uids.length * 14.0),
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < uids.length; i++)
            Positioned(
              left: i * 14.0,
              child: _SeatAvatar(
                name: snapshot.displayNames[uids[i]] ?? _shortUid(uids[i]),
                avatarUrl: snapshot.avatarUrls[uids[i]],
              ),
            ),
        ],
      ),
    );
  }
}

class _SeatAvatar extends StatelessWidget {
  const _SeatAvatar({
    required this.name,
    this.avatarUrl,
  });

  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final url = avatarUrl;
    return CircleAvatar(
      radius: 10,
      backgroundColor: Colors.white24,
      child: url != null && url.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: 20,
                height: 20,
                fit: BoxFit.cover,
                memCacheWidth: 60,
                memCacheHeight: 60,
                placeholder: (_, __) => Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
                errorWidget: (_, __, ___) => Text(
                  initial,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            )
          : Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
    );
  }
}

Lobby? _thisGroupPin(LobbyState state, String threadId) {
  final current = state.currentLobby;
  if (_lobbyIsThisGroupPin(current, threadId)) return current;

  Lobby? newest;
  for (final lobby in state.userLobbies.values) {
    if (!_lobbyIsThisGroupPin(lobby, threadId)) continue;
    if (newest == null || lobby.createdAt.isAfter(newest.createdAt)) {
      newest = lobby;
    }
  }
  if (newest != null) return newest;

  return _pinFromGameLobbies(state, threadId);
}

bool _lobbyIsThisGroupPin(Lobby? lobby, String threadId) {
  if (lobby == null || !lobby.isActive) return false;
  return (lobby.chatGroupId ?? '').trim() == threadId;
}

Lobby? _pinFromGameLobbies(LobbyState state, String threadId) {
  Lobby? newest;
  for (final entry in state.gameLobbies.entries) {
    for (final raw in entry.value) {
      final lobby = _lobbyFromMap(raw, fallbackGame: entry.key);
      if (!_lobbyIsThisGroupPin(lobby, threadId)) continue;
      final currentNewest = newest;
      if (currentNewest == null ||
          lobby.createdAt.isAfter(currentNewest.createdAt)) {
        newest = lobby;
      }
    }
  }
  return newest;
}

Lobby _lobbyFromMap(Map<String, dynamic> raw, {required String fallbackGame}) {
  final id = (raw['id'] ?? raw['lobbyId'] ?? '').toString();
  final game = _mapGameName(raw) ?? fallbackGame;
  final spots = _mapSpots(raw['spots']);
  final max = (raw['maxSpots'] as num?)?.toInt() ??
      (raw['max_spots'] as num?)?.toInt() ??
      (spots.isNotEmpty ? spots.length : 4);
  final createdAt = raw['createdAt'] ?? raw['created_at'];
  return Lobby(
    id: id.isEmpty ? 'map-$game' : id,
    name: (raw['name'] ?? game).toString(),
    memberUids: _mapStringList(raw['memberUids'] ?? raw['member_uids']),
    gameName: game,
    maxSpots: max,
    createdBy: (raw['createdBy'] ?? raw['created_by'] ?? '').toString(),
    createdAt: createdAt is DateTime
        ? createdAt
        : DateTime.tryParse(createdAt?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
    spots: spots.isEmpty ? List<String?>.filled(max, null) : spots,
    spotTimers: const [],
    viewers: const [],
    statuses: const {},
    isActive: raw['isActive'] == true || raw['is_active'] == true,
    chatGroupId:
        (raw['chatGroupId'] ?? raw['chat_group_id'])?.toString(),
  );
}

String? _mapGameName(Map<String, dynamic> raw) {
  final direct = raw['gameName'] ?? raw['game_name'];
  if (direct is String && direct.trim().isNotEmpty) return direct.trim();
  final focus = raw['game_focus'] ?? raw['gameFocus'];
  if (focus is String && focus.trim().isNotEmpty) return focus.trim();
  if (focus is Map) {
    final name = focus['name'];
    if (name is String && name.trim().isNotEmpty) return name.trim();
  }
  return null;
}

List<String?> _mapSpots(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e?.toString()).toList(growable: false);
}

List<String> _mapStringList(Object? raw) {
  if (raw is! List) return const [];
  return raw
      .map((e) => e?.toString() ?? '')
      .where((e) => e.isNotEmpty)
      .toList(growable: false);
}

List<String?> _liveSpots(LobbyState state, Lobby lobby) {
  final selected = state.selectedLobbyId == lobby.id ||
      state.currentLobby?.id == lobby.id;
  if (!selected) return lobby.spots;
  final live = state.gameLobbySpots[lobby.gameName];
  if (live == null || live.isEmpty) return lobby.spots;
  return live;
}

List<String> _seatedUids(List<String?> spots) {
  return spots
      .whereType<String>()
      .map(_seatUid)
      .where((uid) => uid.isNotEmpty)
      .toList(growable: false);
}

String _seatUid(String raw) {
  final trimmed = raw.trim();
  const suffix = '_calling';
  if (trimmed.endsWith(suffix)) {
    return trimmed.substring(0, trimmed.length - suffix.length);
  }
  return trimmed;
}

String _shortUid(String uid) {
  if (uid.length <= 6) return uid;
  return uid.substring(0, 6);
}
