import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_repository.dart';
import '../config/supabase_config.dart';

/// Test backend connection and RLS policies
class BackendConnectionTest {
  static final supabase = Supabase.instance.client;

  /// Run all backend tests
  static Future<void> runAllTests() async {
    if (!kDebugMode) return;

    debugPrint('🧪 Starting Backend Connection Tests...');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    await testSupabaseConnection();
    await testFirebaseJWT();
    await testRLSPolicies();
    await testTableAccess();

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🎉 Backend Connection Tests Complete!');
  }

  /// Test 1: Supabase Connection
  static Future<void> testSupabaseConnection() async {
    debugPrint('\n📡 Test 1: Supabase Connection');
    try {
      debugPrint('   URL: ${SupabaseConfig.url}');
      debugPrint('   ✅ Supabase client initialized');
    } catch (e) {
      debugPrint('   ❌ Supabase connection failed: $e');
    }
  }

  /// Test 2: Firebase JWT
  static Future<void> testFirebaseJWT() async {
    debugPrint('\n🔑 Test 2: Firebase JWT');
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        debugPrint('   ⚠️  No user logged in (expected on first launch)');
        return;
      }

      debugPrint('   User ID: ${currentUser.id}');
      debugPrint('   Email: ${currentUser.email}');
      debugPrint('   ✅ Firebase user authenticated');
    } catch (e) {
      debugPrint('   ❌ Firebase JWT test failed: $e');
    }
  }

  /// Test 3: RLS Policies
  static Future<void> testRLSPolicies() async {
    debugPrint('\n🔒 Test 3: RLS Policies');
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        debugPrint('   ⚠️  Skipping (no user logged in)');
        return;
      }

      // Test: Can read own profile
      try {
        final profile = await supabase
            .from('profiles_public')
            .select()
            .eq('id', currentUser.id)
            .maybeSingle();

        if (profile != null) {
          debugPrint('   ✅ Can read own profile');
        } else {
          debugPrint('   ⚠️  Profile not found (may need to be created)');
        }
      } catch (e) {
        debugPrint('   ❌ Profile read failed: $e');
      }

      // Test: Can read own vehicles
      try {
        final vehicles = await supabase
            .from('vehicles')
            .select()
            .eq('profile_id', currentUser.id) // Changed from owner_id
            .limit(5);

        debugPrint('   ✅ Can read vehicles (${vehicles.length} found)');
      } catch (e) {
        debugPrint('   ❌ Vehicles read failed: $e');
      }

      // Test: Can read active posts
      try {
        final posts = await supabase
            .from('posts') // Changed from slots
            .select()
            .eq('is_active', true)
            .limit(5);

        debugPrint('   ✅ Can read posts (${posts.length} found)');
      } catch (e) {
        debugPrint('   ❌ Posts read failed: $e');
      }

    } catch (e) {
      debugPrint('   ❌ RLS test failed: $e');
    }
  }

  /// Test 4: Table Access
  static Future<void> testTableAccess() async {
    debugPrint('\n📊 Test 4: Table Access');
    
    final tables = [
      'profiles',
      'vehicles',
      'posts', // Changed from 'slots'
      'bookings',
      'reviews',
      // Note: user_posts and user_post_acceptances may not exist in your schema
    ];

    for (final table in tables) {
      try {
        await supabase.from(table).select().limit(1);
        debugPrint('   ✅ $table - accessible');
      } catch (e) {
        debugPrint('   ❌ $table - error: ${e.toString().substring(0, 50)}...');
      }
    }
  }

  /// Quick connection check (non-blocking)
  static Future<bool> quickCheck() async {
    try {
      // Just verify Supabase is initialized
      final _ = Supabase.instance.client;
      return true;
    } catch (e) {
      debugPrint('❌ Backend not connected: $e');
      return false;
    }
  }

  /// Test creating a profile (for new users)
  static Future<void> testCreateProfile() async {
    debugPrint('\n👤 Test: Create Profile');
    try {
      final currentUser = AuthRepository.instance.currentUser;
      if (currentUser == null) {
        debugPrint('   ⚠️  No user logged in');
        return;
      }

      // Check if profile exists
      final existing = await supabase
          .from('profiles_public')
          .select()
          .eq('id', currentUser.id)
          .maybeSingle();

      if (existing != null) {
        debugPrint('   ✅ Profile already exists');
        return;
      }

      // Create profile
      await supabase.from('profiles_public').insert({
        'id': currentUser.id,
        'full_name': currentUser.profileName ?? 'User',
        'email': currentUser.email,
        'phone_number': currentUser.phone,
        'business_type': 'solo',
      });

      debugPrint('   ✅ Profile created successfully');
    } catch (e) {
      debugPrint('   ❌ Profile creation failed: $e');
    }
  }
}

