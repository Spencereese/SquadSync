# Supabase Integration Guide - SquadSync

## ✅ Implementation Complete

Supabase is now integrated as a **dual-client architecture** alongside Firebase.

### Files Created/Modified

#### ✅ Created Files
- `lib/services/supabase_service.dart` - Main Supabase service wrapper
- `lib/examples/supabase_service_example.dart` - Comprehensive usage examples

#### ✅ Modified Files
- `lib/main.dart` - Added Supabase initialization after Firebase

### Initialization

Supabase initializes automatically in `main.dart`:

```dart
// In main() function:
await Firebase.initializeApp();  // Firebase first
await SupabaseService.initialize();  // Then Supabase
```

**Configuration:**
- URL: `https://sfckxrnoiwetmzdycqaa.supabase.co`
- Anon Key: `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...` (full key in service)
- Debug mode: Enabled in development builds only

### Usage Patterns

#### Quick Access
```dart
import 'package:cod_squad_app/services/supabase_service.dart';

// Convenience getter
final data = await supabase.from('squads').select();
```

#### Service Methods
```dart
// Check authentication
if (SupabaseService.isAuthenticated) {
  final userId = SupabaseService.currentUserId;
}

// Sign out
await SupabaseService.signOut();

// Clean up subscriptions
SupabaseService.dispose();
```

### Common Operations

#### 1. Query Data
```dart
final squads = await supabase
  .from('squads')
  .select()
  .eq('game_id', gameId)
  .order('created_at', ascending: false)
  .limit(10);
```

#### 2. Insert Data
```dart
await supabase.from('squads').insert({
  'name': 'My Squad',
  'game_id': 'cod123',
  'created_by': SupabaseService.currentUserId,
});
```

#### 3. Update Data
```dart
await supabase
  .from('squads')
  .update({'name': 'New Name'})
  .eq('id', squadId);
```

#### 4. Delete Data
```dart
await supabase
  .from('squads')
  .delete()
  .eq('id', squadId);
```

#### 5. Real-time Subscriptions
```dart
supabase
  .from('chat_messages')
  .stream(primaryKey: ['id'])
  .eq('squad_id', squadId)
  .listen((messages) {
    // Handle real-time updates
  });
```

### Integration Strategy

**Current State: Dual Client**
- Firebase: Primary data layer (auth, chat, squads)
- Supabase: Ready for gradual migration

**Migration Path:**
1. ✅ **Phase 1**: Initialize both clients (COMPLETE)
2. **Phase 2**: Create Supabase schema mirroring Firebase
3. **Phase 3**: Dual-write to both databases
4. **Phase 4**: Read from Supabase, fallback to Firebase
5. **Phase 5**: Deprecate Firebase reads
6. **Phase 6**: Remove Firebase completely

### Authentication Bridge

**Firebase UID → Supabase Mapping:**
```dart
// To be implemented when migrating auth
await SupabaseService.signInWithFirebaseUid(firebaseUid);
```

Currently throws `UnimplementedError` - will be completed during auth migration.

### Error Handling

All Supabase operations should use try-catch:

```dart
try {
  final data = await supabase.from('table').select();
  // Use data
} catch (e) {
  debugPrint('Supabase error: $e');
  // Fallback to Firebase or show error
}
```

### Real-time Best Practices

1. **Always clean up subscriptions:**
```dart
@override
void dispose() {
  SupabaseService.dispose();  // Removes all channels
  super.dispose();
}
```

2. **Use StreamBuilder for UI:**
```dart
StreamBuilder<List<Map<String, dynamic>>>(
  stream: supabase.from('messages').stream(primaryKey: ['id']),
  builder: (context, snapshot) {
    // Build UI from snapshot.data
  },
)
```

### Storage Integration

Supabase Storage for media uploads:

```dart
// Upload
await supabase.storage
  .from('squad-avatars')
  .uploadBinary('filename.jpg', bytes);

// Get public URL
final url = supabase.storage
  .from('squad-avatars')
  .getPublicUrl('filename.jpg');
```

### Edge Functions

Call Supabase Edge Functions:

```dart
final response = await supabase.functions.invoke('function-name', body: {
  'param': 'value',
});
```

### Row Level Security (RLS)

Supabase RLS policies should be configured in the database for:
- User can only read their own squads
- User can only modify squads they own
- Chat messages visible to squad members only

### Next Steps

1. **Create Supabase Schema**
   - Mirror Firebase structure
   - Add RLS policies
   - Create indexes

2. **Implement Dual-Write**
   - Write to both Firebase and Supabase
   - Ensure data consistency

3. **Migrate Auth**
   - Implement Firebase UID mapping
   - Sync user profiles

4. **Update Notifiers**
   - Add Supabase streams to Riverpod notifiers
   - Maintain Firebase fallback

5. **Test Migration**
   - Verify data consistency
   - Performance testing
   - Real-time sync validation

### Resources

- **Supabase Docs**: https://supabase.com/docs
- **Flutter Package**: https://pub.dev/packages/supabase_flutter
- **Dashboard**: https://supabase.com/dashboard/project/sfckxrnoiwetmzdycqaa

### Troubleshooting

**"Supabase initialization failed"**
- Check internet connection
- Verify URL and anon key are correct
- Check for CORS issues (web only)

**Real-time not working**
- Ensure `stream()` has `primaryKey` parameter
- Check RLS policies allow SELECT
- Verify table has realtime enabled

**Authentication errors**
- Firebase UID mapping not yet implemented
- Use Supabase auth separately for now
- Wait for Phase 3 of migration

---

**Status**: ✅ Supabase initialized and ready for gradual migration from Firebase
