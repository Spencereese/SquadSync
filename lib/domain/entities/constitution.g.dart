// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'constitution.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$ConstitutionTemplateImpl _$$ConstitutionTemplateImplFromJson(
        Map<String, dynamic> json) =>
    _$ConstitutionTemplateImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      icon: json['icon'] as String,
      rules: json['rules'] as Map<String, dynamic>,
      isSystemTemplate: json['isSystemTemplate'] as bool? ?? false,
      createdBy: json['createdBy'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$$ConstitutionTemplateImplToJson(
        _$ConstitutionTemplateImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'icon': instance.icon,
      'rules': instance.rules,
      'isSystemTemplate': instance.isSystemTemplate,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'usageCount': instance.usageCount,
    };

_$ChatConstitutionImpl _$$ChatConstitutionImplFromJson(
        Map<String, dynamic> json) =>
    _$ChatConstitutionImpl(
      id: json['id'] as String,
      chatGroupId: json['chatGroupId'] as String,
      templateId: json['templateId'] as String?,
      rules: json['rules'] as Map<String, dynamic>,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      voteHistory: (json['voteHistory'] as List<dynamic>?)
              ?.map((e) => e as Map<String, dynamic>)
              .toList() ??
          const [],
    );

Map<String, dynamic> _$$ChatConstitutionImplToJson(
        _$ChatConstitutionImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'chatGroupId': instance.chatGroupId,
      'templateId': instance.templateId,
      'rules': instance.rules,
      'createdBy': instance.createdBy,
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt.toIso8601String(),
      'isActive': instance.isActive,
      'voteHistory': instance.voteHistory,
    };

_$ConstitutionVoteImpl _$$ConstitutionVoteImplFromJson(
        Map<String, dynamic> json) =>
    _$ConstitutionVoteImpl(
      id: json['id'] as String,
      constitutionId: json['constitutionId'] as String,
      chatGroupId: json['chatGroupId'] as String,
      proposedRules: json['proposedRules'] as Map<String, dynamic>,
      proposedBy: json['proposedBy'] as String,
      votes: (json['votes'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as bool),
          ) ??
          const {},
      voteCountYes: (json['voteCountYes'] as num?)?.toInt() ?? 0,
      voteCountNo: (json['voteCountNo'] as num?)?.toInt() ?? 0,
      voteThreshold: (json['voteThreshold'] as num?)?.toDouble() ?? 0.5,
      status: json['status'] as String? ?? 'pending',
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
    );

Map<String, dynamic> _$$ConstitutionVoteImplToJson(
        _$ConstitutionVoteImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'constitutionId': instance.constitutionId,
      'chatGroupId': instance.chatGroupId,
      'proposedRules': instance.proposedRules,
      'proposedBy': instance.proposedBy,
      'votes': instance.votes,
      'voteCountYes': instance.voteCountYes,
      'voteCountNo': instance.voteCountNo,
      'voteThreshold': instance.voteThreshold,
      'status': instance.status,
      'expiresAt': instance.expiresAt.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
    };

_$RuleViolationImpl _$$RuleViolationImplFromJson(Map<String, dynamic> json) =>
    _$RuleViolationImpl(
      id: json['id'] as String,
      lobbyId: json['lobbyId'] as String,
      chatGroupId: json['chatGroupId'] as String?,
      userUid: json['userUid'] as String,
      ruleType: json['ruleType'] as String,
      severity: json['severity'] as String? ?? 'minor',
      violationData: json['violationData'] as Map<String, dynamic>? ?? const {},
      enforcementAction: json['enforcementAction'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      resolvedAt: json['resolvedAt'] == null
          ? null
          : DateTime.parse(json['resolvedAt'] as String),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
    );

Map<String, dynamic> _$$RuleViolationImplToJson(_$RuleViolationImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'lobbyId': instance.lobbyId,
      'chatGroupId': instance.chatGroupId,
      'userUid': instance.userUid,
      'ruleType': instance.ruleType,
      'severity': instance.severity,
      'violationData': instance.violationData,
      'enforcementAction': instance.enforcementAction,
      'createdAt': instance.createdAt.toIso8601String(),
      'resolvedAt': instance.resolvedAt?.toIso8601String(),
      'expiresAt': instance.expiresAt?.toIso8601String(),
    };

_$TagAnalyticsImpl _$$TagAnalyticsImplFromJson(Map<String, dynamic> json) =>
    _$TagAnalyticsImpl(
      id: json['id'] as String,
      tag: json['tag'] as String,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 1,
      lobbyCount: (json['lobbyCount'] as num?)?.toInt() ?? 0,
      userCount: (json['userCount'] as num?)?.toInt() ?? 0,
      lastUsed: DateTime.parse(json['lastUsed'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      trendingScore: (json['trendingScore'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] as String?,
    );

Map<String, dynamic> _$$TagAnalyticsImplToJson(_$TagAnalyticsImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tag': instance.tag,
      'usageCount': instance.usageCount,
      'lobbyCount': instance.lobbyCount,
      'userCount': instance.userCount,
      'lastUsed': instance.lastUsed.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'trendingScore': instance.trendingScore,
      'category': instance.category,
    };
