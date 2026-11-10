import 'package:supabase_flutter/supabase_flutter.dart';

/// Stores this install's token for the signed-in person only.
abstract class PushTokenRepository {
  Future<void> register({required String token, required String platform});

  /// Removes this install's token for the signed-in person.
  Future<void> unregister({required String token});
}

class NoopPushTokenRepository implements PushTokenRepository {
  const NoopPushTokenRepository();

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {}

  @override
  Future<void> unregister({required String token}) async {}
}

class MemoryPushTokenRepository implements PushTokenRepository {
  String? token;
  String? platform;
  String? removedToken;

  @override
  Future<void> register({
    required String token,
    required String platform,
  }) async {
    this.token = token;
    this.platform = platform;
  }

  @override
  Future<void> unregister({required String token}) async {
    removedToken = token;
    if (this.token == token) {
      this.token = null;
      platform = null;
    }
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

  @override
  Future<void> unregister({required String token}) async {
    await _client.rpc<dynamic>(
      'sq8_unregister_device_token',
      params: {'device_token': token},
    );
  }
}
