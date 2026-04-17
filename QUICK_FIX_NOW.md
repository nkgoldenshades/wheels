# 🚀 Quick Fix - Do This Now!

## ⚡ 2-Step Fix for "Unknown User"

### Step 1: Run SQL (30 seconds)

Open Supabase SQL Editor and paste this:

```sql
DROP POLICY IF EXISTS "vehicles_select" ON vehicles;

CREATE POLICY "vehicles_select_public" ON vehicles
  FOR SELECT
  TO anon, authenticated
  USING (
    profile_id = (auth.jwt() ->> 'sub'::text)
    OR
    is_active = true
  );
```

Click **Run**.

**Verify it worked:**
```sql
SELECT COUNT(*) FROM vehicles_public;
```

Should return a number > 0 (not 0).

---

### Step 2: Restart Flutter (1 minute)

```bash
flutter clean
flutter pub get
flutter run
```

**CRITICAL:** Must be full restart, not hot reload!

---

## ✅ Check It Worked

Look for these logs in Flutter console:

```
✅ Loaded 5 vehicles from Supabase  ← Should be > 0
✅ Found vehicle: v123, userName=John Doe, name=Honda City
```

**NOT:**
```
✅ Loaded 0 vehicles from Supabase  ❌
⚠️ Vehicle not found  ❌
```

---

## 🎯 Result

Common Feed should now show:
```
┌─────────────────────┐
│ John Doe           │  ✅ Real name
│ Honda City         │  ✅ Real vehicle
└─────────────────────┘
```

Instead of:
```
┌─────────────────────┐
│ Unknown User       │  ❌
│ Unknown Vehicle    │
└─────────────────────┘
```

---

## 🐛 If Still Not Working

Share these with me:

1. **SQL result:** `SELECT COUNT(*) FROM vehicles_public;`
2. **Flutter logs:** The `✅ Loaded X vehicles` line
3. **Screenshot:** The "Unknown User" issue

---

## 📁 Full Documentation

- **`COMPLETE_FIX_UNKNOWN_USER.md`** - Detailed explanation
- **`FIX_VEHICLES_PUBLIC_RLS.sql`** - Full SQL script with verification

---

**That's it! Run the SQL, restart Flutter, and it should work!** 🚀
