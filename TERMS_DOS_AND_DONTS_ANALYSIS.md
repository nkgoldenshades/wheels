# VaultWheels Terms of Service - DOS & DON'Ts Analysis

## ✅ DOS - What Users CAN Do

### Account & Profile (Section 1, 5)
- **DO** provide accurate and truthful information when creating an account
- **DO** be 18 years or older to use VaultWheels
- **DO** maintain your account security
- **DO** use the app for legal activities only
- **DO** skip document uploads if you prefer privacy
- **DO** delete your documents anytime
- **DO** browse and use 100% of the app without uploading documents
- **DO** delete your account anytime from Settings

### Content & Conduct (Section 2, 3, 5)
- **DO** post authentic information about services
- **DO** follow driver/passenger ratings and reviews
- **DO** follow traffic laws and safety regulations
- **DO** share legitimate ride-sharing, parcel delivery, and leasing opportunities
- **DO** use AI chat or escalation system for dispute resolution
- **DO** delete your content anytime
- **DO** continue using the app without sharing documents (PERFECTLY LEGAL)

### Transactions & Payments (Section 4)
- **DO** understand that VaultWheels charges 5% commission on successful transactions
- **DO** accept that commission may be adjusted by VaultWheels
- **DO** be aware commission covers platform maintenance, payment processing, and support
- **DO** expect automatic commission deduction from payouts
- **DO** check payment processing through Razorpay/Stripe
- **DO** expect disputed payments to be handled within 7 days
- **DO** fulfill your tax obligations

### Using Services (Section 3)
- **DO** coordinate peer-to-peer services through the social network
- **DO** use platform features like ride-sharing, parcel delivery, vehicle leasing
- **DO** understand services are community coordination via social network
- **DO** follow applicable cancellation policies for bookings

---

## ❌ DON'Ts - What Users CANNOT Do

### Prohibited Conduct (Section 2)
- **DON'T** harass, threaten, or abuse other users
- **DON'T** post false or misleading information
- **DON'T** engage in fraud or deception
- **DON'T** share other people's personal information without consent
- **DON'T** violate any laws or regulations
- **DON'T** attempt to hack or damage the app
- **DON'T** spam or send unsolicited messages
- **DON'T** engage in any illegal activities

### Profile & Document Misuse (Section 5)
- **DON'T** upload documents unless you truly consent
- **DON'T** assume documents are official government verification (they're not)
- **DON'T** upload fake or fraudulent documents
- **DON'T** use documents for purposes other than face matching
- **DON'T** share sensitive document information publicly

### Content & Intellectual Property (Section 7)
- **DON'T** copy or reproduce VaultWheels' branding/logos without permission
- **DON'T** reproduce VaultWheels content without permission
- **DON'T** post inappropriate content that violates community standards

### Liability Misconceptions (Section 6)
- **DON'T** hold VaultWheels liable for:
  - Accidents or injuries during trips
  - Lost or damaged items
  - Disputes between users
  - Third-party actions
  - Service interruptions

---

## 🚨 KEY ENFORCEMENT ACTIONS (Section 2, 10)

### Consequences for Violations:
- ⚠️ Account suspension for misconduct
- 🔴 Permanent account ban for serious violations
- Account termination at VaultWheels' discretion
- Refund of prepaid credits if service is closed

---

## 📋 CRITICAL COMPLIANCE GAPS IN YOUR APP

### 🔴 **CRITICAL ISSUE #1: Post Media Verification NOT Implemented**
**Location:** `lib/widgets/post_media_upload_widget.dart`
- Terms state posts must be accurate, but NO AI verification exists
- Risk: Users can upload false/misleading content without checks
- **Recommendation:** Implement AI content moderation as discussed

### 🟡 **ISSUE #2: Inappropriate Content Detection**
- Terms prohibit "inappropriate content" but no moderation dashboard
- No automated flagging system mentioned in code
- **Recommendation:** Add content filtering service

### 🟡 **ISSUE #3: Document Upload Consent**
- Section 5 emphasizes "COMPLETELY OPTIONAL" - Make this VERY CLEAR in UI
- Current implementation may not sufficiently emphasize this
- **Recommendation:** Add prominent skip/optional messages

### 🟡 **ISSUE #4: False Information Prevention**
- Terms say "DON'T post false or misleading information"
- No validation for post content authenticity
- **Recommendation:** Add business logic to verify service details

### 🟡 **ISSUE #5: Personal Information Sharing**
- Terms prohibit sharing others' personal info without consent
- Need to ensure reviews/ratings don't expose sensitive data
- **Recommendation:** Audit what data is visible in ratings/reviews

### ⚠️ **ISSUE #6: Document Auto-Deletion**
- Terms state: "Documents are auto-deleted after 30 days"
- No evidence of this deletion mechanism in code
- **Recommendation:** Implement automated deletion job

### ⚠️ **ISSUE #7: Commission Notification**
- Terms state: "Users will be notified of any commission changes"
- Need notification system for commission updates
- **Recommendation:** Add in-app notification for commission changes

### ⚠️ **ISSUE #8: Dispute Resolution Timing**
- Terms state: "Disputed payments are handled within 7 days"
- Verify dispute service enforces this SLA
- **Recommendation:** Check `dispute_service.dart` for 7-day SLA

---

## ✅ CURRENT COMPLIANCE STRENGTHS

1. ✅ **Account Security:** Users responsible for maintaining security (Section 1)
2. ✅ **Ratings/Reviews System:** Implemented and working
3. ✅ **User-Generated Content:** Clearly stated as user's property
4. ✅ **Optional Documents:** Clearly emphasized in Terms (Section 5)
5. ✅ **Privacy Policy Linked:** Reference to DPDP 2023 Act
6. ✅ **Dispute Resolution:** AI chat + escalation system exists
7. ✅ **Account Deletion:** Users can delete anytime from Settings
8. ✅ **Liability Limitation:** Clear in Section 6

---

## 📝 RECOMMENDATIONS - PRIORITY ORDER

### 🔴 **HIGH PRIORITY (Implement ASAP)**

1. **AI Content Moderation for Posts**
   - Prevent false/misleading information
   - Flag inappropriate content
   - File: `lib/services/post_media_service.dart`

2. **Document Auto-Deletion System**
   - Delete documents after 30 days as promised
   - File: Create cleanup task in backend

3. **Spam & Unsolicited Messages Prevention**
   - Block users from mass messaging
   - Rate limit messages per user

4. **User Verification for Document Upload**
   - Clear consent prompt
   - Emphasize "OPTIONAL" prominently
   - File: `lib/widgets/post_media_upload_widget.dart`

### 🟡 **MEDIUM PRIORITY (Implement in next sprint)**

5. **Commission Change Notifications**
   - Notify users when commission rates change
   - Maintain notification history

6. **7-Day Dispute Resolution SLA**
   - Enforce timing in dispute service
   - Auto-escalate if not resolved in time

7. **Data Retention & Deletion Audit**
   - Ensure DPDP 2023 Act compliance
   - Document data retention periods

8. **Inappropriate Content Dashboard**
   - Admin ability to review flagged content
   - Community reporting mechanism

### ⚠️ **LOW PRIORITY (Polish & Enhancement)**

9. **Personal Information Exposure Audit**
   - Review what's visible in reviews/ratings
   - Mask sensitive data if necessary

10. **Terms Update Notification System**
    - Notify users of major changes
    - Track acceptance of new terms

---

## 🔍 IMPLEMENTATION CHECKLIST

- [ ] AI content moderation for post media (HIGH)
- [ ] Document auto-deletion after 30 days (HIGH)
- [ ] Spam/unsolicited message blocking (HIGH)
- [ ] Prominent "optional documents" messaging (HIGH)
- [ ] Commission change notifications (MEDIUM)
- [ ] 7-day dispute SLA enforcement (MEDIUM)
- [ ] DPDP 2023 Act compliance audit (MEDIUM)
- [ ] Inappropriate content dashboard (MEDIUM)
- [ ] Personal info exposure audit (LOW)
- [ ] Terms update notifications (LOW)

---

## 📞 CONTACT & GOVERNANCE

- Legal Contact: legal@vaultwheels.com
- Support Contact: support@vaultwheels.com
- Governed by: Laws of India
- Dispute Resolution: AI chat → Escalation → Arbitration

---

**Last Reviewed:** August 2026 (in alignment with Terms last update)
**Status:** ⚠️ PARTIAL COMPLIANCE - 5 critical gaps identified
