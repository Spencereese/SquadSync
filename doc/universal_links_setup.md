# Universal Links Setup Guide

## Overview
Universal links enable deep linking across iOS, Android, and Web platforms, allowing users to open SquadSync content directly from web links.

## iOS Universal Links Setup

### 1. Add Associated Domains to Xcode
- Open `ios/Runner.xcworkspace` in Xcode
- Select your target → Signing & Capabilities
- Add "Associated Domains" capability
- Add domains:
  - `applinks:lobbiesync.app`
  - `applinks:www.lobbiesync.app`

Entitlements file is already created at `ios/Runner/Runner.entitlements`.

### 2. Host apple-app-site-association file
Create this file at `https://lobbiesync.app/.well-known/apple-app-site-association`:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.example.codSquadApp",
        "paths": [
          "/join/*",
          "/chat",
          "/squad/*",
          "/clips"
        ]
      }
    ]
  }
}
```

**Important**: Replace `TEAMID` with your Apple Team ID from Apple Developer account.

### 3. Verify apple-app-site-association
- File must be served over HTTPS
- Content-Type should be `application/json`
- No `.json` extension
- Test with: https://search.developer.apple.com/appsearch-validation-tool/

## Android App Links Setup

### 1. Add intent filters to AndroidManifest.xml
Already configured in `android/app/src/main/AndroidManifest.xml` with:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    
    <data android:scheme="https" />
    <data android:host="lobbiesync.app" />
    <data android:host="www.lobbiesync.app" />
    <data android:pathPrefix="/join/" />
    <data android:pathPrefix="/chat" />
    <data android:pathPrefix="/squad/" />
    <data android:pathPrefix="/clips" />
</intent-filter>
```

### 2. Host assetlinks.json file
Create this file at `https://lobbiesync.app/.well-known/assetlinks.json`:

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.example.codSquadApp",
      "sha256_cert_fingerprints": [
        "SHA256_FINGERPRINT_HERE"
      ]
    }
  }
]
```

### 3. Get SHA256 fingerprint
```bash
# Debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android

# Release keystore
keytool -list -v -keystore /path/to/release.keystore -alias your_alias
```

### 4. Verify assetlinks.json
- File must be served over HTTPS
- Content-Type should be `application/json`
- Test with: https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://lobbiesync.app&relation=delegate_permission/common.handle_all_urls

## Web Deep Links

Web deep links are handled automatically by go_router configuration. No additional setup needed.

## Testing Universal Links

### iOS
```bash
# Test from Safari or Notes app
https://lobbiesync.app/join/ABC123
https://lobbiesync.app/chat

# Test from terminal (iOS Simulator)
xcrun simctl openurl booted "https://lobbiesync.app/join/ABC123"
```

### Android
```bash
# Test from command line
adb shell am start -a android.intent.action.VIEW -d "https://lobbiesync.app/join/ABC123"

# Test from Chrome browser
https://lobbiesync.app/join/ABC123
```

### Flutter App Links
```bash
# Test custom scheme (fallback)
adb shell am start -a android.intent.action.VIEW -d "codsquadapp://join/ABC123"
xcrun simctl openurl booted "codsquadapp://join/ABC123"
```

## Supported Deep Link Patterns

- **Chat**: `https://lobbiesync.app/chat` or `codsquadapp://chat`
- **Join Lobby**: `https://lobbiesync.app/join/CODE` or `codsquadapp://join/CODE`
- **Squad**: `https://lobbiesync.app/squad` or `codsquadapp://squad`
- **Clips**: `https://lobbiesync.app/clips` or `codsquadapp://clips`
- **Profile**: `https://lobbiesync.app/profile` or `codsquadapp://profile`

## Troubleshooting

### iOS not opening app
1. Delete app and reinstall
2. Verify Team ID in apple-app-site-association
3. Check entitlements in Xcode
4. Test with validation tool
5. Ensure file is at root domain with `.well-known` path

### Android not opening app
1. Verify SHA256 fingerprint matches
2. Check autoVerify="true" in intent filter
3. Test with adb command first
4. Clear app data and reinstall
5. Use Digital Asset Links API to verify

### Links opening in browser instead of app
1. Check that associated domain files are accessible
2. Verify HTTPS is working correctly
3. Ensure no redirect chains (301/302)
4. Check that paths in config match actual URLs

## Security Considerations

- Always use HTTPS for universal links
- Validate deep link parameters before navigation
- Check user authentication state before sensitive routes
- Implement rate limiting on server side
- Log suspicious deep link attempts

## Analytics Integration

Universal link opens are automatically tracked via Firebase Analytics:
- Event: `navigation`
- Parameters: `experiment_id`, `variant`, `route`, `method`
- Use for A/B testing routing performance

## Production Deployment Checklist

- [ ] Upload apple-app-site-association to production server
- [ ] Upload assetlinks.json to production server
- [ ] Update Team ID in apple-app-site-association
- [ ] Update SHA256 fingerprints for release keystore
- [ ] Test all deep link patterns on iOS
- [ ] Test all deep link patterns on Android
- [ ] Verify analytics tracking
- [ ] Document user-facing deep link URLs
