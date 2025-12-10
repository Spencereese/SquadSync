# FCM v1 API Setup Guide for SquadSync

## ✅ Migration from Legacy FCM to FCM v1 API

Firebase has deprecated the legacy FCM API (June 2024). This guide helps you set up the modern FCM v1 API using Supabase Edge Functions.

---

## 📋 Prerequisites

You have:
- **Sender ID**: `756172684661`
- **APNs Auth Key ID**: `39FM9R64T8`
- **APNs Team ID**: `K4ZTXPQ8J9`

You need:
- Firebase service account JSON file
- Supabase CLI installed

---

## 🔧 Setup Steps

### 1. Get Firebase Service Account Credentials

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your SquadSync project
3. Click ⚙️ (Settings) → **Project Settings**
4. Go to **Service Accounts** tab
5. Click **Generate New Private Key**
6. Download the JSON file (keep it secure - never commit to git!)

The JSON file looks like:
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "...",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com",
  ...
}
```

### 2. Configure APNs in Firebase (iOS Notifications)

1. In Firebase Console → Project Settings → **Cloud Messaging**
2. Scroll to **Apple app configuration**
3. Upload your APNs Authentication Key:
   - **Key ID**: `39FM9R64T8`
   - **Team ID**: `K4ZTXPQ8J9`
   - Upload the `.p8` file you downloaded from Apple Developer
4. Save

### 3. Deploy Supabase Edge Function

```bash
# Install Supabase CLI if needed
npm install -g supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref YOUR_PROJECT_REF

# Set environment secrets (from service account JSON)
supabase secrets set FIREBASE_PROJECT_ID="your-project-id"
supabase secrets set FIREBASE_CLIENT_EMAIL="firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com"
supabase secrets set FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nYOUR_PRIVATE_KEY_HERE\n-----END PRIVATE KEY-----\n"

# Deploy the edge function
supabase functions deploy send-push-notification
```

**Important**: When setting `FIREBASE_PRIVATE_KEY`, include the entire key including `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines, with `\n` for newlines.

### 4. Test the Setup

```bash
# Test the edge function locally
supabase functions serve send-push-notification

# In another terminal, test with curl
curl -X POST 'http://localhost:54321/functions/v1/send-push-notification' \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer YOUR_SUPABASE_ANON_KEY' \
  -d '{
    "tokens": ["YOUR_TEST_FCM_TOKEN"],
    "title": "Test Notification",
    "body": "Testing FCM v1 API",
    "data": {}
  }'
```

### 5. Update Flutter App (Already Done)

The code has been updated to call the Supabase Edge Function:
- ✅ `lib/notification_service.dart` - Uses `SupabaseService.client.functions.invoke()`
- ✅ Removes dependency on legacy server key
- ✅ Gracefully handles errors

---

## 🧪 Verification

### Check Edge Function Deployment

```bash
# List deployed functions
supabase functions list

# Check function logs
supabase functions logs send-push-notification
```

### Check FCM Token Storage

```sql
-- In Supabase SQL Editor
SELECT id, fcm_token FROM users WHERE fcm_token IS NOT NULL LIMIT 10;
```

### Test Notification Flow

1. Create a lobby in the app
2. Check Supabase Edge Function logs for notification sends
3. Verify other members receive push notifications

---

## 🔒 Security Notes

- **Never commit service account JSON** - It's in `.gitignore`
- **Use Supabase secrets** for private keys (not environment variables in code)
- **Edge Function handles authentication** - No credentials in Flutter app
- **APNs keys** are managed in Firebase Console

---

## 📊 Architecture

```
Flutter App
    ↓
  LobbyNotifier.createLobby()
    ↓
  NotificationService.sendNotificationToUsers()
    ↓
  Supabase Edge Function (send-push-notification)
    ↓
  FCM v1 API (OAuth2 authentication)
    ↓
  Push Notification to User Devices
```

**Benefits**:
- ✅ Secure - credentials only on server
- ✅ Modern - uses FCM v1 API
- ✅ Scalable - Supabase handles load
- ✅ Cross-platform - works for iOS, Android, web

---

## 🐛 Troubleshooting

### Error: "Invalid authentication credentials"
- Check `FIREBASE_PRIVATE_KEY` includes `\n` for newlines
- Verify `FIREBASE_CLIENT_EMAIL` matches service account JSON
- Ensure private key format is correct (PKCS#8)

### Error: "Project not found"
- Verify `FIREBASE_PROJECT_ID` matches your Firebase project ID
- Check Firebase Console → Project Settings → General

### Notifications not received
- Verify FCM tokens are stored in `users` table
- Check device has internet connection
- Verify APNs is configured for iOS
- Check Edge Function logs for errors

### Edge Function timeout
- Check Supabase function logs
- Verify Firebase service account has correct permissions
- Test OAuth2 token generation locally

---

## 📚 References

- [FCM v1 API Migration Guide](https://firebase.google.com/docs/cloud-messaging/migrate-v1)
- [Supabase Edge Functions](https://supabase.com/docs/guides/functions)
- [Firebase Service Accounts](https://firebase.google.com/docs/admin/setup)

