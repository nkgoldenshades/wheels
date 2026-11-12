# ⚡ Quick Fix: Vehicle Deletion Error

## 🎯 Problem
```
❌ Error: column bookings.slot_id does not exist
```

## ✅ Solution (2 minutes)

### 1️⃣ Open Supabase SQL Editor
- Go to Supabase Dashboard → **SQL Editor** → **New Query**

### 2️⃣ Run This Script
- Open file: `FIND_AND_FIX_SLOT_ID.sql`
- Copy all content
- Paste into SQL Editor
- Click **Run**

### 3️⃣ Look for Success Message
```
🎉 SUCCESS! All slot_id references have been fixed!
🎉 You can now delete vehicles without errors!
```

### 4️⃣ Test in App
- Try deleting a vehicle
- Should work now! ✅

---

## 🔍 What It Does
- Finds all `slot_id` references in database
- Replaces them with `post_id`
- Updates RLS policies, foreign keys, and indexes

## 📊 Before vs After

| Component | Before | After |
|-----------|--------|-------|
| Flutter code | `post_id` ✅ | `post_id` ✅ |
| Database table | `post_id` ✅ | `post_id` ✅ |
| RLS policies | `slot_id` ❌ | `post_id` ✅ |
| Foreign keys | `slot_id` ❌ | `post_id` ✅ |

---

## 💡 Why This Happened
The database had old RLS policies from when the column was called `slot_id`. When you delete a vehicle, these policies run automatically and try to access the non-existent column.

---

## 🆘 Still Not Working?
Send me the output from the SQL Editor - I'll help you debug it!
