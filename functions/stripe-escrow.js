const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');

// All secrets are loaded from .env (local) or Firebase Secret Manager (deployed).
// Do NOT use the deprecated functions.config() API.
const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
if (!stripeSecretKey) {
  console.warn('Missing STRIPE_SECRET_KEY - Stripe functions will not work');
}
const stripe = stripeSecretKey ? require('stripe')(stripeSecretKey) : null;

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceRoleKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseServiceRoleKey) {
  console.warn('Missing Supabase config - Database functions will not work');
}

const supabase = (supabaseUrl && supabaseServiceRoleKey) 
  ? createClient(supabaseUrl, supabaseServiceRoleKey, {
      auth: { persistSession: false },
    })
  : null;

const stripeSupabaseSecrets = [
  'STRIPE_SECRET_KEY',
  'STRIPE_WEBHOOK_SECRET',
  'SUPABASE_URL',
  'SUPABASE_SERVICE_ROLE_KEY',
];
const stripeSupabaseRuntime = functions.runWith({
  secrets: stripeSupabaseSecrets,
});

async function _getAuthUid(req) {
  const header = req.headers?.authorization || req.headers?.Authorization;
  if (!header || typeof header !== 'string') return null;
  const m = header.match(/^Bearer\s+(.+)$/i);
  if (!m) return null;
  const token = m[1];
  if (!token) return null;
  const decoded = await admin.auth().verifyIdToken(token);
  return decoded?.uid ?? null;
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

function _stripeCountryCode(country) {
  if (typeof country !== 'string' || country.trim() === '') return null;
  const normalized = country.trim();
  if (/^[a-z]{2}$/i.test(normalized)) return normalized.toUpperCase();

  const countryMap = {
    'United States': 'US',
    'United Kingdom': 'GB',
    Australia: 'AU',
    Canada: 'CA',
    Singapore: 'SG',
    UAE: 'AE',
    'United Arab Emirates': 'AE',
    Germany: 'DE',
    France: 'FR',
    Japan: 'JP',
    'New Zealand': 'NZ',
    Ireland: 'IE',
    Netherlands: 'NL',
    Switzerland: 'CH',
    Sweden: 'SE',
    Norway: 'NO',
    Denmark: 'DK',
    Finland: 'FI',
    Belgium: 'BE',
    Austria: 'AT',
    Portugal: 'PT',
    Italy: 'IT',
    Spain: 'ES',
    Poland: 'PL',
    'Czech Republic': 'CZ',
    Hungary: 'HU',
    Romania: 'RO',
    'South Africa': 'ZA',
    Brazil: 'BR',
    Mexico: 'MX',
    Malaysia: 'MY',
    Thailand: 'TH',
    Philippines: 'PH',
    Indonesia: 'ID',
    'South Korea': 'KR',
    'Hong Kong': 'HK',
    India: 'IN',
  };

  return countryMap[normalized] || null;
}

/**
 * Create Stripe Connect Express account and onboarding link for a provider.
 */
exports.createConnectedAccount = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const { email, country, user_id, return_url, refresh_url } = req.body;

  if (!email || !country || !user_id) {
    return res.status(400).json({ error: 'Missing email, country, or user_id' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    if (!stripe) {
      return res.status(500).json({ error: 'Stripe is not configured' });
    }

    const countryCode = _stripeCountryCode(country);
    if (!countryCode) {
      return res.status(400).json({ error: 'Unsupported or unknown Stripe country' });
    }

    const account = await stripe.accounts.create({
      type: 'express',
      country: countryCode,
      email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      metadata: { firebase_uid: user_id },
    });

    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: refresh_url || 'https://vervestrideal.com/stripe-refresh',
      return_url: return_url || 'https://vervestrideal.com/stripe-return',
      type: 'account_onboarding',
    });

    res.json({
      account_id: account.id,
      url: accountLink.url,
    });
  } catch (error) {
    console.error('createConnectedAccount error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Create booking with escrow payment
 * Called when user books a post
 */
exports.createBooking = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  // Enable CORS
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  const {
    user_id,
    provider_id,
    post_id,
    slot_id,
    amount,
    currency,
    commission_amount,
    countdown_hours,
  } = req.body;

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const parsedAmount = _toInt(amount);
  const parsedCommission = _toInt(commission_amount) ?? 0;
  const parsedCountdownHours = _toInt(countdown_hours);
  const normalizedCurrency =
    typeof currency === 'string' && currency.trim() !== ''
      ? currency.trim().toLowerCase()
      : 'inr';

  if (!user_id || !provider_id || (!post_id && !slot_id)) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
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
    const referenceId = slot_id || post_id;
    const paymentIntent = await stripe.paymentIntents.create(
      {
        amount: parsedAmount,
        currency: normalizedCurrency,
        capture_method: 'manual',
        metadata: {
          user_id: user_id,
          provider_id: provider_id,
          ...(post_id ? { post_id: post_id } : {}),
          ...(slot_id ? { slot_id: slot_id } : {}),
        },
      },
      {
        idempotencyKey: `pi:${user_id}:${provider_id}:${referenceId}:${parsedAmount}:${normalizedCurrency}`,
      },
    );

    // Calculate countdown end time
    const countdownEndTime = new Date();
    countdownEndTime.setHours(countdownEndTime.getHours() + parsedCountdownHours);

    // Create booking in Supabase (OTP will be auto-generated by database trigger)
    const countdownIso = countdownEndTime.toISOString();
    const createdIso = new Date().toISOString();
    const insertPayload = {
      user_id: user_id,
      provider_id: provider_id,
      ...(post_id ? { post_id: post_id } : {}),
      ...(slot_id ? { slot_id: slot_id } : {}),
      stripe_payment_intent_id: paymentIntent.id,
      amount: parsedAmount,
      currency: normalizedCurrency,
      commission_amount: parsedCommission,
      // otp: NOT provided - will be auto-generated by Supabase trigger for security
      otp_verified: false,
      countdown_end_time: countdownIso,
      status: 'pending',
      created_at: createdIso,
    };

    const { data: insertedBooking, error: insertError } = await supabase
      .from('bookings')
      .insert(insertPayload)
      .select('id, otp')
      .single();

    if (insertError) {
      console.error('Supabase insert booking error:', insertError);
      throw new Error('Failed to create booking');
    }

    const bookingId = insertedBooking?.id;
    const otp = insertedBooking?.otp;
    if (!bookingId) {
      throw new Error('Failed to create booking');
    }

    // Send OTP to provider (via notification/SMS)
    // TODO: Implement notification service
    console.log(`OTP for booking ${bookingId}: ${otp}`);

    res.json({
      success: true,
      booking_id: bookingId,
      payment_intent_id: paymentIntent.id,
      client_secret: paymentIntent.client_secret,
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
exports.verifyOtp = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  const { booking_id, otp } = req.body;

  if (!booking_id || !otp) {
    return res.status(400).json({ error: 'Missing booking_id or otp' });
  }

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  try {
    const nowIso = new Date().toISOString();

    // Load booking first to check provider ownership (auth)
    const { data: existingBooking, error: bookingGetError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', booking_id)
      .maybeSingle();

    if (bookingGetError) {
      console.error('Supabase get booking error:', bookingGetError);
      throw Object.assign(new Error('Booking not found'), { code: 404 });
    }
    if (!existingBooking) {
      throw Object.assign(new Error('Booking not found'), { code: 404 });
    }
    if (existingBooking.provider_id !== callerUid) {
      return res.status(403).json({ error: 'Forbidden' });
    }

    // Verify OTP with fraud detection (max 4 attempts)
    const { data: otpResult, error: otpError } = await supabase
      .rpc('verify_otp_with_fraud_check', {
        p_booking_id: booking_id,
        p_otp: otp,
      })
      .single();

    if (otpError) {
      console.error('OTP verification error:', otpError);
      throw new Error('Failed to verify OTP');
    }

    if (!otpResult.success) {
      return res.status(400).json({
        error: otpResult.message,
        attempts_remaining: otpResult.attempts_remaining,
        booking_closed: otpResult.booking_closed,
      });
    }

    // OTP verified successfully - proceed with payment capture
    const booking = existingBooking;

    // Atomic-ish lock: only move pending -> processing
    const { data: lockedBooking, error: lockError } = await supabase
      .from('bookings')
      .update({
        status: 'processing',
        processing_at: nowIso,
        otp_verified: true,
      })
      .eq('id', booking_id)
      .eq('status', 'pending')
      .gt('countdown_end_time', nowIso)
      .select('*')
      .maybeSingle();

    if (lockError) {
      console.error('Supabase lock booking error:', lockError);
      throw Object.assign(new Error('Failed to process booking'), { code: 500 });
    }
    if (!lockedBooking) {
      if (existingBooking.status !== 'pending') {
        throw Object.assign(new Error('Booking already processed'), { code: 400 });
      }
      const endTime = new Date(existingBooking.countdown_end_time);
      if (new Date() > endTime) {
        throw Object.assign(new Error('Booking expired'), { code: 400 });
      }
      throw Object.assign(new Error('Failed to lock booking'), { code: 400 });
    }

    const { data: providerRow, error: providerError } = await supabase
      .from('profiles')
      .select('stripe_account_id')
      .eq('id', booking.provider_id)
      .maybeSingle();

    if (providerError) {
      console.error('Supabase get provider error:', providerError);
    }
    const providerStripeAccountId = providerRow?.stripe_account_id;

    if (!providerStripeAccountId) {
      await supabase
        .from('bookings')
        .update({
          status: 'payout_missing',
          payout_error: 'Provider has not set up payout account',
        })
        .eq('id', booking_id);
      return res
        .status(400)
        .json({ error: 'Provider has not set up payout account' });
    }

    const paymentIntent = await stripe.paymentIntents.retrieve(
      booking.stripe_payment_intent_id,
    );

    if (paymentIntent.status !== 'requires_capture') {
      await supabase
        .from('bookings')
        .update({
          status: 'capture_invalid_state',
          capture_error: `PaymentIntent status: ${paymentIntent.status}`,
        })
        .eq('id', booking_id);
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
      await supabase
        .from('bookings')
        .update({
          status: 'capture_failed',
          capture_error: `Captured status: ${captured.status}`,
        })
        .eq('id', booking_id);
      return res
        .status(500)
        .json({ error: `Capture failed: ${captured.status}` });
    }

    const transferAmount = booking.amount - (booking.commission_amount ?? 0);
    if (transferAmount <= 0) {
      await supabase
        .from('bookings')
        .update({
          status: 'completed',
          otp_verified: true,
          completed_at: new Date().toISOString(),
          stripe_capture_payment_intent_status: captured.status,
        })
        .eq('id', booking_id);
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

    await supabase
      .from('bookings')
      .update({
        status: 'completed',
        otp_verified: true,
        stripe_transfer_id: transfer.id,
        stripe_payment_intent_status: captured.status,
        completed_at: new Date().toISOString(),
      })
      .eq('id', booking_id);

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
exports.autoRefundExpired = stripeSupabaseRuntime.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    const nowIso = new Date().toISOString();

    try {
      // Find all pending bookings where countdown expired OR fraud suspected
      const { data: expiredRows, error: expiredError } = await supabase
        .from('bookings')
        .select('*')
        .or('and(status.eq.pending,countdown_end_time.lte.' + nowIso + '),status.eq.fraud_suspected');

      if (expiredError) {
        console.error('Supabase expired bookings query error:', expiredError);
        return;
      }

      const expiredBookings = expiredRows ?? [];
      console.log(`Found ${expiredBookings.length} expired/fraud bookings`);

      // Process each expired booking
      const refundPromises = expiredBookings.map(async (booking) => {
        const bookingId = booking.id;

        try {
          const paymentIntent = await stripe.paymentIntents.retrieve(
            booking.stripe_payment_intent_id,
          );

          const isFraud = booking.status === 'fraud_suspected';
          const cancellationReason = isFraud ? 'fraudulent' : 'abandoned';

          if (paymentIntent.status === 'requires_capture') {
            const cancelled = await stripe.paymentIntents.cancel(
              booking.stripe_payment_intent_id,
              {
                cancellation_reason: cancellationReason,
              },
            );

            await supabase
              .from('bookings')
              .update({
                status: isFraud ? 'fraud_suspected' : 'cancelled',
                stripe_payment_intent_status: cancelled.status,
                cancelled_at: new Date().toISOString(),
              })
              .eq('id', bookingId);
            console.log(`Cancelled booking ${bookingId} (${cancellationReason})`);
            return;
          }

          if (paymentIntent.status === 'succeeded') {
            const refund = await stripe.refunds.create({
              payment_intent: booking.stripe_payment_intent_id,
              amount: booking.amount,
            });

            await supabase
              .from('bookings')
              .update({
                status: 'refunded',
                stripe_refund_id: refund.id,
                refunded_at: new Date().toISOString(),
              })
              .eq('id', bookingId);

            console.log(`Refunded booking ${bookingId}`);
            return;
          }

          await supabase
            .from('bookings')
            .update({
              status: 'expired_unhandled',
              stripe_payment_intent_status: paymentIntent.status,
            })
            .eq('id', bookingId);

        } catch (error) {
          console.error(`Failed to refund booking ${bookingId}:`, error);
          // Mark as failed for manual review
          await supabase
            .from('bookings')
            .update({
              status: 'refund_failed',
              refund_error: error.message,
            })
            .eq('id', bookingId);
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
exports.refundPayment = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
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
exports.releaseFunds = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  const { payment_intent_id, provider_id, amount, commission_amount } = req.body;

  if (!payment_intent_id || !provider_id || amount == null || commission_amount == null) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // Look up the booking to get the correct currency
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('currency')
      .eq('stripe_payment_intent_id', payment_intent_id)
      .maybeSingle();

    if (bookingError) {
      console.error('releaseFunds: booking lookup error:', bookingError);
    }

    const currency = booking?.currency ?? 'usd';
    const transferAmount = _toInt(amount) - (_toInt(commission_amount) ?? 0);

    if (transferAmount <= 0) {
      return res.status(400).json({ error: 'Transfer amount must be positive' });
    }

    const transfer = await stripe.transfers.create({
      amount: transferAmount,
      currency: currency,
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

/**
 * Create Stripe Checkout Session for web payments
 * Called when web users want to pay
 */
exports.createCheckoutSession = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  const {
    user_id,
    provider_id,
    post_id,
    slot_id,
    amount,
    currency,
    commission_amount,
    success_url,
    cancel_url,
  } = req.body;

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const parsedAmount = _toInt(amount);
  const parsedCommission = _toInt(commission_amount) ?? 0;
  const normalizedCurrency =
    typeof currency === 'string' && currency.trim() !== ''
      ? currency.trim().toLowerCase()
      : 'inr';

  if (!user_id || !provider_id || (!post_id && !slot_id)) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }
  if (parsedAmount === null || parsedAmount <= 0) {
    return res.status(400).json({ error: 'Invalid amount' });
  }
  if (parsedCommission < 0 || parsedCommission > parsedAmount) {
    return res.status(400).json({ error: 'Invalid commission_amount' });
  }

  try {
    // Calculate countdown end time (1 hour from now)
    const countdownEndTime = new Date();
    countdownEndTime.setHours(countdownEndTime.getHours() + 1);

    // Create pending booking in Supabase FIRST to get booking_id
    // OTP will be auto-generated by database trigger
    const countdownIso = countdownEndTime.toISOString();
    const createdIso = new Date().toISOString();
    
    // Create a temporary payment intent ID placeholder
    const tempPaymentIntentId = `temp_${user_id}_${Date.now()}`;
    
    const insertPayload = {
      user_id: user_id,
      provider_id: provider_id,
      ...(post_id ? { post_id: post_id } : {}),
      ...(slot_id ? { slot_id: slot_id } : {}),
      stripe_payment_intent_id: tempPaymentIntentId,
      amount: parsedAmount,
      currency: normalizedCurrency,
      commission_amount: parsedCommission,
      // otp: NOT provided - will be auto-generated by Supabase trigger for security
      otp_verified: false,
      countdown_end_time: countdownIso,
      status: 'pending',
      created_at: createdIso,
    };

    const { data: insertedBooking, error: insertError } = await supabase
      .from('bookings')
      .insert(insertPayload)
      .select('id, otp')
      .single();

    if (insertError) {
      console.error('Supabase insert booking error:', insertError);
      throw new Error('Failed to create booking');
    }

    const bookingId = insertedBooking?.id;
    const otp = insertedBooking?.otp;
    if (!bookingId) {
      throw new Error('Failed to create booking');
    }

    // Now create Stripe Checkout Session with booking_id in success_url
    const defaultSuccessUrl = `https://vaultwheels.web.app/#/payment-success?booking_id=${bookingId}`;
    const defaultCancelUrl = `https://vaultwheels.web.app/#/payment-cancel?booking_id=${bookingId}`;
    
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: normalizedCurrency,
            product_data: {
              name: 'Booking Payment',
              description: slot_id ? `Slot: ${slot_id}` : `Post: ${post_id}`,
            },
            unit_amount: parsedAmount,
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: success_url || defaultSuccessUrl,
      cancel_url: cancel_url || defaultCancelUrl,
      metadata: {
        booking_id: bookingId,
        user_id: user_id,
        provider_id: provider_id,
        ...(post_id ? { post_id: post_id } : {}),
        ...(slot_id ? { slot_id: slot_id } : {}),
        commission_amount: parsedCommission.toString(),
        countdown_end_time: countdownEndTime.toISOString(),
      },
      payment_intent_data: {
        capture_method: 'manual',
        metadata: {
          booking_id: bookingId,
          user_id: user_id,
          provider_id: provider_id,
          ...(post_id ? { post_id: post_id } : {}),
          ...(slot_id ? { slot_id: slot_id } : {}),
        },
      },
    });

    // Update booking with actual payment_intent_id
    await supabase
      .from('bookings')
      .update({ stripe_payment_intent_id: session.payment_intent })
      .eq('id', bookingId);

    console.log(`Created checkout session for booking ${bookingId}`);

    res.json({
      success: true,
      booking_id: bookingId,
      url: session.url,
      session_id: session.id,
      payment_intent: session.payment_intent,
      countdown_end_time: countdownEndTime.toISOString(),
    });
  } catch (error) {
    console.error('Create checkout session error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Create Stripe Checkout Session for subscription plan payments.
 * This does not create a booking or escrow hold.
 */
exports.createSubscriptionCheckoutSession = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const {
    user_id,
    plan_name,
    amount,
    currency,
    success_url,
    cancel_url,
  } = req.body;

  if (!user_id || !plan_name) {
    return res.status(400).json({ error: 'Missing user_id or plan_name' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  const parsedAmount = _toInt(amount);
  const normalizedCurrency =
    typeof currency === 'string' && currency.trim() !== ''
      ? currency.trim().toLowerCase()
      : 'usd';

  if (parsedAmount === null || parsedAmount <= 0) {
    return res.status(400).json({ error: 'Invalid amount' });
  }

  try {
    if (!stripe) {
      return res.status(500).json({ error: 'Stripe is not configured' });
    }

    const encodedPlanName = encodeURIComponent(plan_name);
    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price_data: {
            currency: normalizedCurrency,
            product_data: {
              name: `${plan_name} Plan`,
              description: 'QuickOHunt subscription plan',
            },
            unit_amount: parsedAmount,
          },
          quantity: 1,
        },
      ],
      mode: 'payment',
      success_url: success_url || `https://vaultwheels.web.app/#/payment-success?type=subscription&plan=${encodedPlanName}`,
      cancel_url: cancel_url || 'https://vaultwheels.web.app/#/payment-cancel?type=subscription',
      metadata: {
        user_id,
        plan_name,
        type: 'subscription',
      },
    });

    res.json({
      success: true,
      url: session.url,
      session_id: session.id,
      payment_intent: session.payment_intent,
    });
  } catch (error) {
    console.error('createSubscriptionCheckoutSession error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Stripe Webhook handler
 * Handles checkout.session.completed to confirm web payments
 * and payment_intent.canceled to mark expired/cancelled bookings.
 *
 * Set your webhook secret in Firebase config:
 *   firebase functions:config:set stripe.webhook_secret="whsec_..."
 */
exports.stripeWebhook = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!webhookSecret) {
    console.error('Missing STRIPE_WEBHOOK_SECRET');
    return res.status(500).json({ error: 'Webhook secret not configured' });
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(
      req.rawBody,
      req.headers['stripe-signature'],
      webhookSecret,
    );
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).json({ error: `Webhook error: ${err.message}` });
  }

  try {
    switch (event.type) {
      // Web checkout: user completed payment on Stripe-hosted page
      case 'checkout.session.completed': {
        const session = event.data.object;
        if (session.metadata?.type === 'subscription') {
          console.log(`Subscription checkout completed for user ${session.metadata?.user_id}`);
          break;
        }

        const bookingId = session.metadata?.booking_id;
        const paymentIntentId = session.payment_intent;

        if (!bookingId || !paymentIntentId) {
          console.warn('checkout.session.completed: missing booking_id or payment_intent in metadata');
          break;
        }

        // Update booking with real payment_intent_id and mark as authorized
        const { error } = await supabase
          .from('bookings')
          .update({
            stripe_payment_intent_id: paymentIntentId,
            payment_status: 'authorized',
            status: 'pending',
          })
          .eq('id', bookingId);

        if (error) {
          console.error('stripeWebhook: failed to update booking after checkout:', error);
        } else {
          console.log(`Booking ${bookingId} confirmed via checkout session`);
        }
        break;
      }

      // Payment intent cancelled (expired or abandoned)
      case 'payment_intent.canceled': {
        const pi = event.data.object;
        const bookingId = pi.metadata?.booking_id;

        if (!bookingId) break;

        const { error } = await supabase
          .from('bookings')
          .update({
            status: 'cancelled',
            payment_status: 'failed',
            cancelled_at: new Date().toISOString(),
          })
          .eq('id', bookingId)
          .in('status', ['pending']);

        if (error) {
          console.error('stripeWebhook: failed to cancel booking:', error);
        } else {
          console.log(`Booking ${bookingId} cancelled via webhook`);
        }
        break;
      }

      // Payment refunded
      case 'charge.refunded': {
        const charge = event.data.object;
        const pi = charge.payment_intent;
        if (!pi) break;

        const { error } = await supabase
          .from('bookings')
          .update({
            status: 'refunded',
            payment_status: 'refunded',
            refunded_at: new Date().toISOString(),
          })
          .eq('stripe_payment_intent_id', pi)
          .in('status', ['pending', 'cancelled', 'expired_unhandled']);

        if (error) {
          console.error('stripeWebhook: failed to mark booking refunded:', error);
        }
        break;
      }

      default:
        // Unhandled event type — ignore
        break;
    }

    res.json({ received: true });
  } catch (err) {
    console.error('Webhook handler error:', err);
    res.status(500).json({ error: err.message });
  }
});

/**
 * Initiate Stripe payout to provider's connected account
 * Called from WithdrawScreen for international providers
 */
exports.initiateStripePayout = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const { user_id, stripe_account_id } = req.body;

  if (!user_id || !stripe_account_id) {
    return res.status(400).json({ error: 'Missing user_id or stripe_account_id' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    // Sum all completed bookings with pending payout for this provider
    const { data: bookings, error: bookingsError } = await supabase
      .from('bookings')
      .select('id, amount, commission_amount, currency')
      .eq('provider_id', user_id)
      .eq('status', 'completed')
      .eq('payout_status', 'pending');

    if (bookingsError) throw new Error(bookingsError.message);
    if (!bookings || bookings.length === 0) {
      return res.status(400).json({ error: 'No pending earnings to withdraw' });
    }

    // Group by currency and transfer each
    const byCurrency = {};
    for (const b of bookings) {
      const cur = (b.currency || 'usd').toLowerCase();
      const net = (b.amount || 0) - (b.commission_amount || 0);
      byCurrency[cur] = (byCurrency[cur] || 0) + net;
    }

    const transfers = [];
    for (const [currency, amount] of Object.entries(byCurrency)) {
      if (amount <= 0) continue;
      const transfer = await stripe.transfers.create({
        amount: Math.trunc(amount),
        currency,
        destination: stripe_account_id,
      });
      transfers.push(transfer.id);
    }

    // Mark bookings as payout processed
    const bookingIds = bookings.map((b) => b.id);
    await supabase
      .from('bookings')
      .update({
        payout_status: 'processed',
        payout_triggered_at: new Date().toISOString(),
        payout_completed_at: new Date().toISOString(),
      })
      .in('id', bookingIds);

    res.json({ success: true, transfers });
  } catch (error) {
    console.error('initiateStripePayout error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Initiate Razorpay payout to provider's bank account
 * Called from WithdrawScreen for Indian providers
 */
exports.initiateRazorpayPayout = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  let callerUid = null;
  try {
    callerUid = await _getAuthUid(req);
  } catch (e) {
    return res.status(401).json({ error: 'Invalid auth token' });
  }
  if (!callerUid) {
    return res.status(401).json({ error: 'Missing auth token' });
  }

  const { user_id, razorpay_account_id } = req.body;

  if (!user_id || !razorpay_account_id) {
    return res.status(400).json({ error: 'Missing user_id or razorpay_account_id' });
  }
  if (callerUid !== user_id) {
    return res.status(403).json({ error: 'Forbidden' });
  }

  try {
    // Sum all completed INR bookings with pending payout
    const { data: bookings, error: bookingsError } = await supabase
      .from('bookings')
      .select('id, amount, commission_amount')
      .eq('provider_id', user_id)
      .eq('status', 'completed')
      .eq('payout_status', 'pending')
      .ilike('currency', 'inr');

    if (bookingsError) throw new Error(bookingsError.message);
    if (!bookings || bookings.length === 0) {
      return res.status(400).json({ error: 'No pending earnings to withdraw' });
    }

    const totalPaise = bookings.reduce((sum, b) => {
      return sum + ((b.amount || 0) - (b.commission_amount || 0));
    }, 0);

    if (totalPaise <= 0) {
      return res.status(400).json({ error: 'No positive balance to withdraw' });
    }

    const razorpayKeyId = process.env.RAZORPAY_KEY_ID;
    const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET;

    if (!razorpayKeyId || !razorpayKeySecret) {
      return res.status(500).json({ error: 'Razorpay credentials not configured' });
    }

    const auth = Buffer.from(`${razorpayKeyId}:${razorpayKeySecret}`).toString('base64');

    // Create Razorpay payout via Payouts API
    const payoutResponse = await fetch('https://api.razorpay.com/v1/payouts', {
      method: 'POST',
      headers: {
        'Authorization': `Basic ${auth}`,
        'Content-Type': 'application/json',
        'X-Payout-Idempotency': `payout_${user_id}_${Date.now()}`,
      },
      body: JSON.stringify({
        account_number: razorpay_account_id, // Provider's Razorpay linked account
        amount: Math.trunc(totalPaise),
        currency: 'INR',
        mode: 'IMPS',
        purpose: 'payout',
        queue_if_low_balance: true,
        narration: 'VaultWheels earnings payout',
      }),
    });

    if (!payoutResponse.ok) {
      const errText = await payoutResponse.text();
      console.error('Razorpay payout error:', errText);
      return res.status(500).json({ error: 'Razorpay payout failed' });
    }

    const payout = await payoutResponse.json();

    // Mark bookings as payout processed
    const bookingIds = bookings.map((b) => b.id);
    await supabase
      .from('bookings')
      .update({
        payout_status: 'processed',
        payout_reference_id: payout.id,
        payout_triggered_at: new Date().toISOString(),
        payout_completed_at: new Date().toISOString(),
      })
      .in('id', bookingIds);

    res.json({ success: true, payout_id: payout.id });
  } catch (error) {
    console.error('initiateRazorpayPayout error:', error);
    res.status(500).json({ error: error.message });
  }
});
