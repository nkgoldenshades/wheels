import 'package:flutter/material.dart';
import '../services/voice_ai_service.dart';

class VoiceAIOverlay extends StatefulWidget {
  final Widget child;
  
  const VoiceAIOverlay({super.key, required this.child});

  @override
  State<VoiceAIOverlay> createState() => _VoiceAIOverlayState();
}

class _VoiceAIOverlayState extends State<VoiceAIOverlay>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Glow animation for active state
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Pulse animation for listening state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Listen to voice AI state changes
    VoiceAIService().addListener(_onVoiceAIStateChanged);
  }

  @override
  void dispose() {
    _glowController.dispose();
    _pulseController.dispose();
    VoiceAIService().removeListener(_onVoiceAIStateChanged);
    super.dispose();
  }

  void _onVoiceAIStateChanged() {
    final voiceAI = VoiceAIService();
    
    if (voiceAI.isActive) {
      _glowController.forward();
      if (voiceAI.isListening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
      }
    } else {
      _glowController.reverse();
      _pulseController.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_glowAnimation, _pulseAnimation]),
      builder: (context, child) {
        final voiceAI = VoiceAIService();
        
        return Stack(
          children: [
            // Main app content
            widget.child,
            
            // Glow overlay when AI is active
            if (voiceAI.isActive)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment.center,
                        radius: 1.5,
                        colors: [
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.purple.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            // Voice AI status indicator
            if (voiceAI.isActive)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 0,
                right: 0,
                child: Center(
                  child: Transform.scale(
                    scale: voiceAI.isListening ? _pulseAnimation.value : 1.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: voiceAI.isListening 
                            ? Colors.blue.withValues(alpha: 0.9)
                            : Colors.purple.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (voiceAI.isListening ? Colors.blue : Colors.purple)
                                .withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            voiceAI.isListening ? Icons.mic : Icons.psychology,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            voiceAI.isListening 
                                ? 'Listening...' 
                                : 'Processing...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            
            // Voice command display
            if (voiceAI.lastCommand.isNotEmpty && voiceAI.isProcessing)
              Positioned(
                bottom: 100,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '"${voiceAI.lastCommand}"',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}



