const functions = require('firebase-functions');
const admin = require('firebase-admin');

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
if (!stripeSecretKey) {
  throw new Error('Missing STRIPE_SECRET_KEY environment variable');
}
const stripe = require('stripe')(stripeSecretKey);

// Get Firestore instance (admin is already initialized in index.js)
const db = admin.firestore();

/**
 * Generate a 6-digit OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function _toInt(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === 'string' && value.trim() !== '') {
    const n = Number(value);
    if (Number.isFinite(n)) return Math.trunc(n);
  }
  return null;
}

/**
 * Create booking with escrow payment
 * Called when user books a post
 */
exports.createBooking = functions.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  const {
    user_id,
    provider_id,
    post_id,
    amount,
    currency,
    commission_amount,
    countdown_hours,
  } = req.body;

  const parsedAmount = _toInt(amount);
  const parsedCommission = _toInt(commission_amount) ?? 0;
  const parsedCountdownHours = _toInt(countdown_hours);
  const normalizedCurrency =
    typeof currency === 'string' && currency.trim() !== ''
      ? currency.trim().toLowerCase()
      : 'inr';

  if (!user_id || !provider_id || !post_id) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  if (parsedAmount === null || parsedAmount <= 0) {
    return res.status(400).json({ error: 'Invalid amount' });
  }
  if (parsedCommission < 0 || parsedCommission > parsedAmount) {
    return res.status(400).json({ error: 'Invalid commission_amount' });
  }
  if (parsedCountdownHours === null || parsedCountdownHours <= 0) {
    return res.status(400).json({ error: 'Invalid countdown_hours' });
  }

  try {
    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: parsedAmount,
        currency: normalizedCurrency,
        capture_method: 'manual',
      metadata: {
        user_id: user_id,
        provider_id: provider_id,
        post_id: post_id,
      },
      },
      {
        idempotencyKey: `pi:${user_id}:${provider_id}:${post_id}:${parsedAmount}:${normalizedCurrency}`,
      },
    );

    // 2. Generate OTP
    const otp = generateOTP();

    // 3. Calculate countdown end time
    const countdownEndTime = new Date();
    countdownEndTime.setHours(countdownEndTime.getHours() + parsedCountdownHours);

    // 4. Create booking in Firestore
    const bookingRef = await db.collection('bookings').add({
      user_id: user_id,
      provider_id: provider_id,
      post_id: post_id,
      stripe_payment_intent_id: paymentIntent.id,
      amount: parsedAmount,
      currency: normalizedCurrency,
      commission_amount: parsedCommission,
      otp: otp,
      countdown_end_time: admin.firestore.Timestamp.fromDate(countdownEndTime),
      status: 'pending',
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Send OTP to provider (via notification/SMS)
    // TODO: Implement notification service
    console.log(`OTP for booking ${bookingRef.id}: ${otp}`);

    res.json({
      success: true,
      booking_id: bookingRef.id,
      client_secret: paymentIntent.client_secret,
      otp: otp, // Remove this in production! Only for testing
      countdown_end_time: countdownEndTime.toISOString(),
    });
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Verify OTP and release funds to provider
 * Called when provider enters OTP
 */
exports.verifyOtp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  const { booking_id, otp } = req.body;

  if (!booking_id || !otp) {
    return res.status(400).json({ error: 'Missing booking_id or otp' });
  }

  try {
    const bookingRef = db.collection('bookings').doc(booking_id);

    const booking = await db.runTransaction(async (tx) => {
      const bookingDoc = await tx.get(bookingRef);
      if (!bookingDoc.exists) {
        throw Object.assign(new Error('Booking not found'), { code: 404 });
      }

      const b = bookingDoc.data();
      if (b.status !== 'pending') {
        throw Object.assign(new Error('Booking already processed'), { code: 400 });
      }

      const endTime = b.countdown_end_time.toDate();
      if (new Date() > endTime) {
        throw Object.assign(new Error('Booking expired'), { code: 400 });
      }

      if (b.otp !== otp) {
        throw Object.assign(new Error('Invalid OTP'), { code: 400 });
      }

      tx.update(bookingRef, {
        status: 'processing',
        processing_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      return b;
    });

    const providerDoc = await db
      .collection('users')
      .doc(booking.provider_id)
      .get();
    const providerStripeAccountId = providerDoc.data()?.stripe_account_id;

    if (!providerStripeAccountId) {
      await bookingRef.update({
        status: 'payout_missing',
        payout_error: 'Provider has not set up payout account',
      });
      return res
        .status(400)
        .json({ error: 'Provider has not set up payout account' });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(
      booking.stripe_payment_intent_id,
    );

    if (paymentIntent.status !== 'requires_capture') {
      await bookingRef.update({
        status: 'capture_invalid_state',
        capture_error: `PaymentIntent status: ${paymentIntent.status}`,
      });
      return res.status(400).json({
        error: `Payment not in capturable state: ${paymentIntent.status}`,
      });
    }

    const captured = await stripe.paymentIntents.capture(
      booking.stripe_payment_intent_id,
      {
        amount_to_capture: booking.amount,
      },
      {
        idempotencyKey: `capture:${booking_id}:${booking.stripe_payment_intent_id}`,
      },
    );

    if (captured.status !== 'succeeded') {
      await bookingRef.update({
        status: 'capture_failed',
        capture_error: `Captured status: ${captured.status}`,
      });
      return res
        .status(500)
        .json({ error: `Capture failed: ${captured.status}` });
    }

    const transferAmount = booking.amount - (booking.commission_amount ?? 0);
    if (transferAmount <= 0) {
      await bookingRef.update({
        status: 'completed',
        completed_at: admin.firestore.FieldValue.serverTimestamp(),
        stripe_capture_payment_intent_status: captured.status,
      });
      return res.json({
        success: true,
        message: 'Payment captured (no provider payout)',
      });
    }

    const transfer = await stripe.transfers.create(
      {
        amount: transferAmount,
        currency: booking.currency,
        destination: providerStripeAccountId,
        transfer_group: booking_id,
      },
      {
        idempotencyKey: `transfer:${booking_id}:${booking.stripe_payment_intent_id}:${transferAmount}`,
      },
    );

    await bookingRef.update({
      status: 'completed',
      stripe_transfer_id: transfer.id,
      stripe_payment_intent_status: captured.status,
      completed_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.json({
      success: true,
      message: 'Payment released to provider',
      transfer_id: transfer.id,
    });
  } catch (error) {
    console.error('Verify OTP error:', error);
    const code = error?.code;
    if (code === 400 || code === 404) {
      return res.status(code).json({ error: error.message });
    }
    res.status(500).json({ error: error.message });
  }
});

/**
 * Auto-refund expired bookings
 * Run this as a scheduled function every minute
 */
exports.autoRefundExpired = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const now = admin.firestore.Timestamp.now();

    try {
      // Find all pending bookings where countdown expired
      const expiredBookings = await db
        .collection('bookings')
        .where('status', '==', 'pending')
        .where('countdown_end_time', '<=', now)
        .get();

      console.log(`Found ${expiredBookings.size} expired bookings`);

      // Process each expired booking
      const refundPromises = expiredBookings.docs.map(async (doc) => {
        const booking = doc.data();
        const bookingId = doc.id;

        try {
          const paymentIntent = await stripe.paymentIntents.retrieve(
            booking.stripe_payment_intent_id,
          );

          if (paymentIntent.status === 'requires_capture') {
            const cancelled = await stripe.paymentIntents.cancel(
              booking.stripe_payment_intent_id,
              {
                cancellation_reason: 'abandoned',
              },
            );

            await doc.ref.update({
              status: 'cancelled',
              stripe_payment_intent_status: cancelled.status,
              cancelled_at: admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(`Cancelled booking ${bookingId}`);
            return;
          }

          if (paymentIntent.status === 'succeeded') {
            const refund = await stripe.refunds.create({
              payment_intent: booking.stripe_payment_intent_id,
              amount: booking.amount,
            });

            await doc.ref.update({
              status: 'refunded',
              stripe_refund_id: refund.id,
              refunded_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            console.log(`Refunded booking ${bookingId}`);
            return;
          }

          await doc.ref.update({
            status: 'expired_unhandled',
            stripe_payment_intent_status: paymentIntent.status,
          });

        } catch (error) {
          console.error(`Failed to refund booking ${bookingId}:`, error);
          // Mark as failed for manual review
          await doc.ref.update({
            status: 'refund_failed',
            refund_error: error.message,
          });
        }
      });

      await Promise.all(refundPromises);
      console.log('Auto-refund completed');
    } catch (error) {
      console.error('Auto-refund error:', error);
    }
  });

/**
 * Manual refund endpoint (for admin/support)
 */
exports.refundPayment = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  const { payment_intent_id, amount } = req.body;

  try {
    const refund = await stripe.refunds.create({
      payment_intent: payment_intent_id,
      amount: amount,
    });

    res.json({
      success: true,
      refund_id: refund.id,
    });
  } catch (error) {
    console.error('Refund error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Release funds manually (for admin/support)
 */
exports.releaseFunds = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  const { payment_intent_id, provider_id, amount, commission_amount } = req.body;

  try {
    const transferAmount = amount - commission_amount;

    const transfer = await stripe.transfers.create({
      amount: transferAmount,
      currency: 'usd',
      destination: provider_id,
    });

    res.json({
      success: true,
      transfer_id: transfer.id,
    });
  } catch (error) {
    console.error('Release funds error:', error);
    res.status(500).json({ error: error.message });
  }
});
