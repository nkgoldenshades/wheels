const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { createClient } = require('@supabase/supabase-js');

// All secrets are loaded from .env (local) or Firebase Secret Manager (deployed).
// Do NOT use the deprecated functions.config() API.
const USE_LIVE_KEYS = process.env.USE_LIVE_KEYS === 'true';

const stripeSecretKey = USE_LIVE_KEYS
  ? process.env.STRIPE_SECRET_KEY_LIVE
  : process.env.STRIPE_SECRET_KEY_TEST;

if (!stripeSecretKey) {
  console.warn(`Missing STRIPE_SECRET_KEY_${USE_LIVE_KEYS ? 'LIVE' : 'TEST'} - Stripe functions will not work`);
}
const stripe = stripeSecretKey ? require('stripe')(stripeSecretKey) : null;

const supabaseUrl = process.env.SUPABASE_URL || 'https://uklltpopjovbhplbvltr.supabase.co';
// Use SERVICE_ROLE_KEY for backend operations (has full admin access)
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_ANON_KEY || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVrbGx0cG9wam92YmhwbGJ2bHRyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwNzkyNDIsImV4cCI6MjA4NzY1NTI0Mn0.tqq3okMJR9z55uPETwrhpIVoS77PwtBFeJw7T1CnRPM';

if (!supabaseUrl || !supabaseKey) {
  console.warn('Missing Supabase config - Database functions will not work');
}

const supabase = (supabaseUrl && supabaseKey)
  ? createClient(supabaseUrl, supabaseKey, {
      auth: { persistSession: false },
    })
  : null;

// v1 HTTP functions (keeping existing deployed functions as v1)
const stripeSupabaseSecrets = [
  'STRIPE_SECRET_KEY_LIVE',
  'STRIPE_SECRET_KEY_TEST',
  'USE_LIVE_KEYS',
];

// Use v1 runWith for secrets
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
exports.createConnectedAccount = functions.https.onRequest(async (req, res) => {
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

    // Fetch the account details to get default_currency
    const accountDetails = await stripe.accounts.retrieve(account.id);
    const defaultCurrency = accountDetails.default_currency
      ? accountDetails.default_currency.toUpperCase()
      : null;

    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: refresh_url || 'https://vervestrideal.com/stripe-refresh',
      return_url: return_url || 'https://vervestrideal.com/stripe-return',
      type: 'account_onboarding',
    });

    res.json({
      account_id: account.id,
      url: accountLink.url,
      currency: defaultCurrency, // ← Return currency!
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
exports.createBooking = functions.https.onRequest(async (req, res) => {
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
      profile_customer_id: user_id,
      profile_provider_id: provider_id,
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
exports.verifyOtp = functions.https.onRequest(async (req, res) => {
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
 *
 * No-show logic (lease slots with security deposit):
 * - If OTP never verified and booking end_time has passed → no-show
 * - Customer gets ride price back (amount - deposit_snapshot)
 * - Provider keeps security deposit (deposit_snapshot) as compensation
 *
 * Normal expiry (no deposit or non-lease):
 * - Full amount refunded to customer
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
          const isFraud = booking.status === 'fraud_suspected';
          const cancellationReason = isFraud ? 'fraudulent' : 'abandoned';

          // ── No-show detection ──────────────────────────────────────────────
          // If the slot end time has passed AND OTP was never verified,
          // this is a no-show. Provider keeps security deposit.
          const depositAmount = booking.deposit_snapshot
            ? Math.round(parseFloat(booking.deposit_snapshot) * 100) // paise
            : 0;
          const slotEndTime = booking.end_time
            ? new Date(booking.end_time)
            : null;
          const isNoShow = !isFraud &&
            !booking.otp_verified &&
            depositAmount > 0 &&
            slotEndTime !== null &&
            slotEndTime <= new Date();

          const totalAmountPaise = booking.amount; // already in paise
          // Ride price = total - deposit (both in paise)
          const ridePricePaise = isNoShow
            ? Math.max(0, totalAmountPaise - depositAmount)
            : totalAmountPaise;

          // ── Razorpay bookings ──────────────────────────────────────────────
          if (booking.razorpay_payment_id && !booking.stripe_payment_intent_id) {
            if (isNoShow) {
              // Refund only ride price to customer; deposit stays with provider
              console.log(`No-show booking ${bookingId}: refunding ride price ${ridePricePaise} paise, provider keeps deposit ${depositAmount} paise`);

              if (ridePricePaise > 0) {
                await getRazorpay().payments.refund(booking.razorpay_payment_id, {
                  amount: ridePricePaise,
                  notes: {
                    reason: 'no_show_ride_price_refund',
                    booking_id: bookingId,
                  },
                });
              }

              await supabase
                .from('bookings')
                .update({
                  status: 'no_show',
                  refunded_at: new Date().toISOString(),
                  refund_note: `No-show: ride price refunded (${ridePricePaise} paise), deposit kept by provider (${depositAmount} paise)`,
                })
                .eq('id', bookingId);
            } else {
              // Full refund — no deposit or not a no-show
              console.log(`Refunding full amount for Razorpay booking ${bookingId}`);
              await getRazorpay().payments.refund(booking.razorpay_payment_id, {
                amount: totalAmountPaise,
                notes: { reason: cancellationReason, booking_id: bookingId },
              });

              await supabase
                .from('bookings')
                .update({
                  status: isFraud ? 'fraud_suspected' : 'refunded',
                  refunded_at: new Date().toISOString(),
                })
                .eq('id', bookingId);
            }
            console.log(`Processed Razorpay booking ${bookingId}`);
            return;
          }

          // ── Stripe bookings ────────────────────────────────────────────────
          const paymentIntent = await stripe.paymentIntents.retrieve(
            booking.stripe_payment_intent_id,
          );

          if (paymentIntent.status === 'requires_capture') {
            // Not yet captured — cancel the hold
            const cancelled = await stripe.paymentIntents.cancel(
              booking.stripe_payment_intent_id,
              { cancellation_reason: cancellationReason },
            );

            await supabase
              .from('bookings')
              .update({
                status: isFraud ? 'fraud_suspected' : 'cancelled',
                stripe_payment_intent_status: cancelled.status,
                cancelled_at: new Date().toISOString(),
              })
              .eq('id', bookingId);
            console.log(`Cancelled Stripe booking ${bookingId} (${cancellationReason})`);
            return;
          }

          if (paymentIntent.status === 'succeeded') {
            if (isNoShow) {
              // Partial refund — ride price only
              console.log(`No-show Stripe booking ${bookingId}: refunding ${ridePricePaise} paise`);
              const refund = ridePricePaise > 0
                ? await stripe.refunds.create({
                    payment_intent: booking.stripe_payment_intent_id,
                    amount: ridePricePaise,
                  })
                : null;

              await supabase
                .from('bookings')
                .update({
                  status: 'no_show',
                  stripe_refund_id: refund?.id ?? null,
                  refunded_at: new Date().toISOString(),
                  refund_note: `No-show: ride price refunded (${ridePricePaise} paise), deposit kept by provider (${depositAmount} paise)`,
                })
                .eq('id', bookingId);
            } else {
              // Full refund
              const refund = await stripe.refunds.create({
                payment_intent: booking.stripe_payment_intent_id,
                amount: totalAmountPaise,
              });

              await supabase
                .from('bookings')
                .update({
                  status: 'refunded',
                  stripe_refund_id: refund.id,
                  refunded_at: new Date().toISOString(),
                })
                .eq('id', bookingId);
            }
            console.log(`Processed Stripe booking ${bookingId}`);
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
exports.refundPayment = functions.https.onRequest(async (req, res) => {
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
 * Manual refund with location verification
 * Called when customer clicks "Refund + Deposit" button
 * Processes immediate payment refund based on GPS verification
 */
exports.manualRefundWithLocation = stripeSupabaseRuntime.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    return res.status(204).send('');
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Get auth user
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
    booking_id,
    refund_amount,
    customer_location_verified,
    refund_type,
  } = req.body;

  if (!booking_id || !refund_amount || refund_type == null) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // Get booking details from database
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', booking_id)
      .single();

    if (bookingError || !booking) {
      console.error('Booking lookup error:', bookingError);
      return res.status(404).json({ error: 'Booking not found' });
    }

    // Security: Only customer can request refund
    if (booking.profile_customer_id !== callerUid) {
      return res.status(403).json({ error: 'Only customer can request refund' });
    }

    // Already refunded?
    if (booking.status === 'refunded') {
      return res.status(400).json({ error: 'Already refunded' });
    }

    const refundAmountPaise = Math.round(refund_amount * 100); // Convert to paise/cents

    // Process refund based on payment method
    let refundResult = null;

    // ── Razorpay refund ──
    if (booking.razorpay_payment_id) {
      console.log(`Processing Razorpay refund for booking ${booking_id}: ${refundAmountPaise} paise`);
      
      try {
        refundResult = await getRazorpay().payments.refund(
          booking.razorpay_payment_id,
          {
            amount: refundAmountPaise,
            notes: {
              reason: customer_location_verified 
                ? 'location_verified_full_refund' 
                : 'standard_refund',
              booking_id: booking_id,
              refund_type: refund_type,
            },
          },
        );

        console.log(`Razorpay refund successful: ${refundResult.id}`);

        return res.json({
          success: true,
          refund_id: refundResult.id,
          amount: refund_amount,
          gateway: 'razorpay',
          message: 'Refund processed via Razorpay',
        });
      } catch (razorpayError) {
        console.error('Razorpay refund error:', razorpayError);
        return res.status(500).json({
          error: 'Razorpay refund failed: ' + razorpayError.message,
        });
      }
    }

    // ── Stripe refund ──
    if (booking.stripe_payment_intent_id) {
      console.log(`Processing Stripe refund for booking ${booking_id}: ${refundAmountPaise} cents`);

      try {
        // Check payment intent status first
        const paymentIntent = await stripe.paymentIntents.retrieve(
          booking.stripe_payment_intent_id,
        );

        // If requires_capture, cancel instead of refund
        if (paymentIntent.status === 'requires_capture') {
          const cancelled = await stripe.paymentIntents.cancel(
            booking.stripe_payment_intent_id,
            {
              cancellation_reason: 'requested_by_customer',
            },
          );

          console.log(`Stripe payment cancelled: ${cancelled.id}`);

          return res.json({
            success: true,
            refund_id: cancelled.id,
            amount: refund_amount,
            gateway: 'stripe',
            message: 'Payment hold cancelled (not yet captured)',
          });
        }

        // If already captured/succeeded, do refund
        if (paymentIntent.status === 'succeeded') {
          refundResult = await stripe.refunds.create({
            payment_intent: booking.stripe_payment_intent_id,
            amount: refundAmountPaise,
            reason: 'requested_by_customer',
            metadata: {
              booking_id: booking_id.toString(),
              refund_type: refund_type,
              location_verified: customer_location_verified.toString(),
            },
          });

          console.log(`Stripe refund successful: ${refundResult.id}`);

          return res.json({
            success: true,
            refund_id: refundResult.id,
            amount: refund_amount,
            gateway: 'stripe',
            message: 'Refund processed via Stripe',
          });
        }

        // Payment in unexpected state
        return res.status(400).json({
          error: `Payment in unexpected state: ${paymentIntent.status}`,
        });
      } catch (stripeError) {
        console.error('Stripe refund error:', stripeError);
        return res.status(500).json({
          error: 'Stripe refund failed: ' + stripeError.message,
        });
      }
    }

    // No payment ID found
    return res.status(400).json({
      error: 'No payment information found for this booking',
    });
  } catch (error) {
    console.error('Manual refund error:', error);
    return res.status(500).json({ error: error.message });
  }
});

/**
 * Release funds manually (for admin/support)
 */
exports.releaseFunds = functions.https.onRequest(async (req, res) => {
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
exports.createCheckoutSession = functions.https.onRequest(async (req, res) => {
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

  // Get the Firebase ID token from the Authorization header
  const authHeader = req.headers?.authorization || req.headers?.Authorization;
  const firebaseToken = authHeader?.replace(/^Bearer\s+/i, '');

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
    // Don't create booking yet - just create Stripe Checkout Session
    // Booking will be created after payment succeeds (via webhook or client)
    // This matches how Razorpay works - no Supabase access needed here!
    
    if (!stripe) {
      return res.status(500).json({ error: 'Stripe is not configured' });
    }

    // Create Stripe Checkout Session with metadata for later booking creation
    const metadata = {
      user_id,
      provider_id,
      ...(post_id ? { post_id } : {}),
      ...(slot_id ? { slot_id } : {}),
      amount: parsedAmount.toString(),
      currency: normalizedCurrency,
      commission_amount: parsedCommission.toString(),
    };

    const defaultSuccessUrl = `https://vaultwheels.web.app/#/payment-success?session_id={CHECKOUT_SESSION_ID}&slot_id=${slot_id || ''}&post_id=${post_id || ''}&provider_id=${provider_id}`;
    const defaultCancelUrl = `https://vaultwheels.web.app/#/payment-cancel`;
    
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
      metadata,
      payment_intent_data: {
        capture_method: 'manual',
        metadata,
      },
      // Allow Stripe to replace {CHECKOUT_SESSION_ID} with actual session ID
      client_reference_id: user_id,
    });

    console.log(`Created checkout session: ${session.id}`);

    res.json({
      success: true,
      url: session.url,
      session_id: session.id,
      payment_intent: session.payment_intent,
    });
  } catch (error) {
    console.error('Create checkout session error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Stripe Webhook Handler
 * Handles checkout.session.completed and creates booking after payment succeeds
 */
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  // Stripe sends webhook signature for verification
  const sig = req.headers['stripe-signature'];
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;

  if (!webhookSecret) {
    console.warn('STRIPE_WEBHOOK_SECRET not configured');
    return res.status(500).send('Webhook secret not configured');
  }

  let event;
  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error(`Webhook signature verification failed: ${err.message}`);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  // Handle the event
  if (event.type === 'checkout.session.completed') {
    const session = event.data.object;
    const metadata = session.metadata || {};

    console.log(`✅ Checkout session completed: ${session.id}`);
    console.log(`   Payment intent: ${session.payment_intent}`);
    console.log(`   Metadata:`, metadata);

    // Extract booking details from metadata
    const {
      user_id,
      provider_id,
      post_id,
      slot_id,
      amount,
      currency,
      commission_amount,
    } = metadata;

    if (!user_id || !provider_id || (!post_id && !slot_id)) {
      console.error('Missing required metadata in checkout session');
      return res.status(200).json({ received: true });
    }

    const parsedAmount = parseInt(amount, 10);
    const parsedCommission = parseInt(commission_amount, 10) || 0;

    // Calculate countdown end time (1 hour from now by default)
    const countdownEndTime = new Date();
    countdownEndTime.setHours(countdownEndTime.getHours() + 1);

    try {
      // Create booking in Supabase using anon key (RLS will check auth context)
      // Since this is a server-side operation, we'll use the anon key and trust the metadata
      const insertPayload = {
        profile_customer_id: user_id,
        profile_provider_id: provider_id,
        ...(post_id ? { post_id } : {}),
        ...(slot_id ? { slot_id } : {}),
        stripe_payment_intent_id: session.payment_intent,
        amount: parsedAmount,
        currency: currency.toLowerCase(),
        commission_amount: parsedCommission,
        otp_verified: false,
        countdown_end_time: countdownEndTime.toISOString(),
        status: 'pending',
        created_at: new Date().toISOString(),
      };

      const { data: insertedBooking, error: insertError } = await supabase
        .from('bookings')
        .insert(insertPayload)
        .select('id, otp')
        .single();

      if (insertError) {
        console.error('❌ Supabase insert booking error:', insertError);
        // Don't fail the webhook - Stripe expects 200
      } else {
        console.log(`✅ Created booking ${insertedBooking?.id} for session ${session.id}`);
      }
    } catch (error) {
      console.error('❌ Error creating booking from webhook:', error);
      // Don't fail the webhook - Stripe expects 200
    }
  }

  // Return 200 to acknowledge receipt
  res.status(200).json({ received: true });
});

/**
 * Create Stripe Checkout Session for subscription plan payments.
 * This does not create a booking or escrow hold.
 */
exports.createSubscriptionCheckoutSession = functions.https.onRequest(async (req, res) => {
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
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
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
exports.initiateStripePayout = functions.https.onRequest(async (req, res) => {
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


/**
 * Auto-downgrade expired subscriptions to 'basic' plan
 * Runs daily at 2 AM UTC via scheduled trigger
 * 
 * This function calls the Supabase database function that resets
 * all expired Premium/Expert subscriptions back to 'basic' plan.
 * 
 * Security: Runs server-side only, users cannot manipulate
 * Performance: Database function uses indexed queries
 */
exports.autoDowngradeExpiredSubscriptions = functions.pubsub
  .schedule('0 2 * * *')  // Daily at 2 AM UTC
  .timeZone('UTC')
  .onRun(async (context) => {
    if (!supabase) {
      console.error('Supabase client not configured');
      return null;
    }

    try {
      console.log('🔄 Starting auto-downgrade of expired subscriptions...');
      
      const { data, error } = await supabase
        .rpc('auto_downgrade_expired_subscriptions');
      
      if (error) {
        console.error('❌ Error downgrading subscriptions:', error);
        throw error;
      }
      
      const count = data || 0;
      console.log(`✅ Successfully downgraded ${count} expired subscription(s) to basic`);
      
      return null;
    } catch (error) {
      console.error('❌ Auto-downgrade error:', error);
      return null;
    }
  });
