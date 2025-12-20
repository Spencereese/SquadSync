#!/bin/bash

# Google Cloud Run Deployment Script for SquadSync Backend
# Deploys the backend with all environment variables configured

set -e  # Exit on error

echo "🚀 Deploying SquadSync Backend to Google Cloud Run..."
echo ""

# Configuration
PROJECT_ID="cod-squad-a4c62"  # Your Firebase project ID
SERVICE_NAME="squadsync-backend"
REGION="us-central1"  # Change if needed

# Check if logged in
echo "🔐 Checking Google Cloud authentication..."
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
    echo "❌ Not logged in to Google Cloud"
    echo "   Run: gcloud auth login"
    exit 1
fi

# Set project
echo "📦 Setting project: $PROJECT_ID"
gcloud config set project "$PROJECT_ID"

# Enable required APIs
echo "🔧 Enabling required APIs..."
gcloud services enable run.googleapis.com --quiet
gcloud services enable cloudbuild.googleapis.com --quiet

# Navigate to backend directory
cd "$(dirname "$0")/backend" || exit 1

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ ERROR: backend/.env file not found!"
    exit 1
fi

# Load environment variables from .env
echo "📋 Loading environment variables from .env..."
source <(grep -v '^#' .env | sed 's/^/export /')

# Deploy to Cloud Run
echo ""
echo "🚀 Deploying to Google Cloud Run..."
echo "   Region: $REGION"
echo "   Service: $SERVICE_NAME"
echo ""

gcloud run deploy "$SERVICE_NAME" \
  --source . \
  --platform managed \
  --region "$REGION" \
  --allow-unauthenticated \
  --set-env-vars="XAI_API_KEY=$XAI_API_KEY,IGDB_CLIENT_ID=$IGDB_CLIENT_ID,IGDB_CLIENT_SECRET=$IGDB_CLIENT_SECRET,SUPABASE_URL=$SUPABASE_URL,SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY" \
  --memory 512Mi \
  --cpu 1 \
  --min-instances 0 \
  --max-instances 10 \
  --timeout 60s

# Get the service URL
echo ""
echo "✅ Deployment complete!"
echo ""
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region "$REGION" --format 'value(status.url)')

echo "🌐 Your backend is now live at:"
echo "   $SERVICE_URL"
echo ""
echo "📋 Next steps:"
echo "   1. Update your Flutter app to use this URL instead of localhost:8080"
echo "   2. Test the endpoints:"
echo "      curl $SERVICE_URL/health"
echo ""
echo "💰 Pricing: Cloud Run free tier includes:"
echo "   - 2 million requests/month"
echo "   - 360,000 GB-seconds/month"
echo "   - Your usage will likely stay in free tier"
echo ""
