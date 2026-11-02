import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:squadsync/core/app.dart';
import 'package:squadsync/core/config.dart';
import 'package:squadsync/core/dependencies.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  final config = SquadSyncConfig.fromEnvironment();
  final overrides = [squadSyncConfigProvider.overrideWithValue(config)];
  if (config.isPresent) {
    WidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(url: config.url, publishableKey: config.anonKey);
    overrides.add(
      supabaseClientProvider.overrideWithValue(Supabase.instance.client),
    );
  }
  runApp(ProviderScope(overrides: overrides, child: const SquadSyncApp()));
}
