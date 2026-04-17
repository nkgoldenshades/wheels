# 📖 VaultWheels - Quick Reference Card

## 🎯 What is VaultWheels?

**A peer-to-peer transport marketplace** where users can:
- **Offer** transport services (rides, parcels, leases)
- **Request** transport services
- **Book** services from others

Think: **"Uber + Airbnb for vehicles, but bidirectional"**

---

## 🏗️ Tech Stack

| Component | Technology |
|-----------|-----------|
| **Frontend** | Flutter (Dart) |
| **Backend** | Supabase (PostgreSQL) |
| **Auth** | Firebase Auth (JWT) |
| **Payments** | Stripe |
| **Maps** | Google Maps API |
| **Storage** | Supabase Storage |
| **State** | ValueNotifier |

---

## 📱 Main Screens

| Screen | Purpose |
|--------|---------|
| **Splash** | Initialize app, check auth |
| **Login** | Email/password login, guest mode |
| **Register** | Create account |
| **Posts Feed** | Browse all available services |
| **Requests** | User's own posts (customer mode) |
| **AI Chat** | Voice assistant |
| **Profile** | User info, vehicles, bookings |
| **Slot Detail** | View post details, book |
| **Create Post** | Offer/request service |

---

## 🗄️ Key Repositories

| Repository | Purpose |
|------------|---------|
| **AuthRepository** | User authentication |
| **SlotRepository** | Provider posts (offers) |
| **CustomerSlotRepository** | Customer posts (requests) |
| **VehicleRepository** | Provider vehicles |
| **CustomerVehicleRepository** | Customer vehicles |
| **BookingRepository** | Bookings/reservations |
| **ProfileRepository** | User profiles |

---

## 🎭 User Roles

| Role | Can Browse | Can Create | Can Book |
|------|-----------|-----------|----------|
| **Guest** | ✅ Yes | ❌ No | ❌ No |
| **Customer** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Provider** | ✅ Yes | ✅ Yes | ✅ Yes |

**Note:** Same user can be both Customer AND Provider!

---

## 🚗 Service Types

| Type | Description | Examples |
|------|-------------|----------|
| **🚗 Ride** | Transport people | Carpool, taxi, airport rides |
| **📦 Parcel** | Deliver packages | Documents, food, e-commerce |
| **🚙 Lease** | Rent vehicles | Daily rental, long-term hire |

---

## 📊 Database Tables

| Table | Purpose |
|-------|---------|
| **profiles** | User accounts |
| **vehicles** | Vehicles (provider & customer) |
| **posts** | Service posts (offers & requests) |
| **bookings** | Reservations |
| **user_posts** | Customer requests |
| **reviews** | Ratings & feedback |

---

## 🔐 Authentication Flow

```
1. User logs in → Firebase Auth
2. Firebase generates JWT token
3. App sends JWT with every Supabase request
4. Supabase RLS checks JWT claims
5. If valid → Allow operation
6. If invalid → Deny operation
```

---

## 🔄 Creating a Post

```
1. User clicks "Create Post"
2. Selects service type (Ride/Parcel/Lease)
3. Selects vehicle from fleet
4. Fills form (locations, time, price)
5. Clicks "Create"
6. SlotRepository validates
7. Extracts coordinates from locations
8. Inserts to Supabase posts table
9. RLS checks authentication
10. Post appears in feed
```

---

## 📍 Location Format

Locations are stored as:
```
"Display Name|latitude,longitude|keywords"
```

**Examples:**
- `"Chennai Central|13.0827,80.2707|railway"`
- `"Bangalore City|12.9716,77.5946"`

**Extracted to separate columns:**
- `from_location` → Display string
- `from_lat` → 13.0827
- `from_lng` → 80.2707

---

## 🎯 Key Features

✅ **Guest Mode** - Browse without login  
✅ **Bidirectional** - Offer AND request services  
✅ **Real-time** - Live updates  
✅ **Secure** - RLS + Firebase JWT  
✅ **Offline** - Local caching  
✅ **Maps** - Coordinate-based search  
✅ **Payments** - Stripe integration  
✅ **Reviews** - Rating system  

---

## 🐛 Common Issues & Fixes

| Issue | Fix |
|-------|-----|
| Posts not showing | Run `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` |
| Empty JWT error | Return `null` from accessToken callback |
| Can't create posts | Check vehicle ownership |
| No guest button | Restart app after code changes |
| Missing coordinates | Extract lat/lng from location strings |

---

## 📂 Important Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry point, routes |
| `lib/services/auth_repository.dart` | Authentication |
| `lib/services/slot_repository.dart` | Provider posts |
| `lib/services/vehicle_repository.dart` | Vehicles |
| `COMPLETE_RLS_FIX_FOR_FIREBASE.sql` | Fix RLS policies |
| `HOW_THE_APP_WORKS.md` | Complete explanation |

---

## 🚀 Quick Commands

### Run App
```bash
flutter run
```

### Clean Build
```bash
flutter clean
flutter pub get
flutter run
```

### Check Diagnostics
```bash
flutter analyze
```

### Build Release
```bash
flutter build apk --release  # Android
flutter build ios --release  # iOS
flutter build web --release  # Web
```

---

## 📊 Data Flow Summary

```
User Action
    ↓
UI Screen
    ↓
Repository (Validation)
    ↓
Supabase Client (API Call)
    ↓
RLS Policy Check
    ↓
Database Operation
    ↓
Response
    ↓
Repository (Update State)
    ↓
UI Rebuild (ValueNotifier)
```

---

## 🎓 Learning Resources

| Topic | File |
|-------|------|
| **Complete Guide** | `HOW_THE_APP_WORKS.md` |
| **Visual Architecture** | `APP_ARCHITECTURE_VISUAL.md` |
| **Guest Mode** | `GUEST_MODE_ADDED.md` |
| **Coordinates Fix** | `COORDINATES_FIX_SUMMARY.md` |
| **RLS Fix** | `SIMPLE_FIX_GUIDE.md` |
| **Troubleshooting** | `POSTS_NOT_SHOWING_CHECKLIST.md` |

---

## 💡 Pro Tips

1. **Always restart app** after code changes (hot reload may not work)
2. **Run SQL scripts** in Supabase SQL Editor for database fixes
3. **Check Flutter console** for detailed error logs
4. **Use diagnostic scripts** to verify database state
5. **Test as guest first** to ensure public access works
6. **Verify coordinates** are being extracted and saved

---

## 🎯 Success Checklist

- [ ] App starts without errors
- [ ] Guest can browse posts
- [ ] Login/register works
- [ ] "Continue as Guest" button visible
- [ ] Posts appear in feed
- [ ] Can create posts when logged in
- [ ] Coordinates saved to database
- [ ] Bookings work
- [ ] Payments process (Stripe)
- [ ] Reviews can be left

---

**Need more details? Read `HOW_THE_APP_WORKS.md`** 📚
