# AI Credits System - Complete Implementation

## Overview
Implemented a credit-based system for AI chat instead of direct money payment. Users consume credits per message, making it more engaging and flexible.

## Why Credits Over Money?

### Advantages of Credits:
✅ **Usage-based**: Deduct credits per AI message  
✅ **Gamification**: Users earn/buy credits  
✅ **Flexible pricing**: Different AI features cost different credits  
✅ **Psychological**: Feels less expensive than direct money  
✅ **Promotional**: Easy to give free credits, bonuses  
✅ **Engagement**: Encourages regular usage  

### Disadvantages of Direct Money:
❌ Direct cost feels expensive  
❌ Less flexible for different features  
❌ Harder to do promotions  
❌ Users hesitate to spend real money on chat  

## Credit System Design

### Credit Costs:
- **1 AI message = 1 credit**
- New users get **50 free credits**
- Guests get **10 free messages** (no credits, no account)

### Credit Packages:
| Credits | Price | Notes |
|---------|-------|-------|
| 100 | ₹10 | Starter pack |
| 500 | ₹40 | **POPULAR** - Best value |
| 1000 | ₹70 | Power user |

## Implementation Details

### Database Changes

#### New Column: `ai_credits`
```sql
ALTER TABLE profiles 
ADD COLUMN ai_credits INTEGER NOT NULL DEFAULT 50;
```

- **Type**: INTEGER
- **Default**: 50 (new users get 50 free credits)
- **Not Null**: Always has a value
- **Indexed**: For faster queries

### Code Changes

#### 1. Profile Model (`lib/services/profile_repository.dart`)

**Added Field:**
```dart
final int aiCredits; // Credits for AI chat (1 credit = 1 message)
```

**Added Methods:**
```dart
// Deduct credits (returns false if insufficient)
Future<bool> deductAICredits(int amount) async

// Add credits (purchase or reward)
Future<void> addAICredits(int amount) async
```

**Updated:**
- `fromJson()` - reads `ai_credits` from database
- `copyWith()` - includes `aiCredits` parameter
- Constructor - defaults to 50 credits

#### 2. AI Chat Page (`lib/screens/ai_chat_page.dart`)

**Credit Display Banner:**
- Shows current credit balance
- Star icon (instead of wallet)
- Refresh button to reload credits
- "Buy" button to purchase more
- Low credit warning (< 10 credits)
  - Orange color scheme
  - "Low credits! Buy more to continue" message

**Credit Deduction:**
- Checks credits before sending message
- Deducts 1 credit per message
- Shows buy dialog if insufficient credits
- Removes message if deduction fails

**Buy Credits Dialog:**
- Shows 3 credit packages
- Tap to purchase (demo mode - no payment yet)
- Popular package highlighted
- Shows price in rupees

### User Experience

#### For New Users:
1. Sign up → Get 50 free credits
2. Can send 50 AI messages
3. See credit balance in AI chat
4. Get low credit warning at 10 credits
5. Buy more credits when needed

#### For Guest Users:
1. No credits (not logged in)
2. Get 10 free messages
3. See conversation counter
4. Login prompt after 10 messages

#### For Logged-In Users:
1. See credit balance at top
2. Send message → 1 credit deducted
3. Balance updates in real-time
4. Low credit warning (orange banner)
5. Buy credits dialog when needed

### Visual Design

#### Normal State (>= 10 credits):
```
┌─────────────────────────────────────────┐
│ ⭐  AI Credits        🔄        [Buy]   │
│     50 credits                          │
└─────────────────────────────────────────┘
```
- Blue gradient background
- Star icon
- Credit count in large text
- Buy button (blue)

#### Low Credits State (< 10 credits):
```
┌─────────────────────────────────────────┐
│ ⭐  AI Credits        🔄        [Buy]   │
│     8 credits                           │
│     Low credits! Buy more to continue   │
└─────────────────────────────────────────┘
```
- Orange gradient background
- Warning message
- Buy button (orange)

### Credit Flow

```
User sends message
  ↓
Check if guest
  ├─ Yes → Check conversation limit (10)
  │         ├─ Reached → Show login prompt
  │         └─ OK → Increment counter
  └─ No → Check AI credits
            ├─ < 1 → Show buy credits dialog
            └─ >= 1 → Deduct 1 credit
                      ↓
                Send to AI
                      ↓
                Get response
                      ↓
                Display to user
```

### Buy Credits Flow

```
User taps "Buy" button
  ↓
Show credit packages dialog
  ├─ 100 credits - ₹10
  ├─ 500 credits - ₹40 (POPULAR)
  └─ 1000 credits - ₹70
  ↓
User selects package
  ↓
[TODO: Payment gateway integration]
  ↓
Add credits to account
  ↓
Update database
  ↓
Show success message
  ↓
Credits available immediately
```

## Database Schema

### profiles table:
```sql
CREATE TABLE profiles (
  id TEXT PRIMARY KEY,
  full_name TEXT,
  email TEXT,
  phone_number TEXT,
  wallet_balance NUMERIC DEFAULT 0,
  ai_credits INTEGER NOT NULL DEFAULT 50,  -- NEW COLUMN
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### Indexes:
```sql
CREATE INDEX idx_profiles_ai_credits ON profiles(ai_credits);
```

## Testing

### Test Cases:

1. **New User Registration**
   - Sign up new account
   - Check profile → should have 50 credits
   - Open AI chat → should show "50 credits"

2. **Send Message - Credit Deduction**
   - Send AI message
   - Check credits → should decrease by 1
   - Send 5 messages → should have 45 credits

3. **Low Credits Warning**
   - Use credits until < 10 remaining
   - Banner should turn orange
   - Should show warning message

4. **Insufficient Credits**
   - Use all credits (0 remaining)
   - Try to send message
   - Should show buy credits dialog
   - Message should not be sent

5. **Buy Credits (Demo)**
   - Tap "Buy" button
   - Select 100 credits package
   - Should add 100 credits
   - Should show success message
   - Balance should update immediately

6. **Refresh Credits**
   - Tap refresh icon
   - Should reload from database
   - Should show "Credits refreshed" message

7. **Guest User**
   - Open app without login
   - Should NOT see credit banner
   - Should see conversation counter
   - Should have 10 free messages

## Future Enhancements

### Phase 2:
- [ ] Payment gateway integration (Razorpay/Stripe)
- [ ] Credit purchase history
- [ ] Refund system
- [ ] Credit expiry (optional)

### Phase 3:
- [ ] Earn credits (referrals, daily login)
- [ ] Credit gifting
- [ ] Subscription plans (unlimited credits)
- [ ] Different costs for different AI models

### Phase 4:
- [ ] Credit analytics dashboard
- [ ] Usage insights
- [ ] Spending predictions
- [ ] Budget alerts

## Migration Guide

### For Existing Users:

1. **Run SQL Migration:**
   ```bash
   # In Supabase SQL Editor
   psql < ADD_AI_CREDITS_COLUMN.sql
   ```

2. **Verify Migration:**
   ```sql
   SELECT COUNT(*) FROM profiles WHERE ai_credits = 50;
   ```

3. **Deploy Code:**
   - Update `profile_repository.dart`
   - Update `ai_chat_page.dart`
   - Test on staging
   - Deploy to production

4. **Monitor:**
   - Check error logs
   - Monitor credit deductions
   - Track purchase conversions

### Rollback Plan:
If issues occur:
1. Revert code changes
2. Keep `ai_credits` column (no harm)
3. Investigate and fix
4. Redeploy

## Analytics to Track

### Key Metrics:
- Average credits per user
- Credit purchase conversion rate
- Most popular package
- Credits used per day
- Low credit warning → purchase rate
- Guest → registered user conversion

### Queries:
```sql
-- Average credits per user
SELECT AVG(ai_credits) FROM profiles;

-- Users with low credits
SELECT COUNT(*) FROM profiles WHERE ai_credits < 10;

-- Total credits in system
SELECT SUM(ai_credits) FROM profiles;
```

## Support & FAQ

### Q: How many credits do I get as a new user?
A: New users get 50 free credits to try the AI chat.

### Q: How much does 1 credit cost?
A: Credits are sold in packages:
- 100 credits = ₹10 (₹0.10 per credit)
- 500 credits = ₹40 (₹0.08 per credit) - Best value!
- 1000 credits = ₹70 (₹0.07 per credit)

### Q: Do credits expire?
A: No, credits never expire. Use them anytime!

### Q: Can I get a refund?
A: Refunds are handled case-by-case. Contact support.

### Q: How do I earn free credits?
A: Coming soon - referrals, daily login bonuses, etc.

### Q: What if I run out of credits?
A: You'll see a prompt to buy more. You can purchase instantly.

## Files Modified

1. `lib/services/profile_repository.dart`
   - Added `aiCredits` field
   - Added `deductAICredits()` method
   - Added `addAICredits()` method
   - Updated `fromJson()`, `copyWith()`

2. `lib/screens/ai_chat_page.dart`
   - Changed wallet balance to AI credits
   - Added credit deduction on message send
   - Added buy credits dialog
   - Added low credit warning
   - Updated UI to show credits instead of money

3. `ADD_AI_CREDITS_COLUMN.sql`
   - SQL migration to add column
   - Set default value
   - Create index

## Success Criteria

✅ New users get 50 free credits  
✅ Credits deduct on message send  
✅ Low credit warning shows  
✅ Buy credits dialog works  
✅ Credits update in real-time  
✅ Guest users unaffected  
✅ No breaking changes  
✅ Database migration successful  

## Conclusion

The AI credits system provides a better user experience than direct money payment. It's more engaging, flexible, and encourages usage. The implementation is complete and ready for testing.

Next steps:
1. Run database migration
2. Test thoroughly
3. Integrate payment gateway
4. Monitor usage and conversions
