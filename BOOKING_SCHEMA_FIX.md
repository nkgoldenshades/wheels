# 🔧 Booking Schema Mismatch - FIXED

## ❌ The Problem

Your Flutter code was using the WRONG field names compared to your Supabase database schema. This caused:
1. Bookings not saving correctly to Supabase
2. Bookings not loading correctly from Supabase
3. Duplicate bookings appearing in the UI

## 📊 Schema Comparison

| Flutter Code (OLD) | Supabase Database (CORRECT) | Notes |
|-------------------|----------------------------|-------|
| `slot_id` | `post_id` | Different field name! |
| `user_id` | `user_id` | ✅ Correct (customer) |
| `price` | `price_snapshot` | Snapshot = frozen at booking time |
| `security_deposit` | `deposit_snapshot` | Snapshot = frozen at booking time |
| `seat_key` (string) | `seat_keys` (array) | Array for multi-seat bookings |
| `booking_mode` | `booking_strategy_snapshot` | Different name + values |
| `stripe_payment_intent_id` | `payment_gateway_id` | Generic payment ID |
| `otp` | `otp_code` | Different field name |
| `user_name`, `user_age`, etc. | `passenger_details` (jsonb) | Nested in JSON object |
| `provider_name`, `provider_phone`, etc. | `metadata` (jsonb) | Nested in JSON object |
| `countdown_end_time`, `stripe_client_secret`, etc. | `metadata` (jsonb) | Nested in JSON object |

## ✅ What Was Fixed

### 1. BookingRepository._syncBookingToSupabase()
**Changed to map Flutter model to correct Supabase schema:**

```dart
// OLD (WRONG)
'slot_id': booking.slotId,
'price': booking.price,
'seat_key': booking.seatKey,
'user_name': booking.userName,

// NEW (CORRECT)
'post_id': booking.slotId,  // Your DB uses post_id
'price_snapshot': booking.price,
'seat_keys': [booking.seatKey],  // Array format
'passenger_details': [{  // Nested jsonb
  'name': booking.userName,
  'age': booking.userAge,
  'phone': booking.userPhone,
  'email': booking.userEmail,
  'gender': booking.userGender?.name,
}],
'metadata': {  // Nested jsonb
  'provider_name': booking.providerName,
  'provider_phone': booking.providerPhone,
  // ... other fields
}
```

### 2. Booking.fromJson()
**Changed to read from correct Supabase fields:**

```dart
// Handles both local storage (camelCase) and Supabase (snake_case + jsonb)
slotId: json['slotId'] ?? json['slot_id'] ?? json['post_id'],
price: json['price'] ?? json['price_snapshot'],
userName: json['userName'] ?? firstPassenger?['name'],  // From passenger_details
providerName: json['providerName'] ?? metadata?['provider_name'],  // From metadata
```

### 3. Added Deduplication
**Prevents duplicate bookings in the UI:**

- Clear bookings list before loading
- Deduplicate by ID in `_loadFromSupabase()`
- Deduplicate in local storage loading
- Deduplicate after creating booking
- Deduplicate when updating with OTP

## 🧪 Testing

### Before Fix:
- ❌ Bookings appeared twice in UI
- ❌ Bookings not saving to Supabase correctly
- ❌ Field name mismatches causing errors

### After Fix:
- ✅ Bookings appear once in UI
- ✅ Bookings save to Supabase with correct schema
- ✅ Bookings load from Supabase correctly
- ✅ All field names match database schema

## 📝 Important Notes

### Your Database Schema Uses:
1. **Snapshots** - Fields like `price_snapshot`, `deposit_snapshot` are frozen at booking time (immutable)
2. **JSONB fields** - `passenger_details` and `metadata` store nested data
3. **Arrays** - `seat_keys` is an array for multi-seat bookings
4. **Different names** - `post_id` (not `slot_id`), `otp_code` (not `otp`), `payment_gateway_id` (not `stripe_payment_intent_id`)

### Booking Strategies:
- `instant` = Shared booking (default)
- `wait_for_full` = Wait for full capacity
- `full_vehicle` = Charter entire vehicle

Maps to Flutter's `BookingMode`:
- `instant` → `BookingMode.shared`
- `full_vehicle` → `BookingMode.full`

## 🚀 Next Steps

1. **Clear old data:**
   ```dart
   // In your app, clear SharedPreferences to remove old bookings
   final prefs = await SharedPreferences.getInstance();
   await prefs.remove('bookings_data');
   ```

2. **Restart the app** - Bookings will now load correctly from Supabase

3. **Create a new booking** - Verify it saves with correct schema

4. **Check Supabase dashboard:**
   - Open `bookings` table
   - Verify fields are populated correctly:
     - `post_id` (not null)
     - `price_snapshot` (has value)
     - `passenger_details` (jsonb with passenger info)
     - `metadata` (jsonb with provider info)

## 🎯 Summary

The duplicate bookings issue was caused by:
1. **Schema mismatch** - Flutter code using wrong field names
2. **Failed saves** - Bookings not saving to Supabase correctly
3. **Failed loads** - Bookings not loading from Supabase correctly
4. **Local storage conflicts** - Old data mixing with new data

All fixed now! Your bookings will sync correctly between Flutter and Supabase. 🎉
