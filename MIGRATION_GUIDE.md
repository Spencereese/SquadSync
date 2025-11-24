# Safe Migration Guide: Legacy Managers → Riverpod Notifiers

## ⚠️ **IMPORTANT SAFETY RULES**
1. **Never delete legacy files until ALL references are migrated**
2. **Test after each file migration** - run `flutter run` to ensure no crashes
3. **Backup before major changes** - commit to git first
4. **Migrate one file at a time** - don't batch changes

## 📋 **Current Legacy References** (as of scan)
- `squad_state_notifier.dart`: user_manager, achievement_manager
- `squad_tab/widgets/squad_controls.dart`: user_manager
- `chat/widgets/group_settings_card.dart`: user_manager
- `chat/widgets/game_selection_card.dart`: user_manager
- `main.dart`: user_manager
- `providers.dart`: user_manager, achievement_manager
- `presentation/notifiers/user_notifier.dart`: achievement_manager

## 🔄 **Migration Steps**

### Step 1: Choose Target File
Pick one file from the list above. Start with simpler ones.

### Step 2: Analyze Usage
For each file, check:
- What methods/properties are used from the legacy manager?
- Are they available in the new notifier?
- What state management pattern is used (Provider vs Riverpod)?

### Step 3: Migrate Code
**Provider → Riverpod Migration:**
```dart
// OLD (Provider)
final userManager = Provider.of<UserManager>(context, listen: false);
final pinnedGames = userManager.pinnedGames;

// NEW (Riverpod)
final userState = ref.watch(userNotifierProvider).value;
final pinnedGames = userState?.pinnedGames ?? [];
```

### Step 4: Update Imports
```dart
// Remove
import '../../managers/user_manager.dart';

// Add
import '../../providers/user_notifier.dart';
```

### Step 5: Test & Verify
- Run `flutter analyze <file>` - no errors
- Run `flutter run` - app starts without crashes
- Test the specific feature that was migrated

### Step 6: Repeat
Move to next file only after current one is working.

## 🗑️ **Safe Deletion (ONLY AFTER all references migrated)**
```bash
# Check one more time
dart lib/legacy_scanner.dart

# If no references found, then delete
rm lib/managers/user_manager.dart
```

## 🆘 **Rollback Plan**
If something breaks:
```bash
git checkout HEAD~1  # Revert last commit
# Or manually undo the changes
```

## 📝 **Migration Checklist**
- [ ] Scan current references
- [ ] Backup/commit current state
- [ ] Migrate file 1
- [ ] Test file 1
- [ ] Migrate file 2
- [ ] Test file 2
- [ ] ...continue...
- [ ] Final scan (should be empty)
- [ ] Safe deletion of legacy files
- [ ] Final test of entire app

## 💡 **Tips**
- Start with files that only use simple properties (like `pinnedGames`)
- Files using complex methods may need those methods added to notifiers first
- Use `AsyncValue.when` for reactive UI updates
- Keep legacy managers as fallback during migration</content>
<parameter name="filePath">/Users/spencereese/Documents/cod_squad_app/MIGRATION_GUIDE.md