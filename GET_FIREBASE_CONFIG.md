# 🔥 Get Your Firebase Config (2 Minutes)

## The Problem

Your `web/index.html` still has placeholder values:
```javascript
apiKey: "YOUR_API_KEY",  // ← Need to replace this
projectId: "YOUR_PROJECT_ID",  // ← And this
// etc...
```

This is why you're still seeing the error!

---

## ✅ Solution: Get Your Real Firebase Config

### Step 1: Go to Firebase Console
Visit: https://console.firebase.google.com

### Step 2: Select Your Project
Click on your "quickohunt" or "vaultwheels" project

### Step 3: Get Web App Config
1. Click the ⚙️ (Settings) icon → "Project settings"
2. Scroll down to "Your apps" section
3. Look for the Web app (</> icon)
4. If you don't have a web app, click "Add app" → Web
5. Click on your web app to see the config
6. You'll see something like this:

```javascript
const firebaseConfig = {
  apiKey: "AIzaSyC...",  // Real key starts with AIza
  authDomain: "your-project.firebaseapp.com",
  projectId: "your-project-id",
  storageBucket: "your-project.appspot.com",
  messagingSenderId: "123456789",
  appId: "1:123456789:web:abc123"
};
```

### Step 4: Copy and Replace
1. Copy the ENTIRE config object
2. Open `web/index.html` in your project
3. Find line ~40 where it says `const firebaseConfig = {`
4. Replace the placeholder values with your real values

---

## 📋 Example

### Before (Placeholder):
```javascript
const firebaseConfig = {
  apiKey: "YOUR_API_KEY",
  authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
  projectId: "YOUR_PROJECT_ID",
  storageBucket: "YOUR_PROJECT_ID.appspot.com",
  messagingSenderId: "YOUR_MESSAGING_SENDER_ID",
  appId: "YOUR_APP_ID"
};
```

### After (Real Config):
```javascript
const firebaseConfig = {
  apiKey: "AIzaSyC1234567890abcdefghijklmnopqrst",
  authDomain: "quickohunt-12345.firebaseapp.com",
  projectId: "quickohunt-12345",
  storageBucket: "quickohunt-12345.appspot.com",
  messagingSenderId: "123456789012",
  appId: "1:123456789012:web:abc123def456"
};
```

---

## 🚨 Important Notes

### ✅ DO:
- Use your REAL Firebase project config
- Copy the entire config object
- Make sure no typos
- Keep the quotes around values

### ❌ DON'T:
- Leave placeholder values
- Mix configs from different projects
- Remove quotes from values
- Change the structure

---

## 🧪 How to Test

After updating the config:

```bash
# Stop any running app (Ctrl+C)
# Then run:
flutter run -d chrome
```

You should see:
- ✅ No red error screen
- ✅ App loads normally
- ✅ Firebase auth works

---

## 🆘 Still Can't Find Config?

### Option 1: Create New Web App
1. Go to Firebase Console
2. Project Settings
3. Scroll to "Your apps"
4. Click "Add app" button
5. Select Web (</> icon)
6. Give it a name: "QuickOHunt Web"
7. Copy the config shown

### Option 2: Check Existing Apps
```bash
# In your project, check if you have firebase.json
cat firebase.json

# Or check for existing config files
ls -la | grep firebase
```

---

## 📸 Visual Guide

1. Firebase Console: https://console.firebase.google.com
2. Click your project
3. Click ⚙️ Settings
4. Scroll to "Your apps"
5. Look for </> Web icon
6. Click it to see config
7. Copy the config object
8. Paste into web/index.html

---

## ⏱️ Time Required

- Finding config: 1 minute
- Copying to index.html: 30 seconds
- Testing: 30 seconds
- **Total: 2 minutes**

---

## ✅ After You Update

Once you paste your real Firebase config:

1. Save `web/index.html`
2. Run `flutter run -d chrome`
3. Error should be GONE! ✅

The app will work perfectly!
