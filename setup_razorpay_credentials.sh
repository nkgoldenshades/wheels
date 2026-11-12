#!/bin/bash

# Razorpay Credentials Setup Script for Firebase Functions
# Run this once to configure your Razorpay credentials

echo "🔧 Setting up Razorpay credentials in Firebase..."
echo ""

cd firebase_functions

# Set Razorpay credentials
echo "📝 Setting RAZORPAY_KEY_ID..."
firebase functions:config:set razorpay.key_id="rzp_test_TyygacttLXjp96"

echo "📝 Setting RAZORPAY_KEY_SECRET..."
firebase functions:config:set razorpay.key_secret="nUsRlMW4Ubw6MnB6OREhdeK9"

echo ""
echo "✅ Credentials set successfully!"
echo ""
echo "📋 Verify configuration:"
firebase functions:config:get

echo ""
echo "🚀 Next steps:"
echo "1. Deploy functions: firebase deploy --only functions"
echo "2. Test payment flow in your Flutter app"
echo "3. Check logs: firebase functions:log"
echo ""
