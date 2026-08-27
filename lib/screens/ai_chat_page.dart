import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_repository.dart';
import '../services/profile_repository.dart';
import '../services/payment_service.dart';
import '../services/pricing_service.dart';
import '../services/app_preferences.dart';
import '../services/dispute_service.dart';
import '../services/credit_repository.dart';
import '../services/ai_memory_service.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:speech_to_text/speech_to_text.dart'; // Commented out for Windows compatibility
// import 'package:permission_handler/permission_handler.dart'; // Not needed

class AIChatPage extends StatefulWidget {
  final int? conversationId; // Support loading existing conversation
  final bool isDisputeMode; // Flag to indicate dispute mediation mode

  const AIChatPage({
    super.key,
    this.conversationId,
    this.isDisputeMode = false,
  });

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final List<ConversationItem> _conversations = []; // ← ADD: Conversation list

  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isLoading = false;
  bool _aiInitialized = false;
  int? _currentConversationId; // Track current conversation
  bool _showSidebar = true; // ← ADD: Toggle sidebar

  // Guest user credit allowance (instead of conversation limit)
  static const double _guestInitialCredits =
      0.0; // Guests get 0 credits - must login for AI access
  double _guestCreditsRemaining = _guestInitialCredits;
  bool _isGuest = false;

  // Image and voice functionality
  final ImagePicker _imagePicker = ImagePicker();
  // final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;

  // AI Toggle state
  bool _aiEnabled = true; // Toggle to enable/disable AI

  // Conversation filter state
  String _conversationFilter = 'all'; // 'all', 'general', 'disputes'

  @override
  void initState() {
    super.initState();
    _loadAIToggleState();
    _checkGuestStatus();
    AIMemoryService.instance.initialize(); // Initialize memory service

    // Load specific conversation if provided
    if (widget.conversationId != null) {
      _currentConversationId = widget.conversationId;
      _loadConversation(widget.conversationId!);
    }

    _loadConversationHistory(); // Load conversation list
    _initializeFirebaseAI();
  }

  Future<void> _loadAIToggleState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _aiEnabled = prefs.getBool('ai_enabled') ?? true;
    });
  }

  Future<void> _toggleAI(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_enabled', value);
    setState(() {
      _aiEnabled = value;
    });

    if (value && !_aiInitialized) {
      // Re-initialize AI if it was disabled
      _initializeFirebaseAI();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _aiEnabled ? '✅ AI Assistant Enabled' : '⚠️ AI Assistant Disabled',
        ),
        backgroundColor: _aiEnabled ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _checkGuestStatus() async {
    final currentUser = AuthRepository.instance.currentUser;
    _isGuest = currentUser == null;

    if (_isGuest) {
      // Load guest conversation count from SharedPreferences (stored as string to preserve decimals)
      final prefs = await SharedPreferences.getInstance();
      final creditsStr = prefs.getString('guest_credits_remaining');
      _guestCreditsRemaining = creditsStr != null
          ? double.tryParse(creditsStr) ?? _guestInitialCredits
          : _guestInitialCredits;
      debugPrint(
        '👤 Guest user - credits remaining: $_guestCreditsRemaining/$_guestInitialCredits',
      );
    }
  }

  // ← ADD: Load conversation history for sidebar
  Future<void> _loadConversationHistory() async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('ai_conversations')
          .select()
          .eq('profile_id', userId)
          .order('updated_at', ascending: false)
          .limit(20);

      if (!mounted) return;
      setState(() {
        _conversations.clear();
        for (final conv in response) {
          _conversations.add(ConversationItem.fromJson(conv));
        }
      });
      debugPrint('📥 Loaded ${_conversations.length} conversations');
    } catch (e) {
      debugPrint('⚠️ Failed to load conversation history: $e');
    }
  }

  // ← ADD: Create new conversation
  Future<void> _createNewConversation() async {
    setState(() {
      _currentConversationId = null;
      _messages.clear();
    });
    _loadConversationHistory();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✨ New conversation started'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ← ADD: Load specific conversation
  Future<void> _loadConversation(int conversationId) async {
    try {
      final response = await Supabase.instance.client
          .from('ai_conversations')
          .select()
          .eq('id', conversationId)
          .single();

      final messagesJson = response['messages'] as List;
      final messages = messagesJson
          .map(
            (msg) => ChatMessage(
              text: msg['content'] as String,
              isUser: msg['role'] == 'user',
              timestamp: DateTime.parse(msg['timestamp'] as String),
              isError: msg['is_error'] as bool? ?? false,
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _currentConversationId = conversationId;
        _messages.clear();
        _messages.addAll(messages);
      });
      debugPrint(
        '📥 Loaded conversation $conversationId with ${messages.length} messages',
      );
    } catch (e) {
      debugPrint('❌ Failed to load conversation: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load conversation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _initializeFirebaseAI() async {
    try {
      debugPrint('🚀 Initializing Firebase Gemini API...');

      // Get system prompt based on mode (dispute or general)
      String systemPrompt = '''
You are a helpful AI assistant for QuickOHunt, a ride-sharing and vehicle rental app.

Key features of QuickOHunt:
- Users can book rides (passenger service)
- Users can send parcels (parcel delivery)
- Users can help with vehicles (with or without operators)
- Users can add their own vehicles to provide services
- Users can add needed vehicles to find rides
- Payment system with wallet and Razorpay integration
- Document verification for legal compliance
- GPS tracking and live location
- Review and rating system

Be conversational, helpful, and specific to ride-sharing context. Keep responses concise (2-3 sentences max). Always sound natural and friendly, never robotic. Always guide users to take action inside the app.
''';

      // If in dispute mode, use specialized dispute mediation prompt
      if (widget.isDisputeMode && _currentConversationId != null) {
        try {
          final conv = await Supabase.instance.client
              .from('ai_conversations')
              .select('metadata, dispute_party')
              .eq('id', _currentConversationId!)
              .single();

          final metadata = conv['metadata'] as Map<String, dynamic>;
          final party = conv['dispute_party'] as String;

          systemPrompt = DisputeService.getDisputeSystemPrompt(metadata, party);
          debugPrint('🤖 Using dispute mediation prompt for $party');
        } catch (e) {
          debugPrint('⚠️ Failed to load dispute context: $e');
        }
      }

      // Use Firebase Gemini API (free tier available, no API key needed)
      // This uses Google AI's Gemini API through Firebase
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash', // Latest, faster, lighter model
        systemInstruction: Content.system(systemPrompt),
      );

      _chat = _model!.startChat();

      // Test the connection silently (don't add to messages)
      try {
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
      } catch (e) {
        debugPrint('⚠️ Connection test failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _aiInitialized = true;
        // Only add welcome message if no messages exist yet AND not in dispute mode
        // (dispute mode already has welcome message from DisputeService)
        if (_messages.isEmpty && !widget.isDisputeMode) {
          final welcomeMessage = _isGuest
              ? "Hi there! Welcome to QuickOHunt. I'm your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app.\n\n⚠️ Guest Mode: AI assistant requires login. Please login to get free credits and unlimited access!\n\nWhat can I help you with today?"
              : "Hi there! Welcome to QuickOHunt. I'm your AI assistant here to help you with rides, vehicle rentals, bookings, and any questions about the app. What can I help you with today?";

          _messages.add(
            ChatMessage(
              text: welcomeMessage,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    } catch (e, stack) {
      debugPrint('❌ Firebase Gemini API initialization failed: $e');
      debugPrint('Stack: $stack');
      if (!mounted) return;
      setState(() {
        _aiInitialized = false;
        _messages.add(
          ChatMessage(
            text:
                "⚠️ AI Assistant is temporarily unavailable.\n\n"
                "Our AI service is currently offline. Please try again later or contact support if the issue persists.\n\n"
                "You can still use all other features of the app — just tap back to continue.",
            isUser: false,
            timestamp: DateTime.now(),
            isError: true,
          ),
        );
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
        _messages.add(
          ChatMessage(
            text: '📎 Image attached: ${picked.name} (${sizeKb}KB)',
            isUser: true,
            timestamp: DateTime.now(),
          ),
        );
      });
      _scrollToBottom();

      // Send image context to AI
      await _sendToFirebaseAI(
        'I have attached an image: ${picked.name}. Please acknowledge it.',
      );
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
        content: Text(
          _isListening
              ? 'Voice input active - speak continuously until you tap mic again'
              : 'Voice input not available on this platform',
        ),
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

  // Memory Settings functionality
  void _showMemorySettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🧠 Memory Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Memory status text
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Status: ${AIMemoryService.instance.getMemoryStatusText()}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ),
            // Thread Memory Toggle
            ValueListenableBuilder<bool>(
              valueListenable: AIMemoryService.instance.threadMemoryEnabled,
              builder: (context, threadEnabled, _) {
                return CheckboxListTile(
                  title: const Text('🧵 Thread Memory'),
                  subtitle: const Text(
                    'Remember messages in this conversation',
                  ),
                  value: threadEnabled,
                  onChanged: (value) {
                    if (value != null) {
                      AIMemoryService.instance.setThreadMemory(value);
                      setState(() {});
                    }
                  },
                );
              },
            ),
            // Chat Memory Toggle
            ValueListenableBuilder<bool>(
              valueListenable: AIMemoryService.instance.chatMemoryEnabled,
              builder: (context, chatEnabled, _) {
                return CheckboxListTile(
                  title: const Text('💬 Chat Memory'),
                  subtitle: const Text('Reference previous conversations'),
                  value: chatEnabled,
                  onChanged: (value) {
                    if (value != null) {
                      AIMemoryService.instance.setChatMemory(value);
                      setState(() {});
                    }
                  },
                );
              },
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Memory Modes:\n'
                '🧠 = Full (Thread + Chat)\n'
                '🧵 = Thread only\n'
                '💬 = Chat only\n'
                '🆕 = No Memory (Fresh)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
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
        aiEnabled: _aiEnabled,
        onToggleAI: _toggleAI,
        onClearChat: _clearChat,
        onReconnectAI: _reconnectAI,
      ),
    );
  }

  void _clearChat() {
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _messages.add(
        ChatMessage(
          text: "Chat history cleared. How can I help you?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
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

    // Check if AI is enabled
    if (!_aiEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ AI Assistant is disabled. Enable it in settings.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Check guest credit limit
    if (_isGuest) {
      final threadMemory = AIMemoryService.instance.threadMemoryEnabled.value;
      final chatMemory = AIMemoryService.instance.chatMemoryEnabled.value;
      final estimatedCredits = CreditRepository.estimateCreditCostForMessage(
        text,
        threadMemory: threadMemory,
        chatMemory: chatMemory,
      );
      if (_guestCreditsRemaining < estimatedCredits) {
        _showLoginPrompt(
          message:
              '⚠️ Insufficient guest credits.\n\nYou have ${_guestCreditsRemaining.toStringAsFixed(4)} credits left, need ~${estimatedCredits.toStringAsFixed(4)}.\n\nLogin to purchase more credits.',
        );
        return;
      }
    }

    // Check AI credits for logged-in users (using token-based pricing)
    if (!_isGuest) {
      final threadMemory = AIMemoryService.instance.threadMemoryEnabled.value;
      final chatMemory = AIMemoryService.instance.chatMemoryEnabled.value;
      final estimatedCredits = CreditRepository.estimateCreditCostForMessage(
        text,
        threadMemory: threadMemory,
        chatMemory: chatMemory,
      );
      final hasCredits = await CreditRepository.instance.hasEnoughCreditsForAI(
        estimatedCredits: estimatedCredits,
      );
      if (!hasCredits) {
        if (mounted) {
          _showBuyCreditsDialog(context);
        }
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Deduct guest credits (keep as raw decimal values)
    if (_isGuest && _messages.isNotEmpty) {
      final lastMessage = _messages.last;
      if (lastMessage.creditCost != null) {
        _guestCreditsRemaining -= lastMessage.creditCost!;
        final prefs = await SharedPreferences.getInstance();
        // Store as string to preserve decimal precision
        await prefs.setString(
          'guest_credits_remaining',
          _guestCreditsRemaining.toString(),
        );
        debugPrint(
          '👤 Guest credits deducted: ${lastMessage.creditCost?.toStringAsFixed(4)}, remaining: ${_guestCreditsRemaining.toStringAsFixed(4)}/$_guestInitialCredits',
        );
      }
    }

    // FIXED: Wrap in try-finally to ensure _isLoading is always reset
    try {
      await _sendToFirebaseAI(text);
    } catch (e) {
      debugPrint('❌ Error in _sendMessage: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLoginPrompt({String? message}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Guest Credit Limit'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message ?? 'You\'ve used all your 20 guest credits.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Login to get unlimited credits and access to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text('• Unlimited AI chat with credits'),
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
            _buildCreditPackage(context, 50, 3),
            const SizedBox(height: 8),
            _buildCreditPackage(context, 200, 10, popular: true),
            const SizedBox(height: 8),
            _buildCreditPackage(context, 1000, 50),
            const SizedBox(height: 16),
            ValueListenableBuilder<String>(
              valueListenable: AppPreferences.instance.currencyCode,
              builder: (context, currency, _) {
                // ✅ NEW: Show converted credit value
                final creditValue = PricingService.instance.convertPrice(
                  0.06,
                  currency,
                );
                final symbol = AppPreferences.instance.currencySymbol;
                String formattedValue;
                if (currency == 'INR') {
                  formattedValue = '$symbol${creditValue.toInt()}';
                } else {
                  formattedValue = '$symbol${creditValue.toStringAsFixed(4)}';
                }
                return Text(
                  'Cost varies by message length & complexity\n'
                  '1 credit = $formattedValue',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
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

  void _showCreditUsageDetails(BuildContext context, ProfileInfo profile) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('Credit Usage'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current balance
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Balance',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${profile.aiCredits} Credits',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Usage breakdown
            const Text(
              'Usage Information:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            // Calculate total credits used today
            _buildUsageRow(
              Icons.chat,
              'Messages sent today',
              '${_messages.where((m) => m.isUser).length}',
            ),
            _buildUsageRow(
              Icons.calculate,
              'Total credits used',
              '${_messages.fold<double>(0, (sum, m) => sum + (m.creditCost ?? 0)).toStringAsFixed(4)} credits',
            ),
            _buildUsageRow(
              Icons.warning_amber,
              'Status',
              profile.aiCredits < 10 ? 'Low balance' : 'Good balance',
              color: profile.aiCredits < 10 ? Colors.red : Colors.green,
            ),
            const SizedBox(height: 16),

            // Quick actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showBuyCreditsDialog(context);
                    },
                    icon: const Icon(Icons.add_shopping_cart, size: 16),
                    label: const Text(
                      'Buy More',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildUsageRow(
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditPackage(
    BuildContext context,
    int credits,
    int price, {
    bool popular = false,
  }) {
    return InkWell(
      onTap: () async {
        Navigator.pop(context); // Close dialog
        await _purchaseAICredits(context, credits, price);
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
                          color: popular
                              ? Colors.blue.shade900
                              : Colors.black87,
                        ),
                      ),
                      if (popular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
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
                  ValueListenableBuilder<String>(
                    valueListenable: AppPreferences.instance.currencyCode,
                    builder: (context, currency, _) {
                      // ✅ NEW: Use dynamic pricing conversion
                      final displayPrice = PricingService.instance
                          .formatCreditPrice(credits, currency);
                      return Text(
                        displayPrice,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      );
                    },
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
      // ✅ Check credits before sending (with memory markup)
      final threadMemory = AIMemoryService.instance.threadMemoryEnabled.value;
      final chatMemory = AIMemoryService.instance.chatMemoryEnabled.value;
      final estimatedCredits = CreditRepository.estimateCreditCostForMessage(
        userText,
        threadMemory: threadMemory,
        chatMemory: chatMemory,
      );
      final hasCredits = await CreditRepository.instance.hasEnoughCreditsForAI(
        estimatedCredits: estimatedCredits,
      );

      if (!hasCredits) {
        final currentBalance = CreditRepository.instance.creditBalance.value;
        _addAIMessage(
          "⚠️ Insufficient credits to send message.\n\n"
          "You have $currentBalance credits, need ≈$estimatedCredits.\n\n"
          "Tap 'Buy Credits' to purchase more.",
          isError: true,
        );
        return;
      }

      debugPrint('📤 Sending to Firebase Gemini API: $userText');

      // ✅ Build context based on memory settings
      String contextMessage = userText;
      final threadMemoryEnabled =
          AIMemoryService.instance.threadMemoryEnabled.value;
      final chatMemoryEnabled =
          AIMemoryService.instance.chatMemoryEnabled.value;

      if (threadMemoryEnabled || chatMemoryEnabled) {
        final contextParts = <String>[];

        // Add thread memory context (current conversation)
        if (threadMemoryEnabled && _messages.isNotEmpty) {
          final recentMessages = _messages.take(
            10,
          ); // Last 10 messages for context
          for (final msg in recentMessages) {
            if (msg.isUser) {
              contextParts.add('User: ${msg.text}');
            } else {
              final preview = msg.text.length > 100
                  ? '${msg.text.substring(0, 100)}...'
                  : msg.text;
              contextParts.add('Assistant: $preview');
            }
          }
        }

        // Add chat memory note (cross-conversation reference)
        if (chatMemoryEnabled && _currentConversationId != null) {
          contextParts.add(
            '\n[Note: You can reference previous conversations in your response]',
          );
        }

        if (contextParts.isNotEmpty) {
          contextMessage =
              '${contextParts.join("\n")}\n\nCurrent message: $userText';
          debugPrint(
            '[Memory] Context built - Thread: $threadMemoryEnabled, Chat: $chatMemoryEnabled',
          );
        }
      } else {
        debugPrint('[Memory] No memory enabled - Fresh start mode');
      }

      final response = await _chat!.sendMessage(Content.text(contextMessage));
      final aiText = response.text?.trim();

      // ✅ Extract token counts from response
      var inputTokens = response.usageMetadata?.promptTokenCount ?? 0;
      var outputTokens = response.usageMetadata?.candidatesTokenCount ?? 0;

      // ✅ If token counts not available, use conservative estimate
      if (inputTokens == 0 && outputTokens == 0) {
        debugPrint('⚠️ Token counts unavailable, using fallback estimate');
        // Estimate based on message and response length
        inputTokens = (userText.split(' ').length * 1.3)
            .ceil(); // ~1.3 tokens per word
        outputTokens = ((aiText?.split(' ').length ?? 100) * 1.3).ceil();
      }

      debugPrint('📊 Tokens - Input: $inputTokens, Output: $outputTokens');

      debugPrint('📥 Firebase Gemini API response: $aiText');

      if (aiText == null || aiText.isEmpty) {
        _addAIMessage(
          "I received an empty response. Please try again.",
          isError: true,
        );
      } else {
        // ✅ Deduct real credits based on token usage
        final deducted = await CreditRepository.instance.deductCredits(
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          conversationId: _currentConversationId?.toString(),
        );

        if (deducted) {
          debugPrint('✅ Credits deducted successfully');
          _addAIMessage(aiText, tokenUsage: (inputTokens, outputTokens));
        } else {
          debugPrint('⚠️ Failed to deduct credits but showing message');
          // Still show message - credit deduction is best-effort
          _addAIMessage(aiText);
        }
      }
    } catch (e) {
      debugPrint('❌ Firebase Gemini API error: $e');
      _addAIMessage(
        "Sorry, I couldn't process your message. Please check your connection and try again.",
        isError: true,
      );
    }
  }

  void _addAIMessage(
    String text, {
    bool isError = false,
    (int, int)? tokenUsage,
  }) {
    if (mounted) {
      // Calculate credit cost from token usage if available (raw decimal value)
      // Include memory markup multiplier
      double? creditCost;
      if (tokenUsage != null) {
        final threadMemory = AIMemoryService.instance.threadMemoryEnabled.value;
        final chatMemory = AIMemoryService.instance.chatMemoryEnabled.value;
        creditCost = CreditRepository.estimateCreditCostForTokens(
          inputTokens: tokenUsage.$1,
          outputTokens: tokenUsage.$2,
          threadMemory: threadMemory,
          chatMemory: chatMemory,
        );
      }

      setState(() {
        _messages.add(
          ChatMessage(
            text: text,
            isUser: false,
            timestamp: DateTime.now(),
            isError: isError,
            tokenUsage: tokenUsage,
            creditCost: creditCost,
          ),
        );
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
      final messagesJson = _messages
          .map(
            (msg) => {
              'role': msg.isUser ? 'user' : 'assistant',
              'content': msg.text,
              'timestamp': msg.timestamp.toIso8601String(),
              if (msg.isError) 'is_error': true,
            },
          )
          .toList();

      if (_currentConversationId == null) {
        // Generate AI title after first exchange (user + assistant message)
        String title = 'New Chat';

        if (_messages.length >= 2) {
          // Let AI generate a smart title based on conversation
          try {
            final titlePrompt =
                'Generate a short, concise title (max 40 characters) for this conversation. '
                'Just respond with the title only, no quotes or extra text:\n\n'
                'User: ${_messages.first.text}\n'
                'Assistant: ${_messages[1].text}';

            final titleResponse = await _model?.generateContent([
              Content.text(titlePrompt),
            ]);
            if (titleResponse != null && titleResponse.text != null) {
              title = titleResponse.text!.trim();
              // Remove quotes if AI added them
              title = title.replaceAll('"', '').replaceAll("'", '');
              // Ensure max length
              if (title.length > 40) {
                title = '${title.substring(0, 37)}...';
              }
            }
          } catch (e) {
            // Fallback: Use first user message
            final firstUserMessage = _messages.firstWhere(
              (msg) => msg.isUser,
              orElse: () => ChatMessage(
                text: 'New Chat',
                isUser: true,
                timestamp: DateTime.now(),
              ),
            );
            title = firstUserMessage.text.trim();
            if (title.length > 40) {
              title = '${title.substring(0, 37)}...';
            }
          }
        }

        // Create new conversation
        final response = await Supabase.instance.client
            .from('ai_conversations')
            .insert({
              'profile_id': userId,
              'title': title,
              'messages': messagesJson,
              'context_type': 'general',
              'context_id': '',
              'is_active': true,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();

        _currentConversationId = response['id'] as int;
        debugPrint(
          '💾 Created new conversation: $_currentConversationId with AI title: $title',
        );

        // Refresh sidebar after creating new conversation
        _loadConversationHistory();
      } else {
        // Update existing conversation
        await Supabase.instance.client
            .from('ai_conversations')
            .update({
              'messages': messagesJson,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _currentConversationId!);

        debugPrint(
          '💾 Updated conversation $_currentConversationId with ${messagesJson.length} messages',
        );

        // Refresh sidebar to update timestamps
        _loadConversationHistory();
      }
    } catch (e) {
      debugPrint('⚠️ Failed to save chat history: $e');
      // Don't show error to user - this is background save
    }
  }

  // Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    ConversationItem conv,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation?'),
        content: Text(
          'Are you sure you want to delete "${conv.title}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteConversation(conv.id);
    }
  }

  // Delete conversation
  Future<void> _deleteConversation(int conversationId) async {
    try {
      await Supabase.instance.client
          .from('ai_conversations')
          .delete()
          .eq('id', conversationId);

      // If deleted conversation was current, clear messages and create new
      if (conversationId == _currentConversationId) {
        setState(() {
          _currentConversationId = null;
          _messages.clear();
        });
      }

      // Refresh conversation list
      await _loadConversationHistory();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗑️ Conversation deleted'),
          duration: Duration(seconds: 2),
        ),
      );

      debugPrint('🗑️ Deleted conversation: $conversationId');
    } catch (e) {
      debugPrint('❌ Failed to delete conversation: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _purchaseAICredits(
    BuildContext context,
    int credits,
    int price,
  ) async {
    final currentUser = AuthRepository.instance.currentUser;
    if (currentUser == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to purchase AI credits'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Capture navigator before async gap
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // Show loading
    navigator.push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) => PopScope(
          canPop: false,
          child: Container(
            color: Colors.black54,
            child: const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Processing payment...'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    try {
      // Get user details and currency
      final profile = ProfileRepository.instance.profile.value;
      final userName = profile.profileName.isEmpty
          ? 'User'
          : profile.profileName;
      final userEmail = currentUser.email;
      final userPhone = profile.phone ?? '0000000000';
      final currency = AppPreferences.instance.currencyCode.value;

      // Convert price to double for payment
      final priceDouble = price.toDouble();

      debugPrint(
        '💳 Starting AI credit purchase: $credits credits, $priceDouble $currency',
      );

      // ✅ NEW: Validate price with backend before processing payment
      // This prevents users from modifying prices in the frontend
      final validationResult = await _validateCreditPriceWithBackend(
        credits: credits,
        amountUSD: priceDouble,
        currency: currency,
      );

      if (!validationResult['valid']) {
        // Close loading
        if (navigator.canPop()) navigator.pop();

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Price validation failed: ${validationResult['error']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Use validated price from backend
      final validatedPrice = validationResult['amount'] ?? priceDouble;

      // Process payment via PaymentService
      final result = await PaymentService.instance.processSubscriptionPayment(
        planName: 'AI Credits ($credits)',
        amount: validatedPrice,
        userName: userName,
        userEmail: userEmail,
        userPhone: userPhone,
        currency: currency,
      );

      debugPrint('💳 Payment result received: ${result.keys.join(", ")}');

      // Close loading
      if (navigator.canPop()) {
        navigator.pop();
        debugPrint('💳 Closed loading dialog');
      }

      // Check for errors
      if (result['error'] != null) {
        debugPrint('💳 Payment error: ${result['error']}');
        messenger.showSnackBar(
          SnackBar(
            content: Text('Payment failed: ${result['error']}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check for web redirect
      if (result['web_redirect'] == true) {
        debugPrint('💳 Web redirect required');
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Complete payment to receive your AI credits.'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      // Payment successful - add credits
      debugPrint('💳 Payment successful, adding $credits credits');
      await ProfileRepository.instance.addAICredits(credits);
      debugPrint('💳 Credits added successfully');

      messenger.showSnackBar(
        SnackBar(
          content: Text('🎉 Added $credits AI credits!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('💳 Exception in _purchaseAICredits: $e');
      debugPrint('💳 Stack trace: $stackTrace');

      // Close loading dialog on error
      if (navigator.canPop()) {
        navigator.pop();
        debugPrint('💳 Closed loading dialog (error path)');
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text('Payment error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Validate credit package price with backend
  /// Prevents clients from tampering with prices
  Future<Map<String, dynamic>> _validateCreditPriceWithBackend({
    required int credits,
    required double amountUSD,
    required String currency,
  }) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('validateAndPurchaseAICredits');

      final result = await callable.call({
        'credits': credits,
        'amountUSD': amountUSD,
        'currency': currency,
      });

      final data = result.data as Map<String, dynamic>;

      if (data['valid'] == true) {
        debugPrint('✅ Backend validated credit purchase');
        return {
          'valid': true,
          'amount': data['amount'] as double,
          'credits': data['credits'] as int,
        };
      } else {
        debugPrint('❌ Backend rejected credit purchase');
        return {
          'valid': false,
          'error': data['message'] ?? 'Price validation failed',
        };
      }
    } catch (e) {
      debugPrint('⚠️ Price validation error: $e');
      // Fail open - if backend validation fails, reject the purchase
      return {'valid': false, 'error': 'Could not validate price with server'};
    }
  }

  // Build sidebar widget for conversation history
  Widget _buildSidebar() {
    // Filter conversations based on selected tab
    final filteredConversations = _conversations.where((conv) {
      if (_conversationFilter == 'all') return true;
      if (_conversationFilter == 'general') {
        return conv.contextType == 'general';
      }
      if (_conversationFilter == 'disputes') {
        return conv.contextType.startsWith(
          'dispute',
        ); // Both 'dispute' and 'dispute_completed'
      }
      return true;
    }).toList();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(right: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.inversePrimary.withValues(alpha: 0.3),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Conversations',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.add,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  onPressed: _createNewConversation,
                  tooltip: 'New Conversation',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // Filter Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                _buildFilterTab('All', 'all', Icons.chat_bubble_outline),
                const SizedBox(width: 4),
                _buildFilterTab('General', 'general', Icons.chat),
                // Disputes tab hidden for launch
                // const SizedBox(width: 4),
                // _buildFilterTab('Disputes', 'disputes', Icons.gavel),
              ],
            ),
          ),

          // Conversations List
          Expanded(
            child: filteredConversations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _conversationFilter == 'disputes'
                            ? 'No disputes yet.\nRaise a dispute from bookings!'
                            : 'No conversations yet.\nStart chatting to create one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredConversations.length,
                    itemBuilder: (context, index) {
                      final conv = filteredConversations[index];
                      final isSelected = conv.id == _currentConversationId;

                      return InkWell(
                        onTap: () => _loadConversation(conv.id),
                        onLongPress: () =>
                            _showDeleteConfirmation(context, conv),
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.1)
                                : (conv.contextType.startsWith('dispute')
                                      ? (conv.contextType == 'dispute_completed'
                                            ? Colors.green.withValues(
                                                alpha: 0.05,
                                              )
                                            : Colors.orange.withValues(
                                                alpha: 0.05,
                                              ))
                                      : Colors.transparent),
                            borderRadius: BorderRadius.circular(8),
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 1,
                                  )
                                : (conv.contextType.startsWith('dispute')
                                      ? Border.all(
                                          color:
                                              conv.contextType ==
                                                  'dispute_completed'
                                              ? Colors.green.withValues(
                                                  alpha: 0.4,
                                                )
                                              : Colors.orange.withValues(
                                                  alpha: 0.3,
                                                ),
                                          width: 1,
                                        )
                                      : null),
                          ),
                          child: Row(
                            children: [
                              // Icon changes based on type
                              Icon(
                                conv.contextType.startsWith('dispute')
                                    ? Icons.gavel
                                    : Icons.chat,
                                color: conv.contextType.startsWith('dispute')
                                    ? (conv.contextType == 'dispute_completed'
                                          ? Colors.green[700]
                                          : Colors.orange[700])
                                    : (isSelected
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[600]),
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            conv.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color:
                                                  conv.contextType.startsWith(
                                                    'dispute',
                                                  )
                                                  ? Colors.orange[900]
                                                  : null,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        // Dispute badge - shows status based on context_type
                                        if (conv.contextType.startsWith(
                                          'dispute',
                                        ))
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  conv.contextType ==
                                                      'dispute_completed'
                                                  ? Colors.green
                                                  : Colors.orange,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              conv.contextType ==
                                                      'dispute_completed'
                                                  ? 'RESOLVED'
                                                  : 'ACTIVE',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatTimestamp(conv.updatedAt),
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // Format timestamp for sidebar
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  // Build filter tab button
  Widget _buildFilterTab(String label, String filter, IconData icon) {
    final isSelected = _conversationFilter == filter;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _conversationFilter = filter;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: Theme.of(context).primaryColor, width: 1)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey[700],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              widget.isDisputeMode ? Icons.gavel : Icons.smart_toy,
              color: _aiInitialized ? Colors.blue : Colors.orange,
              size: 20, // Slightly smaller icon for mobile
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.isDisputeMode ? 'Dispute Mediator' : 'AI Assistant',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16), // Slightly smaller text
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: widget.isDisputeMode
                    ? Colors.orange
                    : (_aiInitialized ? Colors.green : Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.isDisputeMode
                    ? 'Mediation'
                    : (_aiInitialized ? 'Online' : 'Offline'),
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: !_isGuest && !widget.isDisputeMode
            ? IconButton(
                icon: Icon(_showSidebar ? Icons.menu_open : Icons.menu),
                onPressed: () {
                  setState(() {
                    _showSidebar = !_showSidebar;
                  });
                },
                tooltip: _showSidebar ? 'Hide Sidebar' : 'Show Sidebar',
              )
            : null,
        actions: [
          // Credits widget for logged-in users (compact) - tap to see details
          if (!_isGuest)
            ValueListenableBuilder<ProfileInfo>(
              valueListenable: ProfileRepository.instance.profile,
              builder: (context, profile, _) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: InkWell(
                      onTap: () => _showCreditUsageDetails(context, profile),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: profile.aiCredits < 10
                              ? Colors.red.withValues(alpha: 0.1)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: profile.aiCredits < 10
                                ? Colors.red
                                : Colors.blue,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.stars,
                              size: 14,
                              color: profile.aiCredits < 10
                                  ? Colors.red.shade700
                                  : Colors.blue.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${profile.aiCredits}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: profile.aiCredits < 10
                                    ? Colors.red.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          // Buy credits button for logged-in users
          if (!_isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: IconButton(
                  onPressed: () => _showBuyCreditsDialog(context),
                  icon: const Icon(Icons.shopping_cart, size: 20),
                  tooltip: 'Buy Credits',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  style: IconButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ),
          // Guest credit counter
          if (_isGuest)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _guestCreditsRemaining < 5
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _guestCreditsRemaining < 5
                          ? Colors.red
                          : Colors.orange,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _guestCreditsRemaining < 5
                            ? Icons.warning
                            : Icons.stars,
                        size: 12,
                        color: _guestCreditsRemaining < 5
                            ? Colors.red
                            : Colors.orange,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_guestCreditsRemaining.toStringAsFixed(1)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: _guestCreditsRemaining < 5
                              ? Colors.red
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Memory settings button (icon only on mobile)
          ValueListenableBuilder<bool>(
            valueListenable: AIMemoryService.instance.threadMemoryEnabled,
            builder: (context, _, _) {
              return ValueListenableBuilder<bool>(
                valueListenable: AIMemoryService.instance.chatMemoryEnabled,
                builder: (context, _, _) {
                  final memoryIcon = AIMemoryService.instance
                      .getMemoryStatusIcon();
                  return IconButton(
                    onPressed: () => _showMemorySettings(context),
                    icon: Text(
                      memoryIcon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    tooltip: AIMemoryService.instance.getMemoryStatusText(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  );
                },
              );
            },
          ),
          // AI Settings button
          IconButton(
            onPressed: _showAISettings,
            icon: const Icon(Icons.settings, size: 20),
            tooltip: 'AI Settings',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left Sidebar - Conversations (only for logged-in users, not in dispute mode)
          if (!_isGuest && _showSidebar && !widget.isDisputeMode)
            _buildSidebar(),

          // Main Chat Area
          Expanded(
            child: Column(
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: const [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.blue,
                                      child: Icon(
                                        Icons.smart_toy,
                                        size: 16,
                                        color: Colors.white,
                                      ),
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

                // ✅ Balance display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border(
                      bottom: BorderSide(color: Colors.blue[200]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // HIDDEN: Credits balance moved to top header
                      // ValueListenableBuilder<int>(
                      //   valueListenable:
                      //       CreditRepository.instance.creditBalance,
                      //   builder: (context, balance, child) {
                      //     return Text(
                      //       '💳 Balance: $balance credits',
                      //       style: TextStyle(
                      //         fontSize: 13,
                      //         fontWeight: FontWeight.w600,
                      //         color: balance > 10
                      //             ? Colors.green[700]
                      //             : balance > 0
                      //             ? Colors.orange[700]
                      //             : Colors.red[700],
                      //       ),
                      //     );
                      //   },
                      // ),
                      // TextButton.icon(
                      //   onPressed: _showCreditPurchaseBottomSheet,
                      //   icon: const Icon(Icons.add_circle_outline, size: 18),
                      //   label: const Text('Buy Credits'),
                      //   style: TextButton.styleFrom(
                      //     foregroundColor: Colors.blue,
                      //   ),
                      // ),
                      const SizedBox.shrink(), // Empty space
                    ],
                  ),
                ),

                // Message input
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
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
                                horizontal: 16,
                                vertical: 12,
                              ),
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

                // Powered by VerveStrideAI branding
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    border: Border(top: BorderSide(color: Colors.grey[200]!)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Powered by ',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'VerveStrideAI',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                  ),
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
  final (int, int)? tokenUsage; // (inputTokens, outputTokens)
  final double? creditCost; // credits charged (raw decimal)

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.tokenUsage,
    this.creditCost,
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
      child: Column(
        crossAxisAlignment: message.isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: message.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(message.isUser ? 20 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 20),
                    ),
                  ),
                  child: Text(message.text, style: TextStyle(color: textColor)),
                ),
              ),
              if (message.isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey[400],
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
          // ✅ Show cost info for AI messages with token usage
          if (!message.isUser &&
              message.tokenUsage != null &&
              message.creditCost != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsets.only(
                left: message.isUser ? 0 : 24,
                right: message.isUser ? 24 : 0,
              ),
              child: Text(
                '💳 Cost: ${message.creditCost?.toStringAsFixed(4)} credits • ${message.tokenUsage!.$1 + message.tokenUsage!.$2} tokens',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
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
        .map(
          (c) => Tween<double>(
            begin: 0,
            end: -6,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
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
  final bool aiEnabled;
  final Function(bool) onToggleAI;
  final VoidCallback onClearChat;
  final VoidCallback onReconnectAI;

  const AISettingsBottomSheet({
    super.key,
    required this.aiInitialized,
    required this.aiEnabled,
    required this.onToggleAI,
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
                          color: aiInitialized
                              ? Colors.green[700]
                              : Colors.orange[700],
                        ),
                      ),
                      Text(
                        aiInitialized
                            ? 'AI Assistant is connected'
                            : 'AI Assistant is offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: aiInitialized
                              ? Colors.green[600]
                              : Colors.orange[600],
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
          // AI Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: aiEnabled ? Colors.blue.shade50 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: aiEnabled ? Colors.blue.shade200 : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.power_settings_new,
                  color: aiEnabled
                      ? Colors.blue.shade700
                      : Colors.grey.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Assistant',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: aiEnabled
                              ? Colors.blue.shade900
                              : Colors.grey.shade800,
                        ),
                      ),
                      Text(
                        aiEnabled ? 'Currently enabled' : 'Currently disabled',
                        style: TextStyle(
                          fontSize: 12,
                          color: aiEnabled
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: aiEnabled,
                  onChanged: (value) {
                    onToggleAI(value);
                    Navigator.pop(context); // Close settings after toggle
                  },
                  activeTrackColor: Colors.blue.shade200,
                  activeThumbColor: Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

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
                const SnackBar(
                  content: Text('Check debug console for detailed AI logs'),
                ),
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

          const SizedBox(height: 16),

          // Powered by VerveStrideAI branding
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  'Powered by ',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  'VerveStrideAI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
              ],
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

// ============================================================================
// Conversation Item Model for Sidebar
// ============================================================================
class ConversationItem {
  final int id;
  final String title;
  final DateTime updatedAt;
  final bool isActive;
  final String contextType; // 'general', 'dispute', or 'dispute_completed'

  ConversationItem({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.isActive,
    required this.contextType,
  });

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    return ConversationItem(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'New Conversation',
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] as bool? ?? false,
      contextType: json['context_type'] as String? ?? 'general',
    );
  }
}
