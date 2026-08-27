# Rebranding to VerveStride AI

## 🎯 Goal
Rebrand all AI features from generic "AI" or "Gemini" references to **"VerveStride AI"** - creating a white-labeled AI assistant experience.

---

## 📋 Files to Update

### **1. AI Chat Screen** (`lib/screens/ai_chat_page.dart`)

**Changes:**
```dart
// AppBar Title
- title: Text('AI Chat')
+ title: Text('VerveStride AI')

// System Instruction
- systemInstruction: Content.system('''You are QuickOHunt AI Assistant...''')
+ systemInstruction: Content.system('''You are VerveStride AI, VaultWheels' intelligent assistant...''')

// Debug prints
- debugPrint('🚀 Initializing Firebase Gemini API...');
+ debugPrint('🚀 Initializing VerveStride AI...');

// Error messages
- "Sorry, I couldn't process your message..."
+ "Sorry, VerveStride AI couldn't process your message..."

// Input placeholder
- hintText: 'Type your message...'
+ hintText: 'Ask VerveStride AI...'
```

---

### **2. Voice AI Service** (`lib/services/voice_ai_service.dart`)

**Changes:**
```dart
// System instruction
- systemInstruction: Content.system('''You are a helpful AI assistant for QuickOHunt...''')
+ systemInstruction: Content.system('''You are VerveStride AI, VaultWheels' voice assistant...''')

// Debug logs
- debugPrint('🚀 Voice AI: Starting Firebase Gemini API initialization...');
+ debugPrint('🚀 VerveStride AI: Starting voice assistant initialization...');
```

---

### **3. AI Chat Page (Redesigned)** (`lib/screens/ai_chat_page_redesigned.dart`)

**Changes:**
```dart
// System instruction
- systemInstruction: Content.system('''You are QuickOHunt AI Assistant...''')
+ systemInstruction: Content.system('''You are VerveStride AI...''')

// Title
- AppBar title: 'AI Chat'
+ AppBar title: 'VerveStride AI'
```

---

### **4. Main App** (`lib/main.dart`)

Check for any AI-related navigation labels or menu items:
```dart
// Navigation labels
- 'AI Chat'
+ 'VerveStride AI'
```

---

### **5. Terms & Conditions** (`lib/screens/legal/terms_of_service_screen.dart`)

Add AI disclosure section:
```dart
_buildSection(
  'AI Technology Disclosure',
  '''VerveStride AI is VaultWheels' branded AI assistant, powered by Google's Gemini technology.

  • VerveStride AI helps with booking, disputes, and general assistance
  • Conversations are processed using Google's Gemini AI models
  • AI responses are for assistance only, not legal advice
  • Users are responsible for verifying AI-provided information
  
  By using VerveStride AI, you agree to:
  • AI processing of your messages and conversation context
  • Temporary storage of conversation history for context
  • Usage-based credit deduction for AI features''',
),
```

---

### **6. Credit Repository** (`lib/services/credit_repository.dart`)

Update comments:
```dart
// Comments mentioning "Gemini"
- // Gemini pricing: $0.30 per 1M input tokens
+ // VerveStride AI pricing (based on Gemini API): $0.30 per 1M input tokens
```

---

### **7. UI Text Updates**

**Error Messages:**
```dart
- "AI initialization failed"
+ "VerveStride AI initialization failed"

- "No AI response received"
+ "VerveStride AI did not respond"

- "AI service unavailable"
+ "VerveStride AI is currently unavailable"
```

**Success Messages:**
```dart
- "AI is ready"
+ "VerveStride AI is ready"
```

**Loading States:**
```dart
- "AI is thinking..."
+ "VerveStride AI is thinking..."
```

---

## 🎨 Branding Guidelines

### **Voice & Tone**
VerveStride AI should:
- Be helpful and friendly
- Use VaultWheels context (rides, vehicles, bookings)
- Never mention "Gemini" or "Google AI" to end users
- Refer to itself as "VerveStride AI" or simply "I"

### **System Prompt Template**
```dart
systemInstruction: Content.system('''
You are VerveStride AI, VaultWheels' intelligent assistant.

Your role:
• Help users with ride booking, vehicle sharing, and parcel delivery
• Assist with dispute resolution between community members
• Answer questions about the VaultWheels platform
• Provide friendly, helpful, and accurate responses

Platform context:
• VaultWheels is a peer-to-peer community platform
• Users help each other with rides, vehicles, and deliveries
• You facilitate communication and provide information
• You are NOT a legal advisor or decision maker

Response style:
• Be concise but helpful
• Use community-friendly language
• Focus on VaultWheels features and policies
• Suggest contacting support for complex issues
'''),
```

---

## 🚀 Implementation Checklist

- [ ] Update `ai_chat_page.dart` - AppBar title & system prompt
- [ ] Update `voice_ai_service.dart` - System prompt & debug logs
- [ ] Update `ai_chat_page_redesigned.dart` - Title & prompts
- [ ] Update `main.dart` - Navigation labels
- [ ] Add AI disclosure to Terms & Conditions
- [ ] Update `credit_repository.dart` - Comments
- [ ] Search & replace all user-facing "AI" → "VerveStride AI"
- [ ] Search & replace all "Gemini API" → "VerveStride AI" (user-facing only)
- [ ] Test all AI features after rebranding
- [ ] Update app screenshots with new branding

---

## 🔍 Search & Replace Commands

**For user-facing text only (be careful!):**

```bash
# Find all "AI Chat" in UI
grep -r "AI Chat" lib/screens/ lib/widgets/

# Find all system instructions
grep -r "systemInstruction" lib/

# Find all "Gemini" in UI strings
grep -r "Gemini" lib/screens/ lib/widgets/
```

---

## ⚠️ What NOT to Change

**Keep technical references intact:**
- Import statements: `import 'package:firebase_ai/firebase_ai.dart';`
- Variable names: `_model = FirebaseAI.googleAI().generativeModel(...)`
- Debug logs mentioning "Gemini" (internal logs are fine)
- Code comments explaining underlying technology
- Configuration files

**Only change user-facing text that users actually see!**

---

## 📝 Example Before/After

### **Before:**
```dart
AppBar(
  title: Text('AI Chat'),
),
TextField(
  hintText: 'Type your message...',
),
systemInstruction: Content.system('You are QuickOHunt AI Assistant...'),
```

### **After:**
```dart
AppBar(
  title: Text('VerveStride AI'),
),
TextField(
  hintText: 'Ask VerveStride AI...',
),
systemInstruction: Content.system('You are VerveStride AI, VaultWheels\' intelligent assistant...'),
```

---

## ✅ Benefits of Rebranding

1. **Professional identity** - Own branded AI experience
2. **User trust** - Consistent VaultWheels branding
3. **Differentiation** - Not just "another Gemini app"
4. **White-label ready** - Can license to other platforms
5. **Marketing advantage** - "Powered by VerveStride AI"

---

**Ready to implement? I can update all the files systematically!**
