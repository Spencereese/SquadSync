import 'package:freezed_annotation/freezed_annotation.dart';

part 'constitution.freezed.dart';
part 'constitution.g.dart';

/// Constitution template for chat group rules
@freezed
class ConstitutionTemplate with _$ConstitutionTemplate {
  const factory ConstitutionTemplate({
    required String id,
    required String name,
    required String description,
    required String icon,
    required Map<String, dynamic> rules,
    @Default(false) bool isSystemTemplate,
    String? createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int usageCount,
  }) = _ConstitutionTemplate;

  factory ConstitutionTemplate.fromJson(Map<String, dynamic> json) =>
      _$ConstitutionTemplateFromJson(json);
}

/// Active constitution for a chat group
@freezed
class ChatConstitution with _$ChatConstitution {
  const factory ChatConstitution({
    required String id,
    required String chatGroupId,
    String? templateId,
    required Map<String, dynamic> rules,
    required String createdBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(true) bool isActive,
    @Default([]) List<Map<String, dynamic>> voteHistory,
  }) = _ChatConstitution;

  factory ChatConstitution.fromJson(Map<String, dynamic> json) =>
      _$ChatConstitutionFromJson(json);

  /// Get spot timer duration from rules
  static Duration? getSpotTimerDuration(Map<String, dynamic> rules) {
    final timerStr = rules['spot_timer'] as String?;
    if (timerStr == null) return null;
    
    final regex = RegExp(r'(\d+)(m|h|s)');
    final match = regex.firstMatch(timerStr);
    if (match == null) return null;
    
    final value = int.parse(match.group(1)!);
    final unit = match.group(2)!;
    
    switch (unit) {
      case 's':
        return Duration(seconds: value);
      case 'm':
        return Duration(minutes: value);
      case 'h':
        return Duration(hours: value);
      default:
        return null;
    }
  }

  /// Get enforcement level
  static String getEnforcementLevel(Map<String, dynamic> rules) {
    return rules['enforcement_level'] as String? ?? 'loose_social';
  }

  /// Check if mic is required
  static bool isMicRequired(Map<String, dynamic> rules) {
    return rules['mic_required'] as bool? ?? false;
  }

  /// Get max violations before escalation
  static int getMaxViolations(Map<String, dynamic> rules) {
    return rules['max_violations'] as int? ?? 3;
  }

  /// Get violation decay days
  static int getViolationDecayDays(Map<String, dynamic> rules) {
    return rules['violation_decay_days'] as int? ?? 7;
  }
}

/// Vote on constitution changes
@freezed
class ConstitutionVote with _$ConstitutionVote {
  const factory ConstitutionVote({
    required String id,
    required String constitutionId,
    required String chatGroupId,
    required Map<String, dynamic> proposedRules,
    required String proposedBy,
    @Default({}) Map<String, bool> votes,
    @Default(0) int voteCountYes,
    @Default(0) int voteCountNo,
    @Default(0.5) double voteThreshold,
    @Default('pending') String status,
    required DateTime expiresAt,
    required DateTime createdAt,
    DateTime? resolvedAt,
  }) = _ConstitutionVote;

  factory ConstitutionVote.fromJson(Map<String, dynamic> json) =>
      _$ConstitutionVoteFromJson(json);

  /// Check if vote has expired
  const ConstitutionVote._();
  
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  
  bool get isPending => status == 'pending';
  
  bool get hasPassed => status == 'passed';
  
  /// Calculate current vote percentage
  double get yesPercentage {
    final total = voteCountYes + voteCountNo;
    if (total == 0) return 0.0;
    return voteCountYes / total;
  }
  
  /// Check if threshold is met
  bool get thresholdMet => yesPercentage >= voteThreshold;
  
  /// Get remaining time
  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return expiresAt.difference(DateTime.now());
  }
}

/// Rule violation tracking
@freezed
class RuleViolation with _$RuleViolation {
  const factory RuleViolation({
    required String id,
    required String lobbyId,
    String? chatGroupId,
    required String userUid,
    required String ruleType,
    @Default('minor') String severity,
    @Default({}) Map<String, dynamic> violationData,
    String? enforcementAction,
    required DateTime createdAt,
    DateTime? resolvedAt,
    DateTime? expiresAt,
  }) = _RuleViolation;

  factory RuleViolation.fromJson(Map<String, dynamic> json) =>
      _$RuleViolationFromJson(json);

  /// Check if violation is still active
  const RuleViolation._();
  
  bool get isActive {
    if (resolvedAt != null) return false;
    if (expiresAt == null) return true;
    return DateTime.now().isBefore(expiresAt!);
  }
  
  /// Get severity level (0-3)
  int get severityLevel {
    switch (severity) {
      case 'minor':
        return 0;
      case 'moderate':
        return 1;
      case 'major':
        return 2;
      case 'critical':
        return 3;
      default:
        return 0;
    }
  }
}

/// Tag analytics
@freezed
class TagAnalytics with _$TagAnalytics {
  const factory TagAnalytics({
    required String id,
    required String tag,
    @Default(1) int usageCount,
    @Default(0) int lobbyCount,
    @Default(0) int userCount,
    required DateTime lastUsed,
    required DateTime createdAt,
    @Default(0.0) double trendingScore,
    String? category,
  }) = _TagAnalytics;

  factory TagAnalytics.fromJson(Map<String, dynamic> json) =>
      _$TagAnalyticsFromJson(json);

  /// Check if tag is trending
  const TagAnalytics._();
  
  bool get isTrending => trendingScore > 5.0;
  
  /// Get trend direction
  String get trendDirection {
    if (trendingScore > 10.0) return 'hot';
    if (trendingScore > 5.0) return 'rising';
    if (trendingScore > 1.0) return 'stable';
    return 'declining';
  }
}
