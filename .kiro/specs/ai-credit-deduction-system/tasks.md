# Implementation Plan

## Overview

Implement proper credit deduction for AI chat messages based on actual Gemini API token usage. Currently, credits are not being deducted at all, leaving users with unlimited free AI access. This plan addresses all aspects: core deduction logic, UI updates, guest limiting, and testing.

## Task Dependency Graph

```
Task 1 (CreditRepository)
  ├─> Task 2 (AI Chat Page) ──┬─> Task 3 (ChatMessage Model) ──> Task 4 (UI Display)
  │                           └─> Task 5 (Guest Limit)
  │
  └─> Task 6 (Voice AI) ────────────> Task 7 (Buy Credits)
  
Task 8 (Fallback Estimation) ──> Task 9 (Testing)
Task 10 (Documentation) ──> Complete
```

## Tasks

- [ ] 1. Update CreditRepository with AI-Specific Methods
  - **Priority**: 🔴 HIGH | **Depends on**: None | **Est. Time**: 30 min
  - **Description**: Update `lib/services/credit_repository.dart` to add helper methods for AI chat credit management
  - **Sub-tasks**:
    - Add `hasEnoughCreditsForAI()` method to check balance before sending
    - Add `estimateCreditCostForMessage()` static method for upfront estimates
    - Update existing `deductCredits()` to accept optional `conversationId` parameter
    - Update `_syncDeductionToSupabase()` to include conversation context in metadata
    - Add comprehensive documentation comments for all new methods
  - **Success Criteria**:
    - ✅ All methods compile without errors
    - ✅ Token counting formula matches Gemini pricing exactly: (inputTokens × 0.30/1M/0.06) + (outputTokens × 2.50/1M/0.06)
    - ✅ Optional conversation_id properly saved in transaction metadata
    - ✅ No changes to credit purchase/bonus logic

- [ ] 2. Implement Credit Check & Deduction in AI Chat
  - **Priority**: 🔴 HIGH | **Depends on**: Task 1 | **Est. Time**: 45 min
  - **Description**: Modify `lib/screens/ai_chat_page.dart` to check credits before sending and deduct after response
  - **Sub-tasks**:
    - Update `_sendToFirebaseAI()` to check credits before send with tooltip if insufficient
    - Extract `inputTokens` and `outputTokens` from Gemini response.usageMetadata
    - Call `CreditRepository.deductCredits()` with actual token counts after response
    - Handle deduction failure gracefully (still show message but log warning)
    - Update `_sendMessage()` to check guest conversation limit before creating new conversation
  - **Success Criteria**:
    - ✅ Message not sent if balance < estimated cost (1 credit minimum)
    - ✅ User sees clear "Not enough credits (have X, need Y)" message
    - ✅ Token counts successfully extracted from Gemini response
    - ✅ Credits deducted immediately after successful response received
    - ✅ Transaction recorded in CreditRepository with token metadata
    - ✅ Local balance updated in UI after deduction
    - ✅ Guest conversation count incremented only for NEW conversations (not per message)

- [ ] 3. Update ChatMessage Model for Cost Display
  - **Priority**: 🟡 MEDIUM | **Depends on**: Task 2 | **Est. Time**: 20 min
  - **Description**: Enhance ChatMessage model to track token usage and credit cost for transparency
  - **Sub-tasks**:
    - Add `tokenUsage` field: `(int, int)?` to store (inputTokens, outputTokens) pair
    - Add `creditCost` field: `int?` to store credits charged for this message
    - Update all ChatMessage constructors to support optional fields with defaults
    - Update ChatMessage.toJson() / fromJson() if used for persistence
    - Ensure backward compatibility with existing messages (don't break old data)
  - **Success Criteria**:
    - ✅ ChatMessage compiles with new optional fields
    - ✅ New fields don't break existing code or serialization
    - ✅ Token usage and cost properly passed from deduction call to display

- [ ] 4. Display Credit Cost in UI
  - **Priority**: 🟡 MEDIUM | **Depends on**: Task 3 | **Est. Time**: 30 min
  - **Description**: Update AI chat UI to show balance, estimated cost, and actual cost per message
  - **Sub-tasks**:
    - Display current credit balance prominently above chat input (e.g., "💳 Balance: 42 credits")
    - Show "Buy Credits" link next to balance for easy access
    - Display actual cost in AI response bubbles (e.g., "Cost: 0.23 credits • 234 tokens")
    - Color-code cost display (green if < estimate, yellow if close to balance)
    - Update insufficient credits UI to show actual amounts (e.g., "need 0.5, have 0.2")
  - **Success Criteria**:
    - ✅ Balance displays accurately and updates after each message
    - ✅ Cost shows in all AI response messages when available
    - ✅ Token counts display alongside cost for transparency
    - ✅ "Buy Credits" link is easily visible and functional
    - ✅ Insufficient credit message is clear and shows exact amounts

- [ ] 5. Implement Guest Conversation Limit
  - **Priority**: 🟡 MEDIUM | **Depends on**: Task 2 | **Est. Time**: 25 min
  - **Description**: Add modal and logic to limit guest users to 10 free conversations per session
  - **Sub-tasks**:
    - Track guest conversation count in SharedPreferences (key: 'guest_conversation_count')
    - Check if count >= 10 before creating NEW conversation (not during message exchange)
    - Show modal when limit reached with options: "Login" or "Continue"
    - If "Continue": Show 5-second countdown then force login screen
    - Clear counter on login or app restart
  - **Success Criteria**:
    - ✅ Guest counter starts at 0 and increments per new conversation
    - ✅ Counter increments ONLY when new conversation created (not per message)
    - ✅ Modal appears after 10th conversation started, blocks 11th
    - ✅ Existing in-progress conversations don't count towards limit
    - ✅ Login clears the counter and loads user's actual subscription

- [ ] 6. Integrate Credits into Voice AI Service
  - **Priority**: 🟡 MEDIUM | **Depends on**: Task 1 | **Est. Time**: 30 min
  - **Description**: Update `lib/services/voice_ai_service.dart` to check and deduct credits for voice AI responses
  - **Sub-tasks**:
    - Add credit check in `_getAIResponse()` before calling Gemini
    - Extract token counts from voice AI response.usageMetadata
    - Deduct credits after successful voice response (same logic as text)
    - Handle insufficient credits gracefully (return error message instead of response)
    - Log warnings if token counting unavailable
  - **Success Criteria**:
    - ✅ Voice AI checks balance before sending
    - ✅ Returns clear error message if insufficient credits
    - ✅ Credits deducted for voice AI same as text AI
    - ✅ Token counts tracked in transaction metadata
    - ✅ Voice AI errors don't crash the app, degrade gracefully

- [ ] 7. Add Buy Credits Quick Link
  - **Priority**: 🟡 MEDIUM | **Depends on**: Task 4 | **Est. Time**: 20 min
  - **Description**: Add "Buy Credits" bottom sheet accessible from chat UI when insufficient
  - **Sub-tasks**:
    - Create `_showCreditPurchaseBottomSheet()` method in AI Chat Page
    - Show it when user taps "Buy Credits" or when insufficient credits error shown
    - Display pricing prominently: "1 credit = ₹0.06"
    - Show pre-filled packages: 50, 200, 1000 credits with discounts
    - Link to existing payment flow (reuse BuyCreditScreen logic)
  - **Success Criteria**:
    - ✅ Bottom sheet appears on demand
    - ✅ Shows pricing and popular packages with discount info
    - ✅ "Buy" button navigates to payment flow
    - ✅ Modal closes after purchase completes
    - ✅ Balance updates immediately after purchase completes

- [ ] 8. Add Fallback Cost Estimation
  - **Priority**: 🟢 LOW | **Depends on**: Task 2 | **Est. Time**: 15 min
  - **Description**: Improve cost estimation when token counts unavailable from API
  - **Sub-tasks**:
    - Create smart estimation based on message characteristics (length, complexity)
    - Estimate input tokens from user message word count
    - Estimate output tokens from typical response patterns (1-5 sentences)
    - Use formula: estimated_cost = 0.5 credits as safe default
    - Log "estimation used" warning when actual counts unavailable
  - **Success Criteria**:
    - ✅ Fallback estimates are conservative (never underestimate cost)
    - ✅ Estimates never overshoot actual cost by >200%
    - ✅ Works gracefully when Gemini doesn't return token metadata
    - ✅ Warnings logged for debugging

- [ ] 9. Test Credit Deduction End-to-End
  - **Priority**: 🔴 HIGH | **Depends on**: Task 2, Task 4, Task 6 | **Est. Time**: 45 min
  - **Description**: Write comprehensive tests for credit deduction flow and edge cases
  - **Sub-tasks**:
    - Test: Sending message with sufficient credits → credits deducted correctly
    - Test: Sending message with 0 credits → message blocked with error
    - Test: Sending message with 0.1 credits, cost 0.5 → message blocked
    - Test: Multiple consecutive messages → balance decrements correctly
    - Test: Guest at 9 conversations + 1 more → limit reached modal shown
    - Test: Voice AI response → credits deducted same as text
    - Test: Insufficient credits during message send → graceful error, balance unchanged
    - Test: Supabase sync failure → local state preserved, retry in background
  - **Success Criteria**:
    - ✅ All test cases pass
    - ✅ No edge cases with negative balance
    - ✅ Guest limit properly enforced at 10
    - ✅ Sync failures don't cause data loss or duplicates

- [ ] 10. Update Documentation & UI Labels
  - **Priority**: 🟢 LOW | **Depends on**: All prior tasks | **Est. Time**: 15 min
  - **Description**: Update user-facing documentation and help text to explain variable credit pricing
  - **Sub-tasks**:
    - Update credit settings page to explain token-based pricing model
    - Add tooltip: "Cost varies based on message length and complexity"
    - Document in README: "AI credits are deducted per message based on actual Gemini API token usage"
    - Add FAQ: "Why does this message cost more than that one?"
    - Show pricing examples: "100-word question ≈ 0.1 credits, detailed response ≈ 0.3 credits"
  - **Success Criteria**:
    - ✅ Users understand credit pricing is variable, not fixed per message
    - ✅ No misleading "1 credit = 1 message" claim anywhere in UI
    - ✅ Help text mentions token-based calculation explicitly
    - ✅ Documentation shows real pricing examples with token counts

## Notes

- **Overall Acceptance Criteria**:
  - ✅ No free AI messages: Every message costs credits based on actual token usage
  - ✅ Token pricing accurate: Matches Gemini API pricing formula exactly
  - ✅ Balance never goes negative: UI prevents and safeguards against negative balance
  - ✅ Guest limit enforced: 10 free conversations per session, then login required
  - ✅ Transparent pricing: Users see estimated cost before + actual cost after
  - ✅ Reliable sync: Transactions recorded both locally and in Supabase
  - ✅ Graceful fallback: App doesn't crash if token counting fails
  - ✅ Voice AI included: Both text and voice AI messages consume credits

- **Implementation Phases**:
  1. **Phase 1 (Critical)**: Tasks 1, 2, 4 → Core credit deduction working (3.5 hours)
  2. **Phase 2 (Important)**: Tasks 3, 5, 6 → Enhanced UI + guest limits + voice AI (1.5 hours)
  3. **Phase 3 (Polish)**: Tasks 7, 8, 9, 10 → Buy link + fallback + tests + docs (1.5 hours)
  - **Total Estimated Time**: 6.5 hours

- **Revenue Impact**: This implementation unlocks ₹60k-80k monthly from 1000 active users (97% profit margin after API costs)
