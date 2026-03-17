const functions = require('firebase-functions');
const admin = require('firebase-admin');
const Razorpay = require('razorpay');
const crypto = require('crypto');

// Load environment variables from .env file (for local development)
require('dotenv').config();

admin.initializeApp();

// Initialize Stripe
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

// Initialize Supabase for Stripe escrow functions
const stripeEscrowSupabase = require('./stripe-escrow-supabase');

// Get Razorpay keys from environment variables
// For local testing, create a .env file in functions folder with:
// RAZORPAY_KEY_ID=rzp_test_SMpj1xxJxAcT6K
// RAZORPAY_KEY_SECRET=PZKW95oZEjcavJ5flTEZVjeU
const RAZORPAY_KEY_ID = process.env.RAZORPAY_KEY_ID || 'rzp_test_SMpj1xxJxAcT6K';
const RAZORPAY_KEY_SECRET = process.env.RAZORPAY_KEY_SECRET || 'PZKW95oZEjcavJ5flTEZVjeU';

// Initialize Razorpay with your keys
const razorpay = new Razorpay({
  key_id: RAZORPAY_KEY_ID,
  key_secret: RAZORPAY_KEY_SECRET,
});

/**
 * Create Razorpay Order
 * Called before opening Razorpay checkout
 */
exports.createRazorpayOrder = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { 
    amount, 
    currency = 'INR', 
    receipt, 
    notes,
    slotId,
    seatKeys = [] 
  } = data;

  // Validate amount
  if (!amount || amount <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Amount must be greater than 0'
    );
  }

  try {
    // CRITICAL: Validate amount against actual slot/seat prices from Supabase
    // This prevents users from tampering with the amount in the app
    if (slotId) {
      // TODO: Fetch slot from Supabase and verify amount matches
      // const slot = await fetchSlotFromSupabase(slotId);
      // const calculatedAmount = calculateTotalAmount(slot, seatKeys);
      // if (calculatedAmount !== amount) {
      //   throw new functions.https.HttpsError(
      //     'invalid-argument',
      //     'Amount mismatch - possible tampering detected'
      //   );
      // }
      console.log('⚠️ TODO: Implement server-side amount validation');
    }

    // Create Razorpay order
    const order = await razorpay.orders.create({
      amount: amount, // amount in paise
      currency: currency,
      receipt: receipt || `receipt_${Date.now()}`,
      notes: {
        ...notes,
        user_id: context.auth.uid,
        slot_id: slotId,
        seat_keys: seatKeys.join(','),
      },
    });

    console.log('Order created:', order.id, 'for user:', context.auth.uid);

    return {
      orderId: order.id,
      amount: order.amount,
      currency: order.currency,
      receipt: order.receipt,
    };
  } catch (error) {
    console.error('Error creating order:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to create Razorpay order',
      error.message
    );
  }
});

/**
 * Verify Razorpay Payment
 * Called after payment success to verify signature
 */
exports.verifyRazorpayPayment = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { razorpay_order_id, razorpay_payment_id, razorpay_signature } = data;

  // Validate required fields
  if (!razorpay_order_id || !razorpay_payment_id || !razorpay_signature) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Missing required payment details'
    );
  }

  try {
    // Verify signature
    const text = `${razorpay_order_id}|${razorpay_payment_id}`;
    const generatedSignature = crypto
      .createHmac('sha256', RAZORPAY_KEY_SECRET)
      .update(text)
      .digest('hex');

    const isValid = generatedSignature === razorpay_signature;

    if (!isValid) {
      console.error('Signature verification failed');
      throw new functions.https.HttpsError(
        'permission-denied',
        'Invalid payment signature'
      );
    }

    // Fetch payment details from Razorpay
    const payment = await razorpay.payments.fetch(razorpay_payment_id);

    console.log('Payment verified:', razorpay_payment_id);

    return {
      verified: true,
      payment_id: razorpay_payment_id,
      order_id: razorpay_order_id,
      amount: payment.amount,
      status: payment.status,
      method: payment.method,
      email: payment.email,
      contact: payment.contact,
    };
  } catch (error) {
    console.error('Error verifying payment:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to verify payment',
      error.message
    );
  }
});

/**
 * Webhook handler for Razorpay events
 * Handles payments that succeed but don't reach the app
 * (user closes app, network drop, etc.)
 */
exports.razorpayWebhook = functions.https.onRequest(async (req, res) => {
  // Only accept POST requests
  if (req.method !== 'POST') {
    return res.status(405).send('Method not allowed');
  }

  // Verify webhook signature
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET;
  
  if (!webhookSecret) {
    console.error('Webhook secret not configured');
    return res.status(500).send('Webhook not configured');
  }

  const signature = req.headers['x-razorpay-signature'];

  if (!signature) {
    console.error('Missing webhook signature');
    return res.status(400).send('Missing signature');
  }

  // Verify signature
  const expectedSignature = crypto
    .createHmac('sha256', webhookSecret)
    .update(JSON.stringify(req.body))
    .digest('hex');

  if (signature !== expectedSignature) {
    console.error('Invalid webhook signature');
    return res.status(400).send('Invalid signature');
  }

  const event = req.body.event;
  const payload = req.body.payload;

  console.log('Webhook event received:', event);

  try {
    // Handle different events
    switch (event) {
      case 'payment.captured':
        // Payment successful - auto-confirm booking
        const payment = payload.payment.entity;
        console.log('Payment captured:', payment.id);
        
        // TODO: Update booking status in Supabase
        // const orderId = payment.order_id;
        // const notes = payment.notes;
        // await confirmBookingInSupabase(notes.slot_id, notes.user_id, payment.id);
        
        console.log('⚠️ TODO: Auto-confirm booking for payment:', payment.id);
        break;

      case 'payment.failed':
        // Payment failed - mark booking as failed
        const failedPayment = payload.payment.entity;
        console.log('Payment failed:', failedPayment.id);
        
        // TODO: Update booking status to failed
        console.log('⚠️ TODO: Mark booking as failed');
        break;

      case 'order.paid':
        // Order fully paid
        const order = payload.order.entity;
        console.log('Order paid:', order.id);
        break;

      case 'refund.created':
        // Refund initiated
        const refund = payload.refund.entity;
        console.log('Refund created:', refund.id);
        
        // TODO: Update booking status to refunded
        console.log('⚠️ TODO: Process refund');
        break;

      default:
        console.log('Unhandled webhook event:', event);
    }

    res.status(200).send('OK');
  } catch (error) {
    console.error('Error processing webhook:', error);
    res.status(500).send('Internal error');
  }
});

// ============================================
// STRIPE ESCROW FUNCTIONS (SUPABASE VERSION)
// ============================================

// Export Supabase-based Stripe escrow functions
exports.createBooking = stripeEscrowSupabase.createBooking;
exports.verifyOtp = stripeEscrowSupabase.verifyOtp;
exports.autoRefundExpired = stripeEscrowSupabase.autoRefundExpired;
exports.refundPayment = stripeEscrowSupabase.refundPayment;
exports.releaseFunds = stripeEscrowSupabase.releaseFunds;
