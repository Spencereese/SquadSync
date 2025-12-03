# Squad Model Migration

This migration adds new fields to the Squad model to support enhanced squad discovery and management features.

## New Fields Added

- `isPublic` (bool): Whether the squad is publicly discoverable (default: false)
- `tags` (List<String>): Tags for categorizing squads (inferred from game name)
- `lookingForMore` (bool): Whether the squad is looking for additional players (based on available spots)
- `description` (String): Human-readable description of the squad (defaults to game name)
- `bumpTimestamp` (Timestamp?): Timestamp for bumping squads in discovery (null for existing squads)

## Running the Migration

After deploying the updated app code, run the migration script to update existing squads:

```bash
# Install dependencies
flutter pub get

# Run the migration
dart run migrate_squads
```

Or using the executable:

```bash
flutter pub run migrate_squads
```

## Migration Logic

The migration script will:

1. Query all existing squads in Firestore
2. For each squad missing the new fields:
   - Set `isPublic` to `false`
   - Infer `tags` from the `gameName` (e.g., "Call of Duty Warzone" → `["fps", "battle-royale", "competitive"]`)
   - Set `lookingForMore` to `true` if there are available spots
   - Set `description` to the `gameName`
   - Leave `bumpTimestamp` as `null`

## Safety

- The migration is idempotent - it can be run multiple times safely
- Only adds missing fields, doesn't modify existing data
- Includes error handling and progress reporting
- Can be run in production after code deployment

## Testing

Test the migration in a development environment first:

1. Create some test squads
2. Run the migration script
3. Verify the new fields were added correctly
4. Test that the app still works with the updated squads