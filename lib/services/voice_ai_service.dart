import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';

class VoiceAIService extends ChangeNotifier {
  static final VoiceAIService _instance = VoiceAIService._internal();
  factory VoiceAIService() => _instance;
  VoiceAIService._internal();

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  // Firebase AI Logic components
  late final GenerativeModel _model;
  late final ChatSession _chat;
  
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isInitialized = false;
  bool _aiInitialized = false;
  String _lastCommand = '';
  String _lastResponse = '';
  
  bool get isListening => _isListening;
  bool get isProcessing => _isProcessing;
  bool get isActive => _isListening || _isProcessing;
  bool get isInitialized => _isInitialized;
  String get lastCommand => _lastCommand;
  String get lastResponse => _lastResponse;

  // Initialize speech services and Firebase AI
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Voice AI is not supported on web - skip initialization
    if (kIsWeb) {
      if (kDebugMode) print('🌐 Voice AI not supported on web - skipping');
      _isInitialized = false; // Mark as not initialized on web
      return;
    }
    
    try {
      // Request microphone permission (mobile only)
      try {
        final micPermission = await Permission.microphone.request();
        if (micPermission != PermissionStatus.granted) {
          if (kDebugMode) print('🎤 Microphone permission denied');
          return;
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ Permission handler not available: $e');
        // Continue anyway - might work without explicit permission request
      }

      // Initialize speech to text
      final speechAvailable = await _speechToText.initialize(
        onError: (error) {
          if (kDebugMode) print('🎤 Speech error: $error');
          _stopListening();
        },
        onStatus: (status) {
          if (kDebugMode) print('🎤 Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
      );

      if (!speechAvailable) {
        if (kDebugMode) print('🎤 Speech recognition not available');
        return;
      }

      // Initialize text to speech
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(0.8);
      await _flutterTts.setPitch(1.0);

      // Initialize Firebase AI Logic
      await _initializeFirebaseAI();

      _isInitialized = true;
      if (kDebugMode) print('🤖 Voice AI initialized successfully');
    } catch (e) {
      if (kDebugMode) print('❌ Voice AI initialization failed: $e');
      _isInitialized = false;
    }
  }

  // Initialize Firebase Gemini API
  Future<void> _initializeFirebaseAI() async {
    // Voice AI is not supported on web - skip initialization
    if (kIsWeb) {
      if (kDebugMode) print('🌐 Voice AI not supported on web - skipping');
      _aiInitialized = false;
      return;
    }
    
    try {
      debugPrint('🚀 Voice AI: Starting Firebase Gemini API initialization...');
      
      // Use Firebase Gemini API (free tier available, no API key needed)
      _model = FirebaseVertexAI.instance.generativeModel(
        model: 'gemini-2.5-flash',  // Latest, faster, lighter model
        systemInstruction: Content.system('''
You are a helpful AI assistant for QuickOHunt, a ride-sharing and vehicle rental app.

Key features of QuickOHunt:
- Users can book rides (passenger service)
- Users can send parcels (parcel delivery)
- Users can rent/lease vehicles (with or without operators)
- Users can add their own vehicles to provide services
- Users can add needed vehicles to find rides
- Payment system with wallet and Razorpay integration
- Document verification for legal compliance
- GPS tracking and live location
- Review and rating system

Be conversational, helpful, and specific to ride-sharing context. Keep responses concise but informative (2-3 sentences max). Always sound natural and friendly, never robotic.

Examples:
- User: "Hello" → "Hi there! Welcome to QuickOHunt. I'm here to help you with rides, vehicle rentals, or any questions about the app. What can I assist you with today?"
- User: "Book a ride" → "Great! I can help you book a ride. You can choose passenger rides, parcel delivery, or rent a vehicle. Which service interests you?"
- User: "Add vehicle" → "Perfect! You can add vehicles to provide rides and earn money, or add needed vehicles to find rides. Which would you prefer?"
        '''),
      );

      debugPrint('✅ Voice AI: Model created');

      // Start a chat session for conversation continuity
      _chat = _model.startChat();
      _aiInitialized = true;
      
      debugPrint('🔥 Voice AI: Firebase Gemini API initialized with Gemini 2.0 Flash');
    } catch (e) {
      debugPrint('❌ Voice AI initialization failed: $e');
      _aiInitialized = false;
    }
  }

  // Toggle voice AI on/off
  Future<void> toggleVoiceAI() async {
    if (!_isInitialized) {
      await initialize();
      if (!_isInitialized) return;
    }

    if (_isListening) {
      _stopListening();
    } else {
      await _startListening();
    }
  }

  // Start voice listening
  Future<void> _startListening() async {
    if (kIsWeb) {
      if (kDebugMode) print('🌐 Voice AI not supported on web');
      return;
    }
    
    if (!_isInitialized || _isListening) return;

    try {
      _isListening = true;
      _isProcessing = false;
      if (kDebugMode) print('🎤 Voice AI activated - listening...');
      notifyListeners();
      
      await _flutterTts.speak('Listening...');
      
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            _processCommand(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        listenOptions: SpeechListenOptions(
          partialResults: false,
        ),
      );
    } catch (e) {
      if (kDebugMode) print('❌ Failed to start listening: $e');
      _stopListening();
    }
  }

  // Stop voice listening
  void _stopListening() {
    if (!_isListening) return;
    
    _speechToText.stop();
    _isListening = false;
    if (!_isProcessing) {
      if (kDebugMode) print('🔇 Voice AI deactivated');
    }
    notifyListeners();
  }

  // Legacy method for backward compatibility
  void startListening() {
    _startListening();
  }

  void stopListening() {
    _stopListening();
  }

  // Process voice command
  Future<void> _processCommand(String command) async {
    _isListening = false;
    _isProcessing = true;
    _lastCommand = command;
    if (kDebugMode) print('🧠 Processing: $command');
    notifyListeners();

    try {
      // Try to get AI response from Firebase function
      final response = await _getAIResponse(command);
      _lastResponse = response;
      
      // Speak the response
      await _flutterTts.speak(response);
      
      // Handle the command action
      handleVoiceCommand(command);
    } catch (e) {
      if (kDebugMode) print('❌ AI request failed, using fallback: $e');
      // Fallback to basic response if Firebase function fails
      final response = _generateAIResponse(command);
      _lastResponse = response;
      await _flutterTts.speak(response);
      handleVoiceCommand(command);
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    _isProcessing = false;
    if (kDebugMode) print('✅ Command processed: $command');
    notifyListeners();
  }

  // Get AI response using Firebase AI Logic
  Future<String> _getAIResponse(String message) async {
    try {
      if (!_aiInitialized) {
        if (kDebugMode) print('⚠️ Voice AI: Firebase AI not initialized, using fallback');
        return _generateAIResponse(message);
      }

      if (kDebugMode) print('🔥 Voice AI: Sending message to Firebase AI: $message');
      
      // Send message to Gemini via Firebase AI Logic
      final response = await _chat.sendMessage(Content.text(message));
      final aiText = response.text?.trim();
      
      if (aiText != null && aiText.isNotEmpty) {
        if (kDebugMode) print('✅ Voice AI: Got Firebase AI response: $aiText');
        return aiText;
      } else {
        if (kDebugMode) print('⚠️ Voice AI: Empty response from Firebase AI, using fallback');
        return _generateAIResponse(message);
      }
    } catch (e) {
      // Avoid type checking on web - just log the error
      if (kDebugMode) print('❌ Voice AI error: $e');
      // Fallback to basic response if Firebase AI fails
      return _generateAIResponse(message);
    }
  }

  // Generate AI response based on command (fallback)
  String _generateAIResponse(String command) {
    final lowerCommand = command.toLowerCase();
    
    // Note: This is a fallback system. Real AI responses come from Firebase Functions
    
    if (lowerCommand.contains('book') || lowerCommand.contains('ride')) {
      return 'I can help you book a ride. Let me show you available options.';
    } else if (lowerCommand.contains('cancel')) {
      return 'I can help you cancel a booking. Please provide your booking details.';
    } else if (lowerCommand.contains('wallet') || lowerCommand.contains('balance')) {
      return 'Opening your wallet to check balance.';
    } else if (lowerCommand.contains('profile')) {
      return 'Opening your profile page.';
    } else if (lowerCommand.contains('help')) {
      return 'I can help you book rides, check bookings, manage your wallet, and more. What would you like to do?';
    } else if (lowerCommand.contains('hello') || lowerCommand.contains('hi')) {
      return 'Hello! I\'m your AI assistant. How can I help you today?';
    } else {
      return 'I understand you said "$command". How can I help you with your ride needs?';
    }
  }

  // Handle voice commands
  void handleVoiceCommand(String command) {
    final lowerCommand = command.toLowerCase();
    
    if (lowerCommand.contains('book') || lowerCommand.contains('ride')) {
      // Navigate to booking screen
      if (kDebugMode) print('🚗 Navigating to booking...');
    } else if (lowerCommand.contains('wallet') || lowerCommand.contains('balance')) {
      // Navigate to wallet
      if (kDebugMode) print('💰 Opening wallet...');
    } else if (lowerCommand.contains('profile')) {
      // Navigate to profile
      if (kDebugMode) print('👤 Opening profile...');
    } else {
      // General AI response
      if (kDebugMode) print('🤖 AI responding to: $command');
    }
  }

  // Speak a message
  Future<void> speak(String message) async {
    if (!_isInitialized) await initialize();
    await _flutterTts.speak(message);
  }

  // Public method for testing AI responses
  Future<String> testAIResponse(String message) async {
    return await _getAIResponse(message);
  }
}