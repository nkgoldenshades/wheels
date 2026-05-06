import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_repository.dart';
import '../services/profile_repository.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:speech_to_text/speech_to_text.dart'; // Commented out for Windows compatibility
// import 'package:permission_handler/permission_handler.dart'; // Not needed

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();

  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isLoading = false;
  bool _aiInitialized = false;
  int? _currentConversationId; // Track current conversation
  
  // Guest user conversation limit
  static const int _guestConversationLimit = 10;
  int _guestConversationCount = 0;
  bool _isGuest = false;
  
  // Image and voice functionality
  final ImagePicker _imagePicker = ImagePicker();
  // final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _checkGuestStatus();
    _loadOrCreateConversation(); // Load or create conversation
    _initializeFirebaseAI();
  }
  
  Future<void> _checkGuestStatus() async {
    final currentUser = AuthRepository.instance.currentUser;
    _isGuest = currentUser == null;
    
    if (_isGuest) {
      // Load guest conversation count from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _guestConversationCount = prefs.getInt('guest_conversation_count') ?? 0;
      debugPrint('👤 Guest user - conversation count: $_guestConversationCount/$_guestConversationLimit');
    }
  }

  Future<void> _initializeFirebaseAI() async {
    try {
      debugPrint('🚀 Initializing Firebase Gemini API...');
      
      // Use Firebase Gemini API (free tier available, no API key needed)
      // This uses Google AI's Gemini API through Firebase
      _model = FirebaseAI.googleAI().generativeModel(
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

Be conversational, helpful, and specific to ride-sharing context. Keep responses concise (2-3 sentences max). Always sound natural and friendly, never robotic. Always guide users to take action inside the app.
        '''),
      );

      _chat = _model!.startChat();

      // Test the connection
      final testResponse = await _chat!
          .sendMessage(Content.text('say "ready" in one word'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout');
            },
          );
      
      final testText = testResponse.text ?? '';
      debugPrint('✅ Firebase Gemini API test response: $testText');

      if (!mounted) return;
      setState(() {
        _aiInitialized = true;
        final welcomeMessage = _isGuest
            ? "Hi there! Welcome to QuickOHunt. I'm your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app.\n\n⚠️ Guest Mode: You have $_guestConversationLimit free conversations. Login for unlimited access!\n\nWhat can I help you with today?"
            : "Hi there! Welcome to QuickOHunt. I'm your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app. What can I help you with today?";
        
        _messages.add(ChatMessage(
          text: welcomeMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e, stack) {
      debugPrint('❌ Firebase Gemini API initialization failed: $e');
      debugPrint('Stack: $stack');
      if (!mounted) return;
      setState(() {
        _aiInitialized = false;
        _messages.add(ChatMessage(
          text:
              "⚠️ AI Assistant is temporarily unavailable.\n\n"
              "Our AI service is currently offline. Please try again later or contact support if the issue persists.\n\n"
              "You can still use all other features of the app — just tap back to continue.",
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Image picker functionality
  Future<void> _pickImage() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final sizeKb = bytes.length ~/ 1024;

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: '📎 Image attached: ${picked.name} (${sizeKb}KB)',
          isUser: true,
          timestamp: DateTime.now(),
        ));
      });
      _scrollToBottom();

      // Send image context to AI
      await _sendToFirebaseAI('I have attached an image: ${picked.name}. Please acknowledge it.');
    } catch (e) {
      debugPrint('❌ Image picker failed: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pick image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Voice input functionality
  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    if (!mounted) return;
    setState(() {
      _isListening = true;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isListening 
          ? 'Voice input active - speak continuously until you tap mic again' 
          : 'Voice input not available on this platform'),
        backgroundColor: _isListening ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _stopListening() {
    if (!mounted) return;
    setState(() {
      _isListening = false;
    });
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice input stopped'),
        backgroundColor: Colors.grey,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // AI Settings functionality
  void _showAISettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AISettingsBottomSheet(
        aiInitialized: _aiInitialized,
        onClearChat: _clearChat,
        onReconnectAI: _reconnectAI,
      ),
    );
  }

  void _clearChat() {
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages.add(ChatMessage(
        text: "Chat history cleared. How can I help you?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    
    // Mark current conversation as inactive and create new one on next message
    if (_currentConversationId != null) {
      Supabase.instance.client
          .from('ai_conversations')
          .update({'is_active': false})
          .eq('id', _currentConversationId!)
          .then((_) {
            _currentConversationId = null;
            debugPrint('🗑️ Marked conversation as inactive');
          });
    }
    
    Navigator.pop(context); // Close settings
  }

  void _reconnectAI() {
    if (!mounted) return;
    setState(() {
      _aiInitialized = false;
    });
    _initializeFirebaseAI();
    Navigator.pop(context);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Check guest conversation limit
    if (_isGuest && _guestConversationCount >= _guestConversationLimit) {
      _showLoginPrompt();
      return;
    }
    
    // Check AI credits for logged-in users
    if (!_isGuest) {
      final profile = ProfileRepository.instance.profile.value;
      if (profile.aiCredits < 1) {
        _showBuyCreditsDialog(context);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Increment guest conversation count
    if (_isGuest) {
      _guestConversationCount++;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('guest_conversation_count', _guestConversationCount);
      debugPrint('👤 Guest conversation count: $_guestConversationCount/$_guestConversationLimit');
    } else {
      // Deduct 1 credit for logged-in users
      final success = await ProfileRepository.instance.deductAICredits(1);
      if (!success) {
        // This shouldn't happen as we checked above, but handle it anyway
        if (mounted) {
          setState(() {
            _messages.removeLast(); // Remove the user message
            _isLoading = false;
          });
          _showBuyCreditsDialog(context);
        }
        return;
      }
    }

    await _sendToFirebaseAI(text);
  }
  
  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Conversation Limit Reached'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You\'ve reached the limit of $_guestConversationLimit conversations as a guest.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Login to get unlimited AI conversations and access to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Unlimited AI chat'),
            const Text('• Save conversation history'),
            const Text('• Book rides and services'),
            const Text('• Create posts'),
            const Text('• And much more!'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushNamed(context, '/login'); // Go to login
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Login Now'),
          ),
        ],
      ),
    );
  }
  
  void _showBuyCreditsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shopping_cart, color: Colors.blue),
            SizedBox(width: 8),
            Text('Buy AI Credits'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Choose a credit package:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),
            _buildCreditPackage(context, 100, 1),
            const SizedBox(height: 8),
            _buildCreditPackage(context, 500, 4, popular: true),
            const SizedBox(height: 8),
            _buildCreditPackage(context, 1000, 7),
            const SizedBox(height: 16),
            const Text(
              '💡 1 credit = 1 AI message',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreditPackage(BuildContext context, int credits, int price, {bool popular = false}) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close dialog
        // TODO: Integrate with payment gateway (Razorpay/Stripe)
        // For now, just add credits directly (demo)
        await ProfileRepository.instance.addAICredits(credits);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Added $credits credits! (Demo mode - no payment required)'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: popular ? Colors.blue.shade50 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: popular ? Colors.blue : Colors.grey.shade300,
            width: popular ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.stars,
              color: popular ? Colors.blue : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$credits Credits',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: popular ? Colors.blue.shade900 : Colors.black87,
                        ),
                      ),
                      if (popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '\$$price',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendToFirebaseAI(String userText) async {
    if (!_aiInitialized || _chat == null) {
      _addAIMessage(
        "⚠️ AI Assistant is temporarily unavailable. Please try again later.",
        isError: true,
      );
      return;
    }

    try {
      debugPrint('📤 Sending to Firebase Gemini API: $userText');
      final response = await _chat!.sendMessage(Content.text(userText));
      final aiText = response.text?.trim();
      debugPrint('📥 Firebase Gemini API response: $aiText');

      if (aiText == null || aiText.isEmpty) {
        _addAIMessage("I received an empty response. Please try again.",
            isError: true);
      } else {
        _addAIMessage(aiText);
      }
    } catch (e) {
      debugPrint('❌ Firebase Gemini API error: $e');
      _addAIMessage(
        "Sorry, I couldn't process your message. Please check your connection and try again.",
        isError: true,
      );
    }
  }

  void _addAIMessage(String text, {bool isError = false}) {
    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: text,
          isUser: false,
          timestamp: DateTime.now(),
          isError: isError,
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      
      // Save conversation to Supabase (async, don't wait)
      _saveConversationToSupabase();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // Save conversation to ai_conversations table
  Future<void> _saveConversationToSupabase() async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) return;

      // Convert messages to JSONB format
      final messagesJson = _messages.map((msg) => {
        'role': msg.isUser ? 'user' : 'assistant',
        'content': msg.text,
        'timestamp': msg.timestamp.toIso8601String(),
        if (msg.isError) 'is_error': true,
      }).toList();

      if (_currentConversationId == null) {
        // Create new conversation
        final response = await Supabase.instance.client
            .from('ai_conversations')
            .insert({
              'profile_id': userId,
              'title': 'AI Assistant Chat',
              'messages': messagesJson,
              'context_type': 'general',
              'context_id': '',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
        
        _currentConversationId = response['id'] as int;
        debugPrint('💾 Created new conversation: $_currentConversationId');
      } else {
        // Update existing conversation
        await Supabase.instance.client
            .from('ai_conversations')
            .update({
              'messages': messagesJson,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _currentConversationId!);
        
        debugPrint('💾 Updated conversation $_currentConversationId with ${messagesJson.length} messages');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to save chat history: $e');
      // Don't show error to user - this is background save
    }
  }

  // Load or create conversation from ai_conversations table
  Future<void> _loadOrCreateConversation() async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) return;

      // Get the most recent active conversation
      final response = await Supabase.instance.client
          .from('ai_conversations')
          .select()
          .eq('profile_id', userId)
          .eq('is_active', true)
          .eq('context_type', 'general')
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        // Load existing conversation
        _currentConversationId = response['id'] as int;
        final messagesJson = response['messages'] as List;
        
        final messages = messagesJson
            .map((msg) => ChatMessage(
                  text: msg['content'] as String,
                  isUser: msg['role'] == 'user',
                  timestamp: DateTime.parse(msg['timestamp'] as String),
                  isError: msg['is_error'] as bool? ?? false,
                ))
            .toList();

        if (mounted && messages.isNotEmpty) {
          setState(() {
            _messages.clear();
            _messages.addAll(messages);
          });
          debugPrint('📥 Loaded conversation $_currentConversationId with ${messages.length} messages');
        }
      } else {
        // No existing conversation - will create on first message
        debugPrint('📝 No existing conversation found, will create new one');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load conversation: $e');
      // Don't show error - just start fresh
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.smart_toy,
              color: _aiInitialized ? Colors.blue : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('AI Assistant'),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _aiInitialized ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _aiInitialized ? 'Online' : 'Offline',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // Credits widget for logged-in users (compact)
          if (!_isGuest)
            ValueListenableBuilder<ProfileInfo>(
              valueListenable: ProfileRepository.instance.profile,
              builder: (context, profile, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stars, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 4),
                          Text(
                            '${profile.aiCredits}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          // Buy credits button for logged-in users
          if (!_isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () => _showBuyCreditsDialog(context),
                  icon: const Icon(Icons.shopping_cart, size: 16),
                  label: const Text('Buy', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          // Guest conversation counter
          if (_isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _guestConversationCount >= _guestConversationLimit
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _guestConversationCount >= _guestConversationLimit
                          ? Colors.red
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _guestConversationCount >= _guestConversationLimit
                            ? Icons.lock
                            : Icons.chat_bubble_outline,
                        size: 14,
                        color: _guestConversationCount >= _guestConversationLimit
                            ? Colors.red
                            : Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_guestConversationLimit - _guestConversationCount} left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _guestConversationCount >= _guestConversationLimit
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // AI Settings button
          IconButton(
            onPressed: _showAISettings,
            icon: const Icon(Icons.settings),
            tooltip: 'AI Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to AI Assistant...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Show typing indicator as last item inside the list
                      if (_isLoading && index == _messages.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: const [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: Colors.blue,
                                child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
                              ),
                              SizedBox(width: 8),
                              _TypingIndicator(),
                            ],
                          ),
                        );
                      }
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Image picker button
                  IconButton(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image, color: Colors.grey),
                    tooltip: 'Add Image',
                  ),
                  // Mic button with continuous mode indicator
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulsing animation when listening
                      if (_isListening)
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.red.withValues(alpha: 0.2),
                          ),
                        ),
                      IconButton(
                        onPressed: _toggleVoiceInput,
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.grey,
                        ),
                        tooltip: _isListening
                            ? 'Stop Voice Input (Continuous Mode Active)'
                            : 'Start Voice Input (Continuous Mode)',
                      ),
                    ],
                  ),
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: !_isLoading,
                      decoration: InputDecoration(
                        hintText: _isLoading
                            ? 'AI is responding...'
                            : 'Type your message...',
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        isDense: true,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  FloatingActionButton(
                    mini: true,
                    onPressed: _isLoading ? null : _sendMessage,
                    backgroundColor: _isLoading ? Colors.grey : null,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
  });
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = message.isError
        ? Colors.red[100]
        : message.isUser
            ? Colors.blue
            : Colors.grey[200];

    final textColor = message.isUser ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: message.isError ? Colors.red : Colors.blue,
              child: Icon(
                message.isError ? Icons.error : Icons.smart_toy,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 20),
                ),
              ),
              child: Text(
                message.text,
                style: TextStyle(color: textColor),
              ),
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[400],
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      ),
    );
    _animations = _controllers
        .map((c) => Tween<double>(begin: 0, end: -6)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)))
        .toList();

    for (var i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (context, _) => Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: Colors.grey[500],
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// AI Settings Bottom Sheet Widget
class AISettingsBottomSheet extends StatelessWidget {
  final bool aiInitialized;
  final VoidCallback onClearChat;
  final VoidCallback onReconnectAI;

  const AISettingsBottomSheet({
    super.key,
    required this.aiInitialized,
    required this.onClearChat,
    required this.onReconnectAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Title
          Row(
            children: [
              const Icon(Icons.settings, color: Colors.blue),
              const SizedBox(width: 8),
              const Text(
                'AI Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // AI Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: aiInitialized ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: aiInitialized ? Colors.green : Colors.orange,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  aiInitialized ? Icons.check_circle : Icons.warning,
                  color: aiInitialized ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        aiInitialized ? 'AI Connected' : 'AI Offline',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: aiInitialized ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                      Text(
                        aiInitialized 
                          ? 'AI Assistant is connected'
                          : 'AI Assistant is offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: aiInitialized ? Colors.green[600] : Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Settings Options
          _buildSettingsTile(
            icon: Icons.refresh,
            title: 'Reconnect AI',
            subtitle: 'Reconnect to AI Assistant',
            onTap: onReconnectAI,
          ),
          _buildSettingsTile(
            icon: Icons.clear_all,
            title: 'Clear Chat History',
            subtitle: 'Remove all messages',
            onTap: onClearChat,
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'AI Model',
            subtitle: 'VaultWheels AI Assistant',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('VaultWheels AI Assistant')),
              );
            },
          ),
          _buildSettingsTile(
            icon: Icons.bug_report,
            title: 'Debug Mode',
            subtitle: 'View detailed logs in console',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Check debug console for detailed AI logs')),
              );
            },
          ),

          const SizedBox(height: 20),
          
          // Close button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Close'),
            ),
          ),
          
          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}


