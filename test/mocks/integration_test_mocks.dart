// Mock generation file for integration tests
// Run: dart run build_runner build --delete-conflicting-outputs
// This generates mocks that can be exported to integration_test/

import 'package:mockito/annotations.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Generate mocks for integration tests
@GenerateMocks([
  AuthServiceSupabase,
  SupabaseClient,
  GoTrueClient,
  LobbyRepository,
])
void main() {}
