# 💰 Simple Withdraw System - One Provider Per User

## 🧠 **Correct Architecture:**

### **Clean Logic:**
```
2 systems exist → 1 system used per user → 1 payment per booking
```

### **Provider Selection:**
```dart
// At registration/profile setup
if (user.country == 'IN') {
  profile.payment_provider = 'razorpay';
} else {
  profile.payment_provider = 'stripe';
}
```

## 🗄️ **Database Schema:**

### **Updated profiles table:**
```sql
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  -- Payment provider selection
  payment_provider TEXT DEFAULT 'razorpay' CHECK (
    payment_provider IN ('stripe', 'razorpay')
  ),
  
  -- Stripe fields (for international)
  stripe_account_id TEXT,
  stripe_account_verified BOOLEAN DEFAULT FALSE,
  
  -- Razorpay fields (for India)
  razorpay_account_id TEXT,
  razorpay_account_verified BOOLEAN DEFAULT FALSE,
  
  -- Bank details (for Razorpay users)
  bank_account_number TEXT,
  bank_ifsc TEXT,
  bank_account_holder_name TEXT,
  
  -- Wallet balance
  wallet_balance DECIMAL(10,2) DEFAULT 0.00;
```

## 🚀 **Withdraw Screen Implementation:**

### **1. Withdraw Button Widget:**
```dart
class WithdrawButton extends StatefulWidget {
  const WithdrawButton({super.key});

  @override
  State<WithdrawButton> createState() => _WithdrawButtonState();
}

class _WithdrawButtonState extends State<WithdrawButton> {
  String _status = 'idle'; // idle, verifying, processing
  
  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepository.instance.currentProfile;
    final balance = profile.walletBalance;
    
    if (balance <= 0) {
      return ElevatedButton(
        onPressed: null,
        child: Text('No balance to withdraw'),
      );
    }
    
    return _buildButtonByStatus(balance);
  }
  
  Widget _buildButtonByStatus(double balance) {
    switch (_status) {
      case 'verifying':
        return ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Verifying details...'),
            ],
          ),
        );
        
      case 'processing':
        return ElevatedButton(
          onPressed: null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 8),
              Text('Processing payout...'),
            ],
          ),
        );
        
      default:
        return ElevatedButton(
          onPressed: () => _initiateWithdraw(balance),
          child: Text('Withdraw ₹${balance.toStringAsFixed(0)}'),
        );
    }
  }
}
```

### **2. Withdraw Logic:**
```dart
Future<void> _initiateWithdraw(double amount) async {
  final profile = ProfileRepository.instance.currentProfile;
  
  // Route to correct payment provider
  if (profile.paymentProvider == 'razorpay') {
    await _withdrawViaRazorpay(amount, profile);
  } else {
    await _withdrawViaStripe(amount, profile);
  }
}

// Razorpay withdrawal (India users)
Future<void> _withdrawViaRazorpay(double amount, ProfileInfo profile) async {
  // Check if bank details exist
  if (profile.bankAccountNumber == null || profile.bankIfsc == null) {
    _showAddBankDialog();
    return;
  }
  
  // Check if already verified
  if (!profile.razorpayAccountVerified) {
    await _verifyRazorpayAccount(profile);
  }
  
  // Process payout
  await _processRazorpayPayout(amount, profile);
}

// Stripe withdrawal (International users)
Future<void> _withdrawViaStripe(double amount, ProfileInfo profile) async {
  // Check if Stripe account exists
  if (profile.stripeAccountId == null) {
    await _createStripeAccount(profile);
  }
  
  // Check if verified
  if (!profile.stripeAccountVerified) {
    _showStripeVerificationRequired();
    return;
  }
  
  // Process payout
  await _processStripePayout(amount, profile);
}
```

### **3. Razorpay Implementation:**
```dart
Future<void> _verifyRazorpayAccount(ProfileInfo profile) async {
  setState(() => _status = 'verifying');
  
  try {
    // Create fund account if not exists
    if (profile.razorpayAccountId == null) {
      final accountResult = await RazorpayService.createFundAccount(
        accountNumber: profile.bankAccountNumber!,
        ifsc: profile.bankIfsc!,
        name: profile.fullName ?? 'User',
      );
      
      if (!accountResult.success) {
        throw Exception(accountResult.error);
      }
      
      // Save account ID
      await ProfileRepository.instance.updateRazorpayAccount(
        accountResult.accountId!,
      );
    }
    
    // Mark as verified (basic validation passed)
    await ProfileRepository.instance.updateRazorpayVerification(true);
    
  } catch (e) {
    _showError('Bank verification failed: $e');
    setState(() => _status = 'idle');
    return;
  }
}

Future<void> _processRazorpayPayout(double amount, ProfileInfo profile) async {
  setState(() => _status = 'processing');
  
  try {
    final payoutResult = await RazorpayService.createPayout(
      amount: amount,
      accountId: profile.razorpayAccountId!,
    );
    
    if (payoutResult.success) {
      // Deduct from wallet
      await ProfileRepository.instance.updateWalletBalance(
        profile.walletBalance - amount,
      );
      
      _showSuccess('Payout initiated! You\'ll receive ₹${amount.toStringAsFixed(0)} within 2-4 hours.');
    } else {
      _showError('Payout failed: ${payoutResult.error}');
    }
    
  } catch (e) {
    _showError('Payout failed: $e');
  } finally {
    setState(() => _status = 'idle');
  }
}
```

### **4. Stripe Implementation:**
```dart
Future<void> _createStripeAccount(ProfileInfo profile) async {
  setState(() => _status = 'verifying');
  
  try {
    final accountResult = await StripeService.createConnectAccount(
      email: profile.email!,
      country: profile.country ?? 'US',
    );
    
    if (accountResult.success) {
      await ProfileRepository.instance.updateStripeAccount(
        accountResult.accountId!,
      );
      
      // Redirect to Stripe onboarding
      _openStripeOnboarding(accountResult.onboardingUrl!);
    } else {
      throw Exception(accountResult.error);
    }
    
  } catch (e) {
    _showError('Stripe setup failed: $e');
  } finally {
    setState(() => _status = 'idle');
  }
}

Future<void> _processStripePayout(double amount, ProfileInfo profile) async {
  setState(() => _status = 'processing');
  
  try {
    final payoutResult = await StripeService.createPayout(
      amount: amount,
      accountId: profile.stripeAccountId!,
    );
    
    if (payoutResult.success) {
      // Deduct from wallet
      await ProfileRepository.instance.updateWalletBalance(
        profile.walletBalance - amount,
      );
      
      _showSuccess('Payout initiated! You\'ll receive \$${amount.toStringAsFixed(2)} within 2-7 business days.');
    } else {
      _showError('Payout failed: ${payoutResult.error}');
    }
    
  } catch (e) {
    _showError('Payout failed: $e');
  } finally {
    setState(() => _status = 'idle');
  }
}
```

## 🎯 **Payment Service Router:**

### **Clean service interface:**
```dart
class PaymentService {
  static Future<PayoutResult> withdraw({
    required double amount,
    required ProfileInfo profile,
  }) async {
    
    // Route to correct provider
    switch (profile.paymentProvider) {
      case 'razorpay':
        return await RazorpayService.processWithdraw(amount, profile);
      case 'stripe':
        return await StripeService.processWithdraw(amount, profile);
      default:
        throw Exception('Unknown payment provider: ${profile.paymentProvider}');
    }
  }
}
```

## 🎨 **UI Flow:**

### **India User (Razorpay):**
```
1. Tap "Withdraw ₹500"
2. First time: "Verifying bank details..." (2-3 seconds)
3. "Processing payout..." (1-2 seconds)
4. "✅ Payout initiated! You'll receive ₹500 within 2-4 hours."
```

### **International User (Stripe):**
```
1. Tap "Withdraw $50"
2. First time: Redirect to Stripe onboarding
3. After setup: "Processing payout..." (1-2 seconds)  
4. "✅ Payout initiated! You'll receive $50 within 2-7 business days."
```

## 💡 **Key Benefits:**

- ✅ **One provider per user** - no confusion
- ✅ **Clean routing logic** - simple if/else
- ✅ **Lazy verification** - only when needed
- ✅ **Provider-specific UX** - tailored messages
- ✅ **No double charges** - impossible by design

This is the **clean, simple approach** that scales perfectly! 🚀

Want me to implement the actual withdraw screen UI next?
