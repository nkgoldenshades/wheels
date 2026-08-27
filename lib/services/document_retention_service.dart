import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Manages document retention and auto-deletion per DPDP compliance
/// Documents are automatically deleted after retention period
class DocumentRetentionService {
  static final DocumentRetentionService _instance =
      DocumentRetentionService._internal();

  factory DocumentRetentionService() {
    return _instance;
  }

  DocumentRetentionService._internal();

  // Default retention period: 30 days
  static const int defaultRetentionDays = 30;

  /// Record user's consent for document storage
  Future<void> recordConsent({
    required String userId,
    required bool consentGiven,
    required int retentionDays,
    required String verificationMethod, // 'local' or 'backend'
  }) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase.from('verification_consent').upsert({
        'user_id': userId,
        'consent_given': consentGiven,
        'consent_given_at': consentGiven
            ? DateTime.now().toIso8601String()
            : null,
        'retention_days': retentionDays,
        'verification_method': verificationMethod,
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Consent recorded for user: $userId');
    } catch (e) {
      debugPrint('⚠️ Failed to record consent: $e');
      rethrow;
    }
  }

  /// Schedule document deletion after retention period
  Future<void> scheduleDocumentDeletion({
    required String userId,
    required String documentType, // 'id', 'selfie', 'address_proof'
    required int retentionDays,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final deleteAtDate = DateTime.now().add(Duration(days: retentionDays));

      await supabase.from('document_retention').insert({
        'user_id': userId,
        'document_type': documentType,
        'uploaded_at': DateTime.now().toIso8601String(),
        'delete_at': deleteAtDate.toIso8601String(),
        'deleted': false,
      });

      debugPrint('⏰ Document deletion scheduled for $userId on $deleteAtDate');
    } catch (e) {
      debugPrint('⚠️ Failed to schedule deletion: $e');
      rethrow;
    }
  }

  /// Delete document immediately (user request)
  Future<void> deleteDocumentImmediately({
    required String userId,
    required String documentType,
  }) async {
    try {
      final supabase = Supabase.instance.client;

      // Delete from storage
      await supabase.storage.from('verification-documents').remove([
        '$userId/$documentType/${DateTime.now().millisecondsSinceEpoch}',
      ]);

      // Mark as deleted in retention table
      await supabase
          .from('document_retention')
          .update({
            'deleted': true,
            'deleted_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('document_type', documentType)
          .eq('deleted', false);

      debugPrint('🗑️ Document deleted immediately for user: $userId');
    } catch (e) {
      debugPrint('⚠️ Failed to delete document: $e');
      // Don't rethrow - deletion errors shouldn't block the flow
    }
  }

  /// Process expired documents (run daily via Cloud Function)
  /// This should be called by a scheduled Cloud Function
  Future<int> processExpiredDocuments() async {
    try {
      final supabase = Supabase.instance.client;

      // Get all documents that should be deleted
      final expiredDocs = await supabase
          .from('document_retention')
          .select('user_id, document_type, storage_path')
          .lt('delete_at', DateTime.now().toIso8601String())
          .eq('deleted', false);

      int deletedCount = 0;

      for (final doc in expiredDocs) {
        try {
          final userId = doc['user_id'] as String;
          final storagePath = doc['storage_path'] as String?;

          // Delete from storage if path is available
          if (storagePath != null && storagePath.isNotEmpty) {
            await supabase.storage.from('verification-documents').remove([
              storagePath,
            ]);
          }

          // Mark as deleted
          await supabase
              .from('document_retention')
              .update({
                'deleted': true,
                'deleted_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId)
              .eq('document_type', doc['document_type'])
              .eq('deleted', false);

          deletedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to delete document: $e');
          continue;
        }
      }

      debugPrint('🗑️ Processed $deletedCount expired documents');
      return deletedCount;
    } catch (e) {
      debugPrint('⚠️ Failed to process expired documents: $e');
      return 0;
    }
  }

  /// Get retention status for user
  Future<Map<String, dynamic>?> getRetentionStatus(String userId) async {
    try {
      final supabase = Supabase.instance.client;

      final result = await supabase
          .from('verification_consent')
          .select()
          .eq('user_id', userId)
          .single();

      return result;
    } catch (e) {
      debugPrint('⚠️ No retention status found: $e');
      return null;
    }
  }

  /// Check if document will be deleted soon
  Future<bool> willBeDeletedSoon({
    required String userId,
    required String documentType,
    int daysWarning = 3,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final warningDate = DateTime.now().add(Duration(days: daysWarning));

      final result = await supabase
          .from('document_retention')
          .select()
          .eq('user_id', userId)
          .eq('document_type', documentType)
          .eq('deleted', false)
          .lt('delete_at', warningDate.toIso8601String());

      return (result as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }
}
