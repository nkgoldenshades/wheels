import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';

/// Test Supabase connection and database access
class SupabaseConnectionTest {
  static final _supabase = Supabase.instance.client;

  /// Test basic connection to Supabase
  static Future<bool> testConnection() async {
    try {
      debugPrint('🔍 Testing Supabase connection...');
      
      // Test basic query
      final response = await _supabase
          .from('profiles_public')
          .select('id')
          .limit(1);
      
      debugPrint('✅ Supabase connection successful');
      debugPrint('📊 Response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ Supabase connection failed: $e');
      return false;
    }
  }

  /// Test vehicle table access
  static Future<bool> testVehicleTable() async {
    try {
      debugPrint('🔍 Testing vehicles table access...');
      
      final response = await _supabase
          .from('vehicles')
          .select('id, profile_id, vehicle_owner')
          .limit(5);
      
      debugPrint('✅ Vehicles table access successful');
      debugPrint('📊 Found ${response.length} vehicles');
      for (final vehicle in response) {
        debugPrint('🚗 Vehicle: ${vehicle['id']} - Owner: ${vehicle['vehicle_owner']}');
      }
      return true;
    } catch (e) {
      debugPrint('❌ Vehicles table access failed: $e');
      return false;
    }
  }

  /// Test profiles table access
  static Future<bool> testProfilesTable() async {
    try {
      debugPrint('🔍 Testing profiles table access...');
      
      final response = await _supabase
          .from('profiles_public')
          .select('id, full_name')
          .limit(5);
      
      debugPrint('✅ Profiles table access successful');
      debugPrint('📊 Found ${response.length} profiles');
      return true;
    } catch (e) {
      debugPrint('❌ Profiles table access failed: $e');
      return false;
    }
  }

  /// Run all connection tests
  static Future<void> runAllTests() async {
    debugPrint('🚀 Starting Supabase connection tests...');
    debugPrint('🔗 URL: ${SupabaseConfig.url}');
    
    final connectionOk = await testConnection();
    final profilesOk = await testProfilesTable();
    final vehiclesOk = await testVehicleTable();
    
    debugPrint('📋 Test Results:');
    debugPrint('   Connection: ${connectionOk ? "✅" : "❌"}');
    debugPrint('   Profiles: ${profilesOk ? "✅" : "❌"}');
    debugPrint('   Vehicles: ${vehiclesOk ? "✅" : "❌"}');
    
    if (connectionOk && profilesOk && vehiclesOk) {
      debugPrint('🎉 All Supabase tests passed!');
    } else {
      debugPrint('⚠️  Some Supabase tests failed - check configuration');
    }
  }
}


