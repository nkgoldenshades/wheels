# ✅ Expert Plan Updated to "Coming Soon"

## Changes Made

### 1. Updated _PlanCard Widget
**Added new properties:**
```dart
final VoidCallback? onSelect; // Made nullable
final bool isComingSoon; // New flag for coming soon state
```

### 2. Enhanced Visual Design
**Coming Soon Styling:**
- **Color**: Orange theme (instead of blue/grey)
- **Badge**: "Coming Soon" text below title
- **Button**: Disabled with "Coming Soon" text
- **Button Style**: Grey background, disabled state

### 3. Expert Plan Configuration
**Before:**
```dart
_PlanCard(
  title: 'Expert',
  onSelect: () {
    // Allowed selection
    AppPreferences.instance.setSubscriptionPlan(SubscriptionPlan.expert);
  },
)
```

**After:**
```dart
_PlanCard(
  title: 'Expert',
  isComingSoon: true, // ✅ Coming soon flag
  onSelect: null,     // ✅ No action
)
```

---

## Visual Changes

### Expert Plan Card Now Shows:

```
┌─────────────────────────────────────┐
│ Expert                    [EXPERT]  │
│ Coming Soon                         │ ← Orange text
│                                     │
│ ✓ Everything in Premium             │
│ ✓ Expert connection                 │
│ ✓ Priority customer support         │
│                                     │
│ [    Coming Soon    ]               │ ← Disabled button
└─────────────────────────────────────┘
```

### Color Scheme:
- **Basic Plan**: Grey theme
- **Premium Plan**: Blue theme (Recommended)
- **Expert Plan**: Orange theme (Coming Soon) ✅

---

## User Experience

### What Users See:
1. **Expert plan is visible** - Shows what's planned
2. **Clear "Coming Soon" indicator** - Sets expectations
3. **Disabled button** - Prevents selection
4. **Orange color theme** - Visually distinct from active plans

### What Users Can't Do:
- ❌ Select the Expert plan
- ❌ Get confused about availability
- ❌ Expect immediate access

### What Users Can Do:
- ✅ See what Expert plan will include
- ✅ Understand it's coming in the future
- ✅ Choose Basic or Premium plans instead

---

## Benefits

1. **✅ Clear Communication** - Users know Expert plan exists but isn't ready
2. **✅ Prevents Confusion** - No false expectations about availability
3. **✅ Marketing Value** - Shows roadmap and future features
4. **✅ Professional Look** - Better than hiding the plan completely
5. **✅ Easy to Enable** - Just change `isComingSoon: false` when ready

---

## Future Activation

When Expert plan is ready, simply change:

```dart
_PlanCard(
  title: 'Expert',
  isComingSoon: false, // ← Change this to false
  onSelect: () {       // ← Add back the selection logic
    AppPreferences.instance.setSubscriptionPlan(SubscriptionPlan.expert);
    // ... rest of logic
  },
)
```

The Expert plan will now show "Coming Soon" instead of being selectable! 🎉