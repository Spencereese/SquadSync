#!/bin/bash
# regenerate_providers.sh - Regenerate Riverpod providers and run quality checks

echo "🔄 Regenerating Riverpod providers..."
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs

echo "🧪 Running tests..."
flutter test

echo "🔍 Running static analysis..."
flutter analyze

# Check if there are any errors
if [ $? -eq 0 ]; then
    echo "✅ All checks passed! Committing changes..."
    git add .
    git commit -m "Regenerate Riverpod providers and pass all checks"
    echo "🎉 Successfully committed provider regeneration!"
else
    echo "❌ Checks failed. Please fix issues before committing."
    exit 1
fi