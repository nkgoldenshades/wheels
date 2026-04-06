# 💳 Payment Provider Implementation - Proper Usage

## 🎯 **Step 1: Set Provider at Signup**

### **Update ProfileRepository to set provider:**
```dart
// In ProfileRepository.createProfile()
Future<void> createProfile({
  required String uid,
  required String email,
  String? fullName,
  String? country,
}) async {
  // Determine payment provider based on country
  final paymentProvider = (country == 'IN' || country == 'India') 
      ? 'razorpay' 
      : 'stripe';
  
  final profileData = {
    'id': uid,
    'email': email,
    'full_name': fullName,
    'country': country,
    'payment_provider': paymentProvider, // ✅ Set provider
    'created_at': DateTime.now().toIso8601String(),
  };
  
  await supabase.from('profiles').insert(profileData);
}
```

## 🎯 **Step 2: Create Account When Needed (Not at Signup)**

### **Lazy Account Creation Service:**
```dart
class PaymentAccountService {
  
  // Create Stripe account when user first tries to withdraw
  static Future<String?> ensureStripeAccount(ProfileInfo profile) async {
    // Check if already exists
    if (profile.stripeAccountId != null) {
      return profile.stripeAccountId;
    }
    
    try {
      // Create Stripe Connect account
      final response = await http.post(
        Uri.parse('https://api.stripe.com/v1/accounts'),
        headers: {
          'Authorization': 'Bearer ${StripeConfig.secretKey}',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'type': 'express',
          'country': profile.country ?? 'US',
          'email': profile.email,
          'capabilities[transfers][requested]': 'true',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accountId = data['id'];
        
        // Save to database
        await ProfileRepository.instance.updateStripeAccount(accountId);
        
        return accountId;
      } else {
        throw Exception('Failed to create Stripe account');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Stripe account creation failed: $e');
      return null;
    }
  }
  
  // Create Razorpay account when user first adds bank details
  static Future<String?> ensureRazorpayAccount({
    required ProfileInfo profile,
    required String accountNumber,
    required String ifsc,
  }) async {
    // Check if already exists
    if (profile.razorpayAccountId != null) {
      return profile.razorpayAccountId;
    }
    
    try {
      // Step 1: Create contact
      final contactResponse = await http.post(
        Uri.parse('https://api.razorpay.com/v1/contacts'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': profile.fullName ?? 'User',
          'email': profile.email,
          'contact': profile.phoneNumber ?? '',
          'type': 'vendor',
        }),
      );
      
      if (contactResponse.statusCode != 200) {
        throw Exception('Failed to create Razorpay contact');
      }
      
      final contactData = jsonDecode(contactResponse.body);
      final contactId = contactData['id'];
      
      // Step 2: Create fund account
      final accountResponse = await http.post(
        Uri.parse('https://api.razorpay.com/v1/fund_accounts'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${RazorpayConfig.keyId}:${RazorpayConfig.keySecret}'))}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contact_id': contactId,
          'account_type': 'bank_account',
          'bank_account': {
            'name': profile.fullName ?? 'User',
            'ifsc': ifsc,
            'account_number': accountNumber,
          },
        }),
      );
      
      if (accountResponse.statusCode == 200) {
        final accountData = jsonDecode(accountResponse.body);
        final accountId = accountData['id'];
        
        // Save to database
        await ProfileRepository.instance.updateRazorpayAccount(accountId);
        
        return accountId;
      } else {
        throw Exception('Failed to create Razorpay fund account');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Razorpay account creation failed: $e');
      return null;
    }
  }
}
```

## 🎯 **Step 3: Check Before Payout**

### **Withdraw Screen Logic:**
```dart
class WithdrawScreen extends StatefulWidget {
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  String _status = 'idle';
  
  Future<void> _initiateWithdraw() async {
    final profile = ProfileRepository.instance.currentProfile;
    
    // Route based on payment provider
    if (profile.paymentProvider == 'stripe') {
      await _handleStripeWithdraw(profile);
    } else if (profile.paymentProvider == 'razorpay') {
      await _handleRazorpayWithdraw(profile);
    } else {
      _showError('Payment provider not set. Please contact support.');
    }
  }
  
  Future<void> _handleStripeWithdraw(ProfileInfo profile) async {
    // Check if Stripe account exists
    if (profile.stripeAccountId == null) {
      setState(() => _status = 'setting_up');
      
      final accountId = await PaymentAccountService.ensureStripeAccount(profile);
      if (accountId == null) {
        _showError('Failed to set up Stripe account');
        setState(() => _status = 'idle');
        return;
      }
    }
    
    // Check if account is verified
    if (!await _isStripeAccountVerified(profile.stripeAccountId!)) {
      _showStripeOnboardingRequired();
      return;
    }
    
    // Process payout
    await _processStripePayout(profile);
  }
  
  Future<void> _handleRazorpayWithdraw(ProfileInfo profile) async {
    // Check if bank details are needed
    if (profile.razorpayAccountId == null) {
      _showBankDetailsDialog();
      return;
    }
    
    // Process payout
    await _processRazorpayPayout(profile);
  }
  
  void _showBankDetailsDialog() {
    showDialog(
      context: context,
      builder: (context) => BankDetailsDialog(
        onSubmit: (accountNumber, ifsc) async {
          setState(() => _status = 'setting_up');
          
          final profile = ProfileRepository.instance.currentProfile;
          final accountId = await PaymentAccountService.ensureRazorpayAccount(
            profile: profile,
            accountNumber: accountNumber,
            ifsc: ifsc,
          );
          
          if (accountId != null) {
            // Proceed with payout
            await _processRazorpayPayout(profile);
          } else {
            _showError('Failed to verify bank details');
            setState(() => _status = 'idle');
          }
        },
      ),
    );
  }
}
```

## 🎯 **Step 4: Secure Implementation (No Sensitive Data Storage)**

### **ProfileRepository Updates:**
```dart
class ProfileRepository {
  
  // ✅ Store only account IDs, not sensitive data
  Future<void> updateStripeAccount(String accountId) async {
    await supabase
        .from('profiles')
        .update({
          'stripe_account_id': accountId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', currentProfile.id);
    
    // Update local cache
    _currentProfile = _currentProfile?.copyWith(stripeAccountId: accountId);
    notifyListeners();
  }
  
  Future<void> updateRazorpayAccount(String accountId) async {
    await supabase
        .from('profiles')
        .update({
          'razorpay_account_id': accountId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', currentProfile.id);
    
    // Update local cache
    _currentProfile = _currentProfile?.copyWith(razorpayAccountId: accountId);
    notifyListeners();
  }
  
  // ❌ DO NOT store sensitive bank details
  // Let Razorpay/Stripe handle all sensitive data
}
```

## 🎯 **Step 5: Database Schema Update**

### **Clean profiles table (no sensitive data):**
```sql
-- Add payment provider columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS
  payment_provider TEXT DEFAULT 'razorpay' CHECK (
    payment_provider IN ('stripe', 'razorpay')
  ),
  stripe_account_id TEXT,
  razorpay_account_id TEXT,
  wallet_balance DECIMAL(10,2) DEFAULT 0.00;

-- ❌ DO NOT add these columns (security risk):
-- bank_account_number TEXT,  -- Let Razorpay store this
-- bank_ifsc TEXT,            -- Let Razorpay store this
-- stripe_bank_token TEXT,    -- Let Stripe store this
```

## 🎯 **Step 6: Country Detection at Signup**

### **Update registration flow:**
```dart
// In RegisterScreen or ProfileSetup
Future<void> _completeRegistration() async {
  // Detect country (you can use IP geolocation or ask user)
  final country = await _detectUserCountry(); // 'IN' or 'US' etc.
  
  await ProfileRepository.instance.createProfile(
    uid: FirebaseAuth.instance.currentUser!.uid,
    email: _emailController.text,
    fullName: _nameController.text,
    country: country, // ✅ This sets payment_provider automatically
  );
}

Future<String> _detectUserCountry() async {
  // Option 1: Ask user to select
  // Option 2: Use IP geolocation
  // Option 3: Use device locale
  
  // Simple implementation:
  final locale = Localizations.localeOf(context);
  return locale.countryCode ?? 'US';
}
```

## ✅ **Final Flow:**

### **India User:**
```
1. Signup → payment_provider = 'razorpay' ✅
2. Earn money → wallet_balance increases ✅
3. First withdraw → Enter bank details → Create Razorpay account ✅
4. Future withdraws → Direct payout ✅
```

### **International User:**
```
1. Signup → payment_provider = 'stripe' ✅
2. Earn money → wallet_balance increases ✅
3. First withdraw → Create Stripe account → Onboarding ✅
4. Future withdraws → Direct payout ✅
```

This implementation is **secure, scalable, and follows best practices** - no sensitive data stored, lazy account creation, and proper provider routing! 🚀