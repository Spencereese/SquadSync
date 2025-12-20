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
    @Default([]) List<String> tags,
    @Default('group_private') String visibility,
    @Default({}) Map<String, dynamic> constitutionRules,
    String? embeddedMessageId,
    String? chatGroupId,
  }) = _Lobby;

  factory Lobby.fromJson(Map<String, dynamic> json) {
    // Handle null spots/spotTimers from database
    if (json['spots'] == null) {
      final maxSpots = json['maxSpots'] as int? ?? 0;
      json['spots'] = List.filled(maxSpots, null);
    }
    if (json['spotTimers'] == null) {
      final maxSpots = json['maxSpots'] as int? ?? 0;
      json['spotTimers'] = List.filled(maxSpots, null);
    }
    return _$LobbyFromJson(json);
  }

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
