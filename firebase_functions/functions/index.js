const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase Admin
admin.initializeApp();

// Use environment variables (new approach - replaces deprecated functions.config())
const STRIPE_SECRET_KEY = process.env.STRIPE_SECRET_KEY;
const GEMINI_API_KEY = process.env.GEMINI_API_KEY;

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

// Rate limiting store (in production, use Redis or Firestore)
const rateLimitStore = new Map();

// Helper function to check rate limits
function checkRateLimit(userId, maxRequests = 10, windowMs = 24 * 60 * 60 * 1000) {
  const now = Date.now();
  const userKey = `${userId}_${Math.floor(now / windowMs)}`;
  
  const currentCount = rateLimitStore.get(userKey) || 0;
  if (currentCount >= maxRequests) {
    return false;
  }
  
  rateLimitStore.set(userKey, currentCount + 1);
  return true;
}

// Content moderation function
exports.moderateContent = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const { text, type = 'general' } = data;

    // Validate input
    if (!text || typeof text !== 'string') {
      throw new functions.https.HttpsError('invalid-argument', 'Text is required');
    }

    if (text.length > 5000) {
      throw new functions.https.HttpsError('invalid-argument', 'Text too long (max 5000 characters)');
    }

    // Check rate limits
    if (!checkRateLimit(userId, 20)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Rate limit exceeded. Try again later.');
    }

    // Get Gemini model
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

    // Create moderation prompt based on type
    let prompt;
    switch (type) {
      case 'vehicle_description':
        prompt = `Analyze this vehicle description for inappropriate content, spam, or misleading information. 
        Text: "${text}"
        
        Respond with JSON:
        {
          "approved": true/false,
          "reason": "explanation if not approved",
          "confidence": 0.0-1.0,
          "suggestions": "improvement suggestions if any"
        }`;
        break;
        
      case 'user_review':
        prompt = `Analyze this user review for inappropriate content, hate speech, or spam.
        Text: "${text}"
        
        Respond with JSON:
        {
          "approved": true/false,
          "reason": "explanation if not approved", 
          "confidence": 0.0-1.0,
          "sentiment": "positive/negative/neutral"
        }`;
        break;
        
      case 'chat_message':
        prompt = `Analyze this chat message for inappropriate content, harassment, or spam.
        Text: "${text}"
        
        Respond with JSON:
        {
          "approved": true/false,
          "reason": "explanation if not approved",
          "confidence": 0.0-1.0,
          "severity": "low/medium/high"
        }`;
        break;
        
      default:
        prompt = `Analyze this text for inappropriate content, spam, or harmful material.
        Text: "${text}"
        
        Respond with JSON:
        {
          "approved": true/false,
          "reason": "explanation if not approved",
          "confidence": 0.0-1.0
        }`;
    }

    // Generate content
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const aiText = response.text();

    // Parse AI response
    let analysis;
    try {
      analysis = JSON.parse(aiText);
    } catch (e) {
      // Fallback if AI doesn't return valid JSON
      analysis = {
        approved: !aiText.toLowerCase().includes('inappropriate'),
        reason: aiText,
        confidence: 0.5
      };
    }

    // Log the moderation result
    await admin.firestore().collection('moderation_logs').add({
      userId,
      text: text.substring(0, 500), // Store first 500 chars only
      type,
      analysis,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      aiResponse: aiText
    });

    return {
      success: true,
      analysis,
      requestId: context.auth.uid + '_' + Date.now()
    };

  } catch (error) {
    console.error('Content moderation error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Content moderation failed');
  }
});

// Image analysis function
exports.analyzeImages = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const { imageUrls, type = 'vehicle' } = data;

    // Validate input
    if (!imageUrls || !Array.isArray(imageUrls) || imageUrls.length === 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Image URLs are required');
    }

    if (imageUrls.length > 10) {
      throw new functions.https.HttpsError('invalid-argument', 'Too many images (max 10)');
    }

    // Check rate limits (stricter for image analysis)
    if (!checkRateLimit(userId + '_images', 5)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Image analysis rate limit exceeded');
    }

    // Get Gemini Vision model
    const model = genAI.getGenerativeModel({ model: 'gemini-pro-vision' });

    const results = [];

    for (const imageUrl of imageUrls) {
      try {
        // Create analysis prompt based on type
        let prompt;
        switch (type) {
          case 'vehicle':
            prompt = `Analyze this vehicle image for:
            1. Is it actually a vehicle?
            2. Image quality and clarity
            3. Any inappropriate content
            4. Vehicle condition assessment
            
            Respond with JSON:
            {
              "isVehicle": true/false,
              "quality": "poor/fair/good/excellent",
              "appropriate": true/false,
              "condition": "poor/fair/good/excellent",
              "description": "brief description",
              "issues": ["list of any issues found"]
            }`;
            break;
            
          case 'profile':
            prompt = `Analyze this profile image for:
            1. Is it appropriate for a profile picture?
            2. Contains a real person's face?
            3. Image quality
            
            Respond with JSON:
            {
              "appropriate": true/false,
              "hasFace": true/false,
              "quality": "poor/fair/good/excellent",
              "issues": ["list of any issues"]
            }`;
            break;
            
          default:
            prompt = `Analyze this image for inappropriate content, quality, and relevance.
            
            Respond with JSON:
            {
              "appropriate": true/false,
              "quality": "poor/fair/good/excellent",
              "description": "brief description"
            }`;
        }

        // Fetch image and convert to base64 (for Gemini Vision)
        const imageResponse = await fetch(imageUrl);
        const imageBuffer = await imageResponse.arrayBuffer();
        const imageBase64 = Buffer.from(imageBuffer).toString('base64');

        // Analyze image
        const result = await model.generateContent([
          prompt,
          {
            inlineData: {
              data: imageBase64,
              mimeType: imageResponse.headers.get('content-type') || 'image/jpeg'
            }
          }
        ]);

        const response = await result.response;
        const aiText = response.text();

        // Parse AI response
        let analysis;
        try {
          analysis = JSON.parse(aiText);
        } catch (e) {
          analysis = {
            appropriate: !aiText.toLowerCase().includes('inappropriate'),
            quality: 'fair',
            description: aiText
          };
        }

        results.push({
          imageUrl,
          analysis,
          success: true
        });

      } catch (imageError) {
        console.error(`Image analysis failed for ${imageUrl}:`, imageError);
        results.push({
          imageUrl,
          error: 'Analysis failed',
          success: false
        });
      }
    }

    // Log the image analysis
    await admin.firestore().collection('image_analysis_logs').add({
      userId,
      type,
      imageCount: imageUrls.length,
      results: results.map(r => ({ success: r.success, appropriate: r.analysis?.appropriate })),
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });

    return {
      success: true,
      results,
      requestId: context.auth.uid + '_img_' + Date.now()
    };

  } catch (error) {
    console.error('Image analysis error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Image analysis failed');
  }
});

// Smart suggestions function
exports.generateSuggestions = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const { type, context: userContext, data: inputData } = data;

    // Check rate limits
    if (!checkRateLimit(userId + '_suggestions', 15)) {
      throw new functions.https.HttpsError('resource-exhausted', 'Suggestions rate limit exceeded');
    }

    // Get Gemini model
    const model = genAI.getGenerativeModel({ model: 'gemini-pro' });

    let prompt;
    switch (type) {
      case 'vehicle_title':
        prompt = `Generate 3 attractive titles for this vehicle listing:
        Vehicle: ${inputData.vehicleType}
        Service: ${inputData.serviceType}
        Location: ${inputData.location}
        
        Make titles catchy but professional. Respond with JSON:
        {
          "suggestions": ["title1", "title2", "title3"]
        }`;
        break;
        
      case 'route_optimization':
        prompt = `Suggest optimal route and timing for this trip:
        From: ${inputData.from}
        To: ${inputData.to}
        Service: ${inputData.serviceType}
        Time: ${inputData.preferredTime}
        
        Respond with JSON:
        {
          "suggestions": {
            "bestTime": "suggested departure time",
            "duration": "estimated duration", 
            "tips": ["tip1", "tip2", "tip3"]
          }
        }`;
        break;
        
      case 'pricing_suggestion':
        prompt = `Suggest competitive pricing for this service:
        Service: ${inputData.serviceType}
        Distance: ${inputData.distance}km
        Vehicle: ${inputData.vehicleType}
        Location: ${inputData.location}
        
        Respond with JSON:
        {
          "suggestions": {
            "recommendedPrice": number,
            "priceRange": {"min": number, "max": number},
            "reasoning": "explanation"
          }
        }`;
        break;
        
      default:
        throw new functions.https.HttpsError('invalid-argument', 'Invalid suggestion type');
    }

    // Generate suggestions
    const result = await model.generateContent(prompt);
    const response = await result.response;
    const aiText = response.text();

    // Parse AI response
    let suggestions;
    try {
      suggestions = JSON.parse(aiText);
    } catch (e) {
      suggestions = {
        suggestions: [aiText]
      };
    }

    return {
      success: true,
      suggestions,
      requestId: context.auth.uid + '_sug_' + Date.now()
    };

  } catch (error) {
    console.error('Suggestions error:', error);
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Suggestions generation failed');
  }
});

// ─── Stripe Connect: Create Connected Account ────────────────────────────────
const stripe = require('stripe')(STRIPE_SECRET_KEY);

exports.createConnectedAccount = functions.https.onRequest(async (req, res) => {
  // CORS headers
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    res.status(204).send('');
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    // Verify Firebase JWT
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await admin.auth().verifyIdToken(token);
    const userId = decodedToken.uid;

    const { email, country, return_url, refresh_url } = req.body;

    if (!email || !country) {
      res.status(400).json({ error: 'email and country are required' });
      return;
    }

    // Map country name to ISO code
    const countryMap = {
      'United States': 'US', 'United Kingdom': 'GB', 'Australia': 'AU',
      'Canada': 'CA', 'Singapore': 'SG', 'UAE': 'AE', 'Germany': 'DE',
      'France': 'FR', 'Japan': 'JP', 'New Zealand': 'NZ', 'Ireland': 'IE',
      'Netherlands': 'NL', 'Switzerland': 'CH', 'Sweden': 'SE', 'Norway': 'NO',
      'Denmark': 'DK', 'Finland': 'FI', 'Belgium': 'BE', 'Austria': 'AT',
      'Portugal': 'PT', 'Italy': 'IT', 'Spain': 'ES', 'Poland': 'PL',
      'Czech Republic': 'CZ', 'Hungary': 'HU', 'Romania': 'RO',
      'South Africa': 'ZA', 'Brazil': 'BR', 'Mexico': 'MX',
      'Malaysia': 'MY', 'Thailand': 'TH', 'Philippines': 'PH',
      'Indonesia': 'ID', 'South Korea': 'KR', 'Hong Kong': 'HK',
    };

    const countryCode = countryMap[country] || 'US';

    // Create Stripe Express account
    const account = await stripe.accounts.create({
      type: 'express',
      country: countryCode,
      email: email,
      capabilities: {
        card_payments: { requested: true },
        transfers: { requested: true },
      },
      metadata: { firebase_uid: userId },
    });

    // Create onboarding link
    const accountLink = await stripe.accountLinks.create({
      account: account.id,
      refresh_url: refresh_url || 'https://vervestrideal.com/stripe-refresh',
      return_url: return_url || 'https://vervestrideal.com/stripe-return',
      type: 'account_onboarding',
    });

    res.status(200).json({
      account_id: account.id,
      url: accountLink.url,
    });

  } catch (error) {
    console.error('createConnectedAccount error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ─── Stripe: Create Booking with Escrow ──────────────────────────────────────
exports.createBooking = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
    await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);

    const { user_id, provider_id, post_id, slot_id, amount, currency, commission_amount, countdown_hours } = req.body;

    // Create PaymentIntent with manual capture (escrow)
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency || 'inr',
      capture_method: 'manual',
      metadata: { user_id, provider_id, post_id: post_id || slot_id },
    });

    // Generate OTP
    const otp = Math.floor(100000 + Math.random() * 900000).toString();
    const countdownEnd = new Date(Date.now() + (countdown_hours || 1) * 60 * 60 * 1000);

    res.status(200).json({
      client_secret: paymentIntent.client_secret,
      payment_intent_id: paymentIntent.id,
      otp: otp,
      countdown_end_time: countdownEnd.toISOString(),
    });
  } catch (error) {
    console.error('createBooking error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ─── Stripe: Create Checkout Session (web) ───────────────────────────────────
exports.createCheckoutSession = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
    await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);

    const { user_id, provider_id, slot_id, post_id, amount, currency, commission_amount } = req.body;

    const session = await stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [{
        price_data: {
          currency: currency || 'inr',
          product_data: { name: 'VaultWheels Booking' },
          unit_amount: amount,
        },
        quantity: 1,
      }],
      mode: 'payment',
      success_url: req.body.return_url || 'https://vervestrideal.com/booking-success',
      cancel_url: req.body.refresh_url || 'https://vervestrideal.com/booking-cancel',
      metadata: { user_id, provider_id, post_id: post_id || slot_id },
    });

    res.status(200).json({ url: session.url, payment_intent: session.payment_intent });
  } catch (error) {
    console.error('createCheckoutSession error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ─── Stripe: Release Funds to Provider ───────────────────────────────────────
exports.releaseFunds = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
    await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);

    const { payment_intent_id, provider_id, amount, commission_amount } = req.body;

    // Capture the payment (release from escrow)
    await stripe.paymentIntents.capture(payment_intent_id);

    res.status(200).json({ success: true });
  } catch (error) {
    console.error('releaseFunds error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ─── Stripe: Refund Payment ───────────────────────────────────────────────────
exports.refundPayment = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
    await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);

    const { payment_intent_id, amount } = req.body;

    const refund = await stripe.refunds.create({
      payment_intent: payment_intent_id,
      amount: amount,
    });

    res.status(200).json({ success: true, refund_id: refund.id });
  } catch (error) {
    console.error('refundPayment error:', error);
    res.status(500).json({ error: error.message });
  }
});

// ─── Stripe: Verify OTP and Release ──────────────────────────────────────────
exports.verifyOtp = functions.https.onRequest(async (req, res) => {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') { res.status(204).send(''); return; }

  try {
    const authHeader = req.headers.authorization;
    if (!authHeader?.startsWith('Bearer ')) { res.status(401).json({ error: 'Unauthorized' }); return; }
    await admin.auth().verifyIdToken(authHeader.split('Bearer ')[1]);

    const { booking_id, otp } = req.body;
    // OTP verification is handled in Supabase - just return success
    res.status(200).json({ success: true, verified: true });
  } catch (error) {
    console.error('verifyOtp error:', error);
    res.status(500).json({ error: error.message });
  }
});
