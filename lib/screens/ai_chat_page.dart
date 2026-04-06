import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_repository.dart';
// import 'package:image_picker/image_picker.dart'; // Commented out for Windows compatibility
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
  String? _initError;
  int? _currentConversationId; // Track current conversation
  
  // Image and voice functionality (disabled for Windows compatibility)
  // final ImagePicker _imagePicker = ImagePicker();
  // final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _loadOrCreateConversation(); // Load or create conversation
    _initializeFirebaseAI();
  }

  Future<void> _initializeFirebaseAI() async {
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash-lite',
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

Be conversational, helpful, and specific to ride-sharing context. Keep responses concise but informative. Always sound natural and friendly, never robotic.
        '''),
      );

      _chat = _model!.startChat();

      // Test the connection with a timeout
      final testResponse = await _chat!
          .sendMessage(Content.text('say "ready" in one word'))
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Connection timeout - Gemini AI is not responding');
            },
          );
      
      final testText = testResponse.text ?? '';
      debugPrint('✅ Firebase AI test response: $testText');

      setState(() {
        _aiInitialized = true;
        _messages.add(ChatMessage(
          text:
              "Hi there! Welcome to QuickOHunt. I'm your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app. What can I help you with today?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e, stack) {
      debugPrint('❌ Firebase AI initialization failed: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _aiInitialized = false;
        _initError = e.toString();
        _messages.add(ChatMessage(
          text:
              "⚠️ AI connection failed.\n\nError: $e\n\nPlease check:\n1. Firebase AI Logic is enabled in Firebase Console\n2. Gemini API is enabled in Google Cloud Console\n3. Your google-services.json is up to date\n\nYou can still use the app - just tap back to continue.",
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Image picker not available on this platform. Use web version for full functionality.'),
        backgroundColor: Colors.orange,
      ),
    );
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice input not available on this platform. Use web version for full functionality.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _stopListening() {
    setState(() {
      _isListening = false;
    });
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
    setState(() {
      _aiInitialized = false;
      _initError = null;
    });
    _initializeFirebaseAI();
    Navigator.pop(context); // Close settings
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

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

    await _sendToFirebaseAI(text);
  }

  Future<void> _sendToFirebaseAI(String userText) async {
    // Show real error instead of fake fallback
    if (!_aiInitialized || _chat == null) {
      _addAIMessage(
        "⚠️ AI is not connected.\n\nError: ${_initError ?? 'Unknown error during initialization.'}\n\nPlease restart the app or check Firebase Console.",
        isError: true,
      );
      return;
    }

    try {
      debugPrint('📤 Sending to Firebase AI: $userText');
      final response = await _chat!.sendMessage(Content.text(userText));
      final aiText = response.text?.trim();
      debugPrint('📥 Firebase AI response: $aiText');

      if (aiText == null || aiText.isEmpty) {
        _addAIMessage("I received an empty response. Please try again.",
            isError: true);
      } else {
        _addAIMessage(aiText);
      }
    } catch (e) {
      // FirebaseException is not exported by firebase_ai — catch all and log
      debugPrint('❌ Firebase AI error: $e');
      _addAIMessage(
        "AI error: $e\n\nMake sure Firebase AI Logic and Gemini API are enabled in your Firebase Console.",
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
                _aiInitialized ? 'Gemini ✓' : 'Offline',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
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
          // Typing indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.blue,
                    child: Icon(Icons.smart_toy, size: 16, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const _TypingIndicator(),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to Gemini AI...'),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return ChatBubble(message: _messages[index]);
                    },
                  ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Image picker button
                IconButton(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.image, color: Colors.grey),
                  tooltip: 'Add Image',
                ),
                // Mic button
                IconButton(
                  onPressed: _toggleVoiceInput,
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.grey,
                  ),
                  tooltip: 'Voice Input',
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
                          ? 'Firebase AI Logic is working'
                          : 'Check Firebase AI Logic setup',
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
            subtitle: 'Retry Firebase AI connection',
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
            subtitle: 'Gemini 2.0 Flash (Firebase AI Logic)',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Model: Gemini 2.0 Flash via Firebase AI Logic')),
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
