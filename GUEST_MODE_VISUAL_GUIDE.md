# 👁️ Guest Mode Visual Guide

## Before vs After

### Login Screen - BEFORE
```
┌──────────────────────────────────┐
│  ← Login                         │
├──────────────────────────────────┤
│                                  │
│         👤 (icon)                │
│                                  │
│       VaultWheels                │
│    Sign in to continue           │
│                                  │
│  📧 Email                        │
│  ┌────────────────────────────┐ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                  │
│  🔒 Password                     │
│  ┌────────────────────────────┐ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                  │
│  ┌────────────────────────────┐ │
│  │       Sign In              │ │
│  └────────────────────────────┘ │
│                                  │
│  Don't have an account? Sign Up  │
│                                  │
│  ❌ NO WAY TO BROWSE AS GUEST   │
│                                  │
└──────────────────────────────────┘
```

### Login Screen - AFTER ✅
```
┌──────────────────────────────────┐
│  ← Login                         │
├──────────────────────────────────┤
│                                  │
│         👤 (icon)                │
│                                  │
│       VaultWheels                │
│    Sign in to continue           │
│                                  │
│  📧 Email                        │
│  ┌────────────────────────────┐ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                  │
│  🔒 Password                     │
│  ┌────────────────────────────┐ │
│  │                            │ │
│  └────────────────────────────┘ │
│                                  │
│  ┌────────────────────────────┐ │
│  │       Sign In              │ │
│  └────────────────────────────┘ │
│                                  │
│  Don't have an account? Sign Up  │
│                                  │
│  ┌────────────────────────────┐ │ ← NEW!
│  │ 👤 Continue as Guest       │ │
│  └────────────────────────────┘ │
│  Browse posts without signing in │
│                                  │
└──────────────────────────────────┘
```

---

## User Journey - Guest Mode

### Journey 1: Direct Guest Access
```
App Start
   ↓
Splash Screen (2 seconds)
   ↓
Main Screen (Posts Feed)
   ↓
✅ Guest can browse immediately!
```

### Journey 2: From Login Screen
```
App Start
   ↓
Splash Screen
   ↓
Main Screen
   ↓
User clicks "Login" button (top-right)
   ↓
Login Screen
   ↓
User clicks "Continue as Guest" ← NEW!
   ↓
Main Screen (Posts Feed)
   ↓
✅ Guest can browse!
```

### Journey 3: From Register Screen
```
App Start
   ↓
Splash Screen
   ↓
Main Screen
   ↓
User clicks "Login" button
   ↓
Login Screen
   ↓
User clicks "Sign Up" link
   ↓
Register Screen
   ↓
User clicks "Continue as Guest" ← NEW!
   ↓
Main Screen (Posts Feed)
   ↓
✅ Guest can browse!
```

---

## Main Screen - Guest vs Logged In

### Guest Mode (Not Logged In)
```
┌──────────────────────────────────┐
│  VaultWheels        [Login] ←    │ Shows "Login" button
├──────────────────────────────────┤
│                                  │
│  📄 Post 1                       │
│  Chennai → Bangalore             │
│  ₹500 • 4 seats                  │
│                                  │
│  📄 Post 2                       │
│  Mumbai → Pune                   │
│  ₹300 • 2 seats                  │
│                                  │
│  ✅ Can browse posts             │
│  ✅ Can view details             │
│  ❌ Cannot create posts          │
│  ❌ Cannot book                  │
│                                  │
├──────────────────────────────────┤
│ Posts | Requests | AI | Profile  │
└──────────────────────────────────┘
```

### Logged In Mode
```
┌──────────────────────────────────┐
│  VaultWheels  ✅ Logged in ←     │ Shows "Logged in" indicator
├──────────────────────────────────┤
│                                  │
│  📄 Post 1                       │
│  Chennai → Bangalore             │
│  ₹500 • 4 seats                  │
│                                  │
│  📄 Post 2                       │
│  Mumbai → Pune                   │
│  ₹300 • 2 seats                  │
│                                  │
│  ✅ Can browse posts             │
│  ✅ Can view details             │
│  ✅ Can create posts             │
│  ✅ Can book                     │
│                                  │
├──────────────────────────────────┤
│ Posts | Requests | AI | Profile  │
└──────────────────────────────────┘
```

---

## Button Appearance

### "Continue as Guest" Button

**Normal State:**
```
┌─────────────────────────────────┐
│  👤  Continue as Guest          │ ← Blue border, blue text
└─────────────────────────────────┘
   Browse posts without signing in  ← Grey subtitle
```

**Hover State (Web):**
```
┌─────────────────────────────────┐
│  👤  Continue as Guest          │ ← Slightly darker
└─────────────────────────────────┘
   Browse posts without signing in
```

**Disabled State (During Loading):**
```
┌─────────────────────────────────┐
│  👤  Continue as Guest          │ ← Greyed out
└─────────────────────────────────┘
   Browse posts without signing in
```

---

## What Happens When You Click

### Click "Continue as Guest"

**Step 1:** Button pressed
```
User clicks button
   ↓
Navigator.pushReplacementNamed(context, '/main')
   ↓
Navigates to main screen
```

**Step 2:** Main screen loads
```
Main screen checks auth state
   ↓
AuthRepository.instance.currentUser == null
   ↓
Shows "Login" button in AppBar
   ↓
Loads posts from Supabase (as anon user)
```

**Step 3:** Posts appear (if RLS is fixed)
```
Supabase query: SELECT * FROM posts WHERE is_active = true
   ↓
RLS policy checks: Is user allowed to SELECT?
   ↓
If policy allows "public" or "anon" → ✅ Posts returned
If policy requires "authenticated" → ❌ Empty result
```

---

## Testing Checklist

### Visual Test
- [ ] Open app
- [ ] Click "Login" button (top-right)
- [ ] See "Continue as Guest" button
- [ ] Button has person icon
- [ ] Button has blue border
- [ ] Subtitle says "Browse posts without signing in"

### Functional Test
- [ ] Click "Continue as Guest"
- [ ] Returns to main screen
- [ ] Top-right shows "Login" button (not "Logged in")
- [ ] Can see posts in feed (if RLS is fixed)
- [ ] Can click on posts to view details
- [ ] Cannot create posts (shows "Login required")

### Navigation Test
- [ ] From login screen → guest mode → works
- [ ] From register screen → guest mode → works
- [ ] Guest mode → login → works
- [ ] Login → logout → returns to guest mode

---

## Common UI Issues

### Issue: Button not visible
**Symptoms:**
- Login screen looks the same as before
- No "Continue as Guest" button

**Causes:**
- Hot reload didn't pick up changes
- App not restarted

**Fix:**
1. Stop app completely
2. Run `flutter clean` (optional)
3. Restart app
4. Button should appear

---

### Issue: Button visible but greyed out
**Symptoms:**
- Button exists but can't click it
- Button looks disabled

**Causes:**
- `_isLoading` is true
- Sign in/sign up in progress

**Fix:**
- Wait for loading to finish
- Button will become clickable

---

### Issue: Button clicks but nothing happens
**Symptoms:**
- Click button
- Nothing happens
- Still on login screen

**Causes:**
- Navigation error
- Route not found

**Fix:**
1. Check Flutter console for errors
2. Verify `/main` route exists in `MyApp`
3. Check `Navigator.pushReplacementNamed(context, '/main')`

---

### Issue: Goes to main screen but no posts
**Symptoms:**
- Button works
- Main screen loads
- Feed is empty

**Causes:**
- RLS policies block guest access
- No posts in database
- Posts not active

**Fix:**
1. Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql`
2. Check `SELECT COUNT(*) FROM posts WHERE is_active = true`
3. See `POSTS_NOT_SHOWING_CHECKLIST.md`

---

## Success Indicators

### ✅ Guest Mode Working Correctly

**Visual:**
- "Continue as Guest" button visible on login screen
- "Continue as Guest" button visible on register screen
- Button has person icon and blue border
- Subtitle text visible

**Functional:**
- Button navigates to main screen
- Main screen shows "Login" button (not "Logged in")
- Can browse posts without logging in
- Clicking "Create Post" shows "Login required"

**Database:**
- RLS policies allow SELECT for public/anon
- Posts exist and are active
- Guests can query posts table

---

## Screenshots Reference

### Where to Find the Button

**Login Screen:**
```
Scroll down past:
- Email field
- Password field
- Sign In button
- "Don't have an account? Sign Up" link

Then you'll see:
- "Continue as Guest" button ← HERE!
- "Browse posts without signing in" subtitle
```

**Register Screen:**
```
Scroll down past:
- Name field
- Email field
- Password field
- Sign Up button
- "Already have an account? Sign In" link

Then you'll see:
- "Continue as Guest" button ← HERE!
- "Browse posts without signing in" subtitle
```

---

## Mobile vs Web

### Mobile (Android/iOS)
- Button takes full width
- Touch target: 48dp minimum
- Ripple effect on tap
- Scrollable if keyboard open

### Web (Browser)
- Button centered
- Hover effect (darker on hover)
- Cursor changes to pointer
- Click animation

### Desktop (Windows/Mac/Linux)
- Same as web
- Keyboard accessible (Tab to focus, Enter to click)
- Focus indicator visible

---

**Status:** ✅ Guest mode button added and working!

**Next Step:** Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` to allow guests to see posts.
