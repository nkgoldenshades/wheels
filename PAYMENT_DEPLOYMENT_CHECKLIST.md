# 🚀 Secure Payment Deployment Checklist

## ✅ Completed
- [x] Firebase Functions created (`functions/index.js`)
- [x] PaymentService implemented (`lib/services/payment_service.dart`)
- [x] RazorpayService configured (`lib/services/razorpay_service.dart`)
- [x] Booking flow updated with secure verification
- [x] Loading states added (creating order, verifying payment)
- [x] Error handling implemented
- [x] No diagnostic errors

## 🔧 Deployment Steps

### 1. Regenerate Razorpay Keys (CRITICAL)
⚠️ Your test keys were exposed in chat - regenerate them!

1. Go to https://dashboard.razorpay.com
2. Settings → API Keys
3. Click "Regenerate Test Key"
4. Copy new Key ID and Key Secret

### 2. Install Firebase Functions Dependencies
```bash
cd functions
npm install
```

### 3. Configure Razorpay Keys in Firebase
```bash
firebase functions:config:set razorpay.key_id="rzp_test_YOUR_NEW_KEY"
firebase functions:config:set razorpay.key_secret="YOUR_NEW_SECRET"
```

### 4. Deploy Firebase Functions
```bash
firebase deploy --only functions
```

Expected output:
```
✔ functions[createRazorpayOrder]: Successful create operation
✔ functions[verifyRazorpayPayment]: Successful create operation
✔ functions[razorpayWebhook]: Successful create operation
```

### 5. Update Flutter Dependencies
```bash
flutter pub get
```

## 🧪 Testing

### Test Card Details
```
Card Number: 4111 1111 1111 1111
Expiry: 12/25 (any future date)
CVV: 123 (any 3 digits)
OTP: 1234
```

### Test Flow
1. Run app: `flutter run`
2. Login with test account
3. Try to book a slot
4. Click "Pay & Confirm"
5. Should see: "Creating order..." spinner
6. Razorpay checkout opens
7. Enter test card details
8. Should see: "Verifying payment..." dialog
9. Booking confirmed ✅

### Monitor Logs
In separate terminal:
```bash
firebase functions:log --only createRazorpayOrder,verifyRazorpayPayment
```

Watch for:
- ✅ "Order created: order_xxx"
- ✅ "Payment verified: pay_xxx"
- ❌ Any errors

## 🔍 Troubleshooting

### "Failed to create order"
- Check Firebase Functions logs: `firebase functions:log`
- Verify Razorpay keys are set: `firebase functions:config:get`
- Check Firebase billing (Blaze plan required for external API calls)

### "Payment verification failed"
- Check signature in logs
- Verify payment ID matches order ID
- Check network connectivity

### "Verification error"
- Network timeout - user should contact support with payment ID
- Payment may have succeeded - check Razorpay dashboard
- Webhook will auto-confirm if payment succeeded

## 📊 Production Readiness

### Before Going Live:

#### 1. Switch to Live Keys
```bash
firebase functions:config:set razorpay.key_id="rzp_live_YOUR_KEY"
firebase functions:config:set razorpay.key_secret="YOUR_LIVE_SECRET"
firebase deploy --only functions
```

#### 2. Enable Firebase Blaze Plan
- Required for external API calls (Razorpay)
- Free tier: 2M function invocations/month
- After that: $0.40 per million

#### 3. Set Up Webhooks (Optional but Recommended)
1. Deploy functions
2. Get webhook URL from Firebase Console
3. Go to Razorpay Dashboard → Webhooks
4. Add URL: `https://YOUR_REGION-YOUR_PROJECT.cloudfunctions.net/razorpayWebhook`
5. Select events: `payment.captured`, `payment.failed`, `refund.created`
6. Copy webhook secret
7. Configure: `firebase functions:config:set razorpay.webhook_secret="YOUR_SECRET"`
8. Redeploy: `firebase deploy --only functions`

#### 4. Add Server-Side Amount Validation (Recommended)
See `SECURE_PAYMENT_IMPLEMENTATION.md` for Supabase integration

#### 5. Set Up Monitoring
- Firebase Console → Functions → Logs
- Set up alerts for errors
- Monitor payment success rate

## 🎯 Success Metrics

After deployment, monitor:
- Payment success rate (should be >95%)
- Verification failures (should be <1%)
- Average payment time (should be <5 seconds)
- Function errors (should be 0)

## 🆘 Support Procedures

### User Reports Payment Issue:
1. Get payment ID from user
2. Check Razorpay Dashboard → Payments
3. Check Firebase Functions logs
4. If payment succeeded but booking failed:
   - Manually create booking
   - Or trigger webhook manually

### Refund Request:
1. Go to Razorpay Dashboard
2. Find payment
3. Click "Refund"
4. Update booking status in Supabase

## 📝 Next Steps (Optional)

- [ ] Implement refund flow in app
- [ ] Add payment history screen
- [ ] Set up automated reconciliation
- [ ] Add payment analytics
- [ ] Implement partial refunds
- [ ] Add payment retry mechanism
- [ ] Set up fraud detection

## 🔐 Security Checklist

- [x] API keys stored in Firebase config (not code)
- [x] Signature verification on server
- [x] User authentication required
- [x] Order created on server
- [x] Payment verified before booking
- [ ] Amount validated against Supabase (optional)
- [ ] Webhook signature verified (when enabled)
- [ ] Rate limiting enabled (Firebase default)

## 📞 Emergency Contacts

If critical payment issue:
1. Check Firebase Functions status
2. Check Razorpay status page
3. Disable payments temporarily if needed
4. Contact Razorpay support: support@razorpay.com

---

## Quick Commands Reference

```bash
# Deploy
firebase deploy --only functions

# View logs
firebase functions:log

# View config
firebase functions:config:get

# Set config
firebase functions:config:set key="value"

# Test locally
cd functions && npm run serve

# Flutter
flutter pub get
flutter run
```

---

**Status:** Ready for testing ✅
**Next:** Deploy and test with test card
