# SquadSync Codebase Analysis - Pages and Menus Inventory

## Overview
This document tracks pages, screens, and menu components in the SquadSync codebase to identify potential duplicate or replacement code that should be cleaned up.

## Main App Structure
- **Entry Point**: `main.dart` - App initialization, Firebase setup, deep linking
- **Main Screen**: `ChatGroupsScreen` (from chat/chat_groups_screen.dart) - Primary authenticated user screen
- **Setup Screen**: `SetupScreen` (setup_screen.dart) - Authentication/login screen

## Screen Inventory

### Main Screens (Top Level)
1. **ChatGroupsScreen** (`lib/chat/chat_groups_screen.dart`)
   - Primary authenticated screen
   - Shows chat groups and navigation

2. **SetupScreen** (`lib/setup_screen.dart`)
   - Authentication/login screen for unauthenticated users

3. **JoinSquadScreen** (`lib/join_squad_screen.dart`)
   - Screen for joining squads via invite codes

### Squad-Related Screens
4. **SquadTabScreen** (`lib/screens/squad_tab_screen.dart`)
   - Main squad management screen with lobbies and member status
   - **USES**: `SquadTab` widget for full squad interface when lobbyId/gameName provided

5. **SquadTab** (`lib/squad_tab/squad_tab.dart`)
   - Full squad management interface (used by SquadTabScreen)
   - **RELATIONSHIP**: SquadTabScreen wraps SquadTab for specific lobby/game contexts

### Tab Screens (Bottom Navigation)
6. **ProfileTab** (`lib/profile_tab.dart`)
   - User profile management
   - **USED IN**: ChatGroupsScreen bottom navigation (3rd tab)

7. **PerformanceHubTab** (`lib/performance_hub_tab.dart`)
   - Performance tracking and analytics
   - **STATUS**: Not referenced anywhere in codebase - POTENTIAL UNUSED

8. **SettingsTab** (`lib/settings_tab.dart`)
   - App settings and preferences
   - **STATUS**: Not referenced anywhere in codebase - POTENTIAL UNUSED

9. **AvailabilityTab** (`lib/Availability/availability_tab.dart`)
   - User availability scheduling
   - **STATUS**: Not referenced anywhere in codebase - POTENTIAL UNUSED

### Chat-Related Screens
10. **ChatScreen** (`lib/chat/chat_screen.dart`)
    - Main chat interface with messages and input

### Modal/Dialog Screens
11. **PeacockModal** (`lib/chat/peacock_modal.dart`)
    - Modal for creating new lobbies
    - **HAS BACKUP**: `peacock_modal.dart.backup` exists - older version without `initialGame` parameter

12. **RatingDialog** (`lib/rating_dialog.dart`)
    - User rating/review dialog

13. **ScheduleDialog** (`lib/Availability/schedule_dialog.dart`)
    - Schedule creation/editing dialog

### Other Screens
14. **SquadQueuePage** (`lib/squad_tab/squad_queue_page.dart`)
    - Squad queue management
    - **STATUS**: Not referenced anywhere in codebase - POTENTIAL UNUSED

## Navigation Structure Analysis

### ChatGroupsScreen Navigation (Primary App Navigation)
- **Tab 1**: Chat groups (_buildChatGroupsPage)
- **Tab 2**: NotificationsScreen (BROKEN - class doesn't exist)
- **Tab 3**: ProfileTab

### Main.dart Navigation
- Direct navigation to screens without using main_navigation_screen.dart
- main_navigation_screen.dart is empty (1 line, just whitespace)

## Potential Duplicates/Replacements to Investigate

### 1. **CRITICAL ISSUE**: Missing NotificationsScreen
- `ChatGroupsScreen` references `NotificationsScreen()` but this class doesn't exist
- **IMPACT**: App will crash when trying to access the notifications tab
- **ACTION NEEDED**: Either create NotificationsScreen or remove the tab

### 2. **Unused Tab Screens**
- `PerformanceHubTab`, `SettingsTab`, `AvailabilityTab` are not referenced anywhere
- These may have been replaced by functionality in ProfileTab or other screens
- **ACTION NEEDED**: Verify if these are truly unused and can be deleted

### 3. **Squad Management Structure**
- `SquadTabScreen` vs `SquadTab` - appears to be wrapper vs implementation
- SquadTabScreen provides dashboard view, SquadTab provides detailed squad management
- **STATUS**: This seems intentional, not duplicate

### 4. **Empty Files**
- `main_navigation_screen.dart` - completely empty, should be deleted or implemented
- **ACTION NEEDED**: Delete if not needed

### 5. **Backup Files**
- `peacock_modal.dart.backup` - older version of PeacockModal
- **ACTION NEEDED**: Delete backup file

### 6. **Unused Screens**
- `SquadQueuePage` - not referenced anywhere
- **ACTION NEEDED**: Verify if still needed, likely can be deleted

## Files to Analyze Further

### High Priority (Breaking Issues)
- [ ] **FIX**: Create NotificationsScreen or remove notifications tab from ChatGroupsScreen
- [ ] **VERIFY**: Check if PerformanceHubTab, SettingsTab, AvailabilityTab are truly unused
- [ ] **CLEANUP**: Delete main_navigation_screen.dart (empty file)
- [ ] **CLEANUP**: Delete peacock_modal.dart.backup
- [ ] **VERIFY**: Check if SquadQueuePage is still needed

### Medium Priority
- [ ] Review all modal/dialog files for duplicates
- [ ] Check widget organization vs screen organization
- [ ] Verify all screens are reachable from navigation

### Low Priority
- [ ] Review summary files in Summary/ directory
- [ ] Check all imports are current
- [ ] Verify all backup files can be deleted

## Next Steps
Continue systematic analysis of key files to identify unused or duplicate code.