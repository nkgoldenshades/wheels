import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Service to handle dispute creation and management
class DisputeService {
  static final DisputeService instance = DisputeService._();
  DisputeService._();

  final _supabase = Supabase.instance.client;

  /// Create dispute - automatically creates 2 chat threads (customer + provider)
  /// Returns the customer's conversation ID to open their chat
  /// 
  /// SIMPLIFIED: Only needs booking_id - fetches everything else!
  Future<int> createDispute({
    required String bookingId,
    String? disputeReason,
  }) async {
    try {
      debugPrint('🚨 Creating dispute for booking: $bookingId');

      // STEP 1: Fetch ALL data from database using just booking_id
      
      // Get booking data (includes slot_id!)
      final bookingData = await _supabase
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();

      debugPrint('📦 Booking data: $bookingData');

      // Handle different possible field names in database
      final customerId = bookingData['profile_customer_id'] as String? ?? bookingData['user_id'] as String?;
      final providerId = bookingData['profile_provider_id'] as String? ?? bookingData['provider_id'] as String?;
      final vehicleId = bookingData['vehicle_id'] as String?;
      final slotId = (bookingData['slot_id'] ?? bookingData['post_id'])?.toString();

      if (customerId == null || providerId == null || slotId == null) {
        throw Exception('Missing required booking data: customerId=$customerId, providerId=$providerId, slotId=$slotId');
      }

      debugPrint('✅ IDs: customer=$customerId, provider=$providerId, vehicle=$vehicleId, slot=$slotId');

      // Get slot/post data
      final slotData = await _supabase
          .from('posts')
          .select()
          .eq('id', slotId)
          .single();

      // Get vehicle ID from booking or from slot
      final finalVehicleId = vehicleId ?? slotData['vehicle_id']?.toString();
      
      if (finalVehicleId == null) {
        throw Exception('Cannot find vehicle_id in booking or slot data');
      }

      // Get vehicle data
      final vehicleData = await _supabase
          .from('vehicles')
          .select()
          .eq('id', finalVehicleId)
          .single();

      // Get customer profile
      final customerProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', customerId)
          .single();

      // Get provider profile
      final providerProfile = await _supabase
          .from('profiles')
          .select()
          .eq('id', providerId)
          .single();

      debugPrint('✅ Fetched all data for dispute');

      // Get trip media (photos/evidence)
      final tripMedia = bookingData['trip_media'] as List<dynamic>? ?? [];
      
      debugPrint('📸 Found ${tripMedia.length} media items for evidence');

      // Prepare full context for AI
      final fullContext = {
        'booking': bookingData,
        'slot': slotData,
        'vehicle': vehicleData,
        'customer_profile': customerProfile,
        'provider_profile': providerProfile,
        'trip_media': tripMedia, // Photos for evidence analysis
        'dispute_raised_at': DateTime.now().toIso8601String(),
        'dispute_reason': disputeReason,
      };

      // 1. CREATE CUSTOMER'S CHAT THREAD
      final customerChat = await _supabase
          .from('ai_conversations')
          .insert({
            'profile_id': customerId,
            'title': 'Dispute: ${slotData['from_location'] ?? 'Pickup'} → ${slotData['to_location'] ?? 'Dropoff'}',
            'messages': [
              {
                'role': 'assistant',
                'content': _getCustomerWelcomeMessage(bookingData, slotData, disputeReason),
                'timestamp': DateTime.now().toIso8601String(),
              }
            ],
            'context_type': 'dispute',
            'booking_id': bookingId,
            'dispute_party': 'customer',
            'disputed_by': customerId,
            'is_active': true,
            'metadata': fullContext, // Store all context for AI
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      debugPrint('✅ Created customer dispute chat: ${customerChat['id']}');

      // 2. CREATE PROVIDER'S CHAT THREAD
      final providerChat = await _supabase
          .from('ai_conversations')
          .insert({
            'profile_id': providerId,
            'title': 'Dispute: ${slotData['from_location']} → ${slotData['to_location']}',
            'messages': [
              {
                'role': 'assistant',
                'content': _getProviderWelcomeMessage(bookingData, slotData, customerProfile),
                'timestamp': DateTime.now().toIso8601String(),
              }
            ],
            'context_type': 'dispute',
            'booking_id': bookingId,
            'dispute_party': 'provider',
            'disputed_by': customerId,
            'is_active': true,
            'metadata': fullContext, // Same context for consistency
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select('id')
          .single();

      debugPrint('✅ Created provider dispute chat: ${providerChat['id']}');

      // Return customer's conversation ID to open their chat
      // Note: Push notifications for disputes can be added later
      return customerChat['id'] as int;
    } catch (e) {
      debugPrint('❌ Failed to create dispute: $e');
      rethrow;
    }
  }

  /// Mark dispute as completed
  /// Updates both customer and provider threads context_type to 'dispute_completed'
  Future<void> completeDispute({required String bookingId}) async {
    try {
      debugPrint('✅ Marking dispute as completed for booking: $bookingId');

      // Update both threads (customer + provider) to dispute_completed
      await _supabase
          .from('ai_conversations')
          .update({
            'context_type': 'dispute_completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('context_type', 'dispute')
          .eq('booking_id', bookingId);

      debugPrint('✅ Dispute marked as completed');
    } catch (e) {
      debugPrint('❌ Failed to complete dispute: $e');
      rethrow;
    }
  }

  /// Get welcome message for customer
  String _getCustomerWelcomeMessage(
    Map<String, dynamic> booking,
    Map<String, dynamic> slot,
    String? reason,
  ) {
    final tripMedia = booking['trip_media'] as List<dynamic>? ?? [];
    
    return '''
🤖 **AI Dispute Mediator**

Hi! I'm VaultWheels AI Mediator. I'm here to help resolve your dispute fairly and quickly.

**📋 Dispute Details:**
• Booking ID: #${booking['id']}
• Route: ${slot['from_location']} → ${slot['to_location']}
• Date: ${slot['start_time']}
• Amount: ₹${booking['price_snapshot']}
${reason != null ? '• Reason: $reason' : ''}

${tripMedia.isNotEmpty ? '**📸 Evidence Available:**\n• ${tripMedia.length} photos already uploaded from your trip\n• I will review these as part of the evidence\n\n' : ''}**🔒 Privacy:**
This is a private conversation. The provider has a separate chat and won't see your messages directly. I'll gather facts from both sides independently.

**📝 What I Need From You:**
1. Please explain in detail what went wrong
2. When did the issue occur? (exact time if possible)
3. What actions did you take?
4. ${tripMedia.isEmpty ? 'Do you have any evidence? (photos, screenshots, etc.)' : 'I see you have ${tripMedia.length} photos - please explain what they show'}

**⚖️ How I'll Resolve This:**
1. Collect your statement (this chat)
2. Collect provider's statement (separate chat)
3. Analyze objective evidence (GPS, timings, OTP, photos)
4. Review platform policies
5. Make a fair, data-driven decision
6. Present resolution to both parties

**💬 Please tell me what happened:**
''';
  }

  /// Get welcome message for provider
  String _getProviderWelcomeMessage(
    Map<String, dynamic> booking,
    Map<String, dynamic> slot,
    Map<String, dynamic> customerProfile,
  ) {
    final tripMedia = booking['trip_media'] as List<dynamic>? ?? [];
    
    return '''
🤖 **AI Dispute Mediator**

Hello! A customer has raised a dispute for one of your bookings. I'm here to ensure fair resolution for both parties.

**📋 Booking Details:**
• Booking ID: #${booking['id']}
• Route: ${slot['from_location']} → ${slot['to_location']}
• Date: ${slot['start_time']}
• Amount: ₹${booking['price_snapshot']}
• Customer: ${customerProfile['profile_name'] ?? 'User'}

${tripMedia.isNotEmpty ? '**📸 Evidence Available:**\n• ${tripMedia.length} photos from the trip\n• These will be reviewed as part of the evidence\n\n' : ''}**🔒 Privacy:**
This is a private conversation. The customer has a separate chat and won't see your responses directly.

**📝 What I Need From You:**
1. Please explain what happened from your perspective
2. ${tripMedia.isEmpty ? 'Do you have any evidence? (photos, GPS logs, communication records)' : 'I see there are ${tripMedia.length} photos - please explain what happened'}
3. Were there any circumstances beyond your control?
4. Have you tried resolving this directly with the customer?

**⚖️ Resolution Process:**
I'll review:
• Both statements independently
• GPS/location data
• Timing records (OTP verification, arrival times)
• Communication logs
• Photos and evidence (${tripMedia.length} available)
• Platform policies
• Both parties' history and ratings

Based on evidence, I'll make a fair decision that may include:
• Full refund to customer
• Partial refund
• No refund (if no fault found)
• Warnings or penalties as per policy

**💬 Please share your side of the story:**
''';
  }

  /// Get AI system prompt for dispute mediation
  static String getDisputeSystemPrompt(Map<String, dynamic> metadata, String party) {
    final booking = metadata['booking'] as Map<String, dynamic>;
    final vehicle = metadata['vehicle'] as Map<String, dynamic>;
    final customerProfile = metadata['customer_profile'] as Map<String, dynamic>;
    final providerProfile = metadata['provider_profile'] as Map<String, dynamic>;
    final tripMedia = metadata['trip_media'] as List<dynamic>? ?? [];

    return '''
🤖 **You are VaultWheels AI Dispute Mediator**

**YOUR ROLE:**
Act as an impartial, fair, and professional mediator to resolve booking disputes based on objective evidence and platform policies.

**CURRENT CONVERSATION:**
You are speaking with the **$party** in this dispute.

**COMPLETE BOOKING CONTEXT:**

**Booking Information:**
- ID: ${booking['id']}
- Route: ${booking['from_location']} → ${booking['to_location']}
- Scheduled Time: ${booking['start_time']}
- Price: ₹${booking['price_snapshot']}
- Status: ${booking['status']}
- OTP Verified: ${booking['otp_verified']}
- OTP Attempts: ${booking['otp_attempts'] ?? 'None'}
- Booking Mode: ${booking['post_mode']}

**Vehicle Information:**
- Type: ${vehicle['vehicle_type']}
- Brand/Model: ${vehicle['brand_name']} ${vehicle['model_name']}
- Vehicle ID: ${vehicle['id']}
- Capacity: ${vehicle['seating_capacity']} seats

**Customer Profile:**
- Name: ${customerProfile['name']}
- Rating: ${customerProfile['rating'] ?? 'N/A'}
- Verified: ${customerProfile['is_verified'] ?? false}

**Provider Profile:**
- Name: ${providerProfile['name']}
- Rating: ${providerProfile['rating'] ?? 'N/A'}
- Verified: ${providerProfile['is_verified'] ?? false}

**📸 Trip Media Evidence:**
- Available Photos: ${tripMedia.length} items
${tripMedia.isNotEmpty ? '- Photo URLs: ${tripMedia.map((m) => m['url']).join(', ')}' : '- No photos uploaded yet'}

**MEDIATION GUIDELINES:**

1. **Evidence-Based Decisions:**
   - Prioritize objective data (GPS, timestamps, OTP logs)
   - Review uploaded photos carefully - check timestamps and content
   - Photos can show: vehicle condition, location proof, damage evidence
   - Cross-reference all claims with available data
   - ${tripMedia.isNotEmpty ? 'IMPORTANT: ${tripMedia.length} photos are available - analyze them!' : 'Note: No photos provided yet - ask parties to upload evidence'}

2. **Platform Policies:**
   - Provider must arrive within 15 min of scheduled time
   - Customer must be at pickup location on time
   - OTP must be verified for payment release
   - No-shows result in full refund
   - Late arrivals (>15 min): 50% refund
   - Service issues: Case-by-case assessment

3. **Communication Style:**
   - Be empathetic but professional
   - Ask specific, clarifying questions
   - Request concrete evidence (photos, screenshots)
   - Explain your reasoning clearly
   - Remain neutral and unbiased

4. **Evidence Collection:**
   - Review existing ${tripMedia.length} photos if available
   - Ask for additional photos with timestamps if needed
   - Request exact times of events
   - Inquire about communication attempts
   - Check for any witnesses or additional proof

5. **Decision Criteria:**
   - Clear fault (95%+ confidence): Immediate decision
   - Moderate confidence (70-95%): Partial resolution
   - Low confidence (<70%): Escalate to human review
   
6. **Resolution Types:**
   - Full refund + provider penalty (clear provider fault)
   - Partial refund (shared responsibility)
   - No refund + customer warning (customer fault)
   - Escalate (insufficient evidence)

**YOUR IMMEDIATE TASK:**
${party == 'customer' 
  ? 'Collect detailed statement from customer. Ask about timing, location, evidence, and actions taken.'
  : 'Collect detailed statement from provider. Ask about circumstances, evidence, and attempts to fulfill booking.'}

Remember: You're speaking ONLY to the $party in this chat. The other party has a separate conversation. Maintain confidentiality.

**Start the conversation by acknowledging their concern and asking for details.**
''';
  }
}
