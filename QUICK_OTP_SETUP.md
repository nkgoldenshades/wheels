# Quick OTP Setup - 3 Steps

## ⚡ Fast Track Installation

### 1️⃣ Install OTP Trigger (2 minutes)
```sql
-- Copy and paste INSTALL_OTP_TRIGGER_FINAL.sql into Supabase SQL Editor
-- Click RUN
-- ✅ Should see: 2 functions + 1 trigger created
```

### 2️⃣ Install Verification Function (1 minute)
```sql
-- Copy and paste CREATE_OTP_VERIFICATION_FUNCTION.sql into Supabase SQL Editor
-- Click RUN
-- ✅ Should see: Function created + permissions granted
```

### 3️⃣ Test It (2 minutes)
```sql
-- Copy and paste TEST_OTP_COMPLETE.sql into Supabase SQL Editor
-- Click RUN
-- ✅ Review results - all tests should pass
```

---

## 🔍 Quick Verification

### Is trigger installed?
```sql
SELECT tgname FROM pg_trigger WHERE tgname = 'booking_otp_trigger';
```
**Expected:** 1 row ✅

### Are functions installed?
```sql
SELECT proname FROM pg_proc 
WHERE proname IN ('generate_otp', 'set_booking_otp', 'verify_otp');
```
**Expected:** 3 rows ✅

---

## 🎯 What Each File Does

| File | What It Does | When to Use |
|------|--------------|-------------|
| `INSTALL_OTP_TRIGGER_FINAL.sql` | Auto-generates OTP on booking creation | **RUN FIRST** |
| `CREATE_OTP_VERIFICATION_FUNCTION.sql` | Verifies OTP with security checks | **RUN SECOND** |
| `TEST_OTP_COMPLETE.sql` | Tests everything works | **RUN THIRD** |

---

## ✅ Success Checklist

- [ ] Ran `INSTALL_OTP_TRIGGER_FINAL.sql` in Supabase
- [ ] Ran `CREATE_OTP_VERIFICATION_FUNCTION.sql` in Supabase
- [ ] Ran `TEST_OTP_COMPLETE.sql` - all tests passed
- [ ] Verified trigger exists (query above)
- [ ] Verified functions exist (query above)
- [ ] Created test booking - OTP auto-generated
- [ ] Tested OTP verification in Flutter app

---

## 🚨 Common Issues

### ❌ OTP is NULL
**Problem:** Trigger not installed  
**Solution:** Run `INSTALL_OTP_TRIGGER_FINAL.sql`

### ❌ "Function verify_otp does not exist"
**Problem:** Verification function not installed  
**Solution:** Run `CREATE_OTP_VERIFICATION_FUNCTION.sql`

### ❌ "Syntax error near $"
**Problem:** Old SQL file with single `$` delimiter  
**Solution:** Use latest files (already fixed with `$$`)

---

## 📱 Frontend is Ready!

Your Flutter app is already configured:
- ✅ `booking_repository.dart` - Sends `otp: null`, receives backend OTP
- ✅ `otp_service.dart` - Verifies OTP with backend
- ✅ Booking model includes all OTP fields

**Just install the backend SQL and you're done!** 🎉
