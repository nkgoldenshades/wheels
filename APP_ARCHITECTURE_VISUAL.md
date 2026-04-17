# 🎨 VaultWheels - Visual Architecture

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        USER DEVICE                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              FLUTTER APP (Dart)                       │  │
│  │                                                       │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │           UI LAYER (Screens)                 │   │  │
│  │  │  - Splash, Login, Register                   │   │  │
│  │  │  - Main (Posts, Requests, AI, Profile)       │   │  │
│  │  │  - Slot Detail, Create Post, Bookings        │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                      ↕                                │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │      REPOSITORY LAYER (Business Logic)       │   │  │
│  │  │  - AuthRepository                            │   │  │
│  │  │  - SlotRepository (Provider Posts)           │   │  │
│  │  │  - VehicleRepository (Provider Vehicles)     │   │  │
│  │  │  - CustomerSlotRepository (Customer Posts)   │   │  │
│  │  │  - BookingRepository                         │   │  │
│  │  │  - ProfileRepository                         │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                      ↕                                │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │         DATA SOURCES                         │   │  │
│  │  │  - Supabase Client (API calls)               │   │  │
│  │  │  - Firebase Auth (JWT tokens)                │   │  │
│  │  │  - Local Storage (SharedPreferences)         │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            ↕
                    INTERNET (HTTPS)
                            ↕
┌─────────────────────────────────────────────────────────────┐
│                      BACKEND SERVICES                       │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │  FIREBASE AUTH   │  │    SUPABASE      │               │
│  │                  │  │                  │               │
│  │  - User Login    │  │  - PostgreSQL DB │               │
│  │  - JWT Tokens    │  │  - RLS Policies  │               │
│  │  - User Mgmt     │  │  - Realtime      │               │
│  └──────────────────┘  │  - Storage       │               │
│                        │  - REST API      │               │
│                        └──────────────────┘               │
│                                                             │
│  ┌──────────────────┐  ┌──────────────────┐               │
│  │     STRIPE       │  │   GOOGLE MAPS    │               │
│  │  - Payments      │  │  - Geocoding     │               │
│  │  - Subscriptions │  │  - Places API    │               │
│  └──────────────────┘  └──────────────────┘               │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Diagram

### Creating a Post

```
┌──────────┐
│   USER   │
└────┬─────┘
     │ 1. Clicks "Create Post"
     ↓
┌────────────────┐
│  Create Post   │
│    Screen      │
└────┬───────────┘
     │ 2. Fills form
     │    - Service type
     │    - Vehicle
     │    - Locations
     │    - Time, Price
     ↓
┌────────────────┐
│ SlotRepository │
└────┬───────────┘
     │ 3. Validates
     │    - User logged in?
     │    - Vehicle owned?
     │    - Fields valid?
     ↓
┌────────────────┐
│  Extract Coords│
│  from Locations│
└────┬───────────┘
     │ 4. Parse "Name|lat,lng"
     │    → {lat: X, lng: Y}
     ↓
┌────────────────┐
│   Supabase     │
│   INSERT       │
└────┬───────────┘
     │ 5. RLS Check
     │    - JWT valid?
     │    - profile_id matches?
     ↓
┌────────────────┐
│  Database      │
│  posts table   │
└────┬───────────┘
     │ 6. Post saved
     ↓
┌────────────────┐
│  Feed Updates  │
│  (All Users)   │
└────────────────┘
```

### Browsing Posts (Guest)

```
┌──────────┐
│  GUEST   │
└────┬─────┘
     │ 1. Opens app
     ↓
┌────────────────┐
│ Splash Screen  │
└────┬───────────┘
     │ 2. Initialize
     ↓
┌────────────────┐
│  Main Screen   │
│  Posts Tab     │
└────┬───────────┘
     │ 3. Load posts
     ↓
┌────────────────┐
│ SlotRepository │
│  loadSlots()   │
└────┬───────────┘
     │ 4. Query Supabase
     │    SELECT * FROM posts
     │    WHERE is_active = true
     ↓
┌────────────────┐
│   Supabase     │
│   RLS Check    │
└────┬───────────┘
     │ 5. Public SELECT policy
     │    → Allows anon users
     ↓
┌────────────────┐
│  Posts Data    │
│  Returned      │
└────┬───────────┘
     │ 6. Build UI
     ↓
┌────────────────┐
│  Feed Display  │
│  (SlotCards)   │
└────────────────┘
```

---

## 🎭 User Roles & Permissions

```
┌─────────────────────────────────────────────────────────┐
│                    USER ROLES                           │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │    GUEST     │  │   CUSTOMER   │  │   PROVIDER   │ │
│  │  (Not Login) │  │  (Logged In) │  │  (Logged In) │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
│  CAN DO:           CAN DO:           CAN DO:           │
│  ✅ Browse posts   ✅ Browse posts   ✅ Browse posts   │
│  ✅ View details   ✅ View details   ✅ View details   │
│  ❌ Create posts   ✅ Create posts   ✅ Create posts   │
│  ❌ Book posts     ✅ Book posts     ✅ Book posts     │
│  ❌ Add vehicles   ✅ Add vehicles   ✅ Add vehicles   │
│  ❌ Reviews        ✅ Reviews        ✅ Reviews        │
│                    ✅ Request rides  ✅ Offer rides    │
│                    ✅ Track bookings ✅ Manage bookings│
│                                                         │
│  NOTE: Same user can be BOTH Customer AND Provider!    │
└─────────────────────────────────────────────────────────┘
```

---

## 📱 Screen Flow

```
                    ┌─────────────┐
                    │ App Starts  │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Splash    │
                    │   Screen    │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │    Main     │
                    │   Screen    │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐      ┌──────▼──────┐    ┌─────▼─────┐
   │  Posts  │      │  Requests   │    │  Profile  │
   │  Feed   │      │  (My Posts) │    │           │
   └────┬────┘      └──────┬──────┘    └─────┬─────┘
        │                  │                  │
   ┌────▼────┐      ┌──────▼──────┐    ┌─────▼─────┐
   │  Slot   │      │   Create    │    │    My     │
   │ Detail  │      │   Request   │    │ Vehicles  │
   └────┬────┘      └─────────────┘    └─────┬─────┘
        │                                     │
   ┌────▼────┐                         ┌─────▼─────┐
   │  Book   │                         │    Add    │
   │  Now    │                         │  Vehicle  │
   └────┬────┘                         └───────────┘
        │
   ┌────▼────┐
   │ Payment │
   │ (Stripe)│
   └────┬────┘
        │
   ┌────▼────┐
   │Confirmed│
   └─────────┘
```

---

## 🗄️ Database Relationships

```
┌──────────────┐
│   profiles   │
│              │
│  id (PK)     │◄─────────┐
│  full_name   │          │
│  email       │          │
└──────────────┘          │
                          │
                          │ profile_id (FK)
                          │
┌──────────────┐          │
│   vehicles   │          │
│              │          │
│  id (PK)     │◄─────┐   │
│  profile_id  │──────┘   │
│  vehicle_type│          │
│  is_online   │          │
└──────┬───────┘          │
       │                  │
       │ vehicle_id (FK)  │
       │                  │
       ↓                  │
┌──────────────┐          │
│    posts     │          │
│              │          │
│  id (PK)     │          │
│  profile_id  │──────────┘
│  vehicle_id  │
│  from_lat    │
│  from_lng    │
│  to_lat      │
│  to_lng      │
│  is_active   │
└──────┬───────┘
       │
       │ post_id (FK)
       │
       ↓
┌──────────────┐
│   bookings   │
│              │
│  id (PK)     │
│  post_id     │
│  user_id     │
│  provider_id │
│  status      │
│  total_amount│
└──────────────┘
```

---

## 🔐 Authentication Flow

```
┌──────────────────────────────────────────────────────┐
│              AUTHENTICATION FLOW                     │
└──────────────────────────────────────────────────────┘

User enters email/password
         ↓
┌────────────────┐
│  Firebase Auth │
│  Validates     │
└────────┬───────┘
         │ ✅ Valid
         ↓
┌────────────────┐
│  Generate JWT  │
│  Token         │
└────────┬───────┘
         │
         │ JWT Claims:
         │ {
         │   "sub": "firebase_uid",
         │   "email": "user@example.com",
         │   "iss": "firebase_project"
         │ }
         ↓
┌────────────────┐
│  Store Token   │
│  in Memory     │
└────────┬───────┘
         │
         │ Every Supabase request:
         │ Authorization: Bearer <jwt>
         ↓
┌────────────────┐
│   Supabase     │
│   Receives     │
│   Request      │
└────────┬───────┘
         │
         ↓
┌────────────────┐
│  RLS Policy    │
│  Checks JWT    │
└────────┬───────┘
         │
         │ Check:
         │ 1. JWT valid?
         │ 2. 'sub' claim exists?
         │ 3. profile_id matches 'sub'?
         ↓
    ┌────┴────┐
    │         │
   YES       NO
    │         │
    ↓         ↓
┌───────┐ ┌───────┐
│ Allow │ │ Deny  │
└───────┘ └───────┘
```

---

## 🎯 Service Types

```
┌─────────────────────────────────────────────────────┐
│              SERVICE TYPES                          │
├─────────────────────────────────────────────────────┤
│                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────┐ │
│  │  🚗 RIDE     │  │  📦 PARCEL   │  │ 🚙 LEASE │ │
│  │   SHARING    │  │   DELIVERY   │  │          │ │
│  └──────────────┘  └──────────────┘  └──────────┘ │
│                                                     │
│  Features:         Features:         Features:     │
│  • Point-to-point  • Weight limit    • Daily/weekly│
│  • Range-based     • Dimensions      • With/without│
│  • Seat selection  • Fragile items   •   operator  │
│  • Pickup options  • Tracking        • Fuel policy │
│  • Shared rides    • Insurance       • Deposit     │
│                                                     │
│  Examples:         Examples:         Examples:     │
│  • Carpool         • Package         • Car rental  │
│  • Taxi service    • Documents       • Bike rental │
│  • Airport rides   • Food delivery   • Van hire    │
│  • Daily commute   • E-commerce      • Long trips  │
└─────────────────────────────────────────────────────┘
```

---

## 📊 Post Lifecycle

```
┌─────────────────────────────────────────────────────┐
│              POST LIFECYCLE                         │
└─────────────────────────────────────────────────────┘

        ┌──────────┐
        │  DRAFT   │ (User filling form)
        └────┬─────┘
             │ Submit
             ↓
        ┌──────────┐
        │  ACTIVE  │ (Visible in feed)
        └────┬─────┘
             │
    ┌────────┼────────┐
    │                 │
    ↓                 ↓
┌─────────┐      ┌─────────┐
│ BOOKED  │      │ EXPIRED │
│         │      │         │
└────┬────┘      └─────────┘
     │
     ↓
┌─────────┐
│IN PROGRESS│ (Trip ongoing)
└────┬────┘
     │
     ↓
┌─────────┐
│COMPLETED│ (Trip finished)
└────┬────┘
     │
     ↓
┌─────────┐
│REVIEWED │ (User left review)
└─────────┘
```

---

## 🎨 UI Components

```
┌─────────────────────────────────────────────────────┐
│              MAIN UI COMPONENTS                     │
├─────────────────────────────────────────────────────┤
│                                                     │
│  SlotCard (Post in Feed)                            │
│  ┌───────────────────────────────────────────────┐ │
│  │ 🚗 Toyota Innova • 4.8★                       │ │
│  │ Chennai Central → Bangalore City              │ │
│  │ 10:00 AM - 2:00 PM • 4h                       │ │
│  │ ₹500 • 4 seats available                      │ │
│  │ [View Details]                                │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  VehicleCard (Vehicle in List)                     │
│  ┌───────────────────────────────────────────────┐ │
│  │ [Vehicle Photo]                               │ │
│  │ Toyota Innova                                 │ │
│  │ KA-01-AB-1234                                 │ │
│  │ 7 Seater • AC • GPS                           │ │
│  │ ✅ Verified • 🟢 Online                       │ │
│  │ [Edit] [Delete]                               │ │
│  └───────────────────────────────────────────────┘ │
│                                                     │
│  BookingCard (Booking in List)                     │
│  ┌───────────────────────────────────────────────┐ │
│  │ Booking #12345                                │ │
│  │ Chennai → Bangalore                           │ │
│  │ Tomorrow, 10:00 AM                            │ │
│  │ Status: Confirmed ✅                          │ │
│  │ Provider: John Doe                            │ │
│  │ [Track] [Contact] [Cancel]                    │ │
│  └───────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────┘
```

---

## 🔄 State Management

```
┌─────────────────────────────────────────────────────┐
│         VALUENOTIFIER PATTERN                       │
└─────────────────────────────────────────────────────┘

Repository Layer:
┌────────────────────────────────────┐
│  SlotRepository                    │
│                                    │
│  final ValueNotifier<List<Slot>>  │
│    _slots = ValueNotifier([]);    │
│                                    │
│  ValueListenable<List<Slot>>      │
│    get slotsListenable => _slots; │
└────────────────────────────────────┘
                ↕
           Notifies changes
                ↕
UI Layer:
┌────────────────────────────────────┐
│  ValueListenableBuilder(           │
│    valueListenable: repository     │
│      .slotsListenable,             │
│    builder: (context, slots, _) {  │
│      return ListView.builder(      │
│        itemCount: slots.length,    │
│        itemBuilder: (ctx, i) {     │
│          return SlotCard(          │
│            slot: slots[i]          │
│          );                        │
│        }                           │
│      );                            │
│    }                               │
│  )                                 │
└────────────────────────────────────┘

When data changes:
_slots.value = [..._slots.value, newSlot];
                ↓
        UI rebuilds automatically
```

---

## 🎯 Summary

VaultWheels is a **bidirectional transport marketplace** where:

✅ **Users** can be both providers and customers  
✅ **Guests** can browse without login  
✅ **Firebase** handles authentication  
✅ **Supabase** stores all data  
✅ **RLS** ensures security  
✅ **Coordinates** enable mapping  
✅ **Stripe** processes payments  
✅ **Real-time** updates keep everyone in sync  

The architecture is **clean**, **scalable**, and **secure**! 🚀
