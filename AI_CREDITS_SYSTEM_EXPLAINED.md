# AI Credits System - How It Works

## 📊 **Overview**

VaultWheels uses a **credit-based system** for AI chat features. Users buy credits and spend them when using AI assistance.

---

## 💰 **Pricing Structure**

### **1. Credit Purchase Price**
- **$0.10 per credit** (what users pay)
- Example: $1.00 = 10 credits

### **2. Credit Usage Cost**
Based on actual Gemini AI API costs:
- **Input tokens:** $0.30 per 1 million tokens
- **Output tokens:** $2.50 per 1 million tokens

### **3. Memory Markup (Important!)**
AI chat costs MORE when using memory features:

| Memory Mode | Markup | Final Cost |
|-------------|--------|------------|
| **🆕 No Memory** | 1x | Raw API cost |
| **💬 Chat Memory Only** | 2x | Double API cost |
| **🧵 Thread Memory Only** | 3x | Triple API cost |
| **🧠 Full Memory (Thread + Chat)** | 5x | 5× API cost |

**Why?** Memory features require loading previous conversations, increasing token usage.

---

## 🎯 **How Credits Are Earned**

### **1. Guest Users (Not Logged In)**
- ❌ **0 credits** (must login to use AI)

### **2. Registered Users (After Signup)**
- ✅ **0.2 credits free** (welcome bonus)

### **3. Purchase Credits**
- Users buy credits via payment gateway
- Example packages:
  - $1 = 10 credits
  - $5 = 50 credits
  - $10 = 100 credits

### **4. Bonus Credits**
- Referral rewards
- Promotional campaigns
- Admin grants

---

## 💸 **How Credits Are Spent**

### **Example Calculation:**

**User sends message:** "Hello, how do I book a ride?"

**Step 1: Count Tokens**
- Input: ~8 words = 10 tokens (estimated)
- Output: ~100 tokens (AI response)

**Step 2: Calculate Raw API Cost**
- Input cost: 10 tokens × ($0.30 / 1M) = $0.000003
- Output cost: 100 tokens × ($2.50 / 1M) = $0.00025
- **Total API cost:** $0.000253

**Step 3: Apply Memory Markup**
- If using **Full Memory (🧠)**: $0.000253 × 5 = $0.001265
- If using **Thread Only (🧵)**: $0.000253 × 3 = $0.000759
- If using **Chat Only (💬)**: $0.000253 × 2 = $0.000506
- If **No Memory (🆕)**: $0.000253 × 1 = $0.000253

**Step 4: Convert to Credits**
- Credits = Cost ÷ $0.10 (per credit)
- **Full Memory:** $0.001265 ÷ $0.10 = **0.01265 credits**
- **Thread Only:** $0.000759 ÷ $0.10 = **0.00759 credits**
- **Chat Only:** $0.000506 ÷ $0.10 = **0.00506 credits**
- **No Memory:** $0.000253 ÷ $0.10 = **0.00253 credits**

**Step 5: Round Up**
- **Full Memory:** 0.013 credits (actual deduction)
- **Thread Only:** 0.008 credits
- **Chat Only:** 0.006 credits
- **No Memory:** 0.003 credits

---

## 📱 **User Experience**

### **Before Sending AI Message:**
1. User types message
2. App estimates credit cost
3. Shows: "This will cost ~0.01 credits"
4. User confirms

### **After Sending:**
1. Message sent to Gemini AI
2. Response received
3. Actual tokens counted
4. Credits deducted from balance
5. Transaction recorded

### **If Insufficient Credits:**
- ❌ Message blocked
- 💳 "Insufficient credits. Purchase more?" prompt shown
- User can buy credits or cancel

---

## 🗄️ **Database Structure**

### **Table: `profiles_private`**
```sql
- profile_id (UUID)
- ai_credits_available (INTEGER) -- Current balance
```

### **Table: `credit_transactions`**
```sql
- id (TEXT)
- user_id (UUID)
- type (TEXT) -- 'purchase', 'usage', 'bonus'
- credits_changed (INTEGER) -- +10 or -1
- amount_usd (DECIMAL) -- For purchases
- description (TEXT)
- created_at (TIMESTAMP)
- metadata (JSONB) -- Token counts, etc.
```

---

## 🔄 **Credit Flow**

### **Purchase Flow:**
```
User → Payment Gateway (Razorpay/Cashfree)
     → Payment Success
     → Credits Added to Balance
     → Transaction Recorded
```

### **Usage Flow:**
```
User → Sends AI Message
     → Estimate Cost
     → Check Balance (enough?)
     → Deduct Credits (local first)
     → Send to Gemini API
     → Get Response
     → Sync to Supabase
     → Show Response to User
```

### **Bonus Flow:**
```
Admin/System → Grant Bonus Credits
             → Add to User Balance
             → Record as 'bonus' transaction
```

---

## 📊 **Transaction Types**

| Type | Credits Changed | Description |
|------|----------------|-------------|
| **purchase** | +10, +50, +100 | User buys credits |
| **usage** | -0.01, -0.05 | AI message sent |
| **bonus** | +5, +10 | Signup bonus, referral |
| **refund** | +amount | Payment refund |

---

## 🎨 **Example Scenarios**

### **Scenario 1: New User**
1. User signs up → **Gets 0.2 credits free**
2. Sends 20 AI messages (0.01 each) → **0.2 credits spent**
3. Balance: **0 credits**
4. Must purchase to continue

### **Scenario 2: Power User**
1. User buys $10 → **100 credits**
2. Uses AI chat extensively:
   - Full Memory mode: ~0.02 credits/message
   - Can send ~5,000 messages
3. Balance updates in real-time

### **Scenario 3: Guest User**
1. Guest tries AI chat → **Blocked**
2. "Login required to use AI chat" message
3. After login → Gets 0.2 credits
4. Can use AI now

---

## 💡 **Key Features**

### **1. Optimistic Updates**
- Credits deducted locally first (instant)
- Synced to Supabase in background
- Works offline (syncs when online)

### **2. Transaction History**
- Users can view all transactions
- Shows: date, type, amount, description
- Helps track spending

### **3. Real-time Balance**
- Balance updates instantly
- Shown in app header/profile
- Warnings when low (<0.1 credits)

### **4. Fair Pricing**
- Transparent cost calculation
- Based on actual API usage
- Memory markup clearly communicated

---

## 🔧 **Admin Controls**

### **Can Do:**
- Grant bonus credits to users
- View transaction history
- Adjust pricing (with code update)
- Generate usage reports

### **Cannot Do:**
- Directly deduct credits (only usage does this)
- Refund without transaction record

---

## 📈 **Revenue Model**

### **How You Make Money:**

**Cost Breakdown:**
- Gemini API cost: ~$0.000253 per message (no memory)
- With markup (5x): $0.001265 per message
- User pays: 0.01265 credits × $0.10 = **$0.001265**

**Profit = $0** (You break even with API costs)

**Alternative: Add Platform Margin**
- User pays: $0.12 per credit (instead of $0.10)
- Profit: $0.02 per credit = 20% margin
- With 5x markup: profit covers API costs + platform fee

---

## ✅ **Summary**

| Aspect | Details |
|--------|---------|
| **Purchase Price** | $0.10 per credit |
| **Guest Credits** | 0 credits (must login) |
| **Signup Bonus** | 0.2 credits |
| **Usage Cost** | 0.003-0.02 credits per message (depends on memory mode) |
| **Memory Markup** | 1x (none), 2x (chat), 3x (thread), 5x (full) |
| **Storage** | Supabase (source of truth) + Local cache |
| **Sync** | Background, fire-and-forget |

---

**Ready to use! Users can purchase credits and use AI chat features.** 🎉
