# User vs Provider Flow - Complete Picture

## Core Concept: Dual Role System

**Key Insight:** The SAME person can be BOTH a User AND a Provider simultaneously.

```
Single Account (Firebase UID: "GbsFkKmcHCQFJ0ceVoBWz2punch1")
    ↓
Can act as USER (looking for rides)
    AND
Can act as PROVIDER (offering rides)
```

## Profile Structure

### Single Profile, Dual Modes

```
Profile (in public.users table)
├── id: "GbsFkKmcHCQFJ0ceVoBWz2punch1" (Firebase UID)
├── email: "user@example.com"
├── profile_name: "John Doe"
├── avatar_url: "https://..."
├── business_type: "Transport Service" (optional)
└── Mode Toggle: User ↔ Provider
```

## What's Common (Shared Between Both Modes)

### 1. Profile Information
- ✅ Profile name
- ✅ Email
- ✅ Avatar
- ✅ Phone number
- ✅ Business type (if set)

### 2. Authentication
- ✅ Firebase Auth (same login)
- ✅ JWT token (same token)
- ✅ User ID (same Firebase UID)

### 3. Settings
- ✅ Currency preference
- ✅ Language
- ✅ Notification settings
- ✅ Subscription plan

### 4. Reviews
- ✅ Can receive reviews as both user and provider
- ✅ Review history shows both roles

## What's Different (Mode-Specific)

### User Mode (Looking for Services)

**Purpose:** Find and book transportation services

**Features:**
```
User Mode
├── Browse available slots/posts
├── Search for rides
├── Book services
├── Pay for bookings
├── Verify OTP when service starts
├── View spending history
├── Create "Looking For" posts
└── Rate providers after service
```

**Data Access:**
- Views: All available slots from providers
- Creates: Bookings as `user_id`
- Manages: Own "looking for" posts (UserSlotRepository)
- Sees: Spending analytics

**UI Elements:**
- "Needed Vehicles" menu
- "Spending" page
- "Create Post" button (looking for rides)
- Booking history as passenger

### Provider Mode (Offering Services)

**Purpose:** Offer transportation services and earn money

**Features:**
```
Provider Mode
├── Add vehicles
├── Create service slots/posts
├── Set pricing
├── Manage availability
├── Accept/reject bookings
├── Share OTP with users
├── View earnings history
├── Manage seat layouts
└── Receive ratings from users
```

**Data Access:**
- Creates: Vehicles, Slots, Seat Layouts
- Manages: Bookings as `provider_id`
- Creates: "Offering" posts (SlotRepository)
- Sees: Earnings analytics

**UI Elements:**
- "Providing Vehicles" menu
- "Earnings" page
- "Add Vehicle" button
- Booking history as driver/provider

## Database Relationships

### User as Passenger (User Mode)
```sql
-- Booking where you're the passenger
SELECT * FROM bookings 
WHERE user_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Your spending
SELECT SUM(price) FROM bookings 
WHERE user_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1' 
  AND status = 'completed';
```

### User as Provider (Provider Mode)
```sql
-- Bookings where you're the provider
SELECT * FROM bookings 
WHERE provider_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Your earnings
SELECT SUM(price) FROM bookings 
WHERE provider_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1' 
  AND status = 'completed';

-- Your vehicles
SELECT * FROM vehicles 
WHERE user_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';

-- Your slots
SELECT * FROM slots 
WHERE user_id = 'GbsFkKmcHCQFJ0ceVoBWz2punch1';
```

## Profile Page Toggle

### UI Structure
```
Profile Page
├── Profile Header (common)
│   ├── Avatar
│   ├── Name
│   ├── Business Type
│   └── Online Status
│
├── Mode Toggle (switch between roles)
│   ├── [User] button
│   └── [Provider] button
│
├── User Mode Content (when User selected)
│   ├── Needed Vehicles
│   ├── Spending
│   └── Expert Support (if subscribed)
│
└── Provider Mode Content (when Provider selected)
    ├── Providing Vehicles
    └── Earnings
```

### Code Implementation
```dart
class ProfilePage extends StatefulWidget {
  bool _isUserMode = true; // Toggle state

  // Common sections (always visible)
  - Profile header
  - Settings
  - Help & Support
  - Logout

  // Mode-specific sections
  if (_isUserMode) {
    - Needed Vehicles
    - Spending
    - Expert Support
  } else {
    - Providing Vehicles
    - Earnings
  }
}
```

## Booking Flow - Both Perspectives

### As User (Passenger)
```
1. Browse available slots
2. Select a slot
3. Confirm booking details
4. Pay (if required)
5. Receive booking confirmation
6. Wait for service start
7. Provider shares OTP
8. Verify OTP to start service
9. Service completes
10. Rate the provider
```

### As Provider (Driver)
```
1. Create vehicle
2. Create slot/post
3. Wait for bookings
4. Receive booking notification
5. Accept/reject booking
6. Prepare for service
7. Share OTP with user
8. User verifies OTP
9. Provide service
10. Receive payment
11. Get rated by user
```

## Same Person, Both Roles Example

**Scenario:** John has one account

**Morning (Provider Mode):**
```
- John adds his car to the app
- Creates a slot: "City A → City B, 9 AM"
- Alice books John's slot
- John provides the ride
- John earns ₹500
```

**Evening (User Mode):**
```
- John needs to return home
- Searches for rides: "City B → City A, 6 PM"
- Books Bob's slot
- Bob provides the ride
- John pays ₹500
```

**Result:**
- John's earnings: ₹500 (as provider)
- John's spending: ₹500 (as user)
- Net: ₹0, but got both rides!

## Data Repositories

### User Mode Uses:
- `UserSlotRepository` - "Looking for" posts
- `BookingRepository` - Bookings where user_id = current user
- `PassengerRepository` - Saved passenger details

### Provider Mode Uses:
- `VehicleRepository` - Own vehicles
- `SlotRepository` - "Offering" posts
- `SeatLayoutRepository` - Seat configurations
- `BookingRepository` - Bookings where provider_id = current user

### Both Modes Use:
- `AuthRepository` - Authentication
- `ProfileRepository` - Profile info
- `ReviewRepository` - Reviews (given and received)
- `AppPreferences` - Settings

## RLS Security

### User Mode Queries
```sql
-- Can only create bookings as yourself
INSERT INTO bookings (user_id, ...) 
VALUES ('your-firebase-uid', ...);
-- RLS checks: auth.jwt() ->> 'sub' = user_id ✅

-- Can view all slots (marketplace)
SELECT * FROM slots;
-- RLS allows: true ✅
```

### Provider Mode Queries
```sql
-- Can only create vehicles for yourself
INSERT INTO vehicles (user_id, ...) 
VALUES ('your-firebase-uid', ...);
-- RLS checks: auth.jwt() ->> 'sub' = user_id ✅

-- Can only update your own slots
UPDATE slots SET ... 
WHERE user_id = 'your-firebase-uid';
-- RLS checks: auth.jwt() ->> 'sub' = user_id ✅
```

## Summary

**Common (Shared):**
- Single account/profile
- Same Firebase UID
- Same JWT token
- Profile information
- Settings
- Reviews

**User Mode (Passenger):**
- Browse & book services
- Pay for rides
- Verify OTP
- View spending
- Create "looking for" posts

**Provider Mode (Driver):**
- Add vehicles
- Create service slots
- Accept bookings
- Share OTP
- View earnings
- Manage availability

**Key Insight:** It's not two separate accounts - it's ONE account with TWO roles that can be active simultaneously!
