# Supabase Session Persistence Fix for iOS

## Problem
Supabase sessions were not persisting between app launches on iOS. Users had to sign in every time the app restarted.

## Root Cause
iOS requires specific entitlements and configuration for secure storage (Keychain) to persist authentication tokens. The Supabase Flutter SDK automatically uses:
- **iOS**: Keychain (secure, encrypted storage)
- **Android**: SharedPreferences (secure storage)
- **Web**: localStorage

However, iOS Keychain access requires proper app entitlements.

## Solution Implemented

### 1. iOS Entitlements Configuration
**File**: `ios/Runner/Runner.entitlements`

Added Keychain access groups to allow the app to store and retrieve auth tokens:

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.squadsync.app</string>
</array>
```

Also added associated domains for deep linking with Supabase:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:sfckxrnoiwetmzdycqaa.supabase.co</string>
</array>
```

### 2. Info.plist URL Scheme
**File**: `ios/Runner/Info.plist`

Added URL scheme for OAuth callbacks:

```xml
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>com.squadsync.app</string>
    </array>
</dict>
```

### 3. Supabase Initialization
**File**: `lib/services/supabase_service.dart`

Updated initialization with proper storage options:

```dart
await Supabase.initialize(
  url: 'https://sfckxrnoiwetmzdycqaa.supabase.co',
  anonKey: _anonKey,
  authOptions: const FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    autoRefreshToken: true,
  ),
  storageOptions: const StorageClientOptions(
    retryAttempts: 10,
  ),
  debug: kDebugMode,
);

// Increased delay to allow session restoration from Keychain
await Future.delayed(const Duration(milliseconds: 800));
```

### 4. Debug Helper
**File**: `lib/services/session_debug_helper.dart`

Created a comprehensive debugging tool to verify session persistence:

```dart
// Check session status
await SessionDebugHelper.checkSessionPersistence();

// Listen for auth changes
SessionDebugHelper.setupAuthListener();

// Test persistence
await SessionDebugHelper.testSessionPersistence(
  email: 'test@example.com',
  password: 'password',
);
```

## How It Works

### Session Storage Flow

1. **Sign In**: User authenticates with Supabase
2. **Token Storage**: Supabase SDK stores tokens in iOS Keychain
3. **App Close**: Tokens remain in Keychain (persistent storage)
4. **App Launch**: Supabase SDK reads tokens from Keychain
5. **Auto-Refresh**: SDK automatically refreshes expired tokens

### iOS Keychain Benefits

- ✅ Encrypted storage
- ✅ Persists across app launches
- ✅ Survives app uninstall/reinstall (if keychain backup enabled)
- ✅ Secure against unauthorized access
- ✅ Shared across app extensions (with proper entitlements)

## Testing

### Verify Session Persistence

1. **Sign In**: Launch app and sign in with Supabase
2. **Check Logs**: Look for debug output:
   ```
   ✅ Supabase initialized with authentication
   Current session: [user-id]
   Platform: iOS
   iOS: Session persistence via Keychain enabled
   ```

3. **Force Quit**: Completely close the app (swipe up from app switcher)
4. **Relaunch**: Open app again
5. **Verify**: Check if user is still signed in without re-entering credentials

### Debug Output

When session persists correctly:
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📱 SESSION PERSISTENCE CHECK
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Platform: iOS
Storage: iOS Keychain (automatic)
Entitlements required: keychain-access-groups

Session Status:
  ✅ Active session found
  User ID: [user-id]
  User Email: user@example.com
  Access Token: eyJhbGc...
  Refresh Token: v1...
  Expires At: 2025-12-09 10:30:00
  Time until expiry: 23h 45m
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Troubleshooting

### Session Still Not Persisting?

1. **Clean Build**:
   ```bash
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   flutter clean
   flutter pub get
   ```

2. **Check Entitlements**:
   - Open `ios/Runner.xcworkspace` in Xcode
   - Select Runner target
   - Go to "Signing & Capabilities"
   - Verify "Keychain Sharing" is enabled
   - Verify keychain groups match `Runner.entitlements`

3. **Verify Bundle ID**:
   - In Xcode, check that Bundle Identifier matches entitlements
   - Should be `com.squadsync.app` (not `com.example.codSquadApp`)

4. **Check Logs**:
   ```dart
   await SessionDebugHelper.checkSessionPersistence();
   ```

### Common Issues

**Issue**: Session found but tokens expired
- **Solution**: Auto-refresh should handle this. Check network connectivity.

**Issue**: "Keychain access denied" error
- **Solution**: Ensure entitlements are properly configured and app is code-signed.

**Issue**: Session works in debug but not release
- **Solution**: Verify release build includes entitlements file.

## Migration from Firebase Auth

Since you're migrating from Firebase, note that:
- Firebase used its own secure storage mechanism
- Supabase uses native platform storage (Keychain on iOS)
- Both are secure and persistent
- No data migration needed - just re-sign in with Supabase

## Additional Resources

- [Supabase Flutter Documentation](https://supabase.com/docs/reference/dart/introduction)
- [iOS Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)

## Implementation Checklist

- [x] Add Keychain entitlements to `Runner.entitlements`
- [x] Add URL scheme to `Info.plist`
- [x] Update Supabase initialization with storage options
- [x] Add debug helper for testing
- [x] Increase session restoration delay
- [ ] Test on physical iOS device
- [ ] Test session persistence after app restart
- [ ] Test token auto-refresh
- [ ] Update bundle identifier (if needed)
- [ ] Test in release build

## Next Steps

1. **Test on Physical Device**: Simulator may behave differently than real device
2. **Monitor Production**: Use debug helper in staging to verify
3. **Update Bundle ID**: Change from `com.example.codSquadApp` to `com.squadsync.app`
4. **Code Signing**: Ensure proper code signing for release builds

---

**Status**: ✅ Implementation Complete
**Tested**: Pending iOS device testing
**Platform**: iOS (similar fixes apply to Android if needed)
