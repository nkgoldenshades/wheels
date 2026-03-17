# 🚀 Quick Test Guide

## Test the Migration in 5 Minutes

### Step 1: Run the App
```bash
flutter run
```

### Step 2: Sign Up / Sign In
- Use email/password authentication
- Example: `test@example.com` / `password123`

### Step 3: Create a Vehicle
1. Go to "Add" tab
2. Select "Vehicle"
3. Fill in:
   - Name: "My Car"
   - Type: "Car"
   - Year: 2020
   - Capabilities: Select "Passenger"
4. Tap "Save"

### Step 4: Check Supabase
1. Open Supabase Dashboard: https://uklltpopjovbhplbvltr.supabase.co
2. Go to Table Editor → `vehicles`
3. You should see your vehicle with:
   - `user_id` = Your Firebase UID (text format)
   - `name` = "My Car"
   - `type` = "Car"
   - `year` = 2020

### Step 5: Create an Event
1. Go to "Add" tab
2. Select "Event"
3. Fill in:
   - Title: "Test Event"
   - Type: "Hotels"
   - Location: "New York"
   - Radius: 10 km
   - Start/End times
   - Description: "Test event"
4. Tap "Save"

### Step 6: Check Supabase
1. Go to Table Editor → `events`
2. You should see your event with:
   - `user_id` = Your Firebase UID
   - `title` = "Test Event"
   - `location` = "New York"

### Step 7: Create a Slot
1. Go to your vehicle details
2. Tap "Create Slot" (or similar button)
3. Fill in:
   - Slot Type: "Point-to-Point" or "Area Service"
   - Locations (based on type)
   - Start/End times
   - Capacity: 4
   - Price: 100
4. Tap "Save"

### Step 8: Check Supabase
1. Go to Table Editor → `slots`
2. You should see your slot with:
   - `user_id` = Your Firebase UID
   - `vehicle_id` = Your vehicle's UUID
   - `slot_type` = "from_to" or "base_radius"

### Step 9: Restart App Test
1. Close the app completely
2. Reopen the app
3. Sign in again
4. Verify:
   - Your vehicle still appears
   - Your event still appears
   - Your slot still appears

## ✅ Success Criteria

If all of the above work, your migration is successful! You now have:

- ✅ Persistent vehicle storage
- ✅ Persistent event storage
- ✅ Persistent slot storage
- ✅ Data survives app restart
- ✅ Data syncs with Supabase
- ✅ Secure with RLS policies

## 🐛 If Something Doesn't Work

### Check Debug Logs
Look for these messages:
```
🔄 Syncing Firebase user to Supabase: <uid>
🔑 Token refreshed, waiting for accessToken callback...
✅ Ready to sync to Supabase
✅ User synced to Supabase: <uid>
✅ Vehicle created in Supabase: <id>
✅ Event created in Supabase: <id>
✅ Slot created in Supabase: <id>
```

### Common Issues

**Issue**: "No user logged in"
- Make sure you're signed in before creating items

**Issue**: "Failed to create vehicle/event/slot"
- Check Supabase connection
- Verify RLS policies are correct
- Check debug logs for specific error

**Issue**: Data doesn't appear after restart
- Check that repositories are initialized in `main.dart`
- Verify `loadVehicles()`, `loadEvents()`, `loadSlots()` are called

## 📊 View Your Data in Supabase

### Supabase Dashboard
URL: https://uklltpopjovbhplbvltr.supabase.co

### Tables to Check
1. **users** - Your Firebase user profile
2. **vehicles** - Your vehicles
3. **events** - Your events
4. **slots** - Your slots
5. **user_posts** - Your user posts

### What to Look For
- `user_id` should match your Firebase UID (text format)
- All fields should have correct values
- `created_at` should show when you created the item

## 🎉 Next Steps

Once testing is complete:

1. **Test with Multiple Users**
   - Create another account
   - Verify users can only see/edit their own data
   - Verify marketplace shows all users' data

2. **Test Edge Cases**
   - Create vehicle without photos
   - Create event with images
   - Create slot with different types

3. **Test Updates**
   - Edit a vehicle
   - Edit an event
   - Edit a slot
   - Verify changes persist

4. **Test Deletions**
   - Delete a vehicle
   - Delete an event
   - Delete a slot
   - Verify they're removed from Supabase

## 🚀 Ready to Go!

Your app now has full Supabase integration for vehicles, events, and slots. All data persists forever and syncs across devices!
