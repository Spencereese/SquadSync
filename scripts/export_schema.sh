#!/bin/bash
# =====================================================
# Export Supabase Schema for AI Context Sharing
# Usage: ./scripts/export_schema.sh
# Output: lib/diagnostic/schema_snapshot.json
# =====================================================

set -e

echo "🔍 Exporting Supabase schema..."

# Check if supabase CLI is logged in
if ! supabase projects list &> /dev/null; then
    echo "❌ Not logged into Supabase. Run: supabase login"
    exit 1
fi

OUTPUT_FILE="lib/diagnostic/schema_snapshot.json"

# Run the optimized schema query
echo "📊 Running schema export query..."
supabase db dump --file lib/diagnostic/schema_snapshot.sql --data-only=false

echo "✅ Schema exported to: $OUTPUT_FILE"
echo ""
echo "💡 To share with AI:"
echo "   1. Open $OUTPUT_FILE"
echo "   2. Copy entire contents"
echo "   3. Paste into chat"
echo ""
echo "🔗 Or run the quick query in Supabase SQL Editor:"
echo "   lib/diagnostic/quick_schema_export.sql"
