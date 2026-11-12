# AI Chat Credit Section

## Feature Overview
Added a wallet balance/credit section at the top of the AI chat for logged-in users, showing their current balance and providing quick access to add money.

## Implementation Details

### Visual Design

#### For Logged-In Users
A blue gradient banner at the top showing:
- **Wallet icon**: White card with wallet icon
- **Balance label**: "Wallet Balance" with refresh icon
- **Amount**: Large, bold display of current balance (formatted with currency)
- **Add button**: Blue button to add money to wallet

#### For Guest Users
Orange gradient banner showing:
- **Info icon**: Warning/info icon
- **Message**: "Guest Mode: X conversations remaining"
- **Login button**: Orange button to login

### Features

1. **Real-Time Balance Display**
   - Shows current wallet balance from profile
   - Formatted with user's currency preference
   - Updates automatically when profile changes

2. **Refresh Balance**
   - Small refresh icon next to "Wallet Balance" label
   - Tap to reload profile data from database
   - Shows "Balance refreshed" confirmation

3. **Add Money Button**
   - Quick access to add funds
   - Currently shows "coming soon" message
   - Ready to integrate with payment flow

4. **Responsive Design**
   - Gradient background (blue for logged-in, orange for guests)
   - Shadow effects for depth
   - Proper spacing and alignment

### Code Structure

```dart
// Logged-in user section
if (!_isGuest)
  ValueListenableBuilder<ProfileInfo>(
    valueListenable: ProfileRepository.instance.profile,
    builder: (context, profile, _) {
      // Display wallet balance with refresh and add money
    },
  ),

// Guest user section  
if (_isGuest)
  Container(
    // Display conversation limit and login prompt
  ),
```

### User Experience Flow

#### Logged-In User
1. Opens AI Chat
2. Sees wallet balance at top
3. Can tap refresh icon to update balance
4. Can tap "Add" button to add money (coming soon)
5. Balance updates automatically when transactions occur

#### Guest User
1. Opens AI Chat
2. Sees conversation limit banner
3. Can tap "Login" to authenticate
4. After login → sees wallet balance instead

### Integration Points

#### Profile Repository
- Reads `walletBalance` from `ProfileInfo`
- Uses `ProfileRepository.instance.profile` ValueListenable
- Calls `ProfileRepository.instance.init()` to refresh

#### App Preferences
- Uses `AppPreferences.instance.formatMoney()` for currency formatting
- Respects user's currency preference
- Updates when currency changes

### Styling

#### Colors
- **Logged-in**: Blue gradient (`Colors.blue.shade50` to `Colors.blue.shade100`)
- **Guest**: Orange gradient (`Colors.orange.shade100` to `Colors.orange.shade50`)
- **Border**: Matching shade 200 color
- **Text**: Shade 700-900 for contrast

#### Typography
- **Label**: 12px, medium weight
- **Balance**: 20px, bold
- **Button**: 12px

#### Spacing
- Padding: 16px horizontal, 12px vertical
- Icon size: 24px (wallet), 14px (refresh)
- Gap between elements: 8-12px

### Future Enhancements

1. **Add Money Integration**
   - Connect to payment gateway (Stripe/Razorpay)
   - Show payment options dialog
   - Update balance after successful payment

2. **Transaction History**
   - Add button to view transaction history
   - Show recent transactions in expandable section
   - Filter by type (credit/debit)

3. **Quick Actions**
   - Send money to other users
   - Request money
   - Set up auto-reload

4. **Notifications**
   - Low balance warning
   - Transaction confirmations
   - Promotional offers

5. **Analytics**
   - Track spending patterns
   - Show spending insights
   - Budget recommendations

### Testing

#### Test Cases

1. **Logged-In User - Balance Display**
   - Login to account
   - Open AI Chat
   - Should see blue banner with wallet balance
   - Balance should match profile data

2. **Logged-In User - Refresh Balance**
   - Tap refresh icon
   - Should show loading indicator
   - Should update balance from database
   - Should show "Balance refreshed" message

3. **Logged-In User - Add Money**
   - Tap "Add" button
   - Should show "coming soon" message
   - (Future: should open payment dialog)

4. **Guest User - No Credit Section**
   - Open app without login
   - Open AI Chat
   - Should NOT see wallet balance
   - Should see orange guest banner instead

5. **Guest to Logged-In Transition**
   - Start as guest (see orange banner)
   - Login to account
   - Should switch to blue wallet banner
   - Should show correct balance

6. **Currency Formatting**
   - Change currency in settings
   - Open AI Chat
   - Balance should format with new currency
   - Should update without refresh

### Benefits

#### For Users
- Quick visibility of wallet balance
- Easy access to add money
- No need to navigate to profile
- Contextual placement (AI chat may suggest paid features)

#### For Business
- Encourages wallet usage
- Reduces friction for payments
- Increases engagement with payment features
- Promotes premium features

### Files Modified
- `lib/screens/ai_chat_page.dart`

### Dependencies
- `ProfileRepository` - for wallet balance
- `AppPreferences` - for currency formatting
- `AuthRepository` - for login status
