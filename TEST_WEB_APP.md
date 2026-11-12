# 🧪 Test Your Web App - Step by Step

## Pre-Test Checklist

- [ ] Stop any running Flutter processes (Ctrl+C in terminal)
- [ ] Close all Chrome browser windows
- [ ] Clear browser cache or use Incognito mode

## Test 1: Basic Launch ✅

### Step 1: Run the App
```bash
flutter run -d chrome --web-renderer html
```

Or use the helper script:
```bash
# Windows
run_web.bat

# Linux/Mac
./run_web.sh
```

### Expected Output in Terminal:
```
✓ Built build/web/main.dart.js
Launching lib/main.dart on Chrome in debug mode...
Building application for the web...
```

### Expected in Browser:
- ✅ App loads and shows splash screen
- ✅ No red error screens
- ✅ Console shows normal Flutter logs (not CanvasKit errors)

### ⚠️ Warnings You Can Ignore:
```
Failed to load font Roboto from fonts.gstatic.com
```
This is expected and safe - the app uses system fonts instead.

---

## Test 2: Payment Popups ✅

Since you just fixed the payment popup dialogs, let's test them:

### Test Stripe Payment (International)
1. Navigate to a slot booking
2. Select a slot outside India
3. Click "Pay & Confirm"
4. **Expected**: Professional popup dialog appears with:
   - ✅ Payment gateway name (Stripe)
   - ✅ Instructions for web redirect
   - ✅ "Got it" button

### Test Razorpay Payment (India)
1. Navigate to a slot booking
2. Select a slot in India
3. Click "Pay & Confirm"
4. **Expected**: Professional popup dialog appears with:
   - ✅ Payment gateway name (Razorpay)
   - ✅ Instructions for web redirect
   - ✅ "Got it" button

### Test Payment Success
After completing payment (in test mode):
- **Expected**: Success popup dialog with:
  - ✅ Green checkmark icon
  - ✅ OTP code displayed prominently
  - ✅ Booking ID
  - ✅ "View My Bookings" button

---

## Test 3: Core Features ✅

### Authentication
- [ ] Login works
- [ ] Signup works
- [ ] Phone OTP works
- [ ] Logout works

### Map Features
- [ ] Map loads correctly
- [ ] Markers appear
- [ ] Location picker works
- [ ] Geocoding works

### Booking Flow
- [ ] Can view available slots
- [ ] Can select seats (if applicable)
- [ ] Booking form works
- [ ] Payment dialog appears
- [ ] Booking confirmation works

### User Posts
- [ ] Can create user posts
- [ ] Can view user posts
- [ ] Can accept requests
- [ ] Payment flow works

---

## Test 4: Browser Console Check 🔍

### Open DevTools
Press `F12` or `Ctrl+Shift+I` (Windows) / `Cmd+Option+I` (Mac)

### Check Console Tab

#### ✅ Good Signs:
```
Flutter Web Bootstrap: Initializing
Flutter Web Bootstrap: Initialized
```

#### ⚠️ Warnings You Can Ignore:
```
Failed to load font Roboto from fonts.gstatic.com
```

#### ❌ Bad Signs (Should NOT See):
```
Failed to load CanvasKit
Error loading module
Uncaught TypeError
```

If you see bad signs, check `WEB_NETWORK_FIX.md` for troubleshooting.

---

## Test 5: Hot Reload 🔥

### Test Hot Reload Works
1. With app running, open `lib/main.dart`
2. Change something visible (e.g., app title)
3. Save the file
4. In terminal, press `r` (lowercase)

**Expected**: Changes appear in browser without full reload

### Test Hot Restart
1. In terminal, press `R` (uppercase)

**Expected**: App fully restarts

---

## Test 6: Performance Check ⚡

### Check Load Time
- [ ] Initial load < 5 seconds (debug mode)
- [ ] Initial load < 2 seconds (release mode)

### Check Responsiveness
- [ ] UI responds immediately to clicks
- [ ] Scrolling is smooth
- [ ] No lag when typing

### Check Memory
In DevTools → Performance tab:
- [ ] Memory usage stable (not constantly increasing)
- [ ] No memory leaks after navigation

---

## Test 7: Different Screen Sizes 📱

### Test Responsive Design
In Chrome DevTools (F12):
1. Click device toolbar icon (Ctrl+Shift+M)
2. Test these sizes:
   - [ ] Mobile (375x667) - iPhone SE
   - [ ] Tablet (768x1024) - iPad
   - [ ] Desktop (1920x1080) - Full HD

**Expected**: Layout adapts properly to each size

---

## Test 8: Build for Production 🏗️

### Create Production Build
```bash
flutter build web --web-renderer html --release
```

### Expected Output:
```
✓ Built build/web/
```

### Test Production Build Locally
```bash
# Install a simple HTTP server (if not already installed)
# Python 3
python -m http.server 8000 --directory build/web

# Or Node.js
npx http-server build/web -p 8000
```

Then open: `http://localhost:8000`

**Expected**:
- ✅ App loads faster than debug mode
- ✅ All features work
- ✅ No console errors

---

## Troubleshooting Common Issues

### Issue: App won't load
**Solution**:
```bash
flutter clean
flutter pub get
flutter run -d chrome --web-renderer html
```

### Issue: "Waiting for connection"
**Solution**:
1. Close ALL Chrome windows
2. Kill any Chrome processes
3. Try again

### Issue: Changes not appearing
**Solution**:
1. Clear browser cache (Ctrl+Shift+Delete)
2. Or use Incognito mode (Ctrl+Shift+N)
3. Hard refresh (Ctrl+F5)

### Issue: Port already in use
**Solution**:
```bash
flutter run -d chrome --web-renderer html --web-port=8081
```

### Issue: Font warnings persist
**Solution**: These are safe to ignore! The app works fine with system fonts.

---

## Success Criteria ✅

Your web app is working correctly if:

- ✅ App loads without CanvasKit errors
- ✅ All core features work (auth, booking, payments)
- ✅ Payment popups appear correctly
- ✅ Hot reload works
- ✅ Production build succeeds
- ✅ No critical errors in console
- ⚠️ Font warnings (safe to ignore)

---

## Report Issues

If you encounter issues not covered here:

1. **Check browser console** (F12) for specific errors
2. **Check terminal output** for Flutter errors
3. **Review** `WEB_NETWORK_FIX.md` for detailed troubleshooting
4. **Try** `flutter clean && flutter pub get`

---

## Quick Commands Reference

```bash
# Run development
flutter run -d chrome --web-renderer html

# Hot reload
Press 'r' in terminal

# Hot restart
Press 'R' in terminal

# Quit
Press 'q' in terminal

# Build production
flutter build web --web-renderer html --release

# Clean build
flutter clean && flutter pub get
```

---

## Next Steps After Testing

1. ✅ If all tests pass → Deploy to production
2. ⚠️ If some tests fail → Check troubleshooting section
3. 📝 Document any custom configurations needed
4. 🚀 Share with team/users

Happy testing! 🎉
