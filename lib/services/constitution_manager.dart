import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/entities/constitution.dart';
import 'supabase_service.dart';

/// Manages constitution enforcement and rule violations
class ConstitutionManager {
  final SupabaseClient _supabase;

  /// Prefer an injected [supabase] (Riverpod / tests). The no-arg path uses
  /// [SupabaseService.maybeClient] and throws a clear [StateError] when
  /// uninitialized — never [Supabase.instance] assert in a harness.
  ConstitutionManager({SupabaseClient? supabase})
      : _supabase = supabase ?? _clientOrThrow();

  static SupabaseClient _clientOrThrow() {
    final client = SupabaseService.maybeClient;
    if (client == null) {
      throw StateError(
        'ConstitutionManager requires an injected SupabaseClient '
        '(or initialized SupabaseService). Override '
        'constitutionManagerProvider in unit tests — do not construct '
        'against Supabase.instance.',
      );
    }
    return client;
  }

  /// Authenticated uid, or null when there is no session.
  String? get currentUserId => _supabase.auth.currentUser?.id;

  /// Payload for a yes/no vote update. Pure — no network.
  static Map<String, dynamic> voteUpdatePayload({
    required Map<String, bool> existingVotes,
    required String userId,
    required bool yes,
  }) {
    final updatedVotes = Map<String, bool>.from(existingVotes);
    updatedVotes[userId] = yes;
    return {
      'votes': updatedVotes,
      'vote_count_yes': updatedVotes.values.where((v) => v).length,
      'vote_count_no': updatedVotes.values.where((v) => !v).length,
    };
  }

  /// Record [yes] for the current user on [vote].
  Future<void> submitVote({
    required ConstitutionVote vote,
    required bool yes,
  }) async {
    final userId = currentUserId;
    if (userId == null) {
      throw StateError(
        'Cannot submit constitution vote: no authenticated user.',
      );
    }
    final payload = voteUpdatePayload(
      existingVotes: vote.votes,
      userId: userId,
      yes: yes,
    );
    await _supabase
        .from('constitution_votes')
        .update(payload)
        .eq('id', vote.id);
  }

  /// Get active constitution for a chat group
  Future<ChatConstitution?> getActiveConstitution(String chatGroupId) async {
    try {
      final response = await _supabase
          .from('chat_constitutions')
          .select()
          .eq('chat_group_id', chatGroupId)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) return null;
      return ChatConstitution.fromJson(response);
    } catch (e) {
      debugPrint('Error getting active constitution: $e');
      return null;
    }
  }

  /// Get all constitution templates
  Future<List<ConstitutionTemplate>> getTemplates() async {
    try {
      final response = await _supabase
          .from('constitution_templates')
          .select()
          .order('is_system_template', ascending: false)
          .order('usage_count', ascending: false);

      return (response as List)
          .map((json) => ConstitutionTemplate.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting constitution templates: $e');
      return [];
    }
  }

  /// Create a new constitution from template
  Future<ChatConstitution?> createFromTemplate({
    required String chatGroupId,
    required String templateId,
    required String createdBy,
  }) async {
    try {
      // Get template
      final template = await _supabase
          .from('constitution_templates')
          .select()
          .eq('id', templateId)
          .single();

      // Create constitution
      final response = await _supabase
          .from('chat_constitutions')
          .insert({
            'chat_group_id': chatGroupId,
            'template_id': templateId,
            'rules': template['rules'],
            'created_by': createdBy,
            'is_active': true,
          })
          .select()
          .single();

      // Increment template usage
      await _supabase.rpc('increment', params: {
        'table_name': 'constitution_templates',
        'row_id': templateId,
        'column_name': 'usage_count',
      });

      return ChatConstitution.fromJson(response);
    } catch (e) {
      debugPrint('Error creating constitution from template: $e');
      return null;
    }
  }

  /// Record a rule violation
  Future<RuleViolation?> recordViolation({
    required String lobbyId,
    required String chatGroupId,
    required String userUid,
    required String ruleType,
    Map<String, dynamic>? violationData,
  }) async {
    try {
      // Get constitution to determine severity
      final constitution = await getActiveConstitution(chatGroupId);
      if (constitution == null) return null;

      final maxViolations =
          ChatConstitution.getMaxViolations(constitution.rules);
      final decayDays =
          ChatConstitution.getViolationDecayDays(constitution.rules);

      // Calculate severity using database function
      final severityResult =
          await _supabase.rpc('get_violation_severity', params: {
        'p_user_uid': userUid,
        'p_chat_group_id': chatGroupId,
        'p_rule_type': ruleType,
        'p_max_violations': maxViolations,
      });

      final severity = severityResult as String? ?? 'minor';

      // Set expiration based on decay days
      final expiresAt = DateTime.now().add(Duration(days: decayDays));

      // Record violation
      final response = await _supabase
          .from('rule_violations')
          .insert({
            'lobby_id': lobbyId,
            'chat_group_id': chatGroupId,
            'user_uid': userUid,
            'rule_type': ruleType,
            'severity': severity,
            'violation_data': violationData ?? {},
            'expires_at': expiresAt.toIso8601String(),
          })
          .select()
          .single();

      final violation = RuleViolation.fromJson(response);

      // Apply enforcement action
      await _applyEnforcement(violation, constitution);

      return violation;
    } catch (e) {
      debugPrint('Error recording violation: $e');
      return null;
    }
  }

  /// Apply enforcement action based on severity
  Future<void> _applyEnforcement(
    RuleViolation violation,
    ChatConstitution constitution,
  ) async {
    final enforcementLevel =
        ChatConstitution.getEnforcementLevel(constitution.rules);

    String? action;

    if (enforcementLevel == 'strict_auto') {
      // Automatic enforcement
      switch (violation.severity) {
        case 'minor':
          action = 'warning';
          break;
        case 'moderate':
          action = 'spot_removal';
          await _removeFromSpot(violation.lobbyId, violation.userUid);
          break;
        case 'major':
          action = 'lobby_kick';
          await _kickFromLobby(violation.lobbyId, violation.userUid);
          break;
        case 'critical':
          action = 'temp_ban';
          await _applyTempBan(violation.chatGroupId, violation.userUid);
          break;
      }
    } else {
      // Loose social enforcement - just badges
      action = 'badge_applied';
      await _applyBadge(violation.userUid, 'Rule Breaker');
    }

    // Update violation with enforcement action
    await _supabase
        .from('rule_violations')
        .update({'enforcement_action': action}).eq('id', violation.id);
  }

  /// Remove user from spot (moderate violation)
  Future<void> _removeFromSpot(String lobbyId, String userUid) async {
    try {
      // Get lobby
      final lobbyData =
          await _supabase.from('lobbies').select().eq('id', lobbyId).single();

      final spots = List<String?>.from(lobbyData['lobby_spots'] ?? []);

      // Find and clear user's spot
      for (int i = 0; i < spots.length; i++) {
        if (spots[i] == userUid || spots[i] == '${userUid}_calling') {
          spots[i] = null;
        }
      }

      // Update lobby
      await _supabase
          .from('lobbies')
          .update({'lobby_spots': spots}).eq('id', lobbyId);
    } catch (e) {
      debugPrint('Error removing from spot: $e');
    }
  }

  /// Kick user from lobby (major violation)
  Future<void> _kickFromLobby(String lobbyId, String userUid) async {
    try {
      final lobbyData =
          await _supabase.from('lobbies').select().eq('id', lobbyId).single();

      final memberUids = List<String>.from(lobbyData['member_uids'] ?? []);
      memberUids.remove(userUid);

      await _supabase
          .from('lobbies')
          .update({'member_uids': memberUids}).eq('id', lobbyId);

      // Also remove from spots
      await _removeFromSpot(lobbyId, userUid);
    } catch (e) {
      debugPrint('Error kicking from lobby: $e');
    }
  }

  /// Apply temporary ban (critical violation)
  Future<void> _applyTempBan(String? chatGroupId, String userUid) async {
    try {
      // Create ban record (expires in 24 hours)
      await _supabase.from('rule_violations').insert({
        'chat_group_id': chatGroupId,
        'user_uid': userUid,
        'rule_type': 'temp_ban',
        'severity': 'critical',
        'enforcement_action': 'temp_ban',
        'expires_at':
            DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'lobby_id': 'system', // System-level violation
      });
    } catch (e) {
      debugPrint('Error applying temp ban: $e');
    }
  }

  /// Apply social badge
  Future<void> _applyBadge(String userUid, String badgeName) async {
    try {
      // Get current badges
      final userData = await _supabase
          .from('users')
          .select('rule_badges')
          .eq('uid', userUid)
          .single();

      final badges = Map<String, dynamic>.from(userData['rule_badges'] ?? {});
      badges[badgeName] = (badges[badgeName] ?? 0) + 1;

      // Update badges
      await _supabase
          .from('users')
          .update({'rule_badges': badges}).eq('uid', userUid);
    } catch (e) {
      debugPrint('Error applying badge: $e');
    }
  }

  /// Check if user needs check-in
  bool requiresCheckIn(Map<String, dynamic> rules) {
    return rules['check_in_required'] == true;
  }

  /// Get check-in interval
  Duration? getCheckInInterval(Map<String, dynamic> rules) {
    final intervalStr = rules['check_in_interval'] as String?;
    if (intervalStr == null) return null;

    final regex = RegExp(r'(\d+)(m|h|s)');
    final match = regex.firstMatch(intervalStr);
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

  /// Process check-in (called by timer system)
  Future<void> processCheckIn({
    required String lobbyId,
    required String chatGroupId,
    required String userUid,
    required int spotIndex,
  }) async {
    try {
      final constitution = await getActiveConstitution(chatGroupId);
      if (constitution == null) return;

      if (!requiresCheckIn(constitution.rules)) return;

      // Record successful check-in in violation data
      await _supabase.from('rule_violations').insert({
        'lobby_id': lobbyId,
        'chat_group_id': chatGroupId,
        'user_uid': userUid,
        'rule_type': 'check_in_success',
        'severity': 'minor',
        'violation_data': {
          'spot_index': spotIndex,
          'timestamp': DateTime.now().toIso8601String(),
        },
        'enforcement_action': 'none',
      });
    } catch (e) {
      debugPrint('Error processing check-in: $e');
    }
  }

  /// Process missed check-in
  Future<void> processMissedCheckIn({
    required String lobbyId,
    required String chatGroupId,
    required String userUid,
    required int spotIndex,
  }) async {
    await recordViolation(
      lobbyId: lobbyId,
      chatGroupId: chatGroupId,
      userUid: userUid,
      ruleType: 'missed_check_in',
      violationData: {
        'spot_index': spotIndex,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get user's violation history
  Future<List<RuleViolation>> getUserViolations(String userUid) async {
    try {
      final response = await _supabase
          .from('rule_violations')
          .select()
          .eq('user_uid', userUid)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => RuleViolation.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting user violations: $e');
      return [];
    }
  }

  /// Create a vote for constitution changes
  Future<ConstitutionVote?> createVote({
    required String constitutionId,
    required String chatGroupId,
    required String proposedBy,
    required Map<String, dynamic> proposedRules,
    double voteThreshold = 0.5,
    Duration votingPeriod = const Duration(hours: 24),
  }) async {
    try {
      final response = await _supabase
          .from('constitution_votes')
          .insert({
            'constitution_id': constitutionId,
            'chat_group_id': chatGroupId,
            'proposed_by': proposedBy,
            'proposed_rules': proposedRules,
            'vote_threshold': voteThreshold,
            'expires_at': DateTime.now().add(votingPeriod).toIso8601String(),
          })
          .select()
          .single();

      return ConstitutionVote.fromJson(response);
    } catch (e) {
      debugPrint('Error creating vote: $e');
      return null;
    }
  }

  /// Get active votes for a chat group
  Future<List<ConstitutionVote>> getActiveVotes(String chatGroupId) async {
    try {
      final response = await _supabase
          .from('constitution_votes')
          .select()
          .eq('chat_group_id', chatGroupId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => ConstitutionVote.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting active votes: $e');
      return [];
    }
  }
}
