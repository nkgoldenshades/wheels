# Fix "unsupported operation: _Namespace" Error

## The Error
```
Failed to pick image: unsupported operation: _Namespace
```

## Cause
The `camera` package is not properly installed or initialized.

## Solution

### Step 1: Stop the app
Press `Ctrl+C` in terminal or stop from IDE

### Step 2: Clean and get dependencies
```bash
flutter clean
flutter pub get
```

### Step 3: Restart the app
```bash
flutter run
```

### Step 4: If still not working, check camera permissions

#### Android
Make sure `android/app/src/main/AndroidManifest.xml` has:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add these BEFORE <application> tag -->
    <uses-permission android:name="android.permission.CAMERA"/>
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    
    <uses-feature android:name="android.hardware.camera" android:required="false"/>
    <uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
    
    <application ...>
        ...
    </application>
</manifest>
```

#### iOS
Make sure `ios/Runner/Info.plist` has:

```xml
<dict>
    <!-- Add these keys -->
    <key>NSCameraUsageDescription</key>
    <string>We need camera access to verify your vehicle photos</string>
    
    <key>NSMicrophoneUsageDescription</key>
    <string>We need microphone access for video verification</string>
    
    <!-- Other keys... -->
</dict>
```

### Step 5: Test on REAL device
**Important**: Camera doesn't work on emulator!

```bash
# Connect phone via USB
flutter run
```

## Quick Test

After fixing, test the flow:
1. Open app
2. Go to Add Vehicle
3. Scroll down to "Profile Image (DP)"
4. Click "Add" button
5. Choose "Take Live Photo"
6. Camera should open ✅

## Alternative: Use Gallery Only (Temporary)

If you want to test without camera for now, you can temporarily disable the live camera option:

In `add_vehicle_screen.dart`, change the bottom sheet to only show gallery:

```dart
final source = await showModalBottomSheet<String>(
  context: context,
  builder: (context) => SafeArea(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Comment out camera option temporarily
        // ListTile(
        //   leading: const Icon(Icons.camera_alt, color: Colors.blue),
        //   title: const Text('Take Live Photo'),
        //   subtitle: const Text('Recommended - Prevents fake images'),
        //   onTap: () => Navigator.pop(context, 'camera'),
        // ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Choose from Gallery'),
          onTap: () => Navigator.pop(context, 'gallery'),
        ),
        const SizedBox(height: 8),
      ],
    ),
  ),
);
```

## Still Not Working?

Check console for detailed error:
```bash
flutter run --verbose
```

Look for camera-related errors and share them for more specific help.
