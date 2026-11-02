/// Supabase URL and anon key. Both come from `--dart-define` or
/// `--dart-define-from-file=env.json`. An empty value keeps the app on fakes.
class SquadSyncConfig {
  const SquadSyncConfig({required this.url, required this.anonKey});

  static const absent = SquadSyncConfig(url: '', anonKey: '');

  factory SquadSyncConfig.fromEnvironment() {
    return const SquadSyncConfig(
      url: String.fromEnvironment('SUPABASE_URL'),
      anonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    );
  }

  final String url;
  final String anonKey;

  bool get isPresent => url.trim().isNotEmpty && anonKey.trim().isNotEmpty;
}
