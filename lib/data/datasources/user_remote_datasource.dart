import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart';

abstract class UserRemoteDataSource {
  Future<Map<String, dynamic>?> getUserProfile(String uid);
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data);
  Future<Map<String, dynamic>?> getUserRatings(String uid);
  Future<Map<String, dynamic>?> getUserComplaints(String uid);
  Future<void> addBan(String uid, Map<String, dynamic> banData);
  Future<List<Map<String, dynamic>>> getUserGroups(String uid);
}

class UserRemoteDataSourceImpl implements UserRemoteDataSource {
  final _supabase = SupabaseService.client;

  @override
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final response =
        await _supabase.from('users').select().eq('uid', uid).maybeSingle();
    return response;
  }

  @override
  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _supabase.from('users').upsert({
      'uid': uid,
      ...data,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<Map<String, dynamic>?> getUserRatings(String uid) async {
    final response = await _supabase
        .from('user_ratings')
        .select()
        .eq('id', uid)
        .maybeSingle();
    return response;
  }

  @override
  Future<Map<String, dynamic>?> getUserComplaints(String uid) async {
    final response =
        await _supabase.from('complaints').select().eq('id', uid).maybeSingle();
    return response;
  }

  @override
  Future<void> addBan(String uid, Map<String, dynamic> banData) async {
    // Get current bans
    final current = await _supabase
        .from('bans')
        .select('bans')
        .eq('uid', uid)
        .maybeSingle();

    final bans = List<Map<String, dynamic>>.from(current?['bans'] ?? []);
    bans.add(banData);

    await _supabase.from('bans').upsert({
      'uid': uid,
      'bans': bans,
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getUserGroups(String uid) async {
    try {
      final response = await _supabase
          .from('chat_groups')
          .select()
          .contains('member_uids', [uid]);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error fetching user groups: $e');
      return [];
    }
  }
}
