# Firebase Functions Setup for Secure Razorpay Payments

## 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

## 2. Login to Firebase

```bash
firebase login
```

## 3. Initialize Functions (if not already done)

```bash
firebase init functions
```

Select:
- Use existing project (select your QuickOHunt project)
- Language: JavaScript
- ESLint: No (optional)
- Install dependencies: Yes

## 4. Install Dependencies

```bash
cd functions
npm install
```

## 5. Set Razorpay Configuration

```bash
firebase functions:config:set razorpay.key_id="rzp_test_SMpj1xxJxAcT6K"
firebase functions:config:set razorpay.key_secret="PZKW95oZEjcavJ5flTEZVjeU"
firebase functions:config:set razorpay.webhook_secret="YOUR_WEBHOOK_SECRET"
```

## 6. Deploy Functions

```bash
firebase deploy --only functions
```

This will deploy 3 functions:
- `createRazorpayOrder` - Creates secure order
- `verifyRazorpayPayment` - Verifies payment signature
- `razorpayWebhook` - Handles Razorpay webhooks (optional)

## 7. Get Function URLs

After deployment, you'll see URLs like:
```
https://us-central1-YOUR_PROJECT.cloudfunctions.net/createRazorpayOrder
https://us-central1-YOUR_PROJECT.cloudfunctions.net/verifyRazorpayPayment
```

## 8. Test Locally (Optional)

```bash
cd functions
npm run serve
```

This starts local emulator at http://localhost:5001

## 9. View Logs

```bash
firebase functions:log
```

## Security Notes:

✅ **Key Secret is NEVER exposed to the app**
✅ **Signature verification happens on server**
✅ **User authentication required**
✅ **Amount validation on server**

## Next Steps:

Update Flutter app to call these functions instead of client-side payment.
