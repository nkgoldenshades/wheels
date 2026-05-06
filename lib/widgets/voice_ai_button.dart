import 'package:flutter/material.dart';
import '../services/voice_ai_service.dart';

class VoiceAIButton extends StatefulWidget {
  const VoiceAIButton({super.key});

  @override
  State<VoiceAIButton> createState() => _VoiceAIButtonState();
}

class _VoiceAIButtonState extends State<VoiceAIButton>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _colorAnimation = ColorTween(
      begin: Colors.blue,
      end: Colors.red,
    ).animate(_animationController);

    // Listen to voice AI state changes
    VoiceAIService().addListener(_onVoiceAIStateChanged);
  }

  @override
  void dispose() {
    _animationController.dispose();
    VoiceAIService().removeListener(_onVoiceAIStateChanged);
    super.dispose();
  }

  void _onVoiceAIStateChanged() {
    final voiceAI = VoiceAIService();
    if (voiceAI.isActive) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final voiceAI = VoiceAIService();
        
        return Positioned(
          bottom: 80, // Above bottom navigation
          right: 20,
          child: GestureDetector(
            onTap: () {
              voiceAI.toggleVoiceAI();
            },
            onLongPress: () {
              // Long press for settings or help
              _showVoiceAIHelp(context);
            },
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _colorAnimation.value,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_colorAnimation.value ?? Colors.blue).withValues(alpha: 0.3),
                      blurRadius: voiceAI.isActive ? 15 : 8,
                      spreadRadius: voiceAI.isActive ? 3 : 1,
                    ),
                  ],
                ),
                child: Icon(
                  voiceAI.isListening 
                      ? Icons.mic 
                      : voiceAI.isProcessing 
                          ? Icons.psychology 
                          : Icons.mic_none,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showVoiceAIHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy, color: Colors.blue),
            SizedBox(width: 8),
            Text('Voice AI Assistant'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('🎤 Tap to activate voice AI'),
            SizedBox(height: 8),
            Text('🗣️ Say commands like:'),
            SizedBox(height: 4),
            Text('• "Book a ride to airport"'),
            Text('• "Show my bookings"'),
            Text('• "Check wallet balance"'),
            Text('• "Cancel last booking"'),
            SizedBox(height: 8),
            Text('🔴 Tap again to stop listening'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}


