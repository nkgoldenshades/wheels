import 'package:flutter/material.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_repository.dart';
import '../services/profile_repository.dart';

/// Redesigned AI Chat Page with clean VerveStride-like interface
/// Features:
/// - Left sidebar with conversation history
/// - Center welcome screen with AI branding
/// - Clean dark theme
/// - Voice input support
class AIChatPageRedesigned extends StatefulWidget {
  const AIChatPageRedesigned({super.key});

  @override
  State<AIChatPageRedesigned> createState() => _AIChatPageRedesignedState();
}

class _AIChatPageRedesignedState extends State<AIChatPageRedesigned> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final List<Conversation> _conversations = [];

  GenerativeModel? _model;
  ChatSession? _chat;
  bool _isLoading = false;
  int? _currentConversationId;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _initializeFirebaseAI();
    _loadConversations();
  }

  Future<void> _initializeFirebaseAI() async {
    try {
      _model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
        systemInstruction: Content.system('''
You are QuickOHunt AI Assistant. Be helpful, friendly, and concise.
Guide users with ride-sharing, bookings, and vehicle rentals.
Keep responses under 3 sentences unless asked for details.
        '''),
      );

      _chat = _model!.startChat();
      
      debugPrint('✅ AI initialized successfully');
    } catch (e) {
      debugPrint('❌ AI initialization failed: $e');
    }
  }

  Future<void> _loadConversations() async {
    try {
      final userId = AuthRepository.instance.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('ai_conversations')
          .select()
          .eq('profile_id', userId)
          .order('updated_at', ascending: false)
          .limit(10);

      if (!mounted) return;
      setState(() {
        _conversations.clear();
        for (final conv in response) {
          _conversations.add(Conversation(
            id: conv['id'] as int,
            title: conv['title'] as String? ?? 'New Conversation',
            updatedAt: DateTime.parse(conv['updated_at'] as String),
            isActive: conv['is_active'] as bool? ?? false,
          ));
        }
      });
    } catch (e) {
      debugPrint('⚠️ Failed to load conversations: $e');
    }
  }

  Future<void> _createNewConversation() async {
    setState(() {
      _currentConversationId = null;
      _messages.clear();
    });
    _loadConversations();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
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

    // Send to AI
    try {
      final response = await _chat!.sendMessage(Content.text(text));
      final aiText = response.text?.trim() ?? 'No response';

      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: aiText,
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
      _scrollToBottom();
      _saveConversation();
    } catch (e) {
      debugPrint('❌ AI error: $e');
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(
          text: 'Sorry, I encountered an error. Please try again.',
          isUser: false,
          timestamp: DateTime.now(),
          isError: true,
        ));
        _isLoading = false;
      });
    }
  }

  Future<void> _saveConversation() async {
    // Save to Supabase (async, don't wait)
    final userId = AuthRepository.instance.currentUser?.id;
    if (userId == null) return;

    final messagesJson = _messages.map((msg) => {
      'role': msg.isUser ? 'user' : 'assistant',
      'content': msg.text,
      'timestamp': msg.timestamp.toIso8601String(),
    }).toList();

    try {
      if (_currentConversationId == null) {
        final response = await Supabase.instance.client
            .from('ai_conversations')
            .insert({
              'profile_id': userId,
              'title': _messages.first.text.substring(0, 30),
              'messages': messagesJson,
              'context_type': 'general',
              'is_active': true,
            })
            .select('id')
            .single();
        _currentConversationId = response['id'] as int;
      } else {
        await Supabase.instance.client
            .from('ai_conversations')
            .update({'messages': messagesJson})
            .eq('id', _currentConversationId!);
      }
      _loadConversations();
    } catch (e) {
      debugPrint('⚠️ Save failed: $e');
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929), // Dark blue background
      body: Row(
        children: [
          // Left Sidebar - Conversations
          _buildSidebar(),
          
          // Main Chat Area
          Expanded(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: _messages.isEmpty
                      ? _buildWelcomeScreen()
                      : _buildChatList(),
                ),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F2D),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, color: Colors.white70, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Conversations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.add, color: Colors.white70, size: 20),
                  onPressed: _createNewConversation,
                  tooltip: 'New Conversation',
                ),
              ],
            ),
          ),
          
          // Conversations List
          Expanded(
            child: ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final conv = _conversations[index];
                final isSelected = conv.id == _currentConversationId;
                
                return InkWell(
                  onTap: () {
                    // Load conversation
                    setState(() {
                      _currentConversationId = conv.id;
                      // Load messages from Supabase
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? Colors.white.withValues(alpha: 0.1) 
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.chat, color: Colors.white60, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            conv.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conv.isActive)
                          Icon(Icons.push_pin, color: Colors.blue.shade300, size: 14),
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

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white70),
            onPressed: () {},
          ),
          const Expanded(
            child: Text(
              'New Conversation',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder(
                  valueListenable: ProfileRepository.instance.profile,
                  builder: (context, profile, _) {
                    return Text(
                      '${profile.aiCredits} cr',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AI Icon
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade700.withValues(alpha: 0.3),
                  Colors.purple.shade700.withValues(alpha: 0.3),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Title
          const Text(
            'QuickOHunt AI',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Just start talking — I\'ll adapt to you',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 48),
          
          // Suggestions
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              _buildSuggestionChip('Book a ride'),
              _buildSuggestionChip('Find vehicles'),
              _buildSuggestionChip('Rental options'),
              _buildSuggestionChip('Help & Support'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text) {
    return InkWell(
      onTap: () {
        _messageController.text = text;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildTypingIndicator();
        }
        
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        child: Column(
          crossAxisAlignment: message.isUser 
              ? CrossAxisAlignment.end 
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? Colors.blue.shade700 
                    : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            const SizedBox(width: 4),
            _buildDot(1),
            const SizedBox(width: 4),
            _buildDot(2),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white60,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F2D),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          // Voice Input Button
          IconButton(
            icon: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              color: _isListening ? Colors.red : Colors.white70,
            ),
            onPressed: () {
              setState(() {
                _isListening = !_isListening;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isListening 
                      ? '🎤 Voice input active' 
                      : '⏸️ Voice input stopped'),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          
          // Text Input
          Expanded(
            child: TextField(
              controller: _messageController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          
          // Send Button
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.purple.shade600],
              ),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}

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

class Conversation {
  final int id;
  final String title;
  final DateTime updatedAt;
  final bool isActive;

  Conversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.isActive,
  });
}

