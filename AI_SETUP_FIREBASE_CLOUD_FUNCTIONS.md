# 🔥 AI Integration - Firebase Cloud Functions (CORRECT SETUP)

## ⚠️ IMPORTANT: Read This First!

**DO NOT use direct API keys in Flutter app!**
**DO NOT use `google_generative_ai` package in Flutter!**
**DO NOT use `firebase_vertexai` package (not stable on Web)!**

## ✅ Correct Architecture

```
Flutter App → Firebase Cloud Functions → Gemini AI
```

**Why this is correct:**
- 🔐 API keys stay server-side (secure)
- 📱 No keys exposed in APK/Web bundle
- ⚙️ Centralized control and logging
- 🌐 Works on ALL platforms (Web, Android, iOS)
- 🛡️ Rate limiting and abuse prevention

---

## 📁 Current Setup (Already Implemented)

### 1. Firebase Cloud Function
**Location:** `functions/index.js`

```javascript
exports.aiChat = functions.https.onCall(async (data, context) => {
  // Authenticated users only
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { message, conversationHistory = [] } = data;
  
  // Call Gemini AI with server-side API key
  const aiResponse = await getGeminiResponse(message, conversationHistory);
  
  return {
    response: aiResponse,
    timestamp: Date.now(),
  };
});
```

### 2. Flutter Integration
**Location:** `lib/screens/ai_chat_page.dart`

```dart
import 'package:cloud_functions/cloud_functions.dart';

// Call Firebase Function (NOT direct API)
final response = await FirebaseFunctions.instance
    .httpsCallable('aiChat')
    .call({
  'message': userMessage,
  'conversationHistory': _buildHistory(),
});

final aiText = response.data['response'] as String;
```

---

## 🚀 Setup Instructions

### Step 1: Set Gemini API Key (Server-Side)

**Option A: Using Firebase CLI (Recommended)**
```bash
cd functions
firebase functions:config:set gemini.api_key="YOUR_GEMINI_API_KEY_HERE"
firebase deploy --only functions
```

**Option B: Using .env file (Local Development)**
```bash
cd functions
echo "GEMINI_API_KEY=YOUR_GEMINI_API_KEY_HERE" > .env
```

**Get API Key:** https://makersuite.google.com/app/apikey

### Step 2: Install Dependencies
```bash
cd functions
npm install
```

### Step 3: Deploy Functions
```bash
firebase deploy --only functions
```

### Step 4: Test in Flutter App
```bash
flutter run -d chrome
# or
flutter run -d android
```

---

## 📦 Required Packages

### Flutter (`pubspec.yaml`)
```yaml
dependencies:
  cloud_functions: ^6.0.0  # ✅ Use this
  firebase_core: ^4.0.0
  
  # ❌ DO NOT ADD THESE:
  # google_generative_ai: ❌ NO
  # firebase_vertexai: ❌ NO
```

### Firebase Functions (`functions/package.json`)
```json
{
  "dependencies": {
    "@google/generative-ai": "^0.2.0",  // ✅ Server-side only
    "firebase-functions": "^4.5.0",
    "firebase-admin": "^12.0.0"
  }
}
```

---

## 🎯 How It Works

### 1. User sends message in Flutter app
```dart
_messageController.text = "Book me a ride";
```

### 2. Flutter calls Firebase Function
```dart
final response = await FirebaseFunctions.instance
    .httpsCallable('aiChat')
    .call({'message': 'Book me a ride'});
```

### 3. Firebase Function calls Gemini AI
```javascript
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY); // Server-side
const model = genAI.getGenerativeModel({ model: 'gemini-pro' });
const result = await model.generateContent(message);
```

### 4. Response flows back to Flutter
```dart
final aiText = response.data['response'];
// Display: "Great! I can help you book a ride..."
```

---

## 🔒 Security Benefits

| Approach | API Key Location | Security |
|----------|------------------|----------|
| ❌ Direct API in Flutter | Client-side (exposed) | INSECURE |
| ✅ Firebase Functions | Server-side (hidden) | SECURE |

**Why Firebase Functions is better:**
- Users cannot extract API key from APK
- You control rate limits server-side
- You can log/monitor all AI requests
- You can add custom validation/filtering
- Works consistently across all platforms

---

## 🧪 Testing

### Test Firebase Function Locally
```bash
cd functions
npm run serve
```

### Test in Flutter
```dart
// Enable Firebase emulator in Flutter
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);

// Then test normally
final response = await FirebaseFunctions.instance
    .httpsCallable('aiChat')
    .call({'message': 'hello'});
```

---

## 🐛 Troubleshooting

### Error: "Function not found"
```bash
# Deploy functions
firebase deploy --only functions

# Check deployment
firebase functions:list
```

### Error: "API key not configured"
```bash
# Set API key
firebase functions:config:set gemini.api_key="YOUR_KEY"

# Verify
firebase functions:config:get
```

### Error: "Unauthenticated"
```dart
// Make sure user is logged in
final user = FirebaseAuth.instance.currentUser;
if (user == null) {
  // Show login screen
}
```

---

## 📝 Important Notes

1. **Never commit API keys to git**
   - Add `.env` to `.gitignore`
   - Use Firebase config for production

2. **Voice AI Service**
   - Voice AI is mobile-only (speech recognition)
   - Can still use Firebase Functions for AI responses
   - Just disable voice input on Web

3. **Conversation History**
   - Store in Supabase for persistence
   - Pass last 5 messages for context
   - Keep token usage under control

4. **Rate Limiting**
   - Implement in Firebase Function
   - Track requests per user
   - Prevent abuse

---

## ✅ Checklist

- [ ] Gemini API key set in Firebase config
- [ ] Firebase Functions deployed
- [ ] `cloud_functions` package added to Flutter
- [ ] Removed `google_generative_ai` from Flutter
- [ ] Removed `firebase_vertexai` from Flutter
- [ ] Tested on Web
- [ ] Tested on Android
- [ ] API key NOT in Flutter code
- [ ] `.env` file in `.gitignore`

---

## 🎉 Final Result

**Secure, scalable AI integration that:**
- ✅ Works on Web, Android, iOS
- ✅ Keeps API keys secure
- ✅ Provides natural conversations
- ✅ Integrates with Firebase Auth
- ✅ Can be monitored and controlled
- ✅ Production-ready

**This is the CORRECT way to integrate AI in Flutter apps!**
