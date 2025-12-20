# 🚀 Cloud Run Deployment Guide

## Quick Deploy (One Command)

```bash
./deploy_to_cloudrun.sh
```

This will:
1. ✅ Authenticate with Google Cloud
2. ✅ Build your Docker container
3. ✅ Deploy to Cloud Run with all environment variables
4. ✅ Return your live backend URL

---

## Manual Deployment Steps

### 1. Authenticate with Google Cloud
```bash
gcloud auth login
gcloud config set project cod-squad-a4c62
```

### 2. Deploy Backend
```bash
cd backend
gcloud run deploy squadsync-backend \
  --source . \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars="XAI_API_KEY=xai-YOUR_ACTUAL_XAI_API_KEY_HERE,IGDB_CLIENT_ID=yq7hidzec8wv7khe9niom9m6znzrxf,IGDB_CLIENT_SECRET=4ycghqkzf2ylgxbilypdxu4ga937u5,SUPABASE_URL=https://sfckxrnoiwetmzdycqaa.supabase.co,SUPABASE_ANON_KEY=sb_publishable_mQA06ZY-kIYL4XTnoHh6ag_Qg_7Nbwp" \
  --memory 512Mi \
  --cpu 1 \
  --timeout 60s
```

### 3. Get Your Backend URL
After deployment, you'll see output like:
```
Service [squadsync-backend] revision [squadsync-backend-00001-xxx] has been deployed.
Service URL: https://squadsync-backend-xxxxx-uc.a.run.app
```

### 4. Update Your Flutter App

Edit `.env` file:
```dotenv
BACKEND_URL=https://squadsync-backend-xxxxx-uc.a.run.app
```

### 5. Rebuild Your App
```bash
flutter clean
flutter pub get
flutter run --dart-define=BACKEND_URL=https://squadsync-backend-xxxxx-uc.a.run.app
```

---

## Testing Deployment

### Test Backend Health
```bash
curl https://your-backend-url.run.app/health
# Should return: {"status":"ok"}
```

### Test Grok Smart Replies
```bash
curl -X POST https://your-backend-url.run.app/grok/smart-reply \
  -H "Content-Type: application/json" \
  -d '{
    "message": "Hey, want to play Warzone?",
    "sender": "John",
    "chatHistory": []
  }'
```

### Test Agora Token Generation
```bash
curl -X POST https://your-backend-url.run.app/generate-agora-token \
  -H "Content-Type: application/json" \
  -d '{
    "channelName": "test-channel",
    "uid": 12345,
    "certificate": "1398dec50cc54ca5ade6aaf449324629"
  }'
```

---

## Cost & Pricing

### Cloud Run Free Tier (Monthly)
- ✅ 2 million requests
- ✅ 360,000 GB-seconds of compute
- ✅ 180,000 vCPU-seconds
- ✅ 1 GB network egress

### Your Expected Usage
With your current setup (512Mi memory, 1 vCPU):
- **Smart replies**: ~100ms per request
- **Free tier covers**: ~100,000 smart reply requests/month
- **Likely cost**: $0/month (stays in free tier)

### If You Exceed Free Tier
- **Requests**: $0.40 per million requests
- **Compute**: $0.00002400 per GB-second
- **Even with heavy usage**: ~$2-5/month

---

## Environment Variables on Cloud Run

Your backend will have these environment variables set:

| Variable | Value | Purpose |
|----------|-------|---------|
| `XAI_API_KEY` | `xai-BPhjjcIak...` | Grok AI smart replies |
| `IGDB_CLIENT_ID` | `yq7hidzec8...` | Game search |
| `IGDB_CLIENT_SECRET` | `4ycghqkzf...` | Game search auth |
| `SUPABASE_URL` | `https://sfckxrnoiwet...` | Database |
| `SUPABASE_ANON_KEY` | `sb_publishable_mQA...` | Auth |
| `PORT` | `8080` (auto-set) | Cloud Run port |

---

## Updating Deployed Backend

### Quick Update
```bash
cd backend
gcloud run deploy squadsync-backend \
  --source . \
  --region us-central1
```

### Update Environment Variable Only
```bash
gcloud run services update squadsync-backend \
  --region us-central1 \
  --update-env-vars="XAI_API_KEY=new-key-here"
```

### View Current Config
```bash
gcloud run services describe squadsync-backend \
  --region us-central1
```

---

## Monitoring & Logs

### View Logs
```bash
gcloud run logs read squadsync-backend \
  --region us-central1 \
  --limit 50
```

### Live Logs (Follow)
```bash
gcloud run logs tail squadsync-backend \
  --region us-central1
```

### Metrics Dashboard
Visit: https://console.cloud.google.com/run/detail/us-central1/squadsync-backend/metrics

---

## Troubleshooting

### "Permission Denied" Error
```bash
gcloud auth login
gcloud config set project cod-squad-a4c62
```

### "APIs Not Enabled"
```bash
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

### "Build Failed"
Check your `backend/Dockerfile`:
```dockerfile
FROM node:18
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 8080
CMD ["node", "server.js"]
```

### "Environment Variables Not Working"
Verify they're set:
```bash
gcloud run services describe squadsync-backend \
  --region us-central1 \
  --format="value(spec.template.spec.containers[0].env)"
```

---

## Local Testing Before Deploy

Test your backend locally first:
```bash
cd backend
npm install
npm start
# In another terminal:
curl http://localhost:8080/health
```

---

## Production Checklist

- [ ] Backend deployed to Cloud Run
- [ ] Health endpoint returns `{"status":"ok"}`
- [ ] Updated `.env` with Cloud Run URL
- [ ] Rebuilt Flutter app with new URL
- [ ] Tested smart replies in app
- [ ] Tested voice chat with Agora tokens
- [ ] Monitored logs for errors
- [ ] Set up billing alerts (optional)

---

## Rolling Back

### Revert to Previous Version
```bash
# List revisions
gcloud run revisions list --service squadsync-backend --region us-central1

# Rollback to specific revision
gcloud run services update-traffic squadsync-backend \
  --region us-central1 \
  --to-revisions=squadsync-backend-00001-xxx=100
```

---

## Next Steps After Deployment

1. **Test in Production**: Use the deployed URL for all backend features
2. **Monitor Usage**: Check Cloud Run dashboard weekly
3. **Set Billing Alert**: Get notified if you exceed free tier
4. **Custom Domain** (Optional): Add your own domain like `api.squadsync.app`

---

**Deployment Time**: ~3-5 minutes  
**First-Time Setup**: ~10 minutes  
**Future Updates**: ~2 minutes
