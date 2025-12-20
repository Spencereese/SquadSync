#!/bin/bash

# SquadSync Backend Startup Script
# This script starts the Node.js backend server with all APIs configured

echo "🚀 Starting SquadSync Backend Server..."
echo ""
echo "📋 Configured APIs:"
echo "  ✅ Grok AI (xAI-BPhjjcIak...)"
echo "  ✅ IGDB/Twitch (yq7hidzec8...)"
echo "  ✅ Supabase"
echo ""

# Navigate to backend directory
cd "$(dirname "$0")/backend" || exit 1

# Check if node_modules exists
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
    echo ""
fi

# Check if .env exists
if [ ! -f ".env" ]; then
    echo "❌ ERROR: backend/.env file not found!"
    echo "   Copy .env.example and fill in your credentials"
    exit 1
fi

# Start the server
echo "🔥 Starting server on http://localhost:8080"
echo "   Press Ctrl+C to stop"
echo ""

npm start
