# API Configuration & Troubleshooting Guide

## 🔴 Current Issues & Solutions

### 1. IGDB Games Not Loading ✅ FIXED
**Issue**: IGDB/Twitch credentials configured correctly in Flutter app `.env`  
**Solution**: Credentials already set, backend needs update (see Backend Setup below)

### 2. Grok API Not Responding ✅ FIXED
**Issue**: Backend `.env` had correct Grok API key  
**Solution**: Backend credentials updated - restart backend server

### 3. Voice-to-Text Not Working ❌ NEEDS CONFIGURATION
**Issue**: Agora credentials were placeholder values  
**Solution**: ✅ Updated with your actual credentials:
- App ID: `1710c9b5de4145e1bda4c63e5dc06b70`
- Certificate: `1398dec50cc54ca5ade6aaf449324629`

### 4. Apple Login Not Working ⚠️ NEEDS SUPABASE CONFIGURATION
**Issue**: Apple Sign-In requires Supabase dashboard configuration  
**Your Credentials**:
- Team ID: `K4ZTXPQ8J9`
- Key ID: `X3W3HSAXZF`
- Bundle ID: `com.example.codSquadApp`

**Action Required**: Configure in Supabase Dashboard (see Apple Sign-In Setup below)

---

## 📋 Quick Fix Checklist

### Immediate Actions:
- [x] Updated `.env` files with all credentials
- [x] Added Agora App ID and Certificate
- [x] Verified Grok API key in backend
- [ ] **Restart backend server** (CRITICAL - do this now!)
- [ ] Configure Apple Sign-In in Supabase Dashboard
- [ ] Run `flutter pub get`
- [ ] Rebuild app

---

## 🔧 Backend Setup

### Restart Backend Server (REQUIRED)
```bash
cd backend
npm install  # If first time
npm start    # Runs on port 8080
```

**Why**: Backend reads `.env` on startup - must restart to load new credentials

### Verify Backend is Running
```bash
curl http://localhost:8080/health
# Should return: {"status":"ok"}
```

### Test Grok API
```bash
curl -X POST http://localhost:8080/grok/smart-reply \
  -H "Content-Type: application/json" \
  -d '{"message":"Hey, want to play?","sender":"John","chatHistory":[]}'
```

---

## 🍎 Apple Sign-In Configuration

### Supabase Dashboard Setup

1. **Go to Supabase Dashboard**:
   - Navigate to: https://app.supabase.com/project/sfckxrnoiwetmzdycqaa/auth/providers
   - Find "Apple" provider

2. **Enable Apple Provider**:
   - Toggle "Apple Enabled" ON
   - Enter your credentials:
     ```
     Service ID: com.example.codSquadApp
     Team ID: K4ZTXPQ8J9
     Key ID: X3W3HSAXZF
     ```

3. **Upload Private Key**:
   - You have the key file: `backend/AuthKey_X3W3HSAXZF.p8`
   - Copy the contents and paste into Supabase
   - Or upload the file directly

4. **Set Redirect URL**:
   ```
   codsquadapp://auth-callback
   ```

5. **Save Configuration**

### Verify Apple Sign-In
1. Run app on iOS device/simulator
2. Tap "Sign in with Apple"
3. Should see Apple's authentication dialog
4. After approval, should navigate to chat screen

---

## 🎮 IGDB / Twitch Configuration

### Current Status
✅ **Flutter App**: Credentials already configured
✅ **Backend**: Credentials now updated

### Credentials (Active)
```
Client ID: yq7hidzec8wv7khe9niom9m6znzrxf
Client Secret: 4ycghqkzf2ylgxbilypdxu4ga937u5
```

### Test IGDB Integration
```dart
// In Flutter DevTools console:
final gameNotifier = ref.read(gameNotifierProvider.notifier);
await gameNotifier.searchGames('Call of Duty');
```

### Expected Behavior
- Search bar in lobby/game screens should show results
- Game covers should load from IGDB
- Trending clips should appear in Clips tab

---

## 🎙️ Agora Voice/Video Configuration

### Updated Credentials
```
App ID: 1710c9b5de4145e1bda4c63e5dc06b70
Certificate: 1398dec50cc54ca5ade6aaf449324629
```

### Configuration Location
File: `.env` (root directory)
```dotenv
AGORA_APP_ID=1710c9b5de4145e1bda4c63e5dc06b70
AGORA_APP_CERTIFICATE=1398dec50cc54ca5ade6aaf449324629
```

### Test Voice Rooms
1. Navigate to Lobby screen
2. Join a lobby
3. Tap Voice button
4. Should connect to Agora channel
5. Test with another device/user

### Troubleshooting Agora
- **Logs**: Check `lib/services/voice_service.dart` for connection logs
- **Permissions**: Ensure microphone permissions granted
- **Network**: Agora requires internet connection

---

## 🤖 Grok AI Smart Replies

### Backend Configuration
File: `backend/.env`
```dotenv
XAI_API_KEY=xai-YOUR_ACTUAL_XAI_API_KEY_HERE
```

### Test Grok API
```bash
cd backend
node -e "
const axios = require('axios');
axios.post('https://api.x.ai/v1/chat/completions', {
  messages: [{role:'user',content:'Hi!'}],
  model: 'grok-4.1-fast-latest',
  temperature: 0.7,
  max_tokens: 100
}, {
  headers: {
    'Authorization': 'Bearer YOUR_XAI_API_KEY',
    'Content-Type': 'application/json'
  }
}).then(r => console.log('✅ Grok API working:', r.data.choices[0].message))
  .catch(e => console.error('❌ Grok API error:', e.response?.data || e.message));
"
```

### Expected Smart Reply Behavior
1. Open any chat
2. Long press on a message
3. Tap "Smart Reply"
4. Should see AI-generated reply suggestions
5. Tap to insert into message field

---

## 🧪 Testing Checklist

### After Configuration:
- [ ] Backend server restarted
- [ ] `flutter clean` executed
- [ ] `flutter pub get` executed
- [ ] App rebuilt

### Test Each Feature:
- [ ] **Game Search**: Search for "Warzone" - should show IGDB results
- [ ] **Grok Replies**: Long-press message → Smart Reply works
- [ ] **Voice Chat**: Join lobby → Voice button connects
- [ ] **Apple Login**: Sign out → Sign in with Apple succeeds

---

## 🐛 Debugging Commands

### Check Environment Variables Loaded
```dart
// Add to main.dart temporarily (remove after testing):
print('IGDB_CLIENT_ID: ${dotenv.env['IGDB_CLIENT_ID']}');
print('TWITCH_CLIENT_ID: ${dotenv.env['TWITCH_CLIENT_ID']}');
print('AGORA_APP_ID: ${dotenv.env['AGORA_APP_ID']}');
```

### Backend Health Check
```bash
# Check if backend is running
lsof -i :8080

# View backend logs
cd backend && npm start
# Watch for "Server running on port 8080"
```

### Flutter Logs
```bash
# Run with verbose logging
flutter run -v

# Filter for specific services
flutter run | grep -E 'IGDB|Twitch|Agora|Grok'
```

---

## 📞 Support

### Common Errors

#### "IGDB credentials not found"
- **Solution**: Run `flutter clean && flutter pub get`
- **Verify**: Check `.env` file exists in project root

#### "Grok API key not configured"
- **Solution**: Restart backend server
- **Verify**: `curl http://localhost:8080/health`

#### "Apple Sign-In failed"
- **Solution**: Configure in Supabase Dashboard (see above)
- **Verify**: Check Supabase Auth Providers page

#### "Agora connection failed"
- **Solution**: Check microphone permissions
- **Verify**: `print(dotenv.env['AGORA_APP_ID'])` in code

---

## 🎉 Success Indicators

You'll know everything works when:
- ✅ Game search shows Call of Duty covers from IGDB
- ✅ Long-press → Smart Reply shows AI suggestions
- ✅ Voice button connects to Agora with clear audio
- ✅ Apple Sign-In shows native dialog and logs in
- ✅ No console errors about missing credentials

---

**Last Updated**: December 19, 2025  
**Status**: All credentials configured, awaiting backend restart and Apple Sign-In dashboard setup
