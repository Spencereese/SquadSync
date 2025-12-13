import 'package:mockito/annotations.dart';
import 'package:squad_sync/domain/repositories/lobby_repository.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/services/auth_service_supabase.dart';
import 'package:squad_sync/services/timer_service.dart';
import 'package:squad_sync/services/message_service.dart';
import 'package:squad_sync/services/friends_service.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';

// Generate mocks using mockito
@GenerateMocks([
  LobbyRepository,
  ChatRepository,
  GameRepository,
  UserRepository,
  SystemRepository,
  AuthServiceSupabase,
  TimerServiceNotifier,
  MessageService,
  FriendsService,
  GameLocalDataSource,
])
void main() {}
