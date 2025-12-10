import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Script to run the Supabase schema SQL
///
/// Usage: dart run run_supabase_schema.dart
void main() async {
  print('🚀 Initializing Supabase...');

  // Initialize Supabase
  await Supabase.initialize(
    url: 'https://sfckxrnoiwetmzdycqaa.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNmY2t4cm5vaXdldG16ZHljcWFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQ5MDEzMzUsImV4cCI6MjA4MDQ3NzMzNX0.9SZ_HD8SV_-BAz2uYptHohHmOcS6TaF_4JUD5Sl__qA',
  );

  final supabase = Supabase.instance.client;
  print('✅ Supabase initialized');

  // Read the SQL schema file
  print('\n📖 Reading schema file...');
  final schemaFile = File('lib/services/SUPABASE_SCHEMA.sql');
  if (!await schemaFile.exists()) {
    print('❌ Error: SUPABASE_SCHEMA.sql not found at lib/services/');
    exit(1);
  }

  final schemaSql = await schemaFile.readAsString();
  print('✅ Schema file read (${schemaSql.length} characters)');

  // Split SQL into individual statements
  print('\n🔨 Executing SQL statements...');
  final statements = _splitSqlStatements(schemaSql);
  print('Found ${statements.length} SQL statements');

  int successCount = 0;
  int errorCount = 0;

  for (var i = 0; i < statements.length; i++) {
    final stmt = statements[i].trim();
    if (stmt.isEmpty) continue;

    // Skip comments
    if (stmt.startsWith('--')) continue;

    try {
      print('\n[${i + 1}/${statements.length}] Executing...');
      print('${stmt.substring(0, stmt.length > 80 ? 80 : stmt.length)}...');

      await supabase.rpc('exec_sql', params: {'query': stmt});

      print('✅ Success');
      successCount++;
    } catch (e) {
      print('⚠️  Error: $e');
      errorCount++;

      // Continue with other statements even if one fails
      // (some may fail if objects already exist)
    }
  }

  print('\n' + '=' * 60);
  print('📊 Execution Summary:');
  print('   ✅ Success: $successCount');
  print('   ⚠️  Errors: $errorCount');
  print('   📝 Total: ${statements.length}');
  print('=' * 60);

  if (errorCount > 0) {
    print(
        '\n💡 Note: Some errors are expected if tables/objects already exist.');
    print('   Check the errors above to see if they are critical.');
  }

  // Verify tables were created
  print('\n🔍 Verifying tables...');
  try {
    final tables = await supabase.rpc('get_tables');
    print('✅ Tables in database: $tables');
  } catch (e) {
    print('⚠️  Could not verify tables: $e');
  }

  print('\n✨ Schema execution complete!');
  print('\n📌 Next Steps:');
  print('   1. Verify tables in Supabase Dashboard: Table Editor');
  print('   2. Check RLS policies are configured (if needed)');
  print('   3. Run migration script to backfill data from Firestore');

  exit(0);
}

/// Split SQL file into individual statements
List<String> _splitSqlStatements(String sql) {
  final statements = <String>[];
  final lines = sql.split('\n');
  StringBuffer currentStatement = StringBuffer();

  for (final line in lines) {
    final trimmed = line.trim();

    // Skip pure comment lines
    if (trimmed.startsWith('--')) {
      continue;
    }

    currentStatement.write(line);
    currentStatement.write('\n');

    // Statement ends with semicolon
    if (trimmed.endsWith(';')) {
      statements.add(currentStatement.toString().trim());
      currentStatement = StringBuffer();
    }
  }

  // Add final statement if not empty
  if (currentStatement.toString().trim().isNotEmpty) {
    statements.add(currentStatement.toString().trim());
  }

  return statements;
}
