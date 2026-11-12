# 🔍 Debug "Unknown User" Issue - Enhanced Logging

## 🎯 What I Added

I've added detailed debug logging to help diagnose why "Unknown User" is still showing.

### Enhanced Logging in:

1. **`lib/models/vehicle.dart`** - Logs what data is received from Supabase
2. **`lib/services/vehicle_repository.dart`** - Logs raw response and parsed vehicles
3. **`lib/services/customer_vehicle_repository.dart`** - Logs raw response
4. **`lib/services/slot_repository.dart`** - Logs vehicle lookup process

---

## 🔧 How to Debug

### Step 1: Full Restart Flutter

**CRITICAL:** Must do full restart (not hot reload)

```bash
flutter clean
flutter pub get
flutter run
```

---

### Step 2: Check Debug Logs

Look for these logs in your Flutter console:

#### A. Vehicle Loading Logs:
```
🔍 Raw Supabase response (first vehicle): {id: xxx, profile_name: John Doe, ...}
🔍 Vehicle.fromJson: id=xxx, profile_name=John Doe, ... → final=John Doe
✅ Loaded 5 vehicles from Supabase
🔍 First vehicle: id=xxx, userName=John Doe, name=Honda City
```

#### B. Slot Building Logs:
```
🔍 _buildSlotEntries: Building entries for 3 slots
🔍 _buildSlotEntries: VehicleRepository has 5 vehicles
🔍 Looking for vehicle: v123 for slot: s456
✅ Found vehicle: v123, userName=John Doe, name=Honda City
```

OR (if vehicle not found):
```
⚠️ Vehicle not found for slot s456, vehicleId=v123
⚠️ Available vehicle IDs: v111, v222, v333
```

---

## 🐛 Possible Issues and Solutions

### Issue 1: `profile_name=null` in logs

**Cause:** View not returning `profile_name` column

**Debug:**
```sql
-- Check if view has profile_name column
SELECT column_name 
FROM information_schema.columns
WHERE table_name = 'vehicles_public' 
  AND column_name = 'profile_name';

-- Check if view returns data
SELECT id, profile_name FROM vehicles_public LIMIT 1;
```

**Fix:** Recreate view with `profile_name` column

---

### Issue 2: Vehicle not found in repository

**Symptoms in logs:**
```
⚠️ Vehicle not found for slot s456, vehicleId=v123
⚠️ Available vehicle IDs: v111, v222, v333
```

**Cause:** Vehicle ID mismatch or RLS blocking

**Debug:**
```sql
-- Check if vehicle exists in vehicles table
SELECT id, vehicle_name, profile_id 
FROM vehicles 
WHERE id = 'v123';  -- Use the ID from the log

-- Check if vehicle is in vehicles_public view
SELECT id, vehicle_name, profile_name 
FROM vehicles_public 
WHERE id = 'v123';

-- Check if post references correct vehicle
SELECT id, vehicle_id, profile_id 
FROM posts 
WHERE id = 's456';  -- Use the slot ID from the log
```

**Possible causes:**
1. **RLS blocking:** Vehicle exists but RLS policy blocks access
2. **ID mismatch:** Post references wrong vehicle_id
3. **Vehicle deleted:** Vehicle was deleted but post still exists

---

### Issue 3: Vehicles loaded but userName still "Unknown User"

**Symptoms in logs:**
```
✅ Found vehicle: v123, userName=Unknown User, name=Honda City
```

**Cause:** `profile_name` is NULL in the data

**Debug:**
```sql
-- Check if profiles have full_name
SELECT 
  v.id as vehicle_id,
  v.profile_id,
  p.full_name,
  vp.profile_name
FROM vehicles v
LEFT JOIN profiles p ON v.profile_id = p.id
LEFT JOIN vehicles_public vp ON v.id = vp.id
WHERE v.id = 'v123';  -- Use the ID from the log
```

**Fix:** Update profiles with names:
```sql
UPDATE profiles 
SET full_name = 'John Doe' 
WHERE id = 'user_id_here';
```

---

### Issue 4: No vehicles loaded

**Symptoms in logs:**
```
🔍 _buildSlotEntries: VehicleRepository has 0 vehicles
```

**Cause:** Vehicles not loading from Supabase

**Debug:**
```sql
-- Check if vehicles_public view returns any data
SELECT COUNT(*) FROM vehicles_public;

-- Check RLS policies on vehicles table
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies
WHERE tablename = 'vehicles';
```

**Possible causes:**
1. **RLS too restrictive:** View returns no data due to RLS
2. **No vehicles:** No vehicles in database
3. **View broken:** View definition is wrong

---

## 📊 Diagnostic Checklist

Run through this checklist with the debug logs:

### Backend (Supabase):
- [ ] View exists: `SELECT * FROM vehicles_public LIMIT 1;`
- [ ] View has `profile_name` column
- [ ] View returns data with `profile_name` populated
- [ ] Profiles have `full_name` populated
- [ ] Posts reference correct `vehicle_id`

### Frontend (Flutter):
- [ ] Vehicles loaded: "✅ Loaded X vehicles from Supabase"
- [ ] `profile_name` has value in raw response
- [ ] `userName` has value in parsed vehicle
- [ ] Vehicle found in repository: "✅ Found vehicle"
- [ ] App fully restarted (not hot reload)

### Result:
- [ ] Common Feed shows actual names

---

## 🎯 What to Share

If still showing "Unknown User", share these logs:

1. **Vehicle loading logs:**
   ```
   🔍 Raw Supabase response (first vehicle): ...
   🔍 Vehicle.fromJson: ...
   ✅ Loaded X vehicles from Supabase
   ```

2. **Slot building logs:**
   ```
   🔍 _buildSlotEntries: Building entries for X slots
   🔍 _buildSlotEntries: VehicleRepository has X vehicles
   🔍 Looking for vehicle: ...
   ```

3. **SQL query results:**
   ```sql
   SELECT id, vehicle_name, profile_name, profile_id
   FROM vehicles_public LIMIT 5;
   ```

This will help diagnose the exact issue!

---

## 💡 Most Likely Issues

Based on the symptoms, the most likely issues are:

1. **RLS blocking vehicles** (80% probability)
   - Vehicles exist but RLS policy blocks access
   - Fix: Update RLS policies on vehicles table

2. **profile_name is NULL** (15% probability)
   - View exists but profiles don't have names
   - Fix: Update profiles with full_name

3. **View not created correctly** (5% probability)
   - View doesn't have profile_name column
   - Fix: Recreate view

The debug logs will tell us which one it is! 🔍
