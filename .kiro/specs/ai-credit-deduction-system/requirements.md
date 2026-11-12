# AI Credit Deduction System - Requirements

## Overview

Implement proper credit deduction for AI chat messages based on actual token usage from the Gemini API. Currently, credits are not being deducted at all, leaving the system incomplete and allowing unlimited free AI usage.

## Problem Statement

1. **No Credit Deduction**: Users can send unlimited AI messages without any credit cost
2. **Misleading UI**: UI claims "1 credit per message" but nothing is enforced
3. **Token-Based Logic Unused**: Credit repository has sophisticated token-based pricing but it's never called
4. **Guest Limit Not Enforced**: Guest users can theoretically send unlimited messages; their 10-message limit isn't enforced
5. **Revenue Loss**: Premium feature generates no value extraction

## Functional Requirements

### FR-1: Token-Based Credit Calculation
- Calculate credits based on actual Gemini API token usage (input + output tokens)
- Use the formula: `credits = (inputTokens * 0.30/1M/0.06) + (outputTokens * 2.50/1M/0.06)`
- Where 1 credit = $0.06 USD value
- Round up using `.ceil()` to prevent free messages

### FR-2: Deduct Credits Before Sending Message
- Check user has sufficient credits BEFORE sending to AI
- Show clear warning if insufficient credits
- Allow users to purchase credits from within the chat UI
- Prevent message send if credits insufficient

### FR-3: Record Credit Deduction
- Create transaction record after successful API response
- Include in metadata: input tokens, output tokens, calculated cost
- Store in `credit_transactions` table with type='usage'
- Link to user's AI conversation for audit trail

### FR-4: Guest User Limits
- Limit guest users to 10 FREE conversations per session
- After 10 conversations, show login-to-continue prompt
- Track guest conversation count in SharedPreferences
- Reset on app restart or login

### FR-5: Cost Transparency
- Show estimated credit cost before user sends message
- Display token counts in transaction history (for transparency)
- Show "1 credit = ₹0.06" equivalent pricing
- Real-time balance update after deduction

### FR-6: Fallback Handling
- If token count unavailable from API response, use reasonable estimate
- Example: ~0.04 credits for short message, ~0.2 credits for long response
- Log warning when fallback is used
- Don't fail the message if token counting fails (degrade gracefully)

## Non-Functional Requirements

### NF-1: Performance
- Token counting must not add >200ms latency
- Credit deduction should be optimistic (local first, then sync)
- Cache token counts for identical messages

### NF-2: Reliability
- If Supabase sync fails, don't lose local transaction record
- Retry sync in background (up to 3 times)
- Show warning if sync failed but allow continued use

### NF-3: Consistency
- Credits should never go negative in UI
- Transactions must always match balance changes
- Audit trail must be complete and accurate

## Business Logic

### Guest Conversation Tracking
```
- Session starts: Read guest_conversation_count from SharedPreferences
- Each new conversation created: Increment counter + 1
- Threshold reached (count >= 10): Show "Upgrade to continue" modal
- On login: Clear guest count, load user's actual subscription
```

### Credit Deduction Flow
```
1. User enters message text
2. Check balance >= estimated_cost (estimate = 0.5 credits default)
3. If insufficient → Show "Not enough credits" + purchase link
4. If sufficient → Send to Gemini API
5. Get response with token counts (usage metadata)
6. Calculate actual cost = (inputTokens * rate) + (outputTokens * rate)
7. Deduct from local balance
8. Record transaction in database
9. Show actual cost in UI (may differ from estimate)
```

### Pricing Tiers
- **Gemini Input**: $0.30 per 1M tokens = 0.00000005 credits per token
- **Gemini Output**: $2.50 per 1M tokens = 0.00000041 credits per token
- **Estimate for display**: 0.5 credits per average message
- **Short message** (~50 input + 100 output tokens): ~0.05 credits
- **Long message** (~500 input + 500 output tokens): ~0.28 credits

## Data Schema

### credit_transactions table (existing, extend)
```
id: string (primary key)
user_id: string (foreign key → profiles.id)
type: 'usage' | 'purchase' | 'bonus'
credits_changed: integer (negative for usage)
description: string
metadata: jsonb {
  input_tokens?: number,
  output_tokens?: number,
  input_price?: number,
  output_price?: number,
  gemini_model?: string,
  conversation_id?: string
}
created_at: timestamp
related_booking_id: string (optional)
```

### profiles_private table (existing, checked)
- `ai_credits_available`: integer (current balance)
- Last verified to be working ✅

## UI/UX Specifications

### Before Sending Message
```
✓ Current balance displayed
✓ Estimated cost shown: "~0.5 credits"
✓ Send button disabled if balance < estimate
✓ Tooltip on disabled state: "Not enough credits to send"
```

### After Message Sent
```
✓ Show actual cost in message bubble or timestamp
✓ Display new balance below message
✓ Show "Cost: 0.23 credits" in smaller text
✓ Color code: Green if cost < estimate, Yellow if close to balance
```

### Guest Limit Reached
```
✓ Show modal: "You've used 10 free conversations"
✓ Options: "Login" or "Continue as Guest (limited)"
✓ If continue: Show countdown (5, 4, 3...) then force login screen
```

### Insufficient Credits
```
✓ Toast: "Not enough credits (have 0.2, need 0.5)"
✓ Button: "Buy Credits" links to credit purchase
✓ Don't send the message
```

## Success Criteria

1. ✅ Credits deducted on EVERY AI message sent
2. ✅ Calculation matches Gemini token pricing exactly
3. ✅ Guest users limited to 10 conversations
4. ✅ Transaction history shows all usage
5. ✅ User cannot go negative balance
6. ✅ UI shows estimated + actual costs
7. ✅ No messages sent if insufficient credits
8. ✅ Background sync to Supabase works reliably
