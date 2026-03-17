# User Post Payment Flow

## Overview
Users can create posts requesting vehicle services. Providers can accept these requests, and payment is processed after OTP verification.

## Flow

### 1. User Creates Post
- User goes to "Posts" section
- Creates a request with:
  - Service type (Passenger/Parcel/Lease/Working)
  - Route type (From-To or Base-Range)
  - Locations
  - Time window
  - Number of persons
  - Budget (payment amount)
  - Notes

### 2. Provider Accepts Request
- Providers browse user posts
- Click "Accept Request" on a post they want to fulfill
- System generates 6-digit OTP
- OTP is sent to the user (currently logged in console, needs SMS/Email integration)
- Provider sees "Request Accepted" status

### 3. User Verifies OTP
- User receives OTP (via SMS/Email - to be implemented)
- User opens the acceptance in their post detail screen
- Enters the 6-digit OTP
- Clicks "Verify & Pay"

### 4. Payment Processing
- System verifies OTP
- Creates Razorpay order via Firebase Functions (secure)
- Opens Razorpay payment gateway
- User completes payment
- Payment is verified server-side
- Status updated to "Paid"

### 5. Service Delivery
- Provider can now see payment is completed
- Service can be delivered
- Both parties can track the status

## Database Schema

### user_post_acceptances Table
```sql
- id: TEXT (primary key)
- post_id: TEXT (references user_posts)
- provider_id: TEXT (Firebase UID)
- user_id: TEXT (Firebase UID)
- amount: DECIMAL
- status: TEXT (pending/otpVerified/paid/cancelled)
- otp: TEXT (6-digit)
- otp_expires_at: TIMESTAMPTZ
- razorpay_order_id: TEXT
- razorpay_payment_id: TEXT
- created_at: TIMESTAMPTZ
- paid_at: TIMESTAMPTZ
```

## Security Features

1. **OTP Verification**: Prevents unauthorized payments
2. **OTP Expiry**: OTP expires after 10 minutes
3. **Server-side Payment**: Razorpay key secret never exposed to client
4. **Payment Verification**: All payments verified server-side before confirmation
5. **RLS Policies**: Row-level security ensures users only see their own data

## Files Created

1. `lib/models/user_post_acceptance.dart` - Acceptance model
2. `lib/services/user_post_acceptance_repository.dart` - Repository for managing acceptances
3. `lib/screens/user_post/user_post_detail_screen.dart` - UI for viewing and accepting posts
4. `supabase/migrations/003_user_post_acceptances.sql` - Database schema

## Integration Steps

### 1. Run Supabase Migration
```bash
# Apply the migration to create user_post_acceptances table
supabase db push
```

### 2. Initialize Repository in main.dart
Add to initialization:
```dart
await UserPostAcceptanceRepository.instance.init();
```

### 3. Add Navigation
Update the user post card tap handler to navigate to UserPostDetailScreen:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => UserPostDetailScreen(
      post: post,
      isProvider: true, // or false if viewing own post
    ),
  ),
);
```

### 4. SMS/Email Integration (TODO)
Currently OTP is only logged to console. Need to integrate:
- SMS service (Twilio, AWS SNS, etc.)
- Email service (SendGrid, AWS SES, etc.)

Update `UserPostAcceptanceRepository.acceptPost()` to send OTP via SMS/Email.

## Testing Flow

1. **Create User Post**:
   - Login as User A
   - Create a post with budget ₹500

2. **Accept as Provider**:
   - Login as User B (provider)
   - View User A's post
   - Click "Accept Request"
   - Note the OTP from console logs

3. **Verify OTP and Pay**:
   - Login back as User A
   - View your post
   - See the acceptance from User B
   - Enter the OTP
   - Click "Verify & Pay"
   - Complete Razorpay payment

4. **Verify Completion**:
   - Check status shows "Payment Completed"
   - Provider can see payment is done

## Next Steps

1. Integrate SMS/Email for OTP delivery
2. Add push notifications for acceptance events
3. Add rating system after service completion
4. Add dispute resolution mechanism
5. Add refund functionality if needed
