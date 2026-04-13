# Secure Guest Access Implementation

## Problem
Guest users couldn't see posts because RLS policies blocked access to the profiles table.

## Solution
Created a **public_profiles view** that exposes only safe, public information (name and avatar) while keeping sensitive data private.

## Why This Approach is Better

### ❌ Bad Approach (What we avoided):
```sql
-- This exposes ALL profile data to guests
CREATE POLICY "Allow public read" ON profiles
FOR SELECT TO public USING (true);
```
**Problems:**
- Exposes phone numbers
- Exposes email addresses
- Exposes documents
- Exposes wallet balance
- Exposes AI credits
- Security risk!

### ✅ Good Approach (What we implemented):
```sql
-- Create view with ONLY public info
CREATE VIEW public_profiles AS
SELECT id, full_name, profile_photo_url as avatar_url
FROM profiles;
```
**Benefits:**
- Only exposes name and avatar
- Sensitive data stays private
- Guests can see provider names
- Secure by design

## Implementation

### Step 1: Database Changes (SQL)

Run `COMPLETE_GUEST_ACCESS_FIX.sql` in Supabase:

```sql
-- 1. Create public view
CREATE OR REPLACE VIEW public_profiles AS
SELECT 
    id,
    full_name,
    profile_photo_url as avatar_url
FROM profiles;

-- 2. Grant access to view
GRANT SELECT ON public_profiles TO anon;
GRANT SELECT ON public_profiles TO authenticated;

-- 3. Allow public read on posts
CREATE POLICY "Allow public read access to active posts"
ON posts FOR SELECT TO public
USING (is_active = true);

-- 4. Allow public read on vehicles
CREATE POLICY "Allow public read access to online vehicles"
ON vehicles FOR SELECT TO public
USING (is_online = true);

-- 5. KEEP profiles table PRIVATE
CREATE POLICY "Users can view their own profile"
ON profiles FOR SELECT TO authenticated
USING (id = (auth.jwt() ->> 'sub'));
```

### Step 2: Code Changes

#### Updated: `lib/services/slot_repository.dart`
```dart
// OLD (direct profiles table access)
.select('''
  *,
  profiles!posts_profile_id_fkey (
    full_name
  )
''')

// NEW (secure view access)
.select('''
  *,
  public_profiles!posts_profile_id_fkey (
    full_name,
    avatar_url
  )
''')
```

#### Updated: `lib/models/slot.dart`
```dart
// Extract from view with fallback
String? providerName;
if (json['public_profiles'] != null && json['public_profiles'] is Map) {
  providerName = json['public_profiles']['full_name'];
} else if (json['profiles'] != null && json['profiles'] is Map) {
  // Fallback for old queries
  providerName = json['profiles']['full_name'];
}
```

## Security Model

### What Guests Can See:
✅ **Posts** - Active posts (is_active = true)  
✅ **Vehicles** - Online vehicles (is_online = true)  
✅ **Provider Names** - Via public_profiles view  
✅ **Provider Avatars** - Via public_profiles view  

### What Guests CANNOT See:
❌ **Phone Numbers** - Stays in profiles table  
❌ **Email Addresses** - Stays in profiles table  
❌ **Documents** - Stays in profiles table  
❌ **Wallet Balance** - Stays in profiles table  
❌ **AI Credits** - Stays in profiles table  
❌ **Bookings** - Only customer/provider can see  
❌ **AI Conversations** - Only owner can see  

### What Logged-In Users Can See:
✅ Everything guests can see  
✅ Their own profile (full data)  
✅ Their own bookings  
✅ Their own AI conversations  
✅ Contact info AFTER booking (phone numbers)  

## Data Flow

### Guest Browsing Posts:
```
Guest opens app
  ↓
Loads posts from Supabase
  ↓
Query: SELECT * FROM posts 
       JOIN public_profiles ON posts.profile_id = public_profiles.id
       WHERE is_active = true
  ↓
RLS checks: "Allow public read access to active posts"
  ↓
✅ Returns posts with provider names
  ↓
Guest sees posts in feed
```

### Guest Trying to See Full Profile:
```
Guest tries: SELECT * FROM profiles
  ↓
RLS checks: "Users can view their own profile"
  ↓
Guest is not authenticated
  ↓
❌ BLOCKED - Returns empty
  ↓
Sensitive data protected
```

### Logged-In User Booking:
```
User books a ride
  ↓
Booking created with customer_id and provider_id
  ↓
Both parties can now see each other's contact info
  ↓
Phone numbers revealed for coordination
```

## Testing

### Test 1: Guest Can See Posts
```sql
-- Run as anonymous user in Supabase SQL Editor
SELECT id, service_type, price
FROM posts
WHERE is_active = true
LIMIT 5;
```
**Expected:** Returns posts ✅

### Test 2: Guest Can See Provider Names
```sql
-- Run as anonymous user
SELECT p.id, p.service_type, pp.full_name
FROM posts p
JOIN public_profiles pp ON p.profile_id = pp.id
WHERE p.is_active = true
LIMIT 5;
```
**Expected:** Returns posts with names ✅

### Test 3: Guest CANNOT See Full Profiles
```sql
-- Run as anonymous user
SELECT id, full_name, phone_number, email
FROM profiles
LIMIT 5;
```
**Expected:** Returns empty or error ❌ (correct!)

### Test 4: In App (Guest Mode)
1. Open app without login
2. Go to Posts tab
3. Should see posts with provider names ✅
4. Tap on post → See details ✅
5. Try to book → Login prompt ✅

### Test 5: In App (Logged-In)
1. Login to account
2. Go to Posts tab
3. Should see same posts as guest ✅
4. Can create posts ✅
5. Can book rides ✅
6. Can see own bookings ✅

## Troubleshooting

### Issue: "relation public_profiles does not exist"
**Cause:** View not created yet  
**Fix:** Run `CREATE_PUBLIC_PROFILES_VIEW.sql`

### Issue: "permission denied for view public_profiles"
**Cause:** Permissions not granted  
**Fix:** Run `GRANT SELECT ON public_profiles TO anon;`

### Issue: Still can't see posts as guest
**Cause:** RLS policy not created  
**Fix:** Run `COMPLETE_GUEST_ACCESS_FIX.sql`

### Issue: App shows "Unknown User" for providers
**Cause:** Code still using old `profiles` table  
**Fix:** Update to use `public_profiles` view (already done)

## Migration Checklist

- [ ] Run `COMPLETE_GUEST_ACCESS_FIX.sql` in Supabase
- [ ] Verify view created: `SELECT * FROM public_profiles LIMIT 5;`
- [ ] Verify policies created: Check pg_policies table
- [ ] Update app code (already done)
- [ ] Test as guest user
- [ ] Test as logged-in user
- [ ] Verify sensitive data is protected
- [ ] Deploy to production

## Benefits

### Security:
- ✅ Sensitive data stays private
- ✅ Only public info exposed
- ✅ Principle of least privilege
- ✅ Defense in depth

### User Experience:
- ✅ Guests can browse freely
- ✅ See provider names
- ✅ See provider avatars
- ✅ Soft login prompts
- ✅ No forced registration

### Maintainability:
- ✅ Clear separation of public/private data
- ✅ Easy to add more public fields
- ✅ Single source of truth (view)
- ✅ No code duplication

## Future Enhancements

### Phase 2:
- [ ] Add provider rating to view
- [ ] Add provider verification badge
- [ ] Add provider join date
- [ ] Cache view for performance

### Phase 3:
- [ ] Materialized view for faster queries
- [ ] Add indexes on view
- [ ] Add provider stats (total trips, etc.)
- [ ] Add provider bio/description

## Summary

The secure guest access is now implemented using:
1. **public_profiles view** - Exposes only safe data
2. **RLS policies** - Controls who can see what
3. **App code updates** - Uses view instead of table

Guests can now browse posts and see provider names while sensitive data remains protected. This is the industry-standard approach for public/private data separation.

## Files Created/Modified

### SQL Files:
- `CREATE_PUBLIC_PROFILES_VIEW.sql` - Creates the view
- `COMPLETE_GUEST_ACCESS_FIX.sql` - Complete setup
- `QUICK_FIX_GUEST_ACCESS.sql` - Quick fix (deprecated)

### Code Files:
- `lib/services/slot_repository.dart` - Uses public_profiles view
- `lib/models/slot.dart` - Handles view data

### Documentation:
- `SECURE_GUEST_ACCESS_IMPLEMENTATION.md` - This file
- `GUEST_ACCESS_TROUBLESHOOTING.md` - Debug guide
