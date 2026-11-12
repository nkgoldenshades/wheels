# Firebase Setup Guide for QuickOHunt

## ✅ What I've Done:

1. ✅ Added Firebase packages to pubspec.yaml
2. ✅ Initialized Firebase in main.dart
3. ✅ Ready for FlutterFire CLI setup

## 🚀 Step-by-Step Setup:

### Step 1: Install FlutterFire CLI (5 minutes)

Run these commands in terminal:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli
```

### Step 2: Create Firebase Project (3 minutes)

1. Go to https://console.firebase.google.com/
2. Click "Add project"
3. Enter project name: `quickohunt`
4. Disable Google Analytics (optional, can enable later)
5. Click "Create project"
6. Wait for setup to complete

### Step 3: Configure Flutter App with Firebase (2 minutes)

Run in your project directory:

```bash
flutterfire configure
```

This will:
- Ask you to select your Firebase project (choose `quickohunt`)
- Ask which platforms to configure (select all: android, ios, web, windows)
- Automatically create `firebase_options.dart`
- Configure all platforms

### Step 4: Enable Authentication (2 minutes)

1. In Firebase Console, go to "Authentication"
2. Click "Get started"
3. Click "Sign-in method" tab
4. Enable "Email/Password"
   - Toggle it ON
   - Click "Save"
5. (Optional) Enable "Google" sign-in:
   - Toggle it ON
   - Enter support email
   - Click "Save"

### Step 5: Create Firestore Database (3 minutes)

1. In Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Select "Start in production mode" (we'll add rules later)
4. Choose location: `asia-south1` (Mumbai - closest to India)
5. Click "Enable"

### Step 6: Set Up Firestore Security Rules (2 minutes)

1. In Firestore, click "Rules" tab
2. Replace with these rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isSignedIn() {
      return request.auth != null;
    }
    
    // Helper function to check if user owns the document
    function isOwner(userId) {
      return isSignedIn() && request.auth.uid == userId;
    }
    
    // Users collection
    match /users/{userId} {
      allow read: if true; // Anyone can read user profiles
      allow write: if isOwner(userId); // Only owner can update
    }
    
    // Vehicles collection
    match /vehicles/{vehicleId} {
      allow read: if true; // Anyone can view vehicles
      allow create: if isSignedIn();
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Slots collection
    match /slots/{slotId} {
      allow read: if true; // Anyone can view slots
      allow create: if isSignedIn();
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Events collection
    match /events/{eventId} {
      allow read: if true; // Anyone can view events
      allow create: if isSignedIn();
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Bookings collection
    match /bookings/{bookingId} {
      allow read: if isSignedIn() && 
        (request.auth.uid == resource.data.userId || 
         request.auth.uid == resource.data.providerId);
      allow create: if isSignedIn();
      allow update: if isSignedIn() && 
        (request.auth.uid == resource.data.userId || 
         request.auth.uid == resource.data.providerId);
    }
    
    // Payments collection
    match /payments/{paymentId} {
      allow read: if isSignedIn() && 
        (request.auth.uid == resource.data.userId || 
         request.auth.uid == resource.data.providerId);
      allow create: if isSignedIn();
      allow update: if isSignedIn(); // For webhook updates
    }
    
    // User Posts collection
    match /userPosts/{postId} {
      allow read: if true; // Anyone can view posts
      allow create: if isSignedIn();
      allow update, delete: if isOwner(resource.data.userId);
    }
    
    // Seat Layouts collection
    match /seatLayouts/{layoutId} {
      allow read: if isSignedIn();
      allow create: if isSignedIn();
      allow update, delete: if isOwner(resource.data.ownerId);
    }
    
    // Saved Passengers collection
    match /savedPassengers/{passengerId} {
      allow read, write: if isOwner(resource.data.userId);
    }
  }
}
```

3. Click "Publish"

### Step 7: Install Dependencies (1 minute)

Run in terminal:

```bash
flutter pub get
```

### Step 8: Test Your App (1 minute)

Run your app:

```bash
flutter run
```

Should start without errors!

---

## 📊 Firestore Collections Structure

Your app will use these collections:

```
firestore/
├── users/
│   └── {userId}/
├── vehicles/
│   └── {vehicleId}/
├── slots/
│   └── {slotId}/
├── events/
│   └── {eventId}/
├── bookings/
│   └── {bookingId}/
├── payments/
│   └── {paymentId}/
├── userPosts/
│   └── {postId}/
├── seatLayouts/
│   └── {layoutId}/
└── savedPassengers/
    └── {passengerId}/
```

---

## 🎯 What's Next?

After setup is complete:

1. ✅ Test email signup/login (unlimited free!)
2. ✅ Migrate repositories to Firestore (I'll help)
3. ✅ Add real-time listeners
4. ✅ Set up Razorpay webhooks (Cloud Functions)
5. ✅ Deploy!

---

## 💰 Firebase Pricing (Free Tier):

- ✅ **Authentication**: Unlimited users, unlimited emails
- ✅ **Firestore**: 50,000 reads/day, 20,000 writes/day
- ✅ **Storage**: 5GB
- ✅ **Hosting**: 10GB/month

This is enough for development and early users!

---

## 🐛 Troubleshooting:

**Error: "FlutterFire CLI not found"**
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

**Error: "Firebase project not found"**
- Make sure you ran `firebase login`
- Run `flutterfire configure` again

**Error: "Platform not configured"**
- Run `flutterfire configure` and select all platforms

**Firestore permission denied**
- Check security rules are published
- Make sure user is signed in

---

## 📁 Files Created:

After running `flutterfire configure`, you'll have:
- ✅ `lib/firebase_options.dart` (auto-generated)
- ✅ `android/app/google-services.json` (auto-generated)
- ✅ `ios/Runner/GoogleService-Info.plist` (auto-generated)

---

## ✨ Summary:

1. Install Firebase CLI and FlutterFire CLI
2. Create Firebase project
3. Run `flutterfire configure`
4. Enable Authentication (Email/Password)
5. Create Firestore database
6. Set up security rules
7. Run `flutter pub get`
8. Test app

**Total time: ~20 minutes**

Let me know when you're done and I'll help you migrate the repositories to Firestore!
