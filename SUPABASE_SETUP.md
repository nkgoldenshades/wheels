# Supabase Integration Guide

## Why Supabase?
- PostgreSQL database (reliable, scalable)
- Real-time subscriptions (live updates)
- Edge Functions (for Razorpay webhooks)
- Row Level Security (secure data access)
- Free tier available

## Setup Steps

### 1. Create Supabase Project

1. Go to https://supabase.com/
2. Sign up and create a new project
3. Choose a region close to your users
4. Save your project credentials:
   - Project URL: `https://xxxxx.supabase.co`
   - Anon/Public Key: `eyJhbGc...`
   - Service Role Key: `eyJhbGc...` (keep secret!)

### 2. Add Supabase to Flutter

Add to `pubspec.yaml`:
```yaml
dependencies:
  supabase_flutter: ^2.5.0
```

Run:
```bash
flutter pub get
```

### 3. Database Schema

Create these tables in Supabase SQL Editor:

```sql
-- Users table
CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  phone TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  email TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Vehicles table
CREATE TABLE vehicles (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  year INTEGER,
  capabilities TEXT[] NOT NULL,
  photos TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Slots table
CREATE TABLE slots (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  vehicle_id UUID REFERENCES vehicles(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  slot_type TEXT NOT NULL,
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  capacity INTEGER NOT NULL,
  price NUMERIC NOT NULL,
  seat_layout_owner_id UUID,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Events table
CREATE TABLE events (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  location TEXT NOT NULL,
  radius_km NUMERIC NOT NULL,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  description TEXT NOT NULL,
  price NUMERIC,
  images TEXT[],
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Bookings table
CREATE TABLE bookings (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  slot_id UUID REFERENCES slots(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES users(id) ON DELETE CASCADE,
  provider_name TEXT NOT NULL,
  provider_phone TEXT NOT NULL,
  provider_email TEXT,
  provider_avatar TEXT,
  user_name TEXT NOT NULL,
  user_age INTEGER NOT NULL,
  user_gender TEXT NOT NULL,
  user_phone TEXT,
  user_email TEXT,
  seat_key TEXT,
  price NUMERIC NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  otp TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Payments table (for Razorpay escrow)
CREATE TABLE payments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  booking_id UUID REFERENCES bookings(id) ON DELETE CASCADE,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  provider_id UUID REFERENCES users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  razorpay_payment_id TEXT,
  razorpay_order_id TEXT,
  razorpay_signature TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  released_at TIMESTAMP WITH TIME ZONE,
  refunded_at TIMESTAMP WITH TIME ZONE
);

-- Seat Layouts table
CREATE TABLE seat_layouts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  owner_id UUID REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  rows INTEGER NOT NULL,
  cols INTEGER NOT NULL,
  cells JSONB NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Posts table
CREATE TABLE user_posts (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  slot_type TEXT NOT NULL,
  from_location TEXT,
  to_location TEXT,
  base_location TEXT,
  radius NUMERIC,
  start_time TIMESTAMP WITH TIME ZONE NOT NULL,
  end_time TIMESTAMP WITH TIME ZONE NOT NULL,
  budget NUMERIC NOT NULL,
  notes TEXT,
  status TEXT NOT NULL DEFAULT 'active',
  is_online BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE vehicles ENABLE ROW LEVEL SECURITY;
ALTER TABLE slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE seat_layouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_posts ENABLE ROW LEVEL SECURITY;

-- RLS Policies (basic - customize as needed)
CREATE POLICY "Users can view all users" ON users FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON users FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Anyone can view vehicles" ON vehicles FOR SELECT USING (true);
CREATE POLICY "Users can manage own vehicles" ON vehicles FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view slots" ON slots FOR SELECT USING (true);
CREATE POLICY "Users can manage own slots" ON slots FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view events" ON events FOR SELECT USING (true);
CREATE POLICY "Users can manage own events" ON events FOR ALL USING (auth.uid() = user_id);

CREATE POLICY "Users can view own bookings" ON bookings FOR SELECT USING (auth.uid() = user_id OR auth.uid() = provider_id);
CREATE POLICY "Users can create bookings" ON bookings FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Providers can update bookings" ON bookings FOR UPDATE USING (auth.uid() = provider_id);

CREATE POLICY "Users can view own payments" ON payments FOR SELECT USING (auth.uid() = user_id OR auth.uid() = provider_id);
CREATE POLICY "System can manage payments" ON payments FOR ALL USING (true); -- Adjust for webhook access

CREATE POLICY "Users can view own layouts" ON seat_layouts FOR SELECT USING (auth.uid() = owner_id);
CREATE POLICY "Users can manage own layouts" ON seat_layouts FOR ALL USING (auth.uid() = owner_id);

CREATE POLICY "Anyone can view user posts" ON user_posts FOR SELECT USING (true);
CREATE POLICY "Users can manage own posts" ON user_posts FOR ALL USING (auth.uid() = user_id);
```

### 4. Initialize Supabase in Flutter

Update `lib/main.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );
  
  // Initialize Razorpay
  RazorpayService.instance.initialize();
  
  runApp(MyApp());
}

// Access Supabase client anywhere
final supabase = Supabase.instance.client;
```

### 5. Create Supabase Repositories

Example for vehicles:

```dart
class SupabaseVehicleRepository {
  final _supabase = Supabase.instance.client;
  
  Future<List<Vehicle>> getVehicles() async {
    final response = await _supabase
        .from('vehicles')
        .select()
        .order('created_at', ascending: false);
    
    return (response as List)
        .map((json) => Vehicle.fromJson(json))
        .toList();
  }
  
  Future<Vehicle> createVehicle(Vehicle vehicle) async {
    final response = await _supabase
        .from('vehicles')
        .insert(vehicle.toJson())
        .select()
        .single();
    
    return Vehicle.fromJson(response);
  }
}
```

### 6. Razorpay Webhook (Supabase Edge Function)

Create Edge Function for webhook:

```bash
supabase functions new razorpay-webhook
```

In `supabase/functions/razorpay-webhook/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const signature = req.headers.get('x-razorpay-signature')
    const body = await req.text()
    
    // Verify webhook signature
    // ... signature verification logic
    
    const event = JSON.parse(body)
    
    // Initialize Supabase client
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )
    
    // Handle payment events
    if (event.event === 'payment.captured') {
      await supabase
        .from('payments')
        .update({ 
          status: 'held',
          razorpay_payment_id: event.payload.payment.entity.id 
        })
        .eq('razorpay_order_id', event.payload.payment.entity.order_id)
    }
    
    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
```

Deploy:
```bash
supabase functions deploy razorpay-webhook
```

### 7. Configure Razorpay Webhook

1. Go to Razorpay Dashboard → Webhooks
2. Add webhook URL: `https://your-project.supabase.co/functions/v1/razorpay-webhook`
3. Select events: `payment.captured`, `payment.failed`, `refund.processed`
4. Save webhook secret

### 8. Migration Plan

1. **Phase 1**: Set up Supabase project and database
2. **Phase 2**: Create Supabase repositories (replace local ones)
3. **Phase 3**: Implement authentication with Supabase Auth
4. **Phase 4**: Set up Edge Functions for webhooks
5. **Phase 5**: Test payment flow end-to-end
6. **Phase 6**: Deploy and go live

### 9. Benefits of This Setup

✅ Real database (data persists)
✅ Real-time updates (bookings appear instantly)
✅ Secure webhooks (Edge Functions)
✅ Scalable (handles growth)
✅ Free tier (up to 500MB database, 2GB bandwidth)

### 10. Next Steps

1. Create Supabase account
2. Run the SQL schema
3. Get your project credentials
4. I'll help you migrate the repositories
5. Set up authentication
6. Configure webhooks

Ready to start? Let me know when you have your Supabase project ready!
