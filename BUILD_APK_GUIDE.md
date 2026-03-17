# Build ARM64 APK Guide

## 🎯 Build ARM64 APK for Android

### Quick Command

```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

This creates an optimized ARM64 APK for modern Android devices.

---

## 📋 Step-by-Step Instructions

### Step 1: Clean Build
```bash
flutter clean
flutter pub get
```

### Step 2: Build ARM64 APK
```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

### Step 3: Find Your APK
The APK will be located at:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🎨 Build Options

### Option 1: ARM64 Only (Recommended)
**Smallest size, works on most modern phones**
```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```
- Output: `app-arm64-v8a-release.apk`
- Size: ~40-60 MB
- Devices: Modern Android phones (2016+)

### Option 2: Universal APK
**Larger size, works on all devices**
```bash
flutter build apk
```
- Output: `app-release.apk`
- Size: ~80-120 MB
- Devices: All Android devices

### Option 3: Multiple ABIs
**Creates separate APKs for each architecture**
```bash
flutter build apk --split-per-abi
```
- Output: 
  - `app-armeabi-v7a-release.apk` (32-bit ARM)
  - `app-arm64-v8a-release.apk` (64-bit ARM)
  - `app-x86_64-release.apk` (64-bit Intel)
- Size: ~40-60 MB each
- Devices: Choose the right one for your device

---

## 📱 Device Compatibility

### ARM64 (arm64-v8a)
- ✅ Most modern Android phones (2016+)
- ✅ Samsung Galaxy S7 and newer
- ✅ Google Pixel all models
- ✅ OnePlus 3 and newer
- ✅ Xiaomi Redmi Note 4 and newer
- ✅ Your Redmi K20 Pro ✓

### ARM32 (armeabi-v7a)
- Older Android phones (2011-2016)
- Budget devices

### x86_64
- Android emulators
- Some tablets

---

## 🚀 Build for Release

### Step 1: Update Version
Edit `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Change to 1.0.1+2, 1.0.2+3, etc.
```

### Step 2: Generate Signing Key (First Time Only)
```bash
keytool -genkey -v -keystore ~/quickohunt-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias quickohunt
```

Enter details:
- Password: [your-password]
- Name: [your-name]
- Organization: Quickohunt
- City: [your-city]
- State: [your-state]
- Country: IN

### Step 3: Configure Signing
Create `android/key.properties`:
```properties
storePassword=[your-password]
keyPassword=[your-password]
keyAlias=quickohunt
storeFile=C:/Users/[your-username]/quickohunt-key.jks
```

Update `android/app/build.gradle`:
```gradle
// Add before android block
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            // ... existing config
        }
    }
}
```

### Step 4: Build Signed APK
```bash
flutter build apk --target-platform android-arm64 --split-per-abi --release
```

---

## 📦 APK Size Optimization

### Current Size Breakdown
```
Base app: ~20 MB
Flutter framework: ~10 MB
ML Kit models: ~5 MB
Dependencies: ~10 MB
Assets: ~5 MB
Total: ~50 MB (ARM64)
```

### Reduce Size

**1. Enable Obfuscation**
```bash
flutter build apk --obfuscate --split-debug-info=./debug-info --target-platform android-arm64 --split-per-abi
```

**2. Remove Unused Resources**
Add to `android/app/build.gradle`:
```gradle
android {
    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
        }
    }
}
```

**3. Compress Images**
- Use WebP format instead of PNG
- Compress images to 80% quality

---

## 🧪 Test Your APK

### Install on Device
```bash
# Via USB
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Or copy to phone and install manually
```

### Test Checklist
- [ ] App launches successfully
- [ ] Profile photo upload works
- [ ] Liveness detection works
- [ ] Document verification works
- [ ] Face matching works
- [ ] Vehicle creation works
- [ ] Booking flow works
- [ ] No crashes

---

## 📤 Distribution Options

### Option 1: Direct Share
1. Copy APK to Google Drive / Dropbox
2. Share link with users
3. Users download and install

### Option 2: Google Play Store
1. Create Google Play Console account ($25 one-time)
2. Upload APK
3. Fill in store listing
4. Submit for review
5. Publish

### Option 3: Internal Testing
1. Upload to Google Play Console
2. Create internal testing track
3. Add testers by email
4. Share testing link

---

## 🔧 Troubleshooting

### Error: "Gradle build failed"
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --target-platform android-arm64 --split-per-abi
```

### Error: "Signing key not found"
- Check `key.properties` path is correct
- Use forward slashes: `C:/Users/...` not `C:\Users\...`
- Ensure keystore file exists

### Error: "Out of memory"
Add to `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m
```

### APK Too Large
- Use `--split-per-abi` flag
- Enable obfuscation
- Remove unused dependencies

---

## 📊 Build Variants

### Debug Build (for testing)
```bash
flutter build apk --debug --target-platform android-arm64
```
- Larger size
- Includes debug symbols
- Hot reload enabled

### Profile Build (for performance testing)
```bash
flutter build apk --profile --target-platform android-arm64
```
- Medium size
- Performance profiling enabled
- No debug symbols

### Release Build (for production)
```bash
flutter build apk --release --target-platform android-arm64 --split-per-abi
```
- Smallest size
- Optimized performance
- No debug info

---

## 🎉 Quick Reference

### Build ARM64 APK
```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

### Build with Obfuscation
```bash
flutter build apk --obfuscate --split-debug-info=./debug-info --target-platform android-arm64 --split-per-abi
```

### Install on Device
```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

### Check APK Size
```bash
ls -lh build/app/outputs/flutter-apk/
```

---

## 📱 Your Device (Redmi K20 Pro)

**Architecture:** ARM64 (arm64-v8a)
**Android Version:** 10+
**Recommended APK:** `app-arm64-v8a-release.apk`

Build command for your device:
```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

APK location:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## 🚀 Ready to Build!

Run this command now:
```bash
flutter build apk --target-platform android-arm64 --split-per-abi
```

Wait 2-5 minutes for the build to complete, then find your APK at:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Install and test! 🎉
