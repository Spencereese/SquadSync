import '../../services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    try {
      // RLS enforces: users can only update their own profile (auth.uid() = uid)
      await _supabase.from('users').update({
        ...data,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('uid', uid);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        // RLS policy violation - user trying to update someone else's profile
        throw Exception(
            'Permission denied: Cannot update another user\'s profile');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      rethrow;
    }
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
