# Agora RTC Setup Guide

## Overview
This guide covers setting up Agora RTC for production voice chat in SquadSync.

## Prerequisites
- Agora.io account (free tier available)
- Node.js backend for token generation
- Flutter app with agora_rtc_engine package

## Step 1: Get Agora Credentials

1. Go to [Agora Console](https://console.agora.io/)
2. Create a new project or use existing one
3. Navigate to Project Management → Your Project → Config
4. Copy the **App ID** and **App Certificate** (enable if not already)

## Step 2: Configure Environment Variables

1. In your `.env` file, add:
   ```
   AGORA_APP_ID=your_app_id_here
   AGORA_APP_CERTIFICATE=your_app_certificate_here
   ```

2. **NEVER commit `.env` to version control** - it's in `.gitignore`
3. Use `.env.example` as a template for team members

## Step 3: Backend Token Generation

For production security, generate tokens server-side instead of using App ID only.

### Install Dependencies
```bash
cd backend
npm install agora-access-token
```

### Add Token Endpoint to server.js
```javascript
const { RtcTokenBuilder, RtcRole } = require('agora-access-token');

// Add this route
app.post('/agora/token', (req, res) => {
  const { channelName, uid } = req.body;
  const appId = process.env.AGORA_APP_ID;
  const appCertificate = process.env.AGORA_APP_CERTIFICATE;

  if (!appId || !appCertificate) {
    return res.status(500).json({ error: 'Agora credentials not configured' });
  }

  const expirationTimeInSeconds = 3600; // 1 hour
  const currentTimestamp = Math.floor(Date.now() / 1000);
  const privilegeExpiredTs = currentTimestamp + expirationTimeInSeconds;

  const token = RtcTokenBuilder.buildTokenWithUid(
    appId,
    appCertificate,
    channelName,
    uid,
    RtcRole.PUBLISHER,
    privilegeExpiredTs
  );

  res.json({ token });
});
```

### Update VoiceService
In `lib/services/voice_service.dart`, the `generateToken` method will call this endpoint.

## Step 4: Deploy Backend

Deploy your Node.js backend to production (Heroku, AWS, etc.) with environment variables set.

## Security Notes

- **Never expose App Certificate in client code**
- **Always use tokens for production** - App ID only is for testing
- **Rotate certificates regularly** for security
- **Monitor usage** in Agora Console to prevent abuse

## Testing

1. Start backend server
2. Run Flutter app
3. Test voice chat join/leave functionality
4. Verify token generation in backend logs

## Troubleshooting

- **Token errors**: Check backend logs, verify credentials
- **Connection issues**: Ensure firewall allows Agora ports
- **Permission denied**: Check microphone permissions in app
- **SDK version**: Ensure ^6.5.3 for latest bug fixes