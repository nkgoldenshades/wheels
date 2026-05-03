const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase Admin
admin.initializeApp();

// Initialize Gemini AI
const genAI = new GoogleGenerativeAI(functions.config().gemini.api_key);

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