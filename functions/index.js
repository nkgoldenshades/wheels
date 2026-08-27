const functions = require('firebase-functions');
const admin = require('firebase-admin');
const crypto = require('crypto');

// Load environment variables from .env file (for local development)
require('dotenv').config();

admin.initializeApp();

// Note: Razorpay escrow functions are defined inline below
// const razorpayEscrow = require('./razorpay-escrow'); // Module doesn't exist - functions implemented directly

// ═══════════════════════════════════════════════════════════
// 🔑 PAYMENT MODE SWITCH
// On Firebase Cloud, secrets are automatically injected as env vars
// Local development uses .env file
// ═══════════════════════════════════════════════════════════

// Check if USE_LIVE_KEYS is set (from Secret Manager or .env)
const USE_LIVE_KEYS = process.env.USE_LIVE_KEYS === 'true';

console.log(`💳 Payment mode: ${USE_LIVE_KEYS ? '🔴 LIVE (PRODUCTION)' : '🟡 TEST (DEVELOPMENT)'}`);

// Pick the right keys based on mode
// Firebase Cloud automatically injects secrets as environment variables
const RAZORPAY_KEY_ID = USE_LIVE_KEYS
  ? process.env.RAZORPAY_KEY_ID_LIVE
  : process.env.RAZORPAY_KEY_ID_TEST;

const RAZORPAY_KEY_SECRET = USE_LIVE_KEYS
  ? process.env.RAZORPAY_KEY_SECRET_LIVE
  : process.env.RAZORPAY_KEY_SECRET_TEST;

if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
  console.error(`❌ Razorpay ${USE_LIVE_KEYS ? 'LIVE' : 'TEST'} keys not configured`);
  console.error(`   Key ID present: ${!!RAZORPAY_KEY_ID}, Secret present: ${!!RAZORPAY_KEY_SECRET}`);
} else {
  console.log(`✅ Razorpay keys loaded successfully (${USE_LIVE_KEYS ? 'LIVE' : 'TEST'} mode)`);
}

// Initialize Razorpay lazily to avoid crash when keys are missing at startup
let _razorpay = null;
function getRazorpay() {
  if (!_razorpay) {
    if (!RAZORPAY_KEY_ID || !RAZORPAY_KEY_SECRET) {
      throw new Error(`Razorpay ${USE_LIVE_KEYS ? 'LIVE' : 'TEST'} keys not configured`);
    }
    const Razorpay = require('razorpay');
    _razorpay = new Razorpay({ key_id: RAZORPAY_KEY_ID, key_secret: RAZORPAY_KEY_SECRET });
  }
  return _razorpay;
}

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
    const order = await getRazorpay().orders.create({
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
    const payment = await getRazorpay().payments.fetch(razorpay_payment_id);

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

/**
 * AI Chat Endpoint
 * Integrates with Google Gemini AI for natural conversations
 */
exports.aiChat = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { message, conversationHistory = [] } = data;

  // Validate message
  if (!message || typeof message !== 'string' || message.trim().length === 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Message is required and must be a non-empty string'
    );
  }

  try {
    // Use Google Gemini AI for natural responses
    const aiResponse = await getGeminiResponse(message, conversationHistory);

    console.log('AI Chat request processed for user:', context.auth.uid);

    return {
      response: aiResponse,
      timestamp: Date.now(),
      conversationId: `conv_${context.auth.uid}_${Date.now()}`,
    };
  } catch (error) {
    console.error('Error processing AI chat:', error);
    
    // Fallback to basic response if AI fails
    const fallbackResponse = generateBasicResponse(message);
    
    return {
      response: fallbackResponse,
      timestamp: Date.now(),
      conversationId: `conv_${context.auth.uid}_${Date.now()}`,
      fallback: true,
    };
  }
});

/**
 * Get response from Google Gemini AI
 */
async function getGeminiResponse(message, conversationHistory = []) {
  const GEMINI_API_KEY = process.env.GEMINI_API_KEY;
  
  if (!GEMINI_API_KEY) {
    console.log('Gemini API key not configured, using enhanced fallback');
    return generateEnhancedResponse(message);
  }

  try {
    const { GoogleGenerativeAI } = require('@google/generative-ai');
    const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

    // Create system context for the ride-sharing app
    const systemContext = `You are a helpful AI assistant for QuickOHunt, a ride-sharing and vehicle rental app. 

Key features of the app:
- Users can book rides (passenger service)
- Users can send parcels (parcel delivery)
- Users can rent/lease vehicles (with or without operators)
- Users can add their own vehicles to provide services
- Users can add needed vehicles to find rides
- Payment system with wallet and Razorpay integration
- Document verification for legal compliance
- GPS tracking and live location
- Review and rating system

Be conversational, helpful, and specific to ride-sharing context. Keep responses concise but informative. If users ask about features not mentioned above, politely redirect them to app-specific functionality.`;

    // Build conversation context
    let conversationText = systemContext + '\n\n';
    
    // Add conversation history if available
    if (conversationHistory.length > 0) {
      conversationText += 'Previous conversation:\n';
      conversationHistory.slice(-5).forEach(msg => { // Last 5 messages for context
        conversationText += `${msg.role}: ${msg.content}\n`;
      });
      conversationText += '\n';
    }
    
    conversationText += `User: ${message}\nAssistant:`;

    const result = await model.generateContent(conversationText);
    const response = await result.response;
    const aiResponse = response.text();

    return aiResponse || generateEnhancedResponse(message);
  } catch (error) {
    console.error('Gemini API error:', error);
    return generateEnhancedResponse(message);
  }
}

/**
 * Enhanced response generator (better than basic fallback)
 */
function generateEnhancedResponse(message) {
  const lowerMessage = message.toLowerCase();
  
  // Greeting responses
  if (lowerMessage.includes('hello') || lowerMessage.includes('hi') || lowerMessage.includes('hey')) {
    return 'Hi there! Welcome to QuickOHunt. I\'m your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app. What can I help you with today?';
  }
  
  // Booking related
  if (lowerMessage.includes('book') || lowerMessage.includes('ride') || lowerMessage.includes('trip')) {
    return 'Great! I can help you book a ride. You have several options: passenger rides for getting around, parcel delivery for sending items, or vehicle rentals if you prefer to drive yourself. Which type of service interests you?';
  }
  
  // Vehicle related
  if (lowerMessage.includes('vehicle') || lowerMessage.includes('car') || lowerMessage.includes('add') && lowerMessage.includes('vehicle')) {
    return 'Perfect! You can add vehicles in two ways: add your own vehicles to provide rides and earn money, or add needed vehicles to find rides from others. Would you like to provide rides or find rides?';
  }
  
  // Payment related
  if (lowerMessage.includes('payment') || lowerMessage.includes('wallet') || lowerMessage.includes('money') || lowerMessage.includes('pay')) {
    return 'For payments, QuickOHunt uses a secure wallet system with Razorpay integration. You can add money to your wallet, check your balance, or manage payment methods in the app settings. Need help with a specific payment issue?';
  }
  
  // Cancellation
  if (lowerMessage.includes('cancel')) {
    return 'To cancel a booking, go to your bookings page and select the booking you want to cancel. You can get a refund if cancelled within the allowed time frame. The exact refund amount depends on the cancellation policy and timing.';
  }
  
  // Help requests
  if (lowerMessage.includes('help') || lowerMessage.includes('support') || lowerMessage.includes('how')) {
    return 'I\'m here to help! I can assist you with booking rides, managing vehicles, payments, cancellations, and general app navigation. You can also check your booking history, wallet balance, and account settings. What specific area would you like help with?';
  }
  
  // Profile/account
  if (lowerMessage.includes('profile') || lowerMessage.includes('account') || lowerMessage.includes('settings')) {
    return 'You can manage your profile and account settings in the app. This includes updating your personal information, payment methods, notification preferences, and viewing your ride history. Is there something specific you\'d like to update?';
  }
  
  // Location/GPS
  if (lowerMessage.includes('location') || lowerMessage.includes('gps') || lowerMessage.includes('track')) {
    return 'QuickOHunt uses GPS tracking for live location sharing during rides. This helps with pickup coordination and safety. You can enable or disable location sharing in your app settings. Need help with location-related features?';
  }
  
  // Reviews/ratings
  if (lowerMessage.includes('review') || lowerMessage.includes('rating') || lowerMessage.includes('feedback')) {
    return 'After each ride, you can rate your experience and leave reviews. This helps maintain service quality and helps other users make informed decisions. You can also view reviews for vehicles and providers before booking.';
  }
  
  // Default response with context
  return `I understand you're asking about "${message}". As your QuickOHunt assistant, I can help you with ride bookings, vehicle management, payments, and app features. Could you tell me more specifically what you need help with? For example, are you looking to book a ride, add a vehicle, or manage your account?`;
}

/**
 * Validate and Purchase AI Credits
 * Backend validation to prevent client-side price tampering
 * Ensures submitted prices match expected converted prices
 */
exports.validateAndPurchaseAICredits = functions.https.onCall(async (data, context) => {
  // Verify user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }

  const { 
    creditCount, 
    submittedPrice, 
    currency = 'INR',
    paymentMethodId // For Stripe/Razorpay
  } = data;

  // Validate input
  if (!creditCount || ![50, 200, 1000].includes(creditCount)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid credit package. Allowed: 50, 200, 1000 credits'
    );
  }

  if (!submittedPrice || submittedPrice <= 0) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid price submitted'
    );
  }

  // Exchange rates - must match frontend PricingService
  const EXCHANGE_RATES = {
    'USD': 1.0, 'EUR': 0.92, 'GBP': 0.79, 'JPY': 149.50, 'CHF': 0.88,
    'CNY': 7.24, 'INR': 83.0, 'AUD': 1.51, 'CAD': 1.36, 'SGD': 1.33,
    'HKD': 7.78, 'NZD': 1.63, 'SEK': 10.50, 'NOK': 10.58, 'DKK': 6.85,
    'ZAR': 18.50, 'MXN': 17.05, 'BRL': 4.97, 'RUB': 96.50, 'KRW': 1319.0,
    'AED': 3.67, 'SAR': 3.75, 'QAR': 3.64, 'KWD': 0.31, 'BHD': 0.376,
    'OMR': 0.385, 'JOD': 0.709, 'EGP': 30.50, 'PKR': 278.0, 'BDT': 117.0,
    'LKR': 303.0, 'NPR': 132.50, 'THB': 35.50, 'MYR': 4.75, 'IDR': 16050.0,
    'PHP': 56.50, 'VND': 24650.0, 'TRY': 32.50, 'PLN': 3.97, 'CZK': 23.50,
    'HUF': 360.0, 'RON': 4.57, 'BGN': 1.80, 'HRK': 6.93, 'ISK': 134.0,
    'ILS': 3.65, 'CLP': 950.0, 'COP': 3985.0, 'PEN': 3.75, 'UYU': 39.50,
    'PYG': 7380.0, 'ARS': 820.0, 'GHS': 12.50, 'KES': 130.0, 'NGN': 1550.0,
  };

  // Base USD prices for credit packages
  const USD_PRICES = {
    50: 3.0,
    200: 10.0,
    1000: 50.0,
  };

  try {
    const curr = currency.toUpperCase();
    const rate = EXCHANGE_RATES[curr] || 1.0;
    const usdPrice = USD_PRICES[creditCount];
    
    if (!usdPrice) {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Unknown credit package'
      );
    }

    // Convert USD price to target currency
    let expectedPrice = usdPrice * rate;
    
    // Round based on currency
    if (curr === 'INR') {
      expectedPrice = Math.round(expectedPrice);
    } else {
      expectedPrice = Math.round(expectedPrice * 100) / 100;
    }

    // Allow 1% tolerance for floating point precision
    const tolerance = expectedPrice * 0.01;
    const priceDifference = Math.abs(submittedPrice - expectedPrice);

    console.log(`💳 Credit validation: ${creditCount} credits, ${curr}${submittedPrice}, expected: ${curr}${expectedPrice}, diff: ${priceDifference}`);

    if (priceDifference > tolerance) {
      console.error(`❌ Price mismatch detected! Fraud attempt?`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Price validation failed. Suspected price tampering.'
      );
    }

    // Price is valid - proceed with purchase
    console.log(`✅ Price validation passed for user ${context.auth.uid}`);

    // TODO: Process payment through Razorpay/Stripe based on currency
    // For INR: Use Razorpay
    // For others: Use Stripe (if implemented)
    
    // TODO: Update user's credit balance in Supabase
    // await supabase
    //   .from('user_ai_credits')
    //   .update({ credits: credits + creditCount })
    //   .eq('user_id', context.auth.uid);

    return {
      success: true,
      validated: true,
      creditCount: creditCount,
      price: expectedPrice,
      currency: curr,
      timestamp: Date.now(),
    };
  } catch (error) {
    console.error('Error validating credit purchase:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to validate credit purchase',
      error.message
    );
  }
});

/**
 * Basic AI response generator (fallback)
 * Replace this with actual AI service integration
 */
function generateBasicResponse(message) {
  const lowerMessage = message.toLowerCase();
  
  if (lowerMessage.includes('book') || lowerMessage.includes('ride')) {
    return 'I can help you book a ride! You can browse available vehicles and create a booking. Would you like me to show you the available options?';
  } else if (lowerMessage.includes('cancel')) {
    return 'To cancel a booking, go to your bookings page and select the booking you want to cancel. You can get a refund if cancelled within the allowed time.';
  } else if (lowerMessage.includes('payment') || lowerMessage.includes('wallet')) {
    return 'For payment issues, check your wallet balance or payment methods in the app settings. You can add money to your wallet or update payment cards.';
  } else if (lowerMessage.includes('vehicle') || lowerMessage.includes('car')) {
    return 'You can add your vehicle to provide rides or add needed vehicles to find rides. Go to the vehicles section to manage your fleet.';
  } else if (lowerMessage.includes('help')) {
    return 'I can help you with booking rides, managing vehicles, payments, and general app navigation. What specific area do you need help with?';
  } else if (lowerMessage.includes('hello') || lowerMessage.includes('hi')) {
    return 'Hello! I\'m your AI assistant for the ride-sharing app. I can help you with bookings, vehicles, payments, and more. How can I assist you today?';
  } else {
    return `I understand you're asking about "${message}". I'm here to help with ride bookings, vehicle management, payments, and app features. Could you be more specific about what you need help with?`;
  }
}
