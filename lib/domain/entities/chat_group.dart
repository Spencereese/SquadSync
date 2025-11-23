import 'package:freezed_annotation/freezed_annotation.dart';

part 'chat_group.freezed.dart';
part 'chat_group.g.dart';

@freezed
class ChatGroup with _$ChatGroup {
  const factory ChatGroup({
    required String id,
    required String name,
    required List<String> memberUids,
    required bool isPublic,
    required int memberCount,
    required String createdBy,
    required DateTime createdAt,
    String? description,
    String? avatarUrl,
    Map<String, dynamic>? metadata,
    List<String>? admins,
    List<String>? moderators,
    bool? isActive,
    DateTime? lastActivity,
    Map<String, dynamic>? settings,
  }) = _ChatGroup;

  factory ChatGroup.fromJson(Map<String, dynamic> json) =>
      _$ChatGroupFromJson(json);

  factory ChatGroup.create({
    required String name,
    required String createdBy,
    required bool isPublic,
    String? description,
    Map<String, dynamic>? metadata,
  }) =>
      ChatGroup(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        memberUids: [createdBy],
        isPublic: isPublic,
        memberCount: 1,
        createdBy: createdBy,
        createdAt: DateTime.now(),
        description: description,
        metadata: metadata,
        admins: [createdBy],
        moderators: [],
        isActive: true,
        lastActivity: DateTime.now(),
        settings: {},
      );
}