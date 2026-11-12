# 🚗 VaultWheels - Complete App Architecture Explained

## 📋 Table of Contents
1. [App Overview](#app-overview)
2. [Tech Stack](#tech-stack)
3. [App Flow](#app-flow)
4. [Architecture](#architecture)
5. [Key Features](#key-features)
6. [Data Flow](#data-flow)
7. [User Journeys](#user-journeys)

---

## 🎯 App Overview

**VaultWheels** is a **peer-to-peer transport marketplace** where:
- **Providers** offer transport services (rides, parcel delivery, vehicle leasing)
- **Customers** request transport services
- Both can browse and book each other's posts

Think of it as **"Uber meets Airbnb for vehicles"** - but bidirectional!

---

## 🛠️ Tech Stack

### Frontend (Flutter)
- **Framework:** Flutter (Dart)
- **State Management:** ValueNotifier + Repository Pattern
- **UI:** Material Design 3

### Backend (Supabase)
- **Database:** PostgreSQL (Supabase)
- **Authentication:** Firebase Auth (JWT tokens)
- **Storage:** Supabase Storage (for images/videos)
- **Real-time:** Supabase Realtime (for live updates)

### Additional Services
- **Payments:** Stripe
- **Maps:** Google Maps API
- **AI:** Voice AI integration
- **Location:** Geolocator + Google Places

---

## 🔄 App Flow

### 1. App Startup Sequence

```
User Opens App
    ↓
main() function runs
    ↓
Initialize Firebase
    ↓
Initialize AuthRepository
    ↓
Show Splash Screen (2-5 seconds)
    ↓
Initialize Supabase with Firebase JWT
    ↓
Initialize all repositories in background
    ↓
Navigate to Main Screen
    ↓
Check if user is logged in
    ↓
┌─────────────────┬─────────────────┐
│   Guest Mode    │  Logged In Mode │
│   (Browse only) │  (Full access)  │
└─────────────────┴─────────────────┘
```

### 2. Main Screen Structure

```
┌──────────────────────────────────┐
│  VaultWheels    [Login/Logged in]│ ← AppBar
├──────────────────────────────────┤
│                                  │
│  Current Tab Content:            │
│  - Posts (Feed)                  │
│  - Requests (My Posts)           │
│  - AI Chat                       │
│  - Profile                       │
│                                  │
├──────────────────────────────────┤
│ Posts | Requests | AI | Profile  │ ← Bottom Nav
└──────────────────────────────────┘
```

---

## 🏗️ Architecture

### Repository Pattern

The app uses **Repository Pattern** for data management:

```
UI Layer (Screens/Widgets)
    ↓
Repository Layer (Business Logic)
    ↓
Data Sources (Supabase, Firebase, Local Storage)
```

### Key Repositories

#### 1. **AuthRepository** (`lib/services/auth_repository.dart`)
- Manages user authentication
- Firebase Auth integration
- Syncs users to Supabase
- Provides current user state

**Key Methods:**
- `signUpWithEmail()` - Create account
- `signInWithEmail()` - Login
- `logout()` - Sign out
- `syncUserToSupabase()` - Sync Firebase user to Supabase profiles table

#### 2. **SlotRepository** (`lib/services/slot_repository.dart`)
- Manages **provider posts** (services offered)
- CRUD operations for posts
- Syncs with Supabase `posts` table

**Key Methods:**
- `loadSlots()` - Load all active posts
- `addSlot()` - Create new post
- `updateSlot()` - Edit post
- `deleteSlot()` - Remove post

#### 3. **VehicleRepository** (`lib/services/vehicle_repository.dart`)
- Manages **provider vehicles** (vehicles offered for service)
- CRUD operations for vehicles
- Syncs with Supabase `vehicles` table

**Key Methods:**
- `loadVehicles()` - Load all vehicles
- `addVehicle()` - Add new vehicle
- `updateVehicle()` - Edit vehicle
- `deleteVehicle()` - Remove vehicle
- `setOnlineStatus()` - Toggle vehicle availability

#### 4. **CustomerSlotRepository** (`lib/services/customer_slot_repository.dart`)
- Manages **customer posts** (services requested)
- Separate from provider posts
- Syncs with Supabase `user_posts` table

#### 5. **CustomerVehicleRepository** (`lib/services/customer_vehicle_repository.dart`)
- Manages **customer vehicles** (vehicles they're looking for)
- Separate from provider vehicles

#### 6. **BookingRepository** (`lib/services/booking_repository.dart`)
- Manages bookings/reservations
- Handles booking lifecycle
- Syncs with Supabase `bookings` table

#### 7. **ProfileRepository** (`lib/services/profile_repository.dart`)
- Manages user profiles
- Profile photos, documents, verification
- Syncs with Supabase `profiles` table

---

## 🎨 Key Features

### 1. **Dual-Mode System**

The app has **two modes** for each user:

#### Provider Mode (Offering Services)
- Create posts offering rides/parcels/leases
- Add vehicles to fleet
- Receive booking requests
- Manage bookings

#### Customer Mode (Requesting Services)
- Create posts requesting rides/parcels/leases
- Browse available services
- Book provider posts
- Track bookings

**Same user can be both provider AND customer!**

### 2. **Service Types**

Three main service types:

#### 🚗 Ride Sharing
- Point-to-point rides (A → B)
- Range-based rides (within X km of base)
- Seat selection
- Pickup options (door-to-door, pickup point)

#### 📦 Parcel Delivery
- Package dimensions (length, width, height)
- Weight limits
- Delivery time windows
- Tracking

#### 🚙 Vehicle Leasing
- Short-term/long-term rentals
- With or without operator
- Security deposit
- Fuel policy

### 3. **Post Types**

#### From-To Posts
```
From: Chennai Central
To: Bangalore City
Time: 10:00 AM - 2:00 PM
Price: ₹500
Seats: 4
```

#### Range-Based Posts
```
Base: Mumbai CST
Radius: 10 km
Time: 9:00 AM - 6:00 PM
Price: ₹300
```

### 4. **Booking Flow**

```
User browses posts
    ↓
Clicks on post
    ↓
Views details (vehicle, provider, route)
    ↓
Clicks "Book Now"
    ↓
Selects seats (for rides)
    ↓
Confirms booking
    ↓
Payment (Stripe)
    ↓
Booking confirmed
    ↓
Provider receives notification
    ↓
Provider accepts/rejects
    ↓
If accepted: Trip starts
    ↓
Trip completes
    ↓
User leaves review
```

---

## 📊 Data Flow

### Creating a Post (Provider)

```
1. User clicks "Create Post"
    ↓
2. Selects service type (Ride/Parcel/Lease)
    ↓
3. Selects vehicle from their fleet
    ↓
4. Fills form:
   - From/To locations (with coordinates)
   - Time window
   - Price
   - Capacity
   - Terms
    ↓
5. Clicks "Create"
    ↓
6. SlotRepository.addSlot()
    ↓
7. Validates:
   - User is logged in ✓
   - Vehicle belongs to user ✓
   - All required fields filled ✓
    ↓
8. Extracts coordinates from locations
    ↓
9. Inserts to Supabase:
   INSERT INTO posts (
     id, profile_id, vehicle_id,
     from_location, from_lat, from_lng,
     to_location, to_lat, to_lng,
     start_time, end_time, price, ...
   )
    ↓
10. RLS Policy checks:
    - Is user authenticated? (Firebase JWT)
    - Does profile_id match JWT sub claim?
    ↓
11. If allowed: Post created ✓
    ↓
12. Post appears in feed immediately
    ↓
13. Other users can see and book it
```

### Browsing Posts (Guest/User)

```
1. App loads
    ↓
2. SlotRepository.loadSlots()
    ↓
3. Query Supabase:
   SELECT * FROM posts 
   WHERE is_active = true
   ORDER BY created_at DESC
    ↓
4. RLS Policy checks:
   - Public SELECT policy allows everyone
    ↓
5. Posts returned
    ↓
6. For each post:
   - Load vehicle details
   - Load provider profile
   - Calculate duration
   - Format display
    ↓
7. Build SlotEntry objects
    ↓
8. Display in feed as SlotCard widgets
    ↓
9. User can:
   - View details
   - Book (if logged in)
   - Share
   - Report
```

---

## 👤 User Journeys

### Journey 1: New User Signs Up

```
1. Opens app → Splash screen
2. Main screen loads → Shows "Login" button
3. Clicks "Login"
4. Sees login screen
5. Clicks "Sign Up"
6. Fills registration form:
   - Full name
   - Email
   - Password
7. Clicks "Sign Up"
8. AuthRepository.signUpWithEmail()
9. Creates Firebase account
10. Syncs to Supabase profiles table
11. Redirects to main screen
12. Now logged in ✓
13. Can create posts and vehicles
```

### Journey 2: Guest Browses Posts

```
1. Opens app → Splash screen
2. Main screen loads
3. Sees posts feed (guest mode)
4. Scrolls through posts
5. Clicks on a post
6. Views details:
   - Vehicle info
   - Provider profile
   - Route map
   - Price breakdown
7. Clicks "Book Now"
8. Sees "Please log in" message
9. Redirected to login screen
10. Can login or continue browsing
```

### Journey 3: Provider Creates Post

```
1. Logged in user
2. Goes to "Profile" tab
3. Clicks "My Vehicles"
4. Adds a vehicle:
   - Vehicle type (car, bike, van)
   - Name, registration
   - Photos
   - Documents (RC, insurance)
5. Vehicle created ✓
6. Goes back to main screen
7. Clicks "+" button (Create Post)
8. Selects service type: "Ride"
9. Selects vehicle from list
10. Fills form:
    - From: Chennai Central
    - To: Bangalore City
    - Start: 10:00 AM
    - End: 2:00 PM
    - Price: ₹500
    - Seats: 4
11. Clicks "Create Post"
12. Post created ✓
13. Appears in feed
14. Other users can book it
```

### Journey 4: Customer Books a Ride

```
1. Logged in user
2. Browses posts feed
3. Finds suitable ride:
   "Chennai → Bangalore, ₹500, 4 seats"
4. Clicks on post
5. Views details:
   - Vehicle: Toyota Innova
   - Provider: John Doe (4.8★)
   - Route map
   - Departure: 10:00 AM
6. Clicks "Book Now"
7. Selects seats (2 seats)
8. Reviews booking:
   - 2 seats × ₹500 = ₹1000
   - Platform fee: ₹50
   - Total: ₹1050
9. Clicks "Confirm & Pay"
10. Stripe payment screen
11. Enters card details
12. Payment successful ✓
13. Booking confirmed
14. Provider receives notification
15. Provider accepts booking
16. User receives confirmation
17. Trip details shared
18. On trip day: Track location
19. Trip completes
20. User leaves review
```

### Journey 5: Customer Requests Service

```
1. Logged in user
2. Goes to "Requests" tab
3. Clicks "Create Request"
4. Selects service type: "Parcel"
5. Fills form:
   - From: Mumbai
   - To: Pune
   - Package: 5kg, 30×20×10 cm
   - Budget: ₹200
   - Time: Tomorrow 9 AM - 6 PM
6. Clicks "Post Request"
7. Request created ✓
8. Appears in requests feed
9. Providers can see it
10. Provider accepts request
11. User receives notification
12. Negotiates details
13. Confirms booking
14. Service delivered
```

---

## 🔐 Authentication & Security

### Firebase JWT Flow

```
1. User logs in with email/password
    ↓
2. Firebase Auth creates session
    ↓
3. Firebase generates JWT token
    ↓
4. App stores JWT in memory
    ↓
5. Every Supabase request includes JWT:
   Authorization: Bearer <firebase_jwt>
    ↓
6. Supabase extracts JWT claims:
   {
     "sub": "firebase_user_id",
     "email": "user@example.com",
     "iss": "firebase_project_id"
   }
    ↓
7. RLS policies check JWT:
   - Is 'sub' claim present? → Authenticated
   - Does profile_id match 'sub'? → Authorized
    ↓
8. If checks pass: Allow operation
   If checks fail: Deny operation
```

### RLS (Row Level Security) Policies

#### Posts Table Policies

**SELECT (Browse):**
```sql
-- Everyone can view active posts
CREATE POLICY "public_view_active_posts"
ON posts FOR SELECT TO public
USING (is_active = true);
```

**INSERT (Create):**
```sql
-- Only authenticated users can create posts
-- And only for their own profile
CREATE POLICY "firebase_users_insert_own_posts"
ON posts FOR INSERT TO public
WITH CHECK (
  is_firebase_authenticated() AND
  profile_id = (JWT->>'sub')
);
```

**UPDATE/DELETE:**
```sql
-- Users can only modify their own posts
CREATE POLICY "firebase_users_update_own_posts"
ON posts FOR UPDATE TO public
USING (profile_id = (JWT->>'sub'));
```

---

## 📱 Screen Structure

### Main Screens

#### 1. **Splash Screen** (`lib/screens/auth/splash_screen.dart`)
- Shows app logo
- Initializes services
- Checks auth state
- Navigates to main screen

#### 2. **Login Screen** (`lib/screens/auth/login_screen.dart`)
- Email/password login
- "Continue as Guest" button
- Link to register screen

#### 3. **Register Screen** (`lib/screens/auth/register_screen.dart`)
- Create account form
- Profile name uniqueness check
- "Continue as Guest" button

#### 4. **Main Screen** (`lib/main.dart` - MainScreen class)
- Bottom navigation (4 tabs)
- AppBar with login status
- Tab content area

#### 5. **Posts Page** (PostsPage class)
- Feed of all active posts
- Filter by service type
- Search functionality
- Infinite scroll

#### 6. **Requests Page** (RequestsPage class)
- User's own posts (customer mode)
- Create request button
- Edit/delete requests

#### 7. **AI Chat Page** (`lib/screens/ai_chat_page.dart`)
- Voice AI assistant
- Chat interface
- Help with bookings

#### 8. **Profile Page** (ProfilePage class)
- User info
- My vehicles
- My bookings
- Documents
- Settings

#### 9. **Slot Detail Screen** (`lib/screens/slot_detail_screen.dart`)
- Post details
- Vehicle info
- Provider profile
- Route map
- Book button

#### 10. **Create Post Screen** (`lib/screens/add_flow/create_post_screen.dart`)
- Multi-step form
- Service type selection
- Vehicle selection
- Location picker
- Time picker
- Price input

---

## 🗄️ Database Schema

### Key Tables

#### **profiles**
```sql
- id (UUID, PK) - Firebase UID
- full_name (TEXT)
- email (TEXT)
- phone_number (TEXT)
- profile_photo_url (TEXT)
- business_type (ENUM: solo, business)
- created_at (TIMESTAMP)
```

#### **vehicles**
```sql
- id (UUID, PK)
- profile_id (UUID, FK → profiles)
- vehicle_type (TEXT: car, bike, van, truck)
- vehicle_name (TEXT)
- registration_number (TEXT)
- seating_capacity (INT)
- vehicle_photo_url (TEXT)
- gallery_images (TEXT[])
- is_online (BOOLEAN)
- vehicle_owner (ENUM: provider, customer)
- rc_front_url, rc_back_url (TEXT)
- insurance_document_url (TEXT)
- created_at (TIMESTAMP)
```

#### **posts**
```sql
- id (UUID, PK)
- profile_id (UUID, FK → profiles)
- vehicle_id (UUID, FK → vehicles)
- service_type (ENUM: ride, parcel, lease)
- slot_type (ENUM: from_to, from_range)
- from_location (TEXT)
- from_lat, from_lng (NUMERIC)
- to_location (TEXT)
- to_lat, to_lng (NUMERIC)
- base_location (TEXT)
- base_lat, base_lng (NUMERIC)
- radius (NUMERIC)
- start_time, end_time (TIMESTAMP)
- price (NUMERIC)
- capacity (INT)
- is_active (BOOLEAN)
- postmode (ENUM: offer, request)
- created_at (TIMESTAMP)
```

#### **bookings**
```sql
- id (UUID, PK)
- post_id (UUID, FK → posts)
- user_id (UUID, FK → profiles)
- provider_id (UUID, FK → profiles)
- status (ENUM: pending, confirmed, completed, cancelled)
- seats_booked (INT)
- total_amount (NUMERIC)
- payment_status (ENUM: pending, paid, refunded)
- from_lat, from_lng (NUMERIC)
- to_lat, to_lng (NUMERIC)
- created_at (TIMESTAMP)
```

---

## 🔄 State Management

### ValueNotifier Pattern

The app uses **ValueNotifier** for reactive state:

```dart
// Repository holds state
final ValueNotifier<List<Slot>> _slots = ValueNotifier([]);

// Expose as listenable
ValueListenable<List<Slot>> get slotsListenable => _slots;

// UI listens to changes
ValueListenableBuilder(
  valueListenable: SlotRepository.instance.slotsListenable,
  builder: (context, slots, child) {
    return ListView.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) {
        return SlotCard(slot: slots[index]);
      },
    );
  },
)

// Update state triggers rebuild
_slots.value = [..._slots.value, newSlot];
```

---

## 🎯 Key Concepts

### 1. **Guest-First Design**
- App works without login
- Guests can browse all posts
- Login only required for actions (create, book)

### 2. **Bidirectional Marketplace**
- Users can be both providers and customers
- Separate repositories for each mode
- Same UI, different data sources

### 3. **Real-time Updates**
- Supabase Realtime for live data
- Bookings update instantly
- Location tracking in real-time

### 4. **Offline Support**
- Local storage caching
- Works without internet (limited)
- Syncs when online

### 5. **Multi-tenancy**
- Each user has isolated data
- RLS ensures data security
- No user can access others' data

---

## 🚀 Performance Optimizations

### 1. **Lazy Loading**
- Repositories initialize on-demand
- Background initialization for non-critical services
- Timeout protection (10 seconds max)

### 2. **Caching**
- Local storage for offline access
- In-memory cache for frequently accessed data
- Supabase as source of truth

### 3. **Pagination**
- Load posts in batches
- Infinite scroll
- Reduces initial load time

### 4. **Image Optimization**
- Compress before upload
- Lazy load images
- Thumbnail generation

---

## 🐛 Error Handling

### 1. **Network Errors**
```dart
try {
  await supabase.from('posts').select();
} catch (e) {
  debugPrint('Failed to load from Supabase: $e');
  // Fallback to local storage
  await _loadFromLocal();
}
```

### 2. **Auth Errors**
```dart
try {
  await AuthRepository.instance.signIn(...);
} catch (e) {
  // Show user-friendly error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Login failed: $e')),
  );
}
```

### 3. **Validation Errors**
```dart
if (email.isEmpty || password.isEmpty) {
  throw 'Please fill all fields';
}
if (password.length < 6) {
  throw 'Password must be at least 6 characters';
}
```

---

## 📈 Future Enhancements

### Planned Features
1. **Real-time Chat** - Between users and providers
2. **Push Notifications** - Booking updates, messages
3. **Advanced Filters** - Price range, vehicle type, ratings
4. **Route Optimization** - Best routes, traffic-aware
5. **Subscription Plans** - Premium features for providers
6. **Analytics Dashboard** - Earnings, trips, ratings
7. **Multi-language Support** - Localization
8. **Dark Mode** - Theme switching

---

## 🎓 Summary

**VaultWheels** is a comprehensive transport marketplace that:

✅ Connects providers and customers  
✅ Supports multiple service types (ride, parcel, lease)  
✅ Works in guest mode (browse without login)  
✅ Uses Firebase Auth + Supabase for security  
✅ Implements RLS for data protection  
✅ Extracts coordinates for mapping  
✅ Handles payments via Stripe  
✅ Provides real-time updates  
✅ Supports offline mode  
✅ Scales with repository pattern  

The app is built with **Flutter** for cross-platform support, **Supabase** for backend, and **Firebase** for authentication, creating a robust, scalable, and secure transport marketplace.

---

**Need more details on any specific part? Let me know!** 🚀
