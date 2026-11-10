import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:squadsync/features/push/data/firebase_push.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SquadSyncConfig.fromEnvironment();
  final pushes = await openPushNotifications();
  final overrides = [
    squadSyncConfigProvider.overrideWithValue(config),
    pushNotificationsProvider.overrideWithValue(pushes),
  ];
  if (config.isPresent) {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.anonKey,
      authOptions: const FlutterAuthClientOptions(
        autoRefreshToken: true,
        persistSession: true,
      ),
    );
    overrides.add(
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
    );
  }
  runApp(ProviderScope(overrides: overrides, child: const SquadSyncApp()));
}
