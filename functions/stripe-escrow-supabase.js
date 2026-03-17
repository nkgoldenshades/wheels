const functions = require('firebase-functions');
const { createClient } = require('@supabase/supabase-js');

const stripeSecretKey = process.env.STRIPE_SECRET_KEY;
if (!stripeSecretKey) {
  throw new Error('Missing STRIPE_SECRET_KEY environment variable');
}
const stripe = require('stripe')(stripeSecretKey);

// Initialize Supabase with service role key (from environment variable)
const supabase = createClient(
  'https://uklltpopjovbhplbvltr.supabase.co',
  process.env.SUPABASE_SERVICE_ROLE_KEY // Reads from .env file
);

/**
 * Generate a 6-digit OTP
 */
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

function _toInt(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number' && Number.isFinite(value)) return Math.trunc(value);
  if (typeof value === 'string' && value.trim() !== '') {
    const n = Number(value);
    if (Number.isFinite(n)) return Math.trunc(n);
  }
  return null;
}

function _normalizeCurrency(currency) {
  if (typeof currency === 'string' && currency.trim() !== '') {
    return currency.trim().toLowerCase();
  }
  return 'inr';
}

/**
 * Create booking with escrow payment (SUPABASE VERSION)
 */
exports.createBooking = functions.https.onRequest(async (req, res) => {
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

  try {
    const parsedAmount = _toInt(amount);
    const parsedCommission = _toInt(commission_amount) ?? 0;
    const parsedCountdownHours = _toInt(countdown_hours);
    const normalizedCurrency = _normalizeCurrency(currency);

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

    console.log('📝 Creating booking for user:', user_id);

    // Create Stripe PaymentIntent with deterministic idempotency key
    const paymentIntent = await stripe.paymentIntents.create({
      amount: parsedAmount,
      currency: normalizedCurrency,
      capture_method: 'manual',
      metadata: {
        user_id: user_id,
        provider_id: provider_id,
        post_id: post_id,
      },
    }, {
      idempotencyKey: `payment_intent:${user_id}:${provider_id}:${post_id}:${parsedAmount}:${normalizedCurrency}`
    });

    console.log('💳 Stripe PaymentIntent created:', paymentIntent.id);

    // Generate OTP
    const otp = generateOTP();

    // Calculate countdown end time
    const countdownEndTime = new Date();
    countdownEndTime.setHours(countdownEndTime.getHours() + parsedCountdownHours);

    // Create booking in Supabase
    const { data: booking, error } = await supabase
      .from('bookings')
      .insert({
        user_id: user_id,
        provider_id: provider_id,
        post_id: post_id,
        stripe_payment_intent_id: paymentIntent.id,
        amount: parsedAmount,
        currency: normalizedCurrency,
        commission_amount: parsedCommission,
        otp: otp,
        countdown_end_time: countdownEndTime.toISOString(),
        status: 'pending',
        refund_processing: false,
      })
      .select()
      .single();

    if (error) {
      console.error('❌ Supabase error:', error);
      throw new Error(`Database error: ${error.message}`);
    }

    console.log(`✅ Booking created: ${booking.id}`);
    console.log(`🔐 OTP: ${otp}`);

    res.json({
      success: true,
      booking_id: booking.id,
      client_secret: paymentIntent.client_secret,
      otp: otp, // Remove in production
      countdown_end_time: countdownEndTime.toISOString(),
    });
  } catch (error) {
    console.error('❌ Create booking error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Verify OTP and release funds (SUPABASE VERSION)
 */
exports.verifyOtp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  if (req.method === 'OPTIONS') {
    res.set('Access-Control-Allow-Methods', 'POST');
    res.set('Access-Control-Allow-Headers', 'Content-Type');
    return res.status(204).send('');
  }

  const { booking_id, otp } = req.body;

  try {
    console.log(`🔍 Verifying OTP for booking: ${booking_id}`);

    // Get booking
    const { data: booking, error: fetchError } = await supabase
      .from('bookings')
      .select('*')
      .eq('id', booking_id)
      .single();

    if (fetchError || !booking) {
      console.error('❌ Booking not found:', fetchError);
      return res.status(404).json({ error: 'Booking not found' });
    }

    if (booking.status !== 'pending') {
      console.log(`⚠️  Booking already processed (status: ${booking.status})`);
      return res.status(400).json({ error: 'Booking already processed' });
    }

    // Check if timer expired
    const now = new Date();
    const endTime = new Date(booking.countdown_end_time);
    if (now > endTime) {
      console.log('⏰ Booking expired');
      return res.status(400).json({ error: 'Booking expired' });
    }

    // Verify OTP
    if (booking.otp !== otp) {
      console.log('❌ Invalid OTP');
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    console.log('✅ OTP verified');

    // Acquire a processing lock to avoid double capture/transfer
    const { data: processingLock, error: processingError } = await supabase
      .from('bookings')
      .update({
        status: 'processing',
        processing_at: new Date().toISOString(),
      })
      .eq('id', booking_id)
      .eq('status', 'pending')
      .select('id')
      .single();

    if (processingError || !processingLock) {
      console.log('⚠️  Booking already being processed');
      return res.status(409).json({ error: 'Booking already being processed' });
    }

    // Get provider's Stripe account ID
    const { data: provider, error: providerError } = await supabase
      .from('users')
      .select('stripe_account_id')
      .eq('id', booking.provider_id)
      .single();

    if (providerError || !provider?.stripe_account_id) {
      console.error('❌ Provider Stripe account not found');
      return res.status(400).json({ 
        error: 'Provider has not set up payout account' 
      });
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
      { amount_to_capture: booking.amount },
      { idempotencyKey: `capture:booking:${booking_id}:${booking.stripe_payment_intent_id}` },
    );

    if (captured.status !== 'succeeded') {
      await supabase
        .from('bookings')
        .update({
          status: 'capture_failed',
          capture_error: `Captured status: ${captured.status}`,
        })
        .eq('id', booking_id);

      return res.status(500).json({ error: `Capture failed: ${captured.status}` });
    }

    const transferAmount = booking.amount - (booking.commission_amount ?? 0);
    if (transferAmount <= 0) {
      const { error: completeError } = await supabase
        .from('bookings')
        .update({
          status: 'completed',
          stripe_payment_intent_status: captured.status,
          completed_at: new Date().toISOString(),
        })
        .eq('id', booking_id);

      if (completeError) {
        throw new Error(`Update error: ${completeError.message}`);
      }

      return res.json({
        success: true,
        message: 'Payment captured (no provider payout)',
      });
    }

    console.log(`💸 Transferring ${transferAmount} to provider...`);

    const transfer = await stripe.transfers.create({
      amount: transferAmount,
      currency: booking.currency,
      destination: provider.stripe_account_id,
      transfer_group: booking_id,
      metadata: {
        booking_id: booking_id,
        provider_id: booking.provider_id,
      },
    }, {
      idempotencyKey: `transfer:booking:${booking_id}:${booking.stripe_payment_intent_id}:${transferAmount}`
    });

    console.log(`💸 Stripe transfer created: ${transfer.id}`);

    // Update booking status
    const { error: updateError } = await supabase
      .from('bookings')
      .update({
        status: 'completed',
        stripe_transfer_id: transfer.id,
        stripe_payment_intent_status: captured.status,
        completed_at: new Date().toISOString(),
      })
      .eq('id', booking_id);

    if (updateError) {
      console.error('❌ Failed to update booking:', updateError);
      throw new Error(`Update error: ${updateError.message}`);
    }

    console.log('✅ Payment released to provider');

    res.json({
      success: true,
      message: 'Payment released to provider',
      transfer_id: transfer.id,
    });
  } catch (error) {
    console.error('❌ Verify OTP error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * Auto-refund expired bookings (SUPABASE VERSION - PRODUCTION SAFE)
 */
exports.autoRefundExpired = functions.pubsub
  .schedule('every 1 minutes')
  .onRun(async (context) => {
    console.log('🔄 Running auto refund check...');
    const now = new Date().toISOString();

    try {
      // Find expired bookings
      const { data: expiredBookings, error: queryError } = await supabase
        .from('bookings')
        .select('*')
        .eq('status', 'pending')
        .lt('countdown_end_time', now);

      if (queryError) {
        console.error('❌ Query error:', queryError);
        throw queryError;
      }

      console.log(`📦 Expired bookings found: ${expiredBookings?.length || 0}`);

      if (!expiredBookings || expiredBookings.length === 0) {
        console.log('✅ No expired bookings to process');
        return null;
      }

      // Process each expired booking
      const refundPromises = expiredBookings.map(async (booking) => {
        try {
          console.log(`🔒 Processing booking: ${booking.id}`);

          // SAFETY #1: Transaction Lock
          const { data: lockResult, error: lockError } = await supabase
            .from('bookings')
            .update({ refund_processing: true })
            .eq('id', booking.id)
            .eq('status', 'pending')
            .eq('refund_processing', false)
            .select()
            .single();

          if (lockError || !lockResult) {
            console.log(`⚠️  Booking ${booking.id} already being processed`);
            return;
          }

          // SAFETY #2: Idempotency - Check Stripe
          console.log(`🔍 Checking Stripe for payment: ${booking.stripe_payment_intent_id}`);
          
          let paymentIntent;
          try {
            paymentIntent = await stripe.paymentIntents.retrieve(booking.stripe_payment_intent_id);
          } catch (stripeError) {
            console.error(`❌ Failed to retrieve payment: ${stripeError.message}`);
            
            await supabase
              .from('bookings')
              .update({
                status: 'refund_failed',
                refund_error: `Stripe retrieval failed: ${stripeError.message}`,
                refund_processing: false,
              })
              .eq('id', booking.id);
            return;
          }

          if (paymentIntent.status === 'requires_capture') {
            console.log(`🛑 Canceling uncaptured PaymentIntent for booking ${booking.id}...`);
            const cancelled = await stripe.paymentIntents.cancel(
              booking.stripe_payment_intent_id,
              { cancellation_reason: 'abandoned' },
            );

            await supabase
              .from('bookings')
              .update({
                status: 'cancelled',
                stripe_payment_intent_status: cancelled.status,
                cancelled_at: new Date().toISOString(),
                refund_processing: false,
              })
              .eq('id', booking.id);

            console.log(`✅ Booking ${booking.id} cancelled successfully`);
            return;
          }

          if (paymentIntent.status === 'succeeded') {
            const alreadyRefunded =
              typeof paymentIntent.amount_refunded === 'number' &&
              paymentIntent.amount_refunded >= paymentIntent.amount;

            if (alreadyRefunded) {
              console.log(`✅ Payment already refunded in Stripe`);
              await supabase
                .from('bookings')
                .update({
                  status: 'refunded',
                  stripe_refund_id:
                    paymentIntent.charges?.data?.[0]?.refunds?.data?.[0]?.id ||
                    'already_refunded',
                  refunded_at: new Date().toISOString(),
                  refund_processing: false,
                })
                .eq('id', booking.id);
              return;
            }

            console.log(`💸 Creating refund for booking ${booking.id}...`);
            const refund = await stripe.refunds.create({
              payment_intent: booking.stripe_payment_intent_id,
              amount: booking.amount,
              reason: 'expired',
              metadata: {
                booking_id: booking.id,
                auto_refund: 'true',
              },
            }, {
              idempotencyKey: `refund:payment_intent:${booking.stripe_payment_intent_id}`
            });

            console.log(`💸 Stripe refund created: ${refund.id}`);

            await supabase
              .from('bookings')
              .update({
                status: 'refunded',
                stripe_refund_id: refund.id,
                refunded_at: new Date().toISOString(),
                refund_processing: false,
              })
              .eq('id', booking.id);

            console.log(`✅ Booking ${booking.id} refunded successfully`);
            return;
          }

          await supabase
            .from('bookings')
            .update({
              status: 'expired_unhandled',
              stripe_payment_intent_status: paymentIntent.status,
              refund_processing: false,
            })
            .eq('id', booking.id);

          console.log(`⚠️  Booking ${booking.id} in unhandled state: ${paymentIntent.status}`);

        } catch (error) {
          console.error(`❌ Failed to refund booking ${booking.id}:`, error.message);
          
          // Record failure in dead letter queue with exponential backoff
          const { data: existingFailure } = await supabase
            .from('refund_failures')
            .select('attempts')
            .eq('booking_id', booking.id)
            .single();
          
          const attempts = (existingFailure?.attempts || 0) + 1;
          const nextAttempt = new Date();
          nextAttempt.setMinutes(nextAttempt.getMinutes() + Math.pow(2, attempts));
          
          // Record failure
          await supabase
            .from('refund_failures')
            .upsert({
              booking_id: booking.id,
              stripe_payment_intent_id: booking.stripe_payment_intent_id,
              attempts: attempts,
              last_error: error.message,
              next_attempt_at: nextAttempt.toISOString(),
              updated_at: new Date().toISOString(),
            }, {
              onConflict: 'booking_id'
            });
          
          // Update booking status
          await supabase
            .from('bookings')
            .update({
              status: 'refund_failed',
              refund_error: error.message,
              refund_processing: false,
              refund_failed_at: new Date().toISOString(),
            })
            .eq('id', booking.id);
          
          console.log(`📝 Recorded failure for booking ${booking.id}, attempt ${attempts}, next retry: ${nextAttempt.toISOString()}`);
        }
      });

      await Promise.all(refundPromises);
      console.log('✅ Auto-refund check completed');
      
    } catch (error) {
      console.error('❌ Auto-refund error:', error.message);
    }

    return null;
  });

/**
 * Manual refund (SUPABASE VERSION)
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
 * Manual release funds (SUPABASE VERSION)
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
