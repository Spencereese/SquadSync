import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:squad_sync/data/datasources/user_local_datasource.dart';
import 'package:squad_sync/data/datasources/user_remote_datasource.dart';
import 'package:squad_sync/data/datasources/system_local_datasource.dart';
import 'package:squad_sync/data/datasources/system_remote_datasource.dart';
import 'package:squad_sync/data/datasources/squad_local_datasource.dart';
import 'package:squad_sync/data/datasources/squad_remote_datasource.dart';
import 'package:squad_sync/domain/repositories/user_repository.dart';
import 'package:squad_sync/domain/repositories/system_repository.dart';
import 'package:squad_sync/domain/repositories/game_repository.dart';
import 'package:squad_sync/domain/repositories/chat_repository.dart';
import 'package:squad_sync/data/datasources/game_local_datasource.dart';
import 'package:squad_sync/data/datasources/game_remote_datasource.dart';
import 'package:squad_sync/services/igdb_auth_service.dart';
import 'package:squad_sync/chat/sqlite_helper.dart';

// Generate mocks for all dependencies (excluding Firebase to avoid circular deps)
@GenerateMocks([
  UserLocalDataSource,
  UserRemoteDataSource,
  SystemLocalDataSource,
  SystemRemoteDataSource,
  SquadLocalDataSource,
  SquadRemoteDataSource,
  UserRepository,
  GameRepository,
  SystemRepository,
  ChatRepository,
  GameLocalDataSource,
  GameRemoteDataSource,
  SQLiteHelper,
  IgdbAuthService,
  SharedPreferences,
  http.Client,
  FlutterLocalNotificationsPlugin,
])
void main() {}
