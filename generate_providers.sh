#!/bin/bash

# Riverpod Code Generation Script
# This script helps generate Riverpod providers from @riverpod annotations

echo "🏗️  Generating Riverpod providers..."

# Run build_runner to generate code
flutter pub run build_runner build --delete-conflicting-outputs

if [ $? -eq 0 ]; then
    echo "✅ Code generation completed successfully!"
    echo ""
    echo "Generated files:"
    find lib -name "*.g.dart" -type f | while read file; do
        echo "  📄 $file"
    done
    echo ""
    echo "💡 Tip: Use 'flutter pub run build_runner watch' for auto-regeneration during development"
else
    echo "❌ Code generation failed. Check the errors above."
    exit 1
fi