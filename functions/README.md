# Quickohunt Firebase Functions (Razorpay)

## What these functions do

These HTTPS endpoints let you implement a **hold (authorize)** payment first, and then **release (capture)** after OTP.

- `razorpayCreateOrder`
  - Creates a Razorpay Order with `payment_capture: 0` (manual capture).
  - Use this order in Razorpay Checkout.

- `razorpayVerifyPayment`
  - Verifies `razorpay_order_id + razorpay_payment_id + razorpay_signature`.

- `razorpayCapturePayment`
  - Captures an authorized payment (this is your "release" step).

## Secrets

Set these secrets in Firebase Functions:

- `RAZORPAY_KEY_ID`
- `RAZORPAY_KEY_SECRET`

Example (CLI):

```bash
firebase functions:secrets:set RAZORPAY_KEY_ID
firebase functions:secrets:set RAZORPAY_KEY_SECRET
```

## Deploy

1. Replace the Firebase project id in `../.firebaserc`:

- `YOUR_FIREBASE_PROJECT_ID` -> your real project id

2. Install deps and deploy:

```bash
npm --prefix functions install
firebase deploy --only functions
```

## Endpoint payloads

### Create order

POST `https://<region>-<project>.cloudfunctions.net/razorpayCreateOrder`

```json
{
  "amount": 12500,
  "currency": "INR",
  "receipt": "booking_<bookingId>",
  "notes": {
    "bookingId": "..."
  }
}
```

Response:

```json
{
  "orderId": "order_...",
  "amount": 12500,
  "currency": "INR",
  "keyId": "rzp_test_..."
}
```

### Verify payment signature

POST `.../razorpayVerifyPayment`

```json
{
  "orderId": "order_...",
  "paymentId": "pay_...",
  "signature": "..."
}
```

### Capture payment (release)

POST `.../razorpayCapturePayment`

```json
{
  "paymentId": "pay_...",
  "amount": 12500,
  "currency": "INR"
}
```
