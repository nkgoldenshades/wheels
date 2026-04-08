# 🚀 Quick AI Setup (5 Minutes)

## Step 1: Get Gemini API Key (2 min)

1. Go to: https://makersuite.google.com/app/apikey
2. Sign in with Google
3. Click "Create API Key"
4. Copy the key (starts with `AIza...`)

## Step 2: Configure Firebase Functions (2 min)

```bash
cd functions
firebase functions:config:set gemini.api_key="YOUR_API_KEY_HERE"
```

Replace `YOUR_API_KEY_HERE` with your actual key.

## Step 3: Deploy Functions (1 min)

```bash
firebase deploy --only functions
```

Wait for deployment to complete.

## Step 4: Test in Flutter

```bash
flutter pub get
flutter run -d chrome
```

Open AI Chat and send a message!

## ✅ Done!

Your AI is now:
- ✅ Secure (API key on server)
- ✅ Working on Web + Mobile
- ✅ Production-ready

## 🐛 Troubleshooting

### "Function not found"
```bash
firebase deploy --only functions
firebase functions:list
```

### "API key not configured"
```bash
firebase functions:config:get
# Should show: gemini.api_key: "AIza..."
```

### Still not working?
Check Firebase Console → Functions → Logs for errors.
