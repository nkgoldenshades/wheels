# Windows Flutter Build Issues - Diagnostic & Fix Guide

## Issues Identified

### 1. **Network Issue: Failed host lookup 'pub.dev'**
```
ClientException with SocketException: Failed host lookup: 'pub.dev' 
(OS Error: No such host is known, errno = 11001)
```

### 2. **Symlink Issue: Cross-drive symlink error**
```
Creating symlink from C:\Users\...\Pub\Cache\hosted\pub.dev\app_links-7.2.0\ to 
E:\quickohunt\windows\flutter\ephemeral\.plugin_symlinks\app_links failed with 
ERROR_INVALID_FUNCTION. Try moving your Flutter project to the same drive as your Flutter SDK.
```

---

## Root Causes

| Issue | Cause | Impact |
|-------|-------|--------|
| **Network (pub.dev)** | DNS resolution failure or network connectivity | `flutter pub get` fails completely |
| **Symlink (Cross-drive)** | Flutter on C:\, Project on E:\ | `flutter run -d chrome` fails |

---

## ✅ SOLUTION: Multi-Step Fix

### **Step 1: Check Network Connectivity (5 minutes)**

```cmd
REM Open cmd as Administrator and run:
ping pub.dev
ping 8.8.8.8
ipconfig /all
```

**If pub.dev fails but 8.8.8.8 works:**
- DNS issue - proceed to Step 2
- If both fail - your internet is down

**If both fail:**
- Check WiFi/Ethernet connection
- Restart router/modem
- Use mobile hotspot temporarily

---

### **Step 2: Fix DNS (if pub.dev unreachable)**

#### **Option A: Use Google DNS (Recommended)**

Windows 10/11:
1. Settings → Network & Internet → WiFi (or Ethernet)
2. Click your network → "Edit" → DNS settings
3. Set to Manual
4. Preferred DNS: `8.8.8.8`
5. Alternate DNS: `8.8.4.4`
6. Save and wait 30 seconds

Then test:
```cmd
ping pub.dev
```

#### **Option B: Flush DNS Cache**

```cmd
REM Run as Administrator
ipconfig /flushdns
ipconfig /release
ipconfig /renew
```

---

### **Step 3: Move Project to C:\ Drive (RECOMMENDED)**

**This is the permanent fix for the symlink issue.**

#### **Why?**
Flutter symlinks plugins across the same drive. Different drives (C:\ vs E:\) causes `ERROR_INVALID_FUNCTION`.

#### **How to Migrate (20 minutes)**

1. **Close all Flutter/IDE instances**

2. **Copy project to C: drive**
   ```cmd
   REM Run in PowerShell as Administrator
   Copy-Item -Recurse "E:\quickohunt" -Destination "C:\flutter_projects\quickohunt"
   ```

3. **Enter new directory**
   ```cmd
   cd C:\flutter_projects\quickohunt
   ```

4. **Clean and rebuild**
   ```cmd
   flutter clean
   flutter pub get
   ```

5. **Test (choose one)**
   ```cmd
   REM Test for Android
   flutter run -d android
   
   REM Test for Web
   flutter run -d chrome
   
   REM Test for Windows
   flutter run -d windows
   ```

---

### **Step 4: If You CANNOT Move to C:\ (Alternative)**

**Use Symlink Workaround:**

```cmd
REM Run PowerShell as Administrator
REM This creates a symlink from C:\ to your E:\ project

New-Item -ItemType SymbolicLink -Path "C:\quickohunt" -Target "E:\quickohunt"
cd C:\quickohunt
flutter pub get
```

Then always run Flutter from the symlinked C:\ path.

---

### **Step 5: Verify Fix with Pub Get**

```cmd
flutter pub get
```

**Expected output:**
```
Running "flutter pub get" in quickohunt...
Resolving dependencies... (should complete in 10-30 seconds)
Got dependencies
Process finished successfully
```

---

## 🧪 Testing the Fix

After applying the fix, test each platform:

### **Web (Chrome)**
```cmd
flutter run -d chrome
```

### **Windows**
```cmd
flutter run -d windows
```

### **Android (if available)**
```cmd
flutter run -d android
```

---

## 🚨 Troubleshooting If Still Broken

### **Still can't reach pub.dev?**
```cmd
REM Check if Flutter can see pub.dev via HTTP
curl https://pub.dev
```

If curl works but Flutter doesn't:
```cmd
REM Clear Flutter cache
flutter clean
rmdir /s /q %APPDATA%\.pub-cache
flutter pub cache repair
flutter pub get
```

### **Still getting symlink error?**
```cmd
REM Verify you're on same drive
cd .
REM Should show C:\ or at least the same drive as Flutter SDK

REM Find Flutter SDK location
flutter --version
REM Look at the first line output - note the drive letter
```

### **Port 8080/8081 already in use?**
```cmd
REM Kill process using port
netstat -ano | findstr :8080
taskkill /PID <PID> /F
```

---

## 📋 Final Checklist

- [ ] Network working (pub.dev responds to ping)
- [ ] Project on C:\ drive OR C:\ symlink created
- [ ] `flutter clean` run successfully
- [ ] `flutter pub get` completed without errors
- [ ] `flutter run -d chrome` launches app
- [ ] Credit system working in app

---

## 🎯 Quick Command Reference

```cmd
REM Complete reset and test
flutter clean
del pubspec.lock
flutter pub cache repair
flutter pub get
flutter run -d chrome

REM If on different drives, use this instead
REM (assuming project moved to C:\flutter_projects\quickohunt)
cd C:\flutter_projects\quickohunt
flutter clean
flutter pub get
flutter run -d chrome
```

---

## ⏱️ Typical Fix Time

- Network DNS fix: **5-10 minutes**
- Project migration to C:\: **15-20 minutes**
- Verification & testing: **10 minutes**

**Total: 30-40 minutes for complete fix**

---

## Still Need Help?

Check these logs:
1. `flutter doctor -v` - Full environment report
2. Run `flutter pub get` verbosely:
   ```cmd
   flutter pub get -v
   ```

This will show exactly where it's failing.
