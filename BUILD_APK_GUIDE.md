# 📱 Build Android APK Guide

## ✅ Current Status
- ✅ Web version built (`build/web/`)
- 📋 Android APK needed for R2 upload

---

## 🚀 Build Android APK

### **Step 1: Build Release APK**

Open your terminal and run:

```bash
# Navigate to project
cd e:\quickohunt

# Build release APK
flutter build apk --release

# This creates: build/app/outputs/flutter-apk/app-release.apk
```

**Build time:** ~2-5 minutes

---

### **Step 2: Build Optimized APK (Smaller Size)**

For even smaller file size, use split APKs:

```bash
# Build split APKs by ABI (architecture)
flutter build apk --release --split-per-abi

# This creates 3 APKs:
# - app-armeabi-v7a-release.apk (older 32-bit devices)
# - app-arm64-v8a-release.apk (newer 64-bit devices) ← Most common
# - app-x86_64-release.apk (emulators/rare devices)
```

**Benefit:** Each APK is ~30-40% smaller than universal APK

---

### **Step 3: Find Your APK**

After building, your APK will be at:

```
e:\quickohunt\build\app\outputs\flutter-apk\app-release.apk
```

Or if you used split:
```
e:\quickohunt\build\app\outputs\flutter-apk\
├─ app-armeabi-v7a-release.apk (32-bit ARM)
├─ app-arm64-v8a-release.apk (64-bit ARM - MOST USERS)
└─ app-x86_64-release.apk (Intel)
```

---

## 📦 What to Upload to R2

### **Option A: Single Universal APK** (Easier)
Upload: `app-release.apk`
- ✅ Works on all devices
- ✅ Single download link
- ❌ Larger file size (~50-80 MB)

### **Option B: Split APKs** (Better)
Upload all 3 APKs:
- ✅ Smaller downloads
- ✅ Faster installs
- ❌ Users need to pick correct one

**Recommendation:** Use **Option A** (universal APK) for simplicity!

---

## 🎯 After Building

### **1. Rename APK for Branding**
```bash
# Rename to include version
copy build\app\outputs\flutter-apk\app-release.apk quickohunt-v1.0.apk
```

### **2. Upload to Cloudflare R2**
- Go to your R2 bucket: `quickohunt`
- Drag and drop `quickohunt-v1.0.apk`
- Or click "select from computer"

### **3. Enable Public Access**
- Click "Settings" tab in bucket
- Enable "Public Access"
- Add custom domain: `downloads.quickohunt.com`

### **4. Share Download Link**
```
https://downloads.quickohunt.com/quickohunt-v1.0.apk
```

---

## ⚙️ Build Options Explained

### **Standard Build:**
```bash
flutter build apk --release
```
- **Size:** ~60-80 MB
- **Compatibility:** All devices
- **Use:** Quick testing, single link

### **Optimized Build:**
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info
```
- **Size:** ~20-30 MB per APK
- **Security:** Code obfuscation
- **Debug:** Can deobfuscate crash reports
- **Use:** Production release

### **Super Optimized:**
```bash
flutter build apk --release --split-per-abi --obfuscate --split-debug-info=./debug-info --no-tree-shake-icons
```
- **Size:** Even smaller
- **Optimization:** Removes unused icons
- **Use:** When app is finalized

---

## 🔐 Signing (Important!)

Your APK needs to be signed for distribution:

### **Check if Already Signed:**
Look for: `android/key.properties`

If it exists, you're good! If not:

### **Create Signing Key:**

```bash
# Create keystore
keytool -genkey -v -keystore e:\quickohunt\android\quickohunt-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias quickohunt

# Follow prompts:
Enter keystore password: [create password]
Re-enter: [repeat password]
What is your first and last name? [Your name]
What is the name of your organizational unit? QuickOhunt
What is the name of your organization? QuickOhunt
What is the name of your City or Locality? [Your city]
What is the name of your State or Province? [Your state]
What is the two-letter country code? IN
```

### **Configure Signing:**

Create `android/key.properties`:
```properties
storePassword=your_password_here
keyPassword=your_password_here
keyAlias=quickohunt
storeFile=e:\\quickohunt\\android\\quickohunt-key.jks
```

Update `android/app/build.gradle`:
```gradle
android {
    ...
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled true
            shrinkResources true
        }
    }
}
```

Now rebuild!

---

## 📊 Build Size Comparison

| Build Type | Size | Devices | Best For |
|------------|------|---------|----------|
| Universal APK | 60-80 MB | All | Testing, simple distribution |
| Split APKs | 20-30 MB each | Specific arch | Production, Play Store |
| App Bundle | Auto-optimized | All | Play Store only |

---

## ✅ Quick Start Command

**For immediate testing:**
```bash
cd e:\quickohunt
flutter build apk --release
copy build\app\outputs\flutter-apk\app-release.apk quickohunt-v1.0.apk
```

**Then upload `quickohunt-v1.0.apk` to your R2 bucket!**

---

## 🆘 Common Build Errors

### **Error: Android SDK not found**
```bash
# Set ANDROID_HOME
setx ANDROID_HOME "C:\Users\YourName\AppData\Local\Android\Sdk"
```

### **Error: Gradle build failed**
```bash
# Clean and retry
cd android
gradlew clean
cd ..
flutter clean
flutter pub get
flutter build apk --release
```

### **Error: Out of memory**
Add to `android/gradle.properties`:
```properties
org.gradle.jvmargs=-Xmx4096m
```

---

## 🎉 Success Checklist

After building, you should have:
- [ ] APK file exists
- [ ] File size is reasonable (20-80 MB)
- [ ] APK installs on Android device
- [ ] App launches without crashes
- [ ] All features work
- [ ] Ready to upload to R2!

---

## 🚀 Next: Upload to R2

Once APK is built:
1. Open Cloudflare R2 bucket: `quickohunt`
2. Upload `quickohunt-v1.0.apk`
3. Enable public access
4. Connect domain: `downloads.quickohunt.com`
5. Share link: `https://downloads.quickohunt.com/quickohunt-v1.0.apk`

**You're ready to distribute! 🎉**
