#!/bin/bash

# Flutter Web Runner Script
# Runs the app with HTML renderer to avoid CDN network issues

echo "🚀 Starting Flutter Web App with HTML Renderer..."
echo "📝 This avoids Google CDN network issues"
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null
then
    echo "❌ Flutter is not installed or not in PATH"
    exit 1
fi

# Run with HTML renderer
echo "▶️  Running: flutter run -d chrome --web-renderer html"
echo ""

flutter run -d chrome --web-renderer html
