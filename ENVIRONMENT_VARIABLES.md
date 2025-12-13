# Environment Variables Configuration Guide

**Last Updated**: December 12, 2025  
**Status**: ✅ All credentials properly configured with dotenv

---

## Overview

SquadSync uses environment variables for all sensitive credentials following security best practices. The app uses `flutter_dotenv` for Flutter/Dart and standard `dotenv` for the Node.js backend.

---

## ✅ Security Status

### Current Implementation
- ✅ **IGDB API Credentials**: Uses `dotenv.env['IGDB_CLIENT_ID']` and `dotenv.env['IGDB_CLIENT_SECRET']`
- ✅ **xAI Grok API Key**: Managed in backend via `process.env.XAI_API_KEY`
- ✅ **Firebase Credentials**: Backend uses `process.env.GOOGLE_CLOUD_CREDENTIALS` (JSON string)
- ✅ **Database Credentials**: Backend uses `process.env.DB_USER`, `DB_HOST`, `DB_NAME`, `DB_PASSWORD`, `DB_PORT`
- ✅ **Supabase**: Uses `process.env.SUPABASE_URL` and `SUPABASE_ANON_KEY`
- ✅ **.env in .gitignore**: Properly configured to prevent credential commits
- ✅ **dotenv loaded in main.dart**: Initialization complete

### Files Using Environment Variables

#### Flutter App (`lib/`)
1. **`lib/services/igdb_service.dart`** (Lines 53, 61)
   ```dart
   Future<String?> getClientId() async {
     await _ensureStorage();
     final storedId = _storage!.getString(_clientIdKey);
     if (storedId != null) return storedId;
     return dotenv.env['IGDB_CLIENT_ID']; // ✅
   }

   Future<String?> getClientSecret() async {
     await _storage!.getString(_clientSecretKey);
     if (storedSecret != null) return storedSecret;
     return dotenv.env['IGDB_CLIENT_SECRET']; // ✅
   }
   ```

2. **`lib/services/igdb_auth_service.dart`** (Lines 32, 42)
   - Same pattern as igdb_service.dart
   - Falls back to dotenv after checking SharedPreferences

3. **`lib/services/twitch_service.dart`** (Lines 21-22)
   ```dart
   _clientId = dotenv.env['TWITCH_CLIENT_ID'];
   _clientSecret = dotenv.env['TWITCH_CLIENT_SECRET'];
   ```

4. **`lib/main.dart`** (Lines 30-32)
   ```dart
   try {
     await dotenv.load(); // ✅ Loads .env file
   } catch (e) {
     debugPrint('dotenv load failed: $e');
   }
   ```

#### Backend (`backend/`)
1. **`backend/server.js`** (Lines 17, 331, 381, 446)
   - **Firebase**: `process.env.GOOGLE_CLOUD_CREDENTIALS` (Line 17)
   - **xAI Grok**: `process.env.XAI_API_KEY` (Lines 331, 381, 446)
   - **PostgreSQL**: `process.env.DB_USER`, `DB_HOST`, `DB_NAME`, `DB_PASSWORD`, `DB_PORT` (Lines 43-47)

---

## 🔧 Setup Instructions

### 1. Flutter App Setup

#### Create `.env` file in project root:
```bash
cd /path/to/cod_squad_app
cp .env.example .env
```

#### Edit `.env` with your credentials:
```dotenv
# IGDB API (from Twitch Developer Console)
IGDB_CLIENT_ID=your_actual_client_id
IGDB_CLIENT_SECRET=your_actual_client_secret

# Twitch API (if using Twitch integration)
TWITCH_CLIENT_ID=your_twitch_client_id
TWITCH_CLIENT_SECRET=your_twitch_client_secret

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# xAI API Key (optional - only if calling Grok directly from app)
XAI_API_KEY=your_xai_api_key

# Agora (for voice/video)
AGORA_APP_ID=your_agora_app_id
AGORA_APP_CERTIFICATE=your_agora_certificate
```

### 2. Backend Setup

#### Create `backend/.env` file:
```bash
cd backend
cp .env.example .env
```

#### Edit `backend/.env` with your credentials:
```dotenv
# Google Cloud Service Account (single-line JSON)
GOOGLE_CLOUD_CREDENTIALS={"type":"service_account","project_id":"your-project-id",...}

# PostgreSQL Database
DB_USER=your_db_user
DB_HOST=your_db_host
DB_NAME=your_db_name
DB_PASSWORD=your_db_password
DB_PORT=5432

# xAI Grok API (REQUIRED for AI features)
XAI_API_KEY=xai-xxxxxxxxxxxxxxxxxxxx

# IGDB API
IGDB_CLIENT_ID=your_igdb_client_id
IGDB_CLIENT_SECRET=your_igdb_client_secret

# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your_anon_key

# Optional
PORT=8080
```

---

## 📋 Required Credentials

### 1. IGDB API (Twitch)
**Get credentials**: https://dev.twitch.tv/console/apps

1. Create a new app on Twitch Developer Console
2. Note your **Client ID** and **Client Secret**
3. Add to `.env`: `IGDB_CLIENT_ID` and `IGDB_CLIENT_SECRET`

**Used for**: Game search, metadata, cover images

---

### 2. xAI Grok API
**Get API key**: https://console.x.ai/

1. Sign up for xAI account
2. Generate API key in console
3. Add to `backend/.env`: `XAI_API_KEY`

**Used for**:
- Smart replies with sentiment analysis
- AI matchmaking recommendations
- Chat assistance and question answering

**Model**: `grok-4.1-fast-latest` (optimized for low latency)  
**Rate limits**: 3 retries with exponential backoff (1s base delay)

---

### 3. Google Cloud Credentials (Firebase Admin)
**Get credentials**: https://console.firebase.google.com/

1. Go to Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Download JSON file
4. **Convert to single-line string** (remove newlines)
5. Add to `backend/.env`: `GOOGLE_CLOUD_CREDENTIALS`

**Used for**:
- Firebase Admin SDK operations
- Cloud Storage signed URLs
- Firestore database access

**⚠️ Security Note**: Never commit this file to git! Use environment variable only.

---

### 4. PostgreSQL Database
**Setup**: Use Supabase or self-hosted PostgreSQL

Add to `backend/.env`:
```dotenv
DB_USER=postgres
DB_HOST=db.yourproject.supabase.co
DB_NAME=postgres
DB_PASSWORD=your_secure_password
DB_PORT=5432
```

**Used for**: Analytics, message history, user data

---

### 5. Supabase
**Get credentials**: https://app.supabase.com/project/_/settings/api

Add to both `.env` files:
```dotenv
SUPABASE_URL=https://yourproject.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

**Used for**: Real-time data, authentication, storage

---

### 6. Agora (Voice/Video)
**Get credentials**: https://console.agora.io/

Add to `.env`:
```dotenv
AGORA_APP_ID=your_app_id
AGORA_APP_CERTIFICATE=your_certificate
```

**Used for**: Voice rooms, video rooms, screen sharing

---

## 🔒 Security Best Practices

### ✅ What We Do Right
1. **No hardcoded credentials** - All sensitive data in environment variables
2. **`.env` in .gitignore** - Prevents accidental commits
3. **`.env.example` provided** - Template without real credentials
4. **Backend separation** - API keys handled server-side when possible
5. **Fallback strategy** - SharedPreferences → Environment variables → Error

### ⚠️ Important Warnings
- **NEVER commit `.env` files** to version control
- **NEVER hardcode API keys** in source code
- **ALWAYS use `.env.example`** as template (with placeholder values)
- **ROTATE credentials** if accidentally exposed
- **Use service role keys** only in backend (never in Flutter app)

---

## 🧪 Verification

### Check if dotenv is loaded:
```dart
// lib/main.dart already has this:
try {
  await dotenv.load();
  debugPrint('dotenv loaded successfully');
} catch (e) {
  debugPrint('dotenv load failed: $e');
}
```

### Verify environment variables:
```dart
// Add temporary debug code (REMOVE after testing):
debugPrint('IGDB_CLIENT_ID loaded: ${dotenv.env['IGDB_CLIENT_ID'] != null}');
debugPrint('XAI_API_KEY loaded: ${dotenv.env['XAI_API_KEY'] != null}');
```

### Backend verification:
```bash
cd backend
node -e "require('dotenv').config(); console.log('XAI_API_KEY:', process.env.XAI_API_KEY ? 'Loaded' : 'Missing');"
```

---

## 📦 Dependencies

### Flutter (pubspec.yaml)
```yaml
dependencies:
  flutter_dotenv: ^5.1.0  # ✅ Already included
  shared_preferences: ^2.0.0  # For credential caching
```

### Backend (package.json)
```json
{
  "dependencies": {
    "dotenv": "^16.0.0"  // ✅ Already included
  }
}
```

---

## 🔄 Migration from Hardcoded Credentials

### Previous Issues (Now Fixed)
- ❌ **Old**: IGDB credentials hardcoded in `igdb_service.dart`
- ✅ **Now**: Uses `dotenv.env['IGDB_CLIENT_ID']` with fallback to SharedPreferences

- ❌ **Old**: xAI API key potentially hardcoded
- ✅ **Now**: Backend uses `process.env.XAI_API_KEY` exclusively

- ❌ **Old**: Firebase service account paths hardcoded
- ✅ **Now**: Backend uses `process.env.GOOGLE_CLOUD_CREDENTIALS` JSON string

---

## 📚 Related Documentation

- **Supabase Functions**: `lib/diagnostic/SUPABASE_FUNCTIONS_INVENTORY.md`
- **Security Audit**: `SECURITY_AUDIT_2025-12-12.md`
- **Architecture**: `.github/copilot-instructions.md`
- **Backend API**: `backend/README.md` (if exists)

---

## 🚀 Deployment

### Production Environment Variables

#### Flutter App (CI/CD)
Set secrets in GitHub Actions / GitLab CI / etc:
```yaml
env:
  IGDB_CLIENT_ID: ${{ secrets.IGDB_CLIENT_ID }}
  IGDB_CLIENT_SECRET: ${{ secrets.IGDB_CLIENT_SECRET }}
  SUPABASE_URL: ${{ secrets.SUPABASE_URL }}
  SUPABASE_ANON_KEY: ${{ secrets.SUPABASE_ANON_KEY }}
```

#### Backend (Cloud Run / Docker)
```bash
# Google Cloud Run
gcloud run deploy squadsync-backend \
  --set-env-vars="XAI_API_KEY=xxx,DB_HOST=xxx,GOOGLE_CLOUD_CREDENTIALS=xxx"

# Docker
docker run -p 8080:8080 \
  -e XAI_API_KEY=xxx \
  -e DB_HOST=xxx \
  -e GOOGLE_CLOUD_CREDENTIALS=xxx \
  squadsync-backend
```

---

## ✅ Checklist

- [x] `.env` files created (not committed)
- [x] `.env.example` files with placeholders
- [x] `.gitignore` includes `.env`
- [x] `dotenv.load()` called in `main.dart`
- [x] IGDB credentials use environment variables
- [x] xAI Grok API key in backend environment
- [x] Firebase credentials in backend environment
- [x] No hardcoded credentials in source code
- [x] Documentation complete

---

## 🆘 Troubleshooting

### Error: "IGDB credentials not found"
1. Check `.env` file exists in project root
2. Verify `IGDB_CLIENT_ID` and `IGDB_CLIENT_SECRET` are set
3. Ensure `dotenv.load()` is called before using credentials
4. Run `flutter clean && flutter pub get`

### Error: "Grok API key not configured"
1. Check `backend/.env` exists
2. Verify `XAI_API_KEY` is set correctly
3. Restart backend server after updating `.env`

### Error: "Firebase initialization failed"
1. Check `GOOGLE_CLOUD_CREDENTIALS` in `backend/.env`
2. Ensure JSON is valid (use online validator)
3. Verify service account has necessary permissions

---

**Last Verified**: December 12, 2025  
**Status**: ✅ All credentials properly configured with environment variables  
**Security Audit**: Passed - No hardcoded credentials found
