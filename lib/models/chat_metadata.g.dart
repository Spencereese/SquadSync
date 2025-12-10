// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_metadata.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ChatMetadataImpl _$$ChatMetadataImplFromJson(Map<String, dynamic> json) =>
    _$ChatMetadataImpl(
      chatId: json['chatId'] as String,
      lastMessageTimestamp:
          (json['lastMessageTimestamp'] as num?)?.toInt() ?? 0,
      unreadCounts: (json['unreadCounts'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, (e as num).toInt()),
          ) ??
          const {},
      typingUsers: (json['typingUsers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      lastReadMessageId:
          (json['lastReadMessageId'] as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              const {},
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );

Map<String, dynamic> _$$ChatMetadataImplToJson(_$ChatMetadataImpl instance) =>
    <String, dynamic>{
      'chatId': instance.chatId,
      'lastMessageTimestamp': instance.lastMessageTimestamp,
      'unreadCounts': instance.unreadCounts,
      'typingUsers': instance.typingUsers,
      'lastReadMessageId': instance.lastReadMessageId,
      'updatedAt': instance.updatedAt?.toIso8601String(),
    };
