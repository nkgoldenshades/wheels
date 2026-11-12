#!/bin/bash

echo "🚀 Deploying Firebase AI Functions..."

# Check if we're in the right directory
if [ ! -f "functions/package.json" ]; then
    echo "❌ Error: Run this script from your project root directory"
    exit 1
fi

# Install dependencies
echo "📦 Installing dependencies..."
cd functions
npm install

# Check if API key is configured
echo "🔑 Checking API key configuration..."
firebase functions:config:get gemini.api_key > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "⚠️  Gemini API key not configured!"
    echo "Please run: firebase functions:config:set gemini.api_key=\"YOUR_API_KEY\""
    echo "Get your API key from: https://makersuite.google.com/app/apikey"
    read -p "Do you want to continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Deploy functions
echo "🚀 Deploying Firebase Functions..."
cd ..
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo "✅ Deployment successful!"
    echo "🎉 Your AI is now ready with natural responses!"
    echo ""
    echo "Next steps:"
    echo "1. Test the AI chat in your app"
    echo "2. You should get natural, conversational responses"
    echo "3. Check Firebase Console > Functions for logs"
else
    echo "❌ Deployment failed!"
    echo "Check the error messages above and try again"
fi