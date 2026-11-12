# Payment System Flow Diagrams

## 🎨 Visual Guide to Payment System

---

## 1. Provider Post Creation Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    PROVIDER CREATES POST                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                  ┌───────────────────────┐
                  │  Validate Form Data   │
                  └───────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Check Payment Provider       │
              │  - Has paymentProvider?       │
              │  - Has Stripe/Razorpay ID?    │
              └───────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
            ❌ NO                      ✅ YES
                 │                         │
                 ▼                         ▼
     ┌──────────────────────┐   ┌──────────────────────┐
     │  Show Error Dialog   │   │  Get Currency Type   │
     │  "Payment Account    │   │  1. bank_currency    │
     │   Required"          │   │  2. payment_provider │
     └──────────────────────┘   │  3. Default INR      │
                 │               └──────────────────────┘
                 ▼                         │
     ┌──────────────────────┐             ▼
     │  Navigate to         │   ┌──────────────────────┐
     │  Profile Settings    │   │  Create Post with    │
     └──────────────────────┘   │  currency_type       │
                                └──────────────────────┘
                                          │
                                          ▼
                              ┌──────────────────────┐
                              │  Post Visible to     │
                              │  Customers           │
                              └──────────────────────┘
```

---

## 2. Currency Auto-Detection Logic

```
┌─────────────────────────────────────────────────────────────┐
│                 DETERMINE CURRENCY TYPE                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Get User Profile             │
              │  ProfileRepository.profile    │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Check: bank_currency?        │
              └───────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
            ✅ EXISTS                  ❌ NULL
                 │                         │
                 ▼                         ▼
     ┌──────────────────────┐   ┌──────────────────────┐
     │  Return               │   │  Check:               │
     │  bank_currency        │   │  payment_provider?    │
     │  (INR/USD/GBP/EUR)    │   └──────────────────────┘
     └──────────────────────┘             │
                                 ┌────────┴────────┐
                                 │                 │
                        'razorpay'            'stripe'
                                 │                 │
                                 ▼                 ▼
                     ┌──────────────┐   ┌──────────────┐
                     │ Return 'INR' │   │ Return 'USD' │
                     └──────────────┘   └──────────────┘
                                 │                 │
                                 └────────┬────────┘
                                          │
                                          ▼
                                 ┌──────────────┐
                                 │ Default:     │
                                 │ Return 'INR' │
                                 └──────────────┘
```

---

## 3. Customer Booking & Payment Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  CUSTOMER BOOKS SERVICE                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Customer Selects Post        │
              │  + Chooses Seat/Quantity      │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Check Post currency_type     │
              └───────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
          currency = 'INR'          currency = USD/GBP/EUR
                 │                         │
                 ▼                         ▼
┌────────────────────────────┐   ┌────────────────────────────┐
│      RAZORPAY PATH         │   │       STRIPE PATH          │
│                            │   │                            │
│  1. Create Order           │   │  1. Create Payment Intent  │
│     - Firebase Function    │   │     - Stripe API           │
│     - amount_paise         │   │     - amount_cents         │
│     - currency: INR        │   │     - currency: usd/gbp    │
│                            │   │                            │
│  2. Open Razorpay Checkout │   │  2. Open Stripe Checkout   │
│     - Show payment modal   │   │     - Card payment form    │
│     - UPI, Card, NetBank   │   │     - Apple/Google Pay     │
│                            │   │                            │
│  3. Customer Pays          │   │  3. Customer Pays          │
│     - Complete payment     │   │     - Complete payment     │
│                            │   │                            │
│  4. Verify Signature       │   │  4. Confirm Payment        │
│     - Firebase Function    │   │     - Stripe webhook       │
│     - razorpay_signature   │   │     - payment_intent.id    │
└────────────────────────────┘   └────────────────────────────┘
                 │                         │
                 └────────────┬────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Payment Successful           │
              │  - payment_id stored          │
              │  - OTP generated              │
              │  - Money held in escrow       │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Create Booking Record        │
              │  - status: pending_approval   │
              │  - payment_id: xxx            │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Provider Sees Booking        │
              │  Can Accept/Reject            │
              └───────────────────────────────┘
```

---

## 4. Payment Routing Decision

```
┌─────────────────────────────────────────────────────────────┐
│                    PAYMENT ROUTING LOGIC                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  PaymentService.processPayment│
              │  - amount                     │
              │  - currency                   │
              │  - countryCode                │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Extract countryCode from     │
              │  slot location string         │
              │  Format: "Name|lat,lon|...CC" │
              └───────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
          countryCode = 'IN'        countryCode ≠ 'IN'
                 │                         │
                 ▼                         ▼
     ┌──────────────────────┐   ┌──────────────────────┐
     │  Route to RAZORPAY   │   │  Route to STRIPE     │
     │  - India only        │   │  - International     │
     │  - Currency: INR     │   │  - Currency: various │
     └──────────────────────┘   └──────────────────────┘
```

---

## 5. Database Schema Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                      DATABASE TABLES                         │
└─────────────────────────────────────────────────────────────┘

┌──────────────────────┐          ┌──────────────────────┐
│  profiles_private    │          │       posts          │
├──────────────────────┤          ├──────────────────────┤
│ id                   │◄─────────│ profile_id           │
│ payment_provider     │          │ currency_type ◄──────┼─┐
│ stripe_account_id    │          │ price                │ │
│ razorpay_account_id  │          │ capacity             │ │
│ bank_currency ───────┼──────────┼─────────────────────►│ │
│ bank_account_holder  │          │ ...                  │ │
│ bank_account_number  │          └──────────────────────┘ │
│ bank_name            │                                    │
│ bank_ifsc            │                                    │
└──────────────────────┘                                    │
                                                            │
┌──────────────────────────────────────────────────────────┐│
│ Currency Auto-Detection Flow:                            ││
│                                                           ││
│ 1. Read bank_currency from profiles_private              ││
│    └─> If set: Use this (INR/USD/GBP/EUR) ──────────────►││
│                                                           ││
│ 2. Fallback: Check payment_provider                      ││
│    ├─> razorpay → INR ───────────────────────────────────►││
│    └─> stripe → USD ──────────────────────────────────────►││
│                                                           ││
│ 3. Default: INR ──────────────────────────────────────────►││
└──────────────────────────────────────────────────────────┘│
                                                             │
                  ┌──────────────────────────────────────────┘
                  │
                  ▼
        currency_type stored in posts
```

---

## 6. Payment Provider Connection Flow

```
┌─────────────────────────────────────────────────────────────┐
│              CONNECT PAYMENT PROVIDER                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  User Opens Profile Settings  │
              └───────────────────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Choose Payment Gateway       │
              └───────────────────────────────┘
                              │
                 ┌────────────┴────────────┐
                 │                         │
            RAZORPAY                    STRIPE
                 │                         │
                 ▼                         ▼
┌────────────────────────────┐   ┌────────────────────────────┐
│  RAZORPAY SETUP (India)    │   │  STRIPE SETUP (Intl)       │
│                            │   │                            │
│  1. Enter Bank Details     │   │  1. Stripe Onboarding      │
│     - Account holder       │   │     - Business info        │
│     - Account number       │   │     - Tax info             │
│     - Bank name            │   │     - Identity docs        │
│     - IFSC code            │   │                            │
│     - Account type         │   │  2. Connect Bank           │
│                            │   │     - Bank verification    │
│  2. Verify Bank            │   │     - Currency detected    │
│     - Penny drop test      │   │                            │
│     - KYC verification     │   │  3. Get Account ID         │
│                            │   │     - acct_xxxxxxxxxxxxx   │
│  3. Get Contact ID         │   │                            │
│     - cont_xxxxxxxxxxxxx   │   │  4. Store Details          │
│                            │   │     - stripe_account_id    │
│  4. Store Details          │   │     - bank_currency (auto) │
│     - razorpay_account_id  │   └────────────────────────────┘
│     - bank_currency: INR   │                 │
└────────────────────────────┘                 │
                 │                             │
                 └────────────┬────────────────┘
                              │
                              ▼
              ┌───────────────────────────────┐
              │  Payment Provider Connected   │
              │  ✅ Can create provider posts │
              │  ✅ Can receive payments      │
              └───────────────────────────────┘
```

---

## 7. Money Flow (Escrow System)

```
┌─────────────────────────────────────────────────────────────┐
│                    ESCROW PAYMENT FLOW                       │
└─────────────────────────────────────────────────────────────┘

BOOKING CREATED:
    Customer pays → Platform holds money in escrow
    
    ┌──────────────┐
    │   Customer   │
    │   💵 Pays    │
    └──────┬───────┘
           │
           │ Payment
           │ (Full amount + 5% fee)
           ▼
    ┌──────────────────┐
    │   Platform       │
    │   💰 Escrow      │
    │   (Stripe/Rzp)   │
    └──────────────────┘
           │
           │ Money held
           │ Status: pending
           │
           ▼


SERVICE COMPLETED:
    Provider delivers → Platform releases money
    
    ┌──────────────────┐
    │   Platform       │
    │   💰 Escrow      │
    └──────┬───────────┘
           │
           │ Release payment
           │ (Amount - 5% fee)
           │
           ▼
    ┌──────────────┐
    │   Provider   │
    │   💵 Receives│
    └──────────────┘


SERVICE CANCELLED:
    Booking cancelled → Platform refunds customer
    
    ┌──────────────────┐
    │   Platform       │
    │   💰 Escrow      │
    └──────┬───────────┘
           │
           │ Refund
           │ (Full amount)
           │
           ▼
    ┌──────────────┐
    │   Customer   │
    │   💵 Refunded│
    └──────────────┘
```

---

## 8. Multi-Currency Support

```
┌─────────────────────────────────────────────────────────────┐
│                   MULTI-CURRENCY SYSTEM                      │
└─────────────────────────────────────────────────────────────┘

Provider A (India):
    Bank: HDFC, Currency: INR
    Posts → currency_type: 'INR'
    Customers pay via Razorpay
    
    ┌──────────────┐         ┌──────────────┐
    │ Provider A   │         │  Customer    │
    │ 🏦 HDFC      │◄────────│  💳 Razorpay │
    │ 💰 INR       │         │  ₹ 500       │
    └──────────────┘         └──────────────┘


Provider B (USA):
    Bank: Chase, Currency: USD
    Posts → currency_type: 'USD'
    Customers pay via Stripe
    
    ┌──────────────┐         ┌──────────────┐
    │ Provider B   │         │  Customer    │
    │ 🏦 Chase     │◄────────│  💳 Stripe   │
    │ 💰 USD       │         │  $ 50        │
    └──────────────┘         └──────────────┘


Provider C (UK):
    Bank: Barclays, Currency: GBP
    Posts → currency_type: 'GBP'
    Customers pay via Stripe
    
    ┌──────────────┐         ┌──────────────┐
    │ Provider C   │         │  Customer    │
    │ 🏦 Barclays  │◄────────│  💳 Stripe   │
    │ 💰 GBP       │         │  £ 40        │
    └──────────────┘         └──────────────┘
```

---

## 📝 Key Takeaways

### 1. Provider Setup (One-time)
```
Provider → Settings → Connect Payment → Bank → Currency Auto-Detected
```

### 2. Post Creation
```
Provider → Create Post → Currency Auto-Set → Post Live
```

### 3. Customer Booking
```
Customer → Select Post → Pay (Razorpay/Stripe) → Booking Created
```

### 4. Money Flow
```
Customer Pay → Escrow → Service Done → Provider Receives
```

---

**Visual Guide Complete!** 🎨✨
