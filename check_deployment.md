# Quick Deployment Check

## Step 1: Check if Firebase Functions are deployed

Open Firebase Console:
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Go to Functions section
4. Look for `aiChat` function

**If you don't see `aiChat` function**: Functions are not deployed yet.

## Step 2: Check API key configuration

Run this command:
```bash
firebase functions:config:get
```

**Expected output**:
```json
{
  "gemini": {
    "api_key": "AIzaSy..."
  }
}
```

**If empty or no gemini key**: API key not configured.

## Step 3: Quick Fix Commands

### If functions not deployed:
```bash
cd functions
npm install
cd ..
firebase deploy --only functions
```

### If API key not configured:
```bash
# Get API key from: https://makersuite.google.com/app/apikey
firebase functions:config:set gemini.api_key="YOUR_ACTUAL_API_KEY"
firebase deploy --only functions
```

### Complete setup from scratch:
```bash
# 1. Install dependencies
cd functions && npm install && cd ..

# 2. Get API key from https://makersuite.google.com/app/apikey

# 3. Configure API key
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"

# 4. Deploy
firebase deploy --only functions

# 5. Test in app
```

## Step 4: Test

Run the test script:
```bash
dart test_firebase_functions.dart
```

Or test in your app and check debug console for logs like:
- `🔥 Calling Firebase AI function with message: hello`
- `✅ Got AI response from Firebase: [natural response]`

## Common Issues

### "Function not found"
- Functions not deployed
- Wrong function name
- Wrong Firebase project

### "Unauthenticated" 
- User not signed in to Firebase Auth
- Check authentication in your app

### Still getting bot responses
- API key not configured
- API key invalid/expired
- Gemini API quota exceeded

### "Permission denied"
- Firebase Functions rules
- User doesn't have permission

## Quick Test

The fastest way to test if everything is working:

1. Open your Flutter app
2. Use AI chat
3. Check debug console
4. Look for `✅ Got AI response from Firebase:` message

If you see `⚠️ Using fallback response due to error`, then Firebase Functions aren't working properly.