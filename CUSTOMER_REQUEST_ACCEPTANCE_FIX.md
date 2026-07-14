# Customer Request Acceptance Enhancement

## Problem Summary
When providers accept customer requests (need vehicles posts), the system had several issues:
1. ❌ No customer details collected - booking showed "Guest" instead of actual name
2. ❌ Customer details not passed during acceptance
3. ❌ Capacity reduced randomly without clear indication of what was booked

## Solution Implemented

### 1. Enhanced Acceptance Flow (`user_post_detail_screen.dart`)
- Added `_showAcceptanceDialog()` method that collects:
  - Customer Name (required)
  - Customer Age (optional)
  - Customer Phone (optional)
  - Customer Gender (optional)
- Modified `_acceptPost()` to call dialog before creating acceptance
- Passes collected details to repository

### 2. Updated Repository (`user_post_acceptance_repository.dart`)
- Modified `acceptPost()` method to accept customer details parameters:
  - `customerName`
  - `customerAge`
  - `customerPhone`
  - `customerGender`
  - `selectedSeats` (for future compartment selection)
- Stores customer details in `customer_details` jsonb field
- Stores seat selection in `selected_seats` array field

### 3. Database Schema Update (`add_customer_details_to_acceptances.sql`)
- Added `customer_details` jsonb column to `user_post_acceptances` table
- Added `selected_seats` text[] column for compartment tracking
- Created index on customer name for efficient queries

## Usage Flow

1. **Provider views customer request** in "Need Vehicles" section
2. **Provider clicks "Accept Request"** button
3. **Dialog appears** asking for customer details:
   - Name (required)
   - Age, phone, gender (optional)
4. **Provider fills in details** and clicks "Accept Request"
5. **Acceptance created** with customer details stored in database
6. **Customer receives OTP** and can verify + pay
7. **Booking appears in Requests tab** with actual customer name (not "Guest")

## Files Modified

### Dart Files
- `lib/screens/user_post/user_post_detail_screen.dart`
  - Added `_showAcceptanceDialog()` method
  - Modified `_acceptPost()` to collect customer details

- `lib/services/user_post_acceptance_repository.dart`
  - Updated `acceptPost()` method signature
  - Added customer details storage

### SQL Migration
- `add_customer_details_to_acceptances.sql`
  - Schema changes for user_post_acceptances table

## Database Migration Required

Run this SQL to apply the schema changes:

```bash
# Connect to your Supabase database and run:
psql -f add_customer_details_to_acceptances.sql
```

Or execute in Supabase SQL Editor:
```sql
ALTER TABLE user_post_acceptances 
ADD COLUMN IF NOT EXISTS customer_details jsonb DEFAULT '{}'::jsonb;

ALTER TABLE user_post_acceptances 
ADD COLUMN IF NOT EXISTS selected_seats text[] DEFAULT ARRAY[]::text[];
```

## Benefits

✅ **Customer name displayed** in bookings/requests (no more "Guest")
✅ **Full customer information** collected at acceptance time
✅ **Better record keeping** for provider and customer
✅ **Prepared for future compartment selection** feature
✅ **Improved booking experience** with complete details

## Future Enhancements

- [ ] Add actual seat layout visualization for compartment selection
- [ ] Display selected compartments in booking detail view
- [ ] Show which compartments are already booked
- [ ] Integrate with provider's vehicle layout if available

## Testing Checklist

- [ ] Provider can accept customer request
- [ ] Dialog shows with all customer detail fields
- [ ] Name field is required (shows error if empty)
- [ ] Optional fields can be left blank
- [ ] Acceptance created with customer details
- [ ] Customer details stored in database
- [ ] Booking shows actual customer name (not "Guest")
- [ ] OTP flow still works correctly
- [ ] Payment flow still works correctly

## Notes

- Customer requests (need vehicles) don't have layouts - that's a provider-only feature
- Seat selection UI is prepared but not yet functional (awaits layout integration)
- Customer details are stored in jsonb for flexibility
- Selected seats are stored as text array for easy querying
