import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores this install's token for the signed-in person only.
abstract class PushTokenRepository {
  Future<void> register({required String token, required String platform});
}

class NoopPushTokenRepository implements PushTokenRepository {
  const NoopPushTokenRepository();

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {}
}

class MemoryPushTokenRepository implements PushTokenRepository {
  String? token;
  String? platform;

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    this.token = token;
    this.platform = platform;
  }
}

class SupabasePushTokenRepository implements PushTokenRepository {
  SupabasePushTokenRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    await _client.rpc<dynamic>(
      'sq8_register_device_token',
      params: {'device_token': token, 'device_platform': platform},
    );
  }
}
