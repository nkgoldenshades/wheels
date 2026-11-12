# 🤖 Setup Gemini AI API Key

## Why This Changed

We removed `firebase_ai` package because it was causing the web error. Now using `google_generative_ai` directly, which is more stable and works on all platforms.

---

## ✅ Get Your Gemini API Key (2 minutes)

### Step 1: Go to Google AI Studio
Visit: https://aistudio.google.com/app/apikey

### Step 2: Create API Key
1. Click "Create API Key"
2. Select your Google Cloud project (or create new one)
3. Copy the API key

### Step 3: Add to Your Code

You have 2 options:

#### Option A: Quick Test (Hardcode - NOT for production)
```dart
// In lib/screens/ai_chat_page.dart (line ~42)
const apiKey = 'YOUR_ACTUAL_API_KEY_HERE';

// In lib/services/voice_ai_service.dart (line ~105)
const apiKey = 'YOUR_ACTUAL_API_KEY_HERE';
```

#### Option B: Environment Variable (Recommended for production)

1. Create `.env` file in project root:
```env
GEMINI_API_KEY=your_actual_api_key_here
```

2. Add to `.gitignore`:
```
.env
```

3. Install flutter_dotenv:
```yaml
# pubspec.yaml
dependencies:
  flutter_dotenv: ^5.1.0
```

4. Load in main.dart:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}
```

5. Use in code:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiKey = dotenv.env['GEMINI_API_KEY']!;
```

---

## 🔧 Files That Need API Key

### 1. lib/screens/ai_chat_page.dart
```dart
// Line ~42
const apiKey = 'YOUR_GEMINI_API_KEY'; // Replace this
```

### 2. lib/services/voice_ai_service.dart
```dart
// Line ~105
const apiKey = 'YOUR_GEMINI_API_KEY'; // Replace this
```

---

## 🧪 Test It Works

### Test 1: AI Chat
1. Run app: `flutter run -d chrome`
2. Navigate to AI Chat page
3. Send a message
4. Should get response from Gemini

### Test 2: Voice AI
1. Enable microphone permission
2. Tap voice button
3. Speak a question
4. Should hear AI response

---

## 🚨 Common Issues

### Issue 1: "API key not valid"
**Solution:** 
- Check you copied the full API key
- Make sure no extra spaces
- Verify API key is enabled in Google Cloud Console

### Issue 2: "Quota exceeded"
**Solution:**
- Free tier has limits
- Check usage: https://aistudio.google.com/app/apikey
- Upgrade to paid tier if needed

### Issue 3: "Model not found"
**Solution:**
- We're using `gemini-2.0-flash-exp`
- If not available, try `gemini-1.5-flash`
- Check available models: https://ai.google.dev/models/gemini

---

## 💰 Pricing (as of 2024)

### Free Tier:
- 15 requests per minute
- 1 million tokens per day
- Perfect for development

### Paid Tier:
- $0.00025 per 1K characters input
- $0.00075 per 1K characters output
- Very affordable for production

More info: https://ai.google.dev/pricing

---

## 🔒 Security Best Practices

### ❌ DON'T:
- Commit API keys to Git
- Share API keys publicly
- Use same key for dev and production
- Hardcode in production apps

### ✅ DO:
- Use environment variables
- Add `.env` to `.gitignore`
- Rotate keys regularly
- Use different keys per environment
- Monitor usage in Google Cloud Console

---

## 📚 Alternative: Use Backend Proxy (Most Secure)

Instead of putting API key in Flutter app, create a backend:

### Option 1: Cloud Function
```javascript
// Firebase Cloud Function
exports.chatWithAI = functions.https.onCall(async (data, context) => {
  const apiKey = functions.config().gemini.key;
  // Call Gemini API from backend
  // Return response to Flutter
});
```

### Option 2: Express Server
```javascript
// Node.js backend
app.post('/api/chat', async (req, res) => {
  const apiKey = process.env.GEMINI_API_KEY;
  // Call Gemini API
  // Return response
});
```

Then in Flutter:
```dart
// Call your backend instead of Gemini directly
final response = await http.post(
  Uri.parse('https://your-backend.com/api/chat'),
  body: {'message': userMessage},
);
```

---

## ✅ Quick Setup Checklist

- [ ] Get API key from https://aistudio.google.com/app/apikey
- [ ] Replace `YOUR_GEMINI_API_KEY` in `ai_chat_page.dart`
- [ ] Replace `YOUR_GEMINI_API_KEY` in `voice_ai_service.dart`
- [ ] Test AI chat works
- [ ] Test voice AI works
- [ ] (Optional) Move to environment variable
- [ ] (Optional) Set up backend proxy for production

---

## 🎉 You're Done!

Once you add your API key, the AI features will work perfectly. The Firebase web error is completely fixed!

**Time required:** 2 minutes to get key + 1 minute to add to code = 3 minutes total ⏱️
