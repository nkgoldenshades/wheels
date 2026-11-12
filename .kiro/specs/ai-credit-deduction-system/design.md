# AI Credit Deduction System - Design

## Overview

This design document specifies the implementation of credit deduction for AI chat and voice AI interactions based on actual Gemini API token usage. Currently the system allows unlimited free AI usage despite having sophisticated credit logic in place. This design ensures credits are deducted reliably, transparently, and consistently across all AI interactions.

## Architecture

### System Components

```
┌─────────────────────────────────────────────────────────────┐
│                    AI Chat Page                             │
│  (lib/screens/ai_chat_page.dart)                            │
│                                                             │
│  • Check credits before send                               │
│  • Extract token counts from response                      │
│  • Deduct credits after response                           │
│  • Update UI with actual cost                              │
└────────┬────────────────────────────────────────────────────┘
         │
         │ Uses
         │
         ├─────────────────────────────────────────────────────┐
         │                                                     │
         v                                                     v
    ┌──────────────────────────┐               ┌──────────────────────┐
    │  CreditRepository        │               │  Voice AI Service    │
    │  (credit_repository.dart)│               │(voice_ai_service.dart)
    │                          │               │                      │
    │ Public Methods:          │               │ Usage:               │
    │ • hasEnoughCreditsForAI()│               │ • _getAIResponse()   │
    │ • deductCredits()        │◄──────────────│   (needs credit      │
    │ • recordPurchase()       │               │    checks)           │
    │ • addBonusCredits()      │               │                      │
    │ • estimateCreditCost()   │               │ • _processCommand()  │
    └──────────────┬───────────┘               └──────────────────────┘
                   │
                   │ Local Cache
                   │ (SharedPreferences)
                   │
                   │ Sync (fire & forget)
                   │
                   v
    ┌──────────────────────────────────────────┐
    │      Supabase Backend                    │
    │                                          │
    │  Tables:                                 │
    │  • profiles_private                      │
    │    └─ ai_credits_available (int)         │
    │  • credit_transactions                   │
    │    ├─ id (text primary key)              │
    │    ├─ user_id (text foreign key)         │
    │    ├─ type ('usage'|'purchase'|'bonus')  │
    │    ├─ credits_changed (int)              │
    │    ├─ metadata (jsonb)                   │
    │    └─ created_at (timestamp)             │
    │  • ai_conversations                      │
    │    └─ id (linked via metadata)           │
    └──────────────────────────────────────────┘
```

### Data Flow: Credit Deduction

```
User enters message
         │
         v
_sendMessage()
         │
         v
Guest limit check ──YES──> Show limit reached modal
    NO│
         v
_sendToFirebaseAI(text)
         │
         v
Check: balance >= estimated_cost (1 credit default)?
    NO│                      │YES
        │                     v
        │              Send to Gemini API
        │                     │
        │              ┌──────┴──────┐
        │              │             │
        │            Error       Success
        │              │             │
        │              v             v
        │          Show error   Extract tokens
        │              │        from response
        │              │        metadata
        │              v             │
        │          Return    Calculate real cost:
        │                    cost = (inputTokens × rate)
        │                           + (outputTokens × rate)
        │                           │
        │                    Deduct from balance
        │                           │
        │                    Record transaction
        │                           │
        │                    Persist locally
        │                           │
        │                    Sync to Supabase
        │                           │
        │                           v
        │                    Display message
        │                    + actual cost + new balance
        │
        v
Show insufficient credits message
Display "Buy Credits" link
```

## Components and Interfaces

### CreditRepository Enhanced Methods

```dart
/// Check if user has sufficient credits before sending AI message
Future<bool> hasEnoughCreditsForAI({
  required int estimatedCredits,
}) async {
  return creditBalance.value >= estimatedCredits;
}

/// Estimate credit cost based on message length
/// Returns estimated credits needed (conservative estimate)
static int estimateCreditCostForMessage(String message) {
  // Conservative estimate: always use at least 1 credit
  // To account for response generation
  return 1; // Safe default for display purposes
}

/// Get cost estimate for tokens (for display/calculation)
static int estimateCreditCostForTokens({
  required int inputTokens,
  required int outputTokens,
}) {
  // Gemini pricing: $0.30 per 1M input, $2.50 per 1M output
  // 1 credit = $0.06
  // cost = (inputTokens * 0.30 + outputTokens * 2.50) / 1_000_000 / 0.06
  const double inputRate = 0.30 / 1_000_000 / 0.06;
  const double outputRate = 2.50 / 1_000_000 / 0.06;
  return ((inputTokens * inputRate) + (outputTokens * outputRate)).ceil();
}
```

### AI Chat Page Integration

**Message Sending Flow:**

```dart
Future<void> _sendToFirebaseAI(String userText) async {
  // 1. Validate AI ready
  if (!_aiInitialized || _chat == null) return;

  try {
    // 2. Check credits (estimated)
    final hasCredits = await CreditRepository.instance
        .hasEnoughCreditsForAI(estimatedCredits: 1);
    
    if (!hasCredits) {
      _addAIMessage(
        "⚠️ Insufficient credits (have "
        "${CreditRepository.instance.creditBalance.value}, "
        "need ≈1)",
        isError: true,
      );
      return; // Don't send
    }

    // 3. Send to Gemini
    final response = await _chat!.sendMessage(Content.text(userText));
    
    // 4. Extract token usage
    final inputTokens = response.usageMetadata?.promptTokenCount ?? 0;
    final outputTokens = response.usageMetadata?.candidatesTokenCount ?? 0;

    // 5. Deduct real credits
    final success = await CreditRepository.instance.deductCredits(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
      conversationId: _currentConversationId,
    );

    // 6. Display message with cost
    if (success) {
      _addAIMessage(
        response.text ?? 'No response',
        tokenUsage: (inputTokens, outputTokens),
      );
    }
  } catch (e) {
    _addAIMessage("Error: $e", isError: true);
  }
}
```

### ChatMessage Model

```dart
class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isError;
  final (int, int)? tokenUsage;      // ← NEW (inputTokens, outputTokens)
  final int? creditCost;             // ← NEW (credits charged)

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isError = false,
    this.tokenUsage,
    this.creditCost,
  });
}
```

### Voice AI Service Integration

```dart
Future<String> _getAIResponse(String message) async {
  // 1. Check credits
  final hasCredits = await CreditRepository.instance
      .hasEnoughCreditsForAI(estimatedCredits: 1);
  
  if (!hasCredits) {
    return "⚠️ Insufficient credits to process your request.";
  }

  try {
    // 2. Send to Gemini
    final response = await _chat.sendMessage(Content.text(message));
    
    // 3. Extract tokens and deduct
    final inputTokens = response.usageMetadata?.promptTokenCount ?? 0;
    final outputTokens = response.usageMetadata?.candidatesTokenCount ?? 0;
    
    await CreditRepository.instance.deductCredits(
      inputTokens: inputTokens,
      outputTokens: outputTokens,
    );

    return response.text ?? 'No response';
  } catch (e) {
    return "Error processing: $e";
  }
}
```

## Data Models

### CreditTransaction Schema (Existing, Extended)

```dart
class CreditTransaction {
  final String id;                              // txn_timestamp
  final String userId;                          // user ID
  final String type;                            // 'usage' | 'purchase' | 'bonus'
  final int creditsChanged;                     // negative for usage
  final String? description;                    // "AI message"
  final double? amountUSD;                      // purchase amount
  final String? paymentGatewayId;               // razorpay id
  final String? relatedBookingId;               // booking context
  final String? conversationId;                 // ← NEW: AI conversation link
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;         // Extended with:
                                                // - input_tokens
                                                // - output_tokens
                                                // - input_price
                                                // - output_price
}
```

### Guest Conversation Tracking

```dart
// In SharedPreferences:
// Key: 'guest_conversation_count'
// Value: int (0-10+)
// 
// Logic:
// - Reset on app start
// - Increment when _createNewConversation() called
// - Check >= 10 to show limit modal
// - Clear on login
```

## Correctness Properties

1. **Balance Consistency**
   - Local balance never goes negative: `max(0, balance - cost)`
   - Supabase balance matches local after sync
   - Transactions always have matching balance changes

2. **Credit Pricing Accuracy**
   - Formula: `(inputTokens × 0.05×10⁻⁶) + (outputTokens × 0.42×10⁻⁶)` credits
   - Matches Gemini API pricing exactly
   - Always rounds UP (`.ceil()`) to prevent free messages

3. **Guest Limit Enforcement**
   - Counter starts at 0
   - Increments only on new conversation creation
   - Blocks new conversations at >= 10
   - Resets on login

4. **Transaction Audit Trail**
   - Every credit deduction recorded
   - Includes token counts and conversation ID
   - Persisted both locally and in Supabase
   - Never deleted or modified

5. **Sync Reliability**
   - Local state is source of truth during offline
   - Supabase sync is fire-and-forget (doesn't block UX)
   - Failures logged but don't prevent message display
   - Retry mechanism for failed syncs

## Testing Strategy

### Unit Tests

```dart
test('hasEnoughCreditsForAI returns true if balance >= estimate', () {
  CreditRepository.instance.creditBalance.value = 5;
  expect(
    CreditRepository.instance.hasEnoughCreditsForAI(estimatedCredits: 3),
    true,
  );
});

test('deductCredits calculates cost correctly for tokens', () {
  // Input: 100 tokens, Output: 200 tokens
  // Expected: (100 × 0.05×10⁻⁶) + (200 × 0.42×10⁻⁶) = 0.000095 ≈ 1 credit (ceil)
  final cost = CreditRepository.estimateCreditCostForTokens(
    inputTokens: 100,
    outputTokens: 200,
  );
  expect(cost, greaterThanOrEqualTo(0));
});
```

### Integration Tests

```dart
test('Sending AI message deducts credits', () async {
  // Setup: Create user with 100 credits
  // Action: Send message that costs 5 credits
  // Assert: Balance = 95 credits, transaction recorded
});

test('Guest limit blocks 11th conversation', () async {
  // Setup: Guest user with 10 conversations
  // Action: Try to create 11th conversation
  // Assert: Modal shown, conversation not created
});

test('Sync failure preserves local state', () async {
  // Setup: Supabase sync disabled
  // Action: Send message and deduct credits
  // Assert: Local balance updated, transaction recorded locally
});
```

### UI Tests

```dart
test('Balance display updates after message', () async {
  // Setup: UI showing balance = 100
  // Action: Send message costing 5 credits
  // Assert: Balance display = 95
});

test('Insufficient credits disables send button', () async {
  // Setup: User has 0 credits
  // Action: User types message
  // Assert: Send button disabled, tooltip shown
});
```
