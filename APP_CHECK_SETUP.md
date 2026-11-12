# Firebase App Check Setup Guide for VaultWheels

## What is Firebase App Check?

Firebase App Check protects your Firebase backend resources (like AI chat, Cloud Functions, Firestore) from abuse by verifying that requests come from your legitimate app, not from bots or unauthorized sources.

**Why You Need This:**
- Your AI chat functionality requires App Check to work on production domains
- Without App Check configured, you'll see 400/401 errors when using Firebase AI services
- App Check prevents abuse and protects your Firebase quotas

## Current Status

✅ **Code Implementation:** Complete  
❌ **Firebase Console Registration:** Required (see steps below)  
❌ **Site Key Configuration:** Required (see step 3 below)

## Setup Instructions

### Step 1: Register Your Web Apps in Firebase Console

You have **two web apps** that need to be registered:

1. **quickohunt** (web)
2. **vaultwheels**

**Production domains to register:**
- `vaultwheels.web.app`
- `wheels.vervestrideai.com`
- `quickohunt-app.web.app`

**How to Register:**

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: **quickohunt-app** (Project Number: 759157073844)
3. Navigate to **Security** > **App Check** in the left sidebar
4. Click the **Apps** tab
5. For each web app (quickohunt and vaultwheels):
   - Click **Register app** or select existing app
   - Choose **reCAPTCHA Enterprise** as the provider
   - Firebase will automatically create a reCAPTCHA Enterprise site key
   - No need to manually create keys in Google reCAPTCHA Admin Console
6. Add your production domains:
   - `vaultwheels.web.app`
   - `wheels.vervestrideai.com`
   - `quickohunt-app.web.app`
   - For localhost testing: `localhost` (optional, but recommended for development)

### Step 2: Get Your reCAPTCHA Enterprise Site Key

After registering your apps in Step 1:

1. In Firebase Console > App Check > Apps tab
2. Find your registered web app
3. Click on it to see the configuration
4. Copy the **reCAPTCHA Enterprise site key** (starts with `6L...`)
   - This is NOT a secret key - it's safe to include in client code
   - Firebase auto-generates this when you register the app

### Step 3: Add Site Key to Your Code

Open the file: **`c:\quickohunt\lib\main.dart`**

Find this line (around line 141):
```dart
'YOUR_RECAPTCHA_ENTERPRISE_SITE_KEY_HERE',
```

Replace it with your actual site key from Step 2:
```dart
'6LxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxXXX',  // Your real key
```

**Example:**
```dart
webProvider: ReCaptchaEnterpriseProvider(
  '6LdRcPQqAAAAABCDEFGHIJKLMNOPQRSTUVWXYZ123',  // Real key from Firebase Console
),
```

### Step 4: Deploy and Test

1. **Build your app:**
   ```bash
   flutter build web --release
   ```

2. **Deploy to Firebase Hosting:**
   ```bash
   firebase deploy --only hosting
   ```

3. **Test on production domain:**
   - Visit `https://vaultwheels.web.app` or your custom domain
   - Open AI chat
   - Send a message
   - Should work without 400/401 errors

## Testing on Localhost

**Important:** Localhost testing has limitations with App Check.

### Option 1: Add localhost to allowed domains (Recommended)
1. Go to Firebase Console > App Check
2. Add `localhost` to your allowed domains list
3. AI chat will work on localhost with real verification

### Option 2: Use debug tokens (For development only)
1. In Firebase Console > App Check > Apps > Debug tokens
2. Generate a debug token
3. Add to your environment (not recommended for production builds)

### Option 3: Test directly on production
- Deploy and test on your production domains
- This is the most reliable way to verify App Check is working

## Understanding reCAPTCHA Enterprise vs v3

**You are using reCAPTCHA Enterprise (modern, recommended):**
- ✅ More security features and fraud detection
- ✅ 10,000 free assessments per month
- ✅ Better bot protection
- ✅ Auto-created by Firebase (no manual setup needed)

**NOT using reCAPTCHA v3 (deprecated):**
- ⚠️ Older version being phased out
- ⚠️ Fewer security features
- ⚠️ Manual Google reCAPTCHA registration required

**Key Difference:**
- reCAPTCHA Enterprise keys are created and managed entirely within Firebase Console
- You don't need to visit Google reCAPTCHA Admin Console separately

## Troubleshooting

### Error: "App Check token is invalid" (401)
**Cause:** Site key not configured or incorrect  
**Fix:**
1. Verify you replaced `YOUR_RECAPTCHA_ENTERPRISE_SITE_KEY_HERE` in main.dart
2. Ensure the site key matches what's shown in Firebase Console
3. Rebuild and redeploy: `flutter build web && firebase deploy`

### Error: "Request blocked by App Check" (400)
**Cause:** Domain not registered in Firebase Console  
**Fix:**
1. Go to Firebase Console > App Check
2. Add your production domain to the allowed list
3. Wait 5-10 minutes for changes to propagate

### Error: "reCAPTCHA Enterprise site key not found"
**Cause:** Apps not registered in Firebase Console  
**Fix:**
1. Complete Step 1 above to register your web apps
2. Firebase will auto-generate the site key during registration

### AI Chat works on localhost but not production
**Cause:** Localhost uses different verification than production  
**Fix:**
1. Verify your production domain is registered in Firebase Console
2. Check that you're using the correct site key (from Firebase Console, not a test key)
3. Clear browser cache and try again

### AI Chat still shows 400/401 errors after setup
**Checklist:**
- [ ] Registered both web apps (quickohunt and vaultwheels) in Firebase Console
- [ ] Added all production domains to allowed list
- [ ] Copied the correct reCAPTCHA Enterprise site key from Firebase Console
- [ ] Replaced placeholder in main.dart with real site key
- [ ] Rebuilt the app: `flutter build web`
- [ ] Deployed to hosting: `firebase deploy`
- [ ] Waited 5-10 minutes for Firebase to propagate changes
- [ ] Cleared browser cache and refreshed

### CORS Errors
**Note:** CORS errors are different from App Check errors.  
If you see CORS errors, that's a separate configuration issue with your Firebase project or Supabase backend, not App Check.

## Token Time-to-Live (TTL) Configuration

**Default TTL:** 1 day (recommended)

To change TTL:
1. Firebase Console > App Check > Apps
2. Click your app > Settings
3. Adjust TTL (range: 30 minutes to 7 days)

**Considerations:**
- **Shorter TTL (30 min - 2 hours):** More secure, but more frequent re-verification
- **Longer TTL (1-7 days):** Better performance, slightly less secure
- **Default (1 day):** Good balance for most apps

## Platform-Specific Notes

This setup is for **Flutter web only**.

**Mobile platforms** (if you add them later):
- **Android:** Uses Play Integrity provider (auto-configured)
- **iOS:** Uses App Attest provider (auto-configured)
- **Both:** Require separate registration in Firebase Console

## Security Best Practices

1. ✅ **Site key is public:** Safe to commit to git (it's not a secret)
2. ✅ **Secret key stays in Firebase:** Never expose or download it
3. ✅ **Register only production domains:** Don't add untrusted domains
4. ✅ **Monitor usage:** Check Firebase Console > App Check > Metrics
5. ✅ **Enable enforcement:** Once tested, enable enforcement for all Firebase services

## Enable Enforcement (Optional but Recommended)

After verifying App Check works:

1. Go to Firebase Console > App Check
2. Click **APIs** tab
3. For each service (e.g., Firebase AI, Cloud Functions):
   - Click the service
   - Click **Enforce**
   - This will block requests without valid App Check tokens

**Warning:** Only enable enforcement after confirming App Check works on production!

## Need Help?

**Firebase Documentation:**
- [App Check Overview](https://firebase.google.com/docs/app-check)
- [reCAPTCHA Enterprise Setup](https://firebase.google.com/docs/app-check/web/recaptcha-enterprise-provider)

**Your Firebase Project:**
- Project: quickohunt-app
- Project Number: 759157073844
- Console: https://console.firebase.google.com/project/quickohunt-app

**Common Issues:**
- Forgot to register apps → See Step 1
- Wrong site key → See Step 2 and verify in Firebase Console
- Not deployed → See Step 4
- Domain not whitelisted → See Step 1, add your domain

---

**Summary:**
1. Register apps in Firebase Console (creates site key automatically)
2. Copy site key from Firebase Console
3. Paste into `lib/main.dart` replacing placeholder
4. Build and deploy
5. Test on production domain

Good luck! 🚀
