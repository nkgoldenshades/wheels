import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage AI chat memory settings and context
class AIMemoryService {
  AIMemoryService._();
  static final AIMemoryService instance = AIMemoryService._();

  // Memory settings stored in SharedPreferences
  static const String _threadMemoryKey = 'ai_thread_memory_enabled';
  static const String _chatMemoryKey = 'ai_chat_memory_enabled';

  // ValueNotifiers for reactive UI updates
  final ValueNotifier<bool> threadMemoryEnabled = ValueNotifier<bool>(true);
  final ValueNotifier<bool> chatMemoryEnabled = ValueNotifier<bool>(false);

  /// Initialize memory settings from SharedPreferences
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      threadMemoryEnabled.value =
          prefs.getBool(_threadMemoryKey) ?? true; // Default: ON
      chatMemoryEnabled.value =
          prefs.getBool(_chatMemoryKey) ?? false; // Default: OFF
      debugPrint(
        '[AIMemoryService] Initialized - Thread: ${threadMemoryEnabled.value}, Chat: ${chatMemoryEnabled.value}',
      );
    } catch (e) {
      debugPrint('[AIMemoryService] Error initializing: $e');
    }
  }

  /// Toggle thread memory setting
  Future<void> setThreadMemory(bool enabled) async {
    try {
      threadMemoryEnabled.value = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_threadMemoryKey, enabled);
      debugPrint('[AIMemoryService] Thread memory set to: $enabled');
    } catch (e) {
      debugPrint('[AIMemoryService] Error setting thread memory: $e');
    }
  }

  /// Toggle chat memory setting
  Future<void> setChatMemory(bool enabled) async {
    try {
      chatMemoryEnabled.value = enabled;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_chatMemoryKey, enabled);
      debugPrint('[AIMemoryService] Chat memory set to: $enabled');
    } catch (e) {
      debugPrint('[AIMemoryService] Error setting chat memory: $e');
    }
  }

  /// Get memory status icon
  String getMemoryStatusIcon() {
    final thread = threadMemoryEnabled.value;
    final chat = chatMemoryEnabled.value;

    if (thread && chat) return '🧠'; // Full memory
    if (thread && !chat) return '🧵'; // Thread only
    if (!thread && chat) return '💬'; // Chat only
    return '🆕'; // No memory
  }

  /// Get memory status text
  String getMemoryStatusText() {
    final thread = threadMemoryEnabled.value;
    final chat = chatMemoryEnabled.value;

    if (thread && chat) return 'Full Memory (Thread + Chat)';
    if (thread && !chat) return 'Thread Memory Only';
    if (!thread && chat) return 'Chat Memory Only';
    return 'No Memory (Fresh Start)';
  }
}
