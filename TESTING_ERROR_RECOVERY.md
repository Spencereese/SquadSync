# Quick Error Recovery Guide

## For Testing

### When You See "Too many channels" Error

**What happens automatically:**
1. Error is caught and cleaned up
2. Channels auto-removed
3. Chat reinitializes after 1 second
4. You see brief "Cleaning up..." message
5. Chat works normally again

**No action needed!** The app recovers automatically.

---

### Manual Recovery (Debug Mode Only)

**Red bug button (bottom-right of chat):**
1. Tap the bug icon 🐛
2. See current channel count
3. Click "Cleanup & Retry"
4. All channels reset and chat reinitializes

**Use when:**
- Testing error scenarios
- Want to force a clean state
- Channels aren't cleaning up automatically

---

### Error Messages You'll See

| Message | Meaning | Action |
|---------|---------|--------|
| "Too many connections. Cleaning up..." | Channel limit hit, auto-recovering | None - wait 1 sec |
| "Chat will work with limited features" | Real-time degraded, core features work | Can dismiss, or retry later |
| "Connection issue. Retrying..." | Temporary network problem | None - auto-retry |

---

### Debug Console Indicators

**Good signs:**
- ✅ `Cleaned up all channels`
- ✅ `Typing channel subscribed`
- ✅ `Presence tracking enabled`

**Warnings (app still works):**
- ⚠️ `WARNING: Approaching channel limit` (80+ channels)
- ⚠️ `No user, skipping presence channel` (not logged in)
- ⚠️ `Failed to initialize typing channel` (typing won't show)

**Auto-recovery:**
- 🧹 `Auto-cleaning channels due to high count`
- 🔔 `Active Supabase channels: X`

---

### What Still Works When Errors Occur

Even if real-time features fail, these always work:
- ✅ View cached messages
- ✅ Send new messages (queued for sync)
- ✅ Navigate between chats
- ✅ Access settings
- ✅ View lobby info
- ✅ Upload media

**Degraded features:**
- ⚠️ Real-time message updates (refresh to see new)
- ⚠️ Typing indicators
- ⚠️ Online presence

---

### Testing Checklist

Test these scenarios to verify error handling:

- [ ] Open 10+ different chats rapidly
- [ ] Navigate back and forth between chats
- [ ] Force airplane mode, then reconnect
- [ ] Kill and restart app multiple times
- [ ] Use debug button to force cleanup
- [ ] Check console for clean logs (no crashes)

**Expected:**
- No app crashes or freezes
- User-friendly error messages
- Automatic recovery within seconds
- Debug logs show cleanup happening

---

### Quick Commands (Debug Console)

```dart
// Check channel count
print('Channels: ${SupabaseService.activeChannelCount}');

// Force cleanup
SupabaseService.dispose();

// Check if approaching limit
print('Near limit: ${SupabaseService.isApproachingChannelLimit}');

// See detailed channel info
SupabaseService.logChannelUsage();
```

---

### Key Points

1. **Errors won't block the app** - All critical features have fallbacks
2. **Auto-recovery is built-in** - Most errors fix themselves
3. **Debug button is your friend** - Use it during testing to force clean state
4. **Console logs are informative** - Use emoji indicators to quickly spot issues
5. **Core chat always works** - Even if real-time features degrade

---

### If Something Still Breaks

If the app becomes unresponsive:

1. **First:** Tap debug bug button → "Cleanup & Retry"
2. **Second:** Restart the app (kills all channels)
3. **Third:** Check console logs for unhandled errors
4. **Fourth:** Report with logs showing error sequence

The new error handling should prevent unrecoverable states!
