# Guest AI Chat Conversation Limit

## Feature Overview
Guest users (not logged in) are limited to 10 AI conversations to encourage registration while still providing a trial experience.

## Implementation Details

### Conversation Tracking
- **Storage**: Uses `SharedPreferences` to track guest conversation count locally
- **Key**: `guest_conversation_count`
- **Limit**: 10 conversations per guest user
- **Counter**: Increments with each message sent by guest

### User Experience

#### Visual Indicators
1. **App Bar Badge**: Shows remaining conversations (e.g., "8 left")
   - Orange badge when conversations remaining
   - Red badge when limit reached
   - Shows lock icon when limit reached

2. **Top Banner**: Persistent banner for guests showing:
   - "Guest Mode: X conversations remaining"
   - Quick "Login" button

3. **Welcome Message**: AI greeting mentions guest limit:
   - "⚠️ Guest Mode: You have 10 free conversations. Login for unlimited access!"

#### Login Prompt
When guest reaches 10 conversations, a dialog appears:
- **Title**: "Conversation Limit Reached"
- **Message**: Explains the limit and benefits of logging in
- **Benefits Listed**:
  - Unlimited AI chat
  - Save conversation history
  - Book rides and services
  - Create posts
  - And much more!
- **Actions**:
  - "Maybe Later" - Dismisses dialog
  - "Login Now" - Navigates to login screen

### Code Changes

#### Files Modified
- `lib/screens/ai_chat_page.dart`

#### Key Changes
1. Added guest status tracking:
   ```dart
   bool _isGuest = false;
   int _guestConversationCount = 0;
   static const int _guestConversationLimit = 10;
   ```

2. Check guest status on init:
   ```dart
   Future<void> _checkGuestStatus() async {
     final currentUser = AuthRepository.instance.currentUser;
     _isGuest = currentUser == null;
     
     if (_isGuest) {
       final prefs = await SharedPreferences.getInstance();
       _guestConversationCount = prefs.getInt('guest_conversation_count') ?? 0;
     }
   }
   ```

3. Enforce limit on message send:
   ```dart
   if (_isGuest && _guestConversationCount >= _guestConversationLimit) {
     _showLoginPrompt();
     return;
   }
   ```

4. Increment counter after each message:
   ```dart
   if (_isGuest) {
     _guestConversationCount++;
     final prefs = await SharedPreferences.getInstance();
     await prefs.setInt('guest_conversation_count', _guestConversationCount);
   }
   ```

### Testing

#### Test Cases
1. **Guest User - First Conversation**
   - Open app without login
   - Go to AI Chat
   - Should see "10 left" badge
   - Should see guest banner
   - Send message - counter decrements to "9 left"

2. **Guest User - Approaching Limit**
   - Send 9 messages as guest
   - Should see "1 left" badge
   - Banner updates accordingly

3. **Guest User - Limit Reached**
   - Send 10th message
   - Should see "0 left" badge with red color
   - Try to send 11th message
   - Should see login prompt dialog
   - Cannot send more messages until login

4. **Logged In User**
   - Login to account
   - Go to AI Chat
   - Should NOT see guest badge or banner
   - Can send unlimited messages
   - No conversation limit enforced

5. **Guest to Logged In Transition**
   - Start as guest, send 5 messages
   - Login to account
   - Counter should reset/not apply
   - Can send unlimited messages

### Benefits

#### For Users
- Try AI chat before committing to registration
- Clear indication of trial limitations
- Easy path to unlock full features

#### For Business
- Encourages user registration
- Provides value before asking for commitment
- Reduces anonymous/spam usage
- Increases conversion rate

### Future Enhancements
- Reset counter after X days for returning guests
- Different limits for different features
- Track guest by device ID instead of just local storage
- Analytics on conversion rate from guest to registered user
