# QuickOHunt - Supabase Setup Instructions

## Step 1: Create Supabase Account

1. Go to https://supabase.com/
2. Click "Start your project"
3. Sign up with GitHub or email
4. Create a new organization (free)

## Step 2: Create New Project

1. Click "New Project"
2. Fill in:
   - **Name**: quickohunt (or your choice)
   - **Database Password**: Create a strong password (save it!)
   - **Region**: Choose closest to your users (e.g., Mumbai for India)
   - **Pricing Plan**: Free
3. Click "Create new project"
4. Wait 2-3 minutes for provisioning

## Step 3: Run Database Schema

1. In your Supabase dashboard, click "SQL Editor" in the left sidebar
2. Click "New query"
3. Copy the entire content from `supabase_schema.sql`
4. Paste it into the SQL editor
5. Click "Run" (or press Ctrl+Enter)
6. You should see: "Success. No rows returned"
7. Check the "Table Editor" - you should see all tables created

## Step 4: Get Your Credentials

1. Click "Settings" (gear icon) in the left sidebar
2. Click "API" under Project Settings
3. Copy these values:

```
Project URL: https://xxxxxxxxxxxxx.supabase.co
anon/public key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

## Step 5: Add Supabase to Your Flutter App

1. Open `pubspec.yaml`
2. Add dependency:
```yaml
dependencies:
  supabase_flutter: ^2.5.0
```

3. Run in terminal:
```bash
flutter pub get
```

## Step 6: Initialize Supabase

Create a new file `lib/config/supabase_config.dart`:

```dart
class SupabaseConfig {
  static const String url = 'YOUR_PROJECT_URL_HERE';
  static const String anonKey = 'YOUR_ANON_KEY_HERE';
}
```

Update `lib/main.dart` - add at the top of `main()` function:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // Rest of your initialization code...
  runApp(MyApp());
}

// Global Supabase client
final supabase = Supabase.instance.client;
```

## Step 7: Verify Setup

Run this test query in Supabase SQL Editor:

```sql
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public';
```

You should see all these tables:
- users
- vehicles
- slots
- events
- bookings
- payments
- seat_layouts
- user_posts
- saved_passengers

## What's Next?

After setup is complete, I'll help you:

1. ✅ Migrate local repositories to Supabase
2. ✅ Implement authentication
3. ✅ Add real-time subscriptions
4. ✅ Set up Razorpay webhooks
5. ✅ Test the complete flow

## Troubleshooting

**Problem**: SQL script fails
- **Solution**: Make sure you're running it in a fresh project, or drop existing tables first

**Problem**: Can't find API keys
- **Solution**: Settings → API → Copy "Project URL" and "anon public" key

**Problem**: Flutter app can't connect
- **Solution**: Check that URL and key are correct in `supabase_config.dart`

## Files You Have

- ✅ `supabase_schema.sql` - Complete database schema (run this in Supabase)
- ✅ `SUPABASE_SETUP.md` - Detailed Supabase guide
- ✅ `RAZORPAY_INTEGRATION.md` - Payment integration guide
- ✅ `lib/services/razorpay_service.dart` - Razorpay service (ready to use)
- ✅ `lib/services/payment_repository.dart` - Payment state management

## Ready?

Once you complete these steps, let me know and I'll help you migrate your app to use Supabase!
