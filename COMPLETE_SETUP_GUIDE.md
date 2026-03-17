# Complete Supabase + Email Setup Guide

## ✅ What I've Done:

1. ✅ Added `supabase_flutter` to pubspec.yaml
2. ✅ Created `lib/config/supabase_config.dart` for credentials
3. ✅ Initialized Supabase in `main.dart`
4. ✅ Created database schema files

## 🚀 Your Action Items:

### Step 1: Install Supabase Package (2 minutes)

Run in terminal:
```bash
flutter pub get
```

### Step 2: Create Supabase Project (5 minutes)

1. Go to https://supabase.com/
2. Click "Start your project" → Sign up
3. Click "New Project"
4. Fill in:
   - Name: `quickohunt`
   - Database Password: (create strong password - SAVE IT!)
   - Region: `Mumbai` (closest to India)
5. Click "Create new project"
6. Wait 2-3 minutes for setup

### Step 3: Run Database Schema (2 minutes)

1. In Supabase dashboard, click "SQL Editor" (left sidebar)
2. Click "New query"
3. Open `supabase_schema.sql` file
4. Copy ALL content
5. Paste into SQL Editor
6. Click "Run" (or Ctrl+Enter)
7. Should see: "Success. No rows returned"
8. Click "Table Editor" - verify all tables created

### Step 4: Get Your Credentials (1 minute)

1. Click "Settings" (gear icon, left sidebar)
2. Click "API"
3. Copy these two values:

```
Project URL: https://xxxxxxxxxxxxx.supabase.co
anon public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Step 5: Add Credentials to Your App (1 minute)

1. Open `lib/config/supabase_config.dart`
2. Replace:
```dart
static const String url = 'YOUR_SUPABASE_PROJECT_URL';
static const String anonKey = 'YOUR_SUPABASE_ANON_KEY';
```

With your actual values:
```dart
static const String url = 'https://xxxxxxxxxxxxx.supabase.co';
static const String anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...';
```

### Step 6: Enable Email Auth (1 minute)

1. In Supabase dashboard, go to "Authentication" → "Providers"
2. "Email" should already be enabled ✅
3. Done! (You get 4 emails/hour for free testing)

### Step 7: Test Your App (1 minute)

Run your app:
```bash
flutter run
```

Should start without errors!

---

## 📧 Optional: Add Unlimited Emails (10 minutes)

For production, add custom SMTP:

### Option A: Resend (Recommended - 3,000 emails/month free)

1. Go to https://resend.com/
2. Sign up (free)
3. Get API key
4. In Supabase: Authentication → Settings → SMTP Settings
5. Fill in:
   - Host: `smtp.resend.com`
   - Port: `587`
   - Username: `resend`
   - Password: (your Resend API key)
   - Sender email: `noreply@yourdomain.com`
6. Save

### Option B: SendGrid (100 emails/day free)

1. Go to https://sendgrid.com/
2. Sign up
3. Create API key
4. In Supabase SMTP settings:
   - Host: `smtp.sendgrid.net`
   - Port: `587`
   - Username: `apikey`
   - Password: (your SendGrid API key)

### Option C: Mailgun (5,000 emails/month free for 3 months)

1. Go to https://mailgun.com/
2. Sign up
3. Get SMTP credentials
4. Add to Supabase SMTP settings

---

## 🎯 What's Next?

After setup is complete:

1. ✅ Test email signup/login
2. ✅ Migrate repositories to Supabase (I'll help)
3. ✅ Add real-time subscriptions
4. ✅ Set up Razorpay webhooks
5. ✅ Deploy!

---

## 🐛 Troubleshooting:

**Error: "Invalid API key"**
- Check that you copied the full anon key (it's very long!)
- Make sure no extra spaces

**Error: "Failed to connect"**
- Check your internet connection
- Verify the URL is correct (starts with https://)

**SQL script fails**
- Make sure you're in a fresh project
- Or drop existing tables first

**Email not sending**
- Check spam folder
- Remember: 4 emails/hour limit on free tier
- Add custom SMTP for unlimited

---

## 📁 Files Created:

- ✅ `lib/config/supabase_config.dart` - Your credentials go here
- ✅ `supabase_schema.sql` - Database schema (run in Supabase)
- ✅ `pubspec.yaml` - Updated with supabase_flutter
- ✅ `lib/main.dart` - Supabase initialized

---

## ✨ Summary:

1. Run `flutter pub get`
2. Create Supabase project
3. Run SQL schema
4. Copy credentials to config file
5. Test app
6. (Optional) Add custom SMTP for unlimited emails

**Total time: ~15 minutes**

Let me know when you're done and I'll help you migrate the repositories!
