# 💳 Test Razorpay Integration

## Phase 1: Basic Integration Test (Start Here)

**No Cloud Function needed for this phase!**

### What You'll Test
- ✅ Razorpay checkout opens
- ✅ Payment form displays
- ✅ Test card processing
- ✅ Success/failure callbacks
- ✅ Payment data stored in database

### What You WON'T Test Yet
- ⏳ Escrow holding (needs Cloud Function)
- ⏳ Payment release (needs Cloud Function)
- ⏳ Refunds (needs Cloud Function)
- ⏳ Webhook verification (needs Cloud Function)

---

## Step 1: Get Razorpay Test Keys (5 minutes)

### 1.1 Sign Up / Login
1. Go to: https://dashboard.razorpay.com/
2. Sign up or login
3. Switch to **Test Mode** (toggle in top-left)

### 1.2 Get API Keys
1. Go to **Settings** → **API Keys**
2. Click **Generate Test Key**
3. Copy both keys:
   - **Key ID**: `rzp_test_xxxxxxxxxxxxx`
   - **Key Secret**: `xxxxxxxxxxxxxxxxxxxxx`

**⚠️ Important:** Use TEST keys, not LIVE keys!

---

## Step 2: Add Keys to Your App (2 minutes)

### Update `lib/services/razorpay_service.dart`

Replace these lines:

```dart
// Replace with your actual Razorpay keys from dashboard
static const String keyId = 'YOUR_RAZORPAY_KEY_ID';
static const String keySecret = 'YOUR_RAZORPAY_KEY_SECRET';
```

With your actual test keys:

```dart
// Razorpay TEST keys (from dashboard)
static const String keyId = 'rzp_test_xxxxxxxxxxxxx';
static const String keySecret = 'xxxxxxxxxxxxxxxxxxxxx';
```

---

## Step 3: Initialize Razorpay (1 minute)

### Update `lib/main.dart`

Find the `main()` function initialization section and add:

```dart
// Initialize Razorpay
RazorpayService.instance.initialize();
```

Add this AFTER Firebase/Supabase initialization, around line 95.

---

## Step 4: Create Test Payment Screen (10 minutes)

Create `lib/screens/test_payment_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/razorpay_service.dart';
import '../services/auth_repository.dart';

class TestPaymentScreen extends StatefulWidget {
  const TestPaymentScreen({super.key});

  @override
  State<TestPaymentScreen> createState() => _TestPaymentScreenState();
}

class _TestPaymentScreenState extends State<TestPaymentScreen> {
  final _amountController = TextEditingController(text: '100');
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _startPayment() {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showError('Please enter a valid amount');
      return;
    }

    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      _showError('Please login first');
      return;
    }

    setState(() => _isProcessing = true);

    // Generate order ID (in production, get this from backend)
    final orderId = const Uuid().v4();

    RazorpayService.instance.openCheckout(
      amount: (amount * 100).toInt(), // Convert to paise
      orderId: orderId,
      name: currentUser.name ?? 'User',
      description: 'Test Payment',
      email: currentUser.email,
      contact: currentUser.phone ?? '9999999999',
      onSuccess: _handlePaymentSuccess,
      onFailure: _handlePaymentFailure,
    );
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    setState(() => _isProcessing = false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✅ Payment Successful!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Payment ID: ${response.paymentId}'),
            const SizedBox(height: 8),
            Text('Order ID: ${response.orderId}'),
            const SizedBox(height: 8),
            Text('Signature: ${response.signature?.substring(0, 20)}...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    debugPrint('✅ Payment Success:');
    debugPrint('  Payment ID: ${response.paymentId}');
    debugPrint('  Order ID: ${response.orderId}');
    debugPrint('  Signature: ${response.signature}');
  }

  void _handlePaymentFailure(PaymentFailureResponse response) {
    setState(() => _isProcessing = false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('❌ Payment Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Code: ${response.code}'),
            const SizedBox(height: 8),
            Text('Message: ${response.message}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    debugPrint('❌ Payment Failed:');
    debugPrint('  Code: ${response.code}');
    debugPrint('  Message: ${response.message}');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Razorpay Payment'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Payment Integration',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isProcessing ? null : _startPayment,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay Now'),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Test Cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildTestCard(
              'Success',
              '4111 1111 1111 1111',
              'Any future date',
              '123',
              Colors.green,
            ),
            const SizedBox(height: 8),
            _buildTestCard(
              'Failure',
              '4000 0000 0000 0002',
              'Any future date',
              '123',
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestCard(
    String title,
    String number,
    String expiry,
    String cvv,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text('Card: $number'),
          Text('Expiry: $expiry'),
          Text('CVV: $cvv'),
        ],
      ),
    );
  }
}
```

---

## Step 5: Add Navigation to Test Screen

### Option A: Add to Main Menu

In your main navigation, add a button:

```dart
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TestPaymentScreen()),
    );
  },
  child: const Text('Test Payment'),
),
```

### Option B: Add to Debug Menu

Or create a debug-only route in `main.dart`:

```dart
routes: {
  '/test-payment': (context) => const TestPaymentScreen(),
  // ... other routes
},
```

---

## Step 6: Test Payment Flow (5 minutes)

### 6.1 Run the App
```bash
flutter run
```

### 6.2 Navigate to Test Payment Screen

### 6.3 Test Success Case
1. Enter amount: `100`
2. Click "Pay Now"
3. Razorpay checkout should open
4. Use test card: `4111 1111 1111 1111`
5. Expiry: Any future date (e.g., `12/25`)
6. CVV: `123`
7. Click "Pay"

**Expected Result:**
- ✅ Payment succeeds
- ✅ Success dialog appears
- ✅ Console shows payment ID, order ID, signature

### 6.4 Test Failure Case
1. Enter amount: `50`
2. Click "Pay Now"
3. Use test card: `4000 0000 0000 0002`
4. Complete payment

**Expected Result:**
- ❌ Payment fails
- ❌ Failure dialog appears
- ❌ Console shows error code and message

---

## Step 7: Verify in Razorpay Dashboard (2 minutes)

1. Go to: https://dashboard.razorpay.com/
2. Ensure you're in **Test Mode**
3. Go to **Transactions** → **Payments**
4. You should see your test payments

**Verify:**
- [ ] Payment appears in dashboard
- [ ] Amount matches
- [ ] Status shows "Captured" (for success)
- [ ] Payment ID matches console output

---

## What's Working Now ✅

After this test, you've verified:
- ✅ Razorpay SDK integration
- ✅ Checkout UI opens correctly
- ✅ Test cards work
- ✅ Success/failure callbacks fire
- ✅ Payment IDs are generated

---

## What's NOT Working Yet ⏳

These require Cloud Functions (Phase 2):
- ⏳ Escrow holding
- ⏳ Payment release to provider
- ⏳ Refunds to user
- ⏳ Webhook verification
- ⏳ Payment status updates in database

---

## Phase 2: Escrow with Cloud Functions

### When You Need This
- When you want to hold payment until service completion
- When you need to release payment to provider
- When you need to handle refunds
- For production deployment

### What You'll Need
1. **Supabase Edge Function** (recommended) OR **Firebase Cloud Function**
2. **Razorpay Webhook** configuration
3. **Payment verification** logic
4. **Escrow state machine**

### Time Estimate
- Setup: 30 minutes
- Testing: 20 minutes
- **Total: 50 minutes**

---

## Troubleshooting

### Issue: Razorpay checkout doesn't open
**Cause:** Keys not configured or invalid
**Fix:** 
- Verify keys are correct
- Ensure you're using TEST keys
- Check `RazorpayService.instance.initialize()` is called

### Issue: "Invalid key_id"
**Cause:** Wrong key format or LIVE key in test mode
**Fix:**
- Use TEST key (starts with `rzp_test_`)
- Copy key exactly from dashboard

### Issue: Payment succeeds but no callback
**Cause:** Callbacks not registered
**Fix:**
- Verify `_razorpay.on()` calls in `initialize()`
- Check `onSuccess` and `onFailure` are passed

### Issue: App crashes on payment
**Cause:** Missing Razorpay package or initialization
**Fix:**
- Run `flutter pub get`
- Verify `razorpay_flutter` in `pubspec.yaml`
- Call `initialize()` in `main()`

---

## Next Steps

### After Basic Test Passes
1. ✅ Integrate payment into booking flow
2. ✅ Store payment records in Supabase `payments` table
3. ✅ Show payment history to users

### For Production
1. ⏳ Set up Cloud Function for escrow
2. ⏳ Configure webhooks
3. ⏳ Switch to LIVE keys
4. ⏳ Test with real small amounts

---

## Quick Summary

**Can test NOW without Cloud Function:**
- ✅ Basic payment flow
- ✅ Test cards
- ✅ Success/failure handling
- ✅ Razorpay dashboard verification

**Need Cloud Function for:**
- ⏳ Escrow (hold payment)
- ⏳ Release to provider
- ⏳ Refunds
- ⏳ Webhook verification

**Start with Phase 1, add Phase 2 when ready for production escrow!**

---

**Time to test: 25 minutes total**
