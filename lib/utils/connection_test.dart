import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple connection test utilities
class ConnectionTest {
  static final _supabase = Supabase.instance.client;

  /// Test basic Supabase connection
  static Future<void> testSupabaseConnection() async {
    if (!kDebugMode) return;
    
    try {
      debugPrint('🔍 Testing Supabase connection...');
      
      // Test profiles table
      final profilesResponse = await _supabase
          .from('profiles')
          .select('id')
          .limit(1);
      debugPrint('✅ Profiles table: ${profilesResponse.length} records found');
      
      // Test vehicles table
      final vehiclesResponse = await _supabase
          .from('vehicles')
          .select('id, vehicle_owner')
          .limit(5);
      debugPrint('✅ Vehicles table: ${vehiclesResponse.length} records found');
      
      // Show vehicle owner distribution
      final customerVehicles = vehiclesResponse.where((v) => v['vehicle_owner'] == 'customer').length;
      final providerVehicles = vehiclesResponse.where((v) => v['vehicle_owner'] == 'provider').length;
      debugPrint('📊 Customer vehicles: $customerVehicles, Provider vehicles: $providerVehicles');
      
      debugPrint('🎉 Supabase connection test completed successfully!');
    } catch (e) {
      debugPrint('❌ Supabase connection test failed: $e');
      debugPrint('💡 Check if database migration was run');
    }
  }

  /// Test vehicle owner field migration
  static Future<void> testVehicleOwnerField() async {
    if (!kDebugMode) return;
    
    try {
      debugPrint('🔍 Testing vehicle_owner field...');
      
      final response = await _supabase
          .from('vehicles')
          .select('id, vehicle_owner, profile_id')
          .limit(10);
      
      if (response.isEmpty) {
        debugPrint('📝 No vehicles found in database');
        return;
      }
      
      debugPrint('✅ Found ${response.length} vehicles:');
      for (final vehicle in response) {
        debugPrint('   🚗 ${vehicle['id']}: owner=${vehicle['vehicle_owner']}, profile=${vehicle['profile_id']}');
      }
      
      // Check if migration is needed
      final hasOldField = response.any((v) => v.containsKey('is_user_vehicle'));
      if (hasOldField) {
        debugPrint('⚠️  Old is_user_vehicle field still exists - migration needed');
      } else {
        debugPrint('✅ Migration completed - using vehicle_owner field');
      }
      
    } catch (e) {
      debugPrint('❌ Vehicle owner field test failed: $e');
      if (e.toString().contains('column "vehicle_owner" does not exist')) {
        debugPrint('💡 Run the database migration to add vehicle_owner field');
      }
    }
  }
}