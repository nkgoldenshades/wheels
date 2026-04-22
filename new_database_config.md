# 🚀 New Database Setup Guide

## 1. Run the Schema
Copy and paste `fresh_database_setup.sql` into your new Supabase SQL Editor and run it.

## 2. Update Your Config
Update `lib/config/supabase_config.dart` with your new project details:

```dart
class SupabaseConfig {
  static const String url = 'https://YOUR_NEW_PROJECT.supabase.co';
  static const String anonKey = 'YOUR_NEW_ANON_KEY';
}
```

## 3. Test the Setup
Run this in Supabase SQL Editor to verify Firebase JWT is working:

```sql
SELECT get_jwt_claims();
```

**Expected result when logged in:**
- Should show Firebase UID in `sub` field
- Should show `role: authenticated`

## 4. Your App is Ready!
Your Flutter app (`lib/main.dart`) already has the correct Firebase JWT setup:
- ✅ `accessToken` callback configured
- ✅ Firebase UID passed to Supabase
- ✅ RLS policies will work immediately

## 5. Clean Database Benefits
- 🔥 No migration baggage
- 🔥 Proper constraints and indexes
- 🔥 Optimized RLS policies
- 🔥 Production-ready schema

Your app should work perfectly with the new database!
