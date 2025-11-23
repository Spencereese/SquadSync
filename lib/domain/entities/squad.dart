import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad.freezed.dart';
part 'squad.g.dart';

@freezed
class Squad with _$Squad {
  const factory Squad({
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
  }) = _Squad;

  factory Squad.fromJson(Map<String, dynamic> json) =>
      _$SquadFromJson(json);

  factory Squad.create({
    required String name,
    required String gameName,
    required int maxSpots,
    required String createdBy,
  }) =>
      Squad(
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