# Migration Auth Fix - Use Service Role Key

## Problem
`auth.uid()` returns NULL because Supabase client session isn't persisting. The SQL query confirms:
```sql
SELECT auth.uid(), auth.email();
-- Returns: null, null
```

This means RLS policies can't validate the authenticated user, even with permissive `WITH CHECK (true)` policies.

## Solution: Use Service Role Key During Migration

Instead of trying to sync Firebase Auth to Supabase Auth, we can bypass RLS entirely by using the **service role key** instead of the **anon key**.

### Why This Works
1. **Service role key** has full database access and **bypasses RLS policies**
2. No auth session needed - writes work immediately
3. Perfect for migration phase
4. Can switch back to anon key + proper auth later

### Implementation

#### Option 1: Environment-Based Key Selection (Recommended)

Modify `lib/services/supabase_service.dart`:

```dart
static Future<void> initialize() async {
  // During migration, use service role key to bypass RLS
  // Set this to false once migration is complete
  const bool useMigrationMode = true;
  
  final String supabaseKey = useMigrationMode
      ? _serviceRoleKey  // Bypasses RLS
      : _anonKey;        // Requires authentication

  await Supabase.initialize(
    url: 'https://sfckxrnoiwetmzdycqaa.supabase.co',
    anonKey: supabaseKey,
    debug: kDebugMode,
  );

  if (kDebugMode) {
    debugPrint('✅ Supabase initialized in ${useMigrationMode ? "MIGRATION" : "PRODUCTION"} mode');
  }
}

// Get service role key from Supabase Dashboard > Settings > API
// https://supabase.com/dashboard/project/sfckxrnoiwetmzdycqaa/settings/api
static const String _serviceRoleKey = 'YOUR_SERVICE_ROLE_KEY_HERE';
static const String _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

#### Option 2: Use AppConfig Flag

Add to `lib/core/app_config.dart`:
```dart
static const bool useSupabaseServiceRole = true;  // Migration mode
```

Then in `supabase_service.dart`:
```dart
final String supabaseKey = AppConfig.useSupabaseServiceRole
    ? _serviceRoleKey
    : _anonKey;
```

### Get Service Role Key

1. Go to Supabase Dashboard: https://supabase.com/dashboard/project/sfckxrnoiwetmzdycqaa/settings/api
2. Copy the `service_role` key (NOT the anon key)
3. **CRITICAL**: Never commit this to git - add to .env or app_config.dart with gitignore

### Testing Plan

1. **Update service key** in supabase_service.dart
2. **Hot restart** app (not hot reload - need to reinitialize Supabase)
3. **Send test message** - should succeed without any auth issues
4. **Verify in Supabase** - message appears in chat_messages table
5. **Monitor logs** - should see "✅ Dual-write to Supabase successful"

### Migration Timeline

**Phase 4a** (Current): Service role key + dual-write → All messages go to both DBs
**Phase 4b**: Monitor for issues, verify data consistency
**Phase 5**: Switch to read from Supabase (keep writing to both)
**Phase 6**: Proper Supabase Auth setup with RLS
**Phase 7**: Tighten RLS policies, switch to anon key
**Phase 8**: Deprecate Firestore

### Security Notes

- **Service role key** has FULL database access - treat like a password
- Only use during migration phase
- Never expose in client code in production
- Switch to anon key once auth is properly configured
- Current RLS policies are permissive anyway, so security is equivalent

### Alternative: Disable RLS Temporarily

If you don't want to use service role key, you can disable RLS on tables during migration:

```sql
ALTER TABLE chat_messages DISABLE ROW LEVEL SECURITY;
ALTER TABLE users DISABLE ROW LEVEL SECURITY;
```

Then re-enable after migration:
```sql
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
```

But service role key is cleaner - you can keep RLS enabled and just bypass it for writes.
