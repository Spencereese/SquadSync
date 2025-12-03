import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'squad.freezed.dart';
part 'squad.g.dart';

class TimestampConverter
    implements JsonConverter<Timestamp, Map<String, dynamic>> {
  const TimestampConverter();

  @override
  Timestamp fromJson(Map<String, dynamic> json) {
    return Timestamp(json['seconds'] as int, json['nanoseconds'] as int);
  }

  @override
  Map<String, dynamic> toJson(Timestamp timestamp) => {
        'seconds': timestamp.seconds,
        'nanoseconds': timestamp.nanoseconds,
      };
}

@freezed
class PeacockTimer with _$PeacockTimer {
  const factory PeacockTimer({
    @TimestampConverter() required Timestamp endTime,
    required bool isActive,
  }) = _PeacockTimer;

  factory PeacockTimer.fromJson(Map<String, dynamic> json) =>
      _$PeacockTimerFromJson(json);
}

@freezed
class Squad with _$Squad {
  const factory Squad({
    required String id,
    required String name,
    String? primaryGameId,
    String? primaryGameName,
    int? maxSpots,
    required String creatorUid,
    @TimestampConverter() required Timestamp createdAt,
    required bool isPublic,
    String? inviteCode,
    required List<String> memberUids,
    @TimestampConverter() required Timestamp lastActivity,
    required Map<String, String?> spotClaims,
    required Map<String, PeacockTimer> peacockTimers,
    required Map<String, String> userStatuses,
    required List<String> tags,
    required bool lookingForMore,
    required String description,
    @TimestampConverter() Timestamp? bumpTimestamp,
  }) = _Squad;

  factory Squad.fromJson(Map<String, dynamic> json) => _$SquadFromJson(json);
}

extension SquadFirestore on Squad {
  static Squad fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    // Safe get with defaults
    Map<String, dynamic> getMap(String key) =>
        (data[key] as Map<String, dynamic>?) ?? {};
    List<String> getList(String key) =>
        (data[key] as List<dynamic>?)?.cast<String>() ?? <String>[];

    // Helper to parse timestamp safely
    Timestamp _parseTimestamp(dynamic value) {
      if (value is Timestamp) return value;
      if (value is String) {
        try {
          final dateTime = DateTime.parse(value);
          return Timestamp.fromDate(dateTime);
        } catch (e) {
          return Timestamp.now();
        }
      }
      return Timestamp.now();
    }

    return Squad(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Squad',
      primaryGameId: data['primaryGameId'] as String?,
      primaryGameName: data['primaryGameName'] as String?,
      maxSpots: data['maxSpots'] as int?,
      creatorUid: data['creatorUid'] as String? ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      isPublic: data['isPublic'] as bool? ?? false,
      inviteCode: data['inviteCode'] as String?,
      memberUids: getList('memberUids'),
      lastActivity: _parseTimestamp(data['lastActivity']),
      spotClaims:
          Map<String, String?>.from(getMap('spotClaims')), // String -> String?
      peacockTimers: (getMap('peacockTimers')).map((key, value) => MapEntry(
          key, PeacockTimer.fromJson(value as Map<String, dynamic>? ?? {}))),
      userStatuses: Map<String, String>.from(getMap('userStatuses')),
      tags: getList('tags'),
      lookingForMore: data['lookingForMore'] as bool? ?? false,
      description: data['description'] as String? ?? '',
      bumpTimestamp: data['bumpTimestamp'] != null
          ? _parseTimestamp(data['bumpTimestamp'])
          : null,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'primaryGameId': primaryGameId,
        'primaryGameName': primaryGameName,
        'maxSpots': maxSpots,
        'creatorUid': creatorUid,
        'createdAt': createdAt,
        'isPublic': isPublic,
        'inviteCode': inviteCode,
        'memberUids':
            memberUids.isEmpty ? <String>[] : memberUids, // never null
        'lastActivity': lastActivity,
        'spotClaims': spotClaims.isEmpty ? <String, String?>{} : spotClaims,
        'peacockTimers': peacockTimers.isEmpty
            ? <String, dynamic>{}
            : peacockTimers.map((k, v) => MapEntry(k, v.toJson())),
        'userStatuses':
            userStatuses.isEmpty ? <String, String>{} : userStatuses,
        'tags': tags.isEmpty ? <String>[] : tags,
        'lookingForMore': lookingForMore,
        'description': description,
        'bumpTimestamp': bumpTimestamp,
      };
}
