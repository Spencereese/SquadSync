#!/bin/bash

# Migration script runner for Squad model updates
# This script runs the Dart migration to add new fields to existing squads

echo "Running Squad migration script..."

# Check if Flutter/Dart is available
if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter is not installed or not in PATH"
    exit 1
fi

# Navigate to the project directory
cd "$(dirname "$0")"

# Run the migration script
flutter pub run migrate_squads.dart

echo "Migration script completed."