import 'package:flutter_test/flutter_test.dart';
import 'package:squad_sync/core/app_env.dart';

void main() {
  test('placeholder SUPABASE_URL is rejected', () {
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_URL',
        'https://your-project.supabase.co',
      ),
      isTrue,
    );
    expect(isPlaceholderEnvValue('SUPABASE_URL', ''), isTrue);
    expect(isPlaceholderEnvValue('SUPABASE_URL', null), isTrue);
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_ANON_KEY',
        'your_anon_key',
      ),
      isTrue,
    );
    expect(
      isPlaceholderEnvValue(
        'SUPABASE_URL',
        'https://abcxyz.supabase.co',
      ),
      isFalse,
    );
  });

  test('dart-define wins over .env.example placeholder', () {
    final merged = mergeEnvLayers(
      asset: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
        'SUPABASE_ANON_KEY': 'your_anon_key',
      },
      dartDefines: const {
        'SUPABASE_URL': 'https://real-project.supabase.co',
        'SUPABASE_ANON_KEY': 'eyJhbGciOi.real',
      },
    );

    expect(merged['SUPABASE_URL'], 'https://real-project.supabase.co');
    expect(merged['SUPABASE_ANON_KEY'], 'eyJhbGciOi.real');
    expect(
      isPlaceholderEnvValue('SUPABASE_URL', merged['SUPABASE_URL']),
      isFalse,
    );
  });

  test('placeholder dart-define does not overwrite a real file .env', () {
    final merged = mergeEnvLayers(
      asset: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
      },
      file: const {
        'SUPABASE_URL': 'https://from-file.supabase.co',
      },
      dartDefines: const {
        'SUPABASE_URL': 'https://your-project.supabase.co',
      },
    );

    expect(merged['SUPABASE_URL'], 'https://from-file.supabase.co');
  });
}
