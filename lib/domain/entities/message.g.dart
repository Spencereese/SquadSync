// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MessageImpl _$$MessageImplFromJson(Map<String, dynamic> json) =>
    _$MessageImpl(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      messageType: $enumDecode(_$MessageTypeEnumMap, json['messageType']),
      mediaUrl: json['mediaUrl'] as String?,
      mediaType: json['mediaType'] as String?,
      reactions: (json['reactions'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, (e as num).toInt()),
      ),
      replyTo: json['replyTo'] as String?,
      poll: json['poll'] == null
          ? null
          : Poll.fromJson(json['poll'] as Map<String, dynamic>),
      voiceNoteUrl: json['voiceNoteUrl'] as String?,
      voiceNoteDuration: (json['voiceNoteDuration'] as num?)?.toInt(),
      aiResponse: json['aiResponse'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isEdited: json['isEdited'] as bool?,
      editedAt: json['editedAt'] == null
          ? null
          : DateTime.parse(json['editedAt'] as String),
      isDeleted: json['isDeleted'] as bool?,
      deletedAt: json['deletedAt'] == null
          ? null
          : DateTime.parse(json['deletedAt'] as String),
    );

Map<String, dynamic> _$$MessageImplToJson(_$MessageImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'senderId': instance.senderId,
      'text': instance.text,
      'timestamp': instance.timestamp.toIso8601String(),
      'messageType': _$MessageTypeEnumMap[instance.messageType]!,
      'mediaUrl': instance.mediaUrl,
      'mediaType': instance.mediaType,
      'reactions': instance.reactions,
      'replyTo': instance.replyTo,
      'poll': instance.poll,
      'voiceNoteUrl': instance.voiceNoteUrl,
      'voiceNoteDuration': instance.voiceNoteDuration,
      'aiResponse': instance.aiResponse,
      'metadata': instance.metadata,
      'isEdited': instance.isEdited,
      'editedAt': instance.editedAt?.toIso8601String(),
      'isDeleted': instance.isDeleted,
      'deletedAt': instance.deletedAt?.toIso8601String(),
    };

const _$MessageTypeEnumMap = {
  MessageType.text: 'text',
  MessageType.image: 'image',
  MessageType.video: 'video',
  MessageType.audio: 'audio',
  MessageType.voiceNote: 'voiceNote',
  MessageType.file: 'file',
  MessageType.poll: 'poll',
  MessageType.aiResponse: 'aiResponse',
  MessageType.system: 'system',
};

_$PollImpl _$$PollImplFromJson(Map<String, dynamic> json) => _$PollImpl(
      id: json['id'] as String,
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>).map((e) => e as String).toList(),
      votes: (json['votes'] as Map<String, dynamic>).map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      createdBy: json['createdBy'] as String,
      isClosed: json['isClosed'] as bool?,
      closedAt: json['closedAt'] == null
          ? null
          : DateTime.parse(json['closedAt'] as String),
    );

Map<String, dynamic> _$$PollImplToJson(_$PollImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'question': instance.question,
      'options': instance.options,
      'votes': instance.votes,
      'createdAt': instance.createdAt.toIso8601String(),
      'createdBy': instance.createdBy,
      'isClosed': instance.isClosed,
      'closedAt': instance.closedAt?.toIso8601String(),
    };
