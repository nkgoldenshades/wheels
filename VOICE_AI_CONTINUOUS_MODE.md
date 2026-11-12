# Voice AI Continuous Mode

## Overview
The AI microphone now supports continuous listening mode - it stays active until you manually turn it off.

## How It Works

### Before (Single Command Mode)
1. Tap mic → Speak → AI responds → Mic stops
2. Need to tap mic again for next command

### After (Continuous Mode) ✅
1. Tap mic → Mic stays active continuously
2. Speak multiple commands without tapping again
3. AI responds to each command
4. Mic automatically restarts listening after each response
5. Tap mic again to stop

## Features

### Continuous Listening
- Mic stays active for 30 seconds per listening session
- Automatically restarts after processing each command
- No need to tap mic between commands

### Visual Feedback
- Red mic icon when active
- Pulsing red circle around mic button
- Toast notifications:
  - "Voice input active - speak continuously until you tap mic again" (on start)
  - "Voice input stopped" (on stop)

### Smart Pausing
- 2-second pause detection (shorter than before)
- Automatically processes command when you stop speaking
- Restarts listening after AI responds

## Usage

### Starting Continuous Mode
1. Tap the microphone button in AI chat
2. See red pulsing indicator
3. Start speaking your commands

### Using Continuous Mode
1. Speak your first command
2. Wait for AI response
3. Speak your next command (no need to tap mic)
4. Repeat as needed

### Stopping Continuous Mode
1. Tap the microphone button again
2. Red indicator disappears
3. Voice input stops

## Technical Details

### Voice AI Service Changes
- Added `_continuousMode` flag
- Increased `listenFor` duration to 30 seconds
- Reduced `pauseFor` to 2 seconds
- Auto-restart after processing command

### Code Changes
```dart
// New continuous mode flag
bool _continuousMode = false;

// Auto-restart after command
if (_continuousMode) {
  await Future.delayed(const Duration(milliseconds: 500));
  await _startListening();
}
```

## Platform Support

### Mobile (Android/iOS)
- ✅ Full support
- ✅ Continuous listening
- ✅ Background processing

### Web
- ⚠️ Limited support
- Voice input not available on web platform
- Use text input instead

## Tips

1. **Speak Clearly**: Wait for AI response before next command
2. **Natural Pauses**: 2-second pause triggers command processing
3. **Stop When Done**: Tap mic to stop and save battery
4. **Background Use**: Works while app is in foreground

## Troubleshooting

### Mic Stops After First Command
- Check if continuous mode is enabled
- Verify microphone permissions
- Restart the app

### No Response
- Check internet connection
- Verify Firebase AI is initialized
- Check microphone permissions

### Battery Drain
- Stop continuous mode when not needed
- Use text input for long conversations
- Close AI chat when done

## Future Enhancements

- [ ] Wake word detection ("Hey QuickOHunt")
- [ ] Background listening
- [ ] Voice command shortcuts
- [ ] Multi-language support
- [ ] Offline voice processing
