import 'package:freezed_annotation/freezed_annotation.dart';

part 'lobby.freezed.dart';
part 'lobby.g.dart';

@freezed // Disable DiagnosticableTreeMixin - has bugs in Freezed 3.0
class Lobby with _$Lobby {
  const factory Lobby({
    required String id,
    required String name,
    required List<String> memberUids,
    required String gameName,
    required int maxSpots,
    required String createdBy,
    required DateTime createdAt,
    required List<String?> spots,
    required List<Map<String, dynamic>?> spotTimers,
    required List<String> viewers,
    required Map<String, String> statuses,
    required bool isActive,
    String? description,
    Map<String, dynamic>? settings,
  }) = _Lobby;

  factory Lobby.fromJson(Map<String, dynamic> json) => _$LobbyFromJson(json);

  factory Lobby.create({
    required String name,
    required String gameName,
    required int maxSpots,
    required String createdBy,
  }) =>
      Lobby(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        memberUids: [createdBy],
        gameName: gameName,
        maxSpots: maxSpots,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        spots: List.filled(maxSpots, null),
        spotTimers: List.filled(maxSpots, null),
        viewers: [],
        statuses: {},
        isActive: true,
      );
}
