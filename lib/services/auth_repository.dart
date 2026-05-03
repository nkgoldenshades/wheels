import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'profile_name_registry.dart';
import 'device_info_service.dart';

class AppAuthUser {
  final String id;
  final String email;
  final String? profileName;
  final String? avatarUrl;
  final String? phone;

  const AppAuthUser({
    required this.id,
    required this.email,
    this.profileName,
    this.avatarUrl,
    this.phone,
  });
}

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  final ValueNotifier<AppAuthUser?> _currentUser = ValueNotifier<AppAuthUser?>(null);
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;

  static const _storageKeyUser = 'auth_user';

  ValueListenable<AppAuthUser?> get currentUserListenable => _currentUser;

  AppAuthUser? get currentUser => _currentUser.value;

  bool get isAuthenticated => _currentUser.value != null;

  set currentUser(AppAuthUser? user) {
    _currentUser.value = user;
  }

  Future<void> setDisplayName(String profileName) async {
    final trimmed = profileName.trim();
    if (trimmed.isEmpty) return;
    final u = _currentUser.value;
    if (u == null) return;
    
    // Update Firebase user display name
    await _firebaseAuth.currentUser?.updateDisplayName(trimmed);
    
    final updated = AppAuthUser(
      id: u.id,
      email: u.email,
      profileName: trimmed,
      avatarUrl: u.avatarUrl,
      phone: u.phone,
    );
    _currentUser.value = updated;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKeyUser, _encodeUser(updated));
  }

  Future<void> init() async {
    // Listen to Firebase auth state changes
    _firebaseAuth.authStateChanges().listen((firebase_auth.User? firebaseUser) {
      if (firebaseUser != null) {
        _currentUser.value = AppAuthUser(
          id: firebaseUser.uid,
          email: firebaseUser.email ?? '',
          profileName: firebaseUser.displayName,
          avatarUrl: firebaseUser.photoURL,
          phone: firebaseUser.phoneNumber,
        );
      } else {
        _currentUser.value = null;
      }
    });

    // Check if user is already signed in
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser != null) {
      _currentUser.value = AppAuthUser(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        profileName: firebaseUser.displayName,
        avatarUrl: firebaseUser.photoURL,
        phone: firebaseUser.phoneNumber,
      );
    }
  }

  // Sign up with email and password
  Future<AppAuthUser?> signUpWithEmail({
    required String email,
    required String password,
    String? profileName,
  }) async {
    try {
      // Check profile name uniqueness before creating account
      if (profileName != null && profileName.trim().isNotEmpty) {
        await ProfileNameRegistry.instance.init();
        final isAvailable = ProfileNameRegistry.instance.isNameAvailable(
          profileName.trim(),
        );
        
        if (!isAvailable) {
          throw 'Profile name already taken. Please choose a different name.';
        }
      }
      
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      if (profileName != null && profileName.trim().isNotEmpty) {
        await credential.user?.updateDisplayName(profileName.trim());
        
        // Register the profile name
        await ProfileNameRegistry.instance.registerName(
          credential.user!.uid,
          profileName.trim(),
        );
      }

      final user = AppAuthUser(
        id: credential.user!.uid,
        email: email.trim(),
        profileName: profileName?.trim(),
        avatarUrl: null,
        phone: null,
      );

      _currentUser.value = user;
      
      // Sync user to Supabase with timeout
      try {
        await syncUserToSupabase().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️  Supabase sync timed out - continuing anyway');
          },
        );
      } catch (e) {
        debugPrint('⚠️  Supabase sync failed: $e - continuing anyway');
      }

      // Record device session (fire-and-forget, non-blocking)
      unawaited(DeviceInfoService.instance.recordLoginSession(user.id));
      
      return user;
    } catch (e) {
      final msg = _extractFirebaseError(e);
      throw msg ?? 'Sign up failed: $e';
    }
  }
  Future<void> syncUserToSupabase() async {
    final firebaseUser = _firebaseAuth.currentUser;
    
    if (firebaseUser == null) {
      debugPrint('⚠️ No Firebase user to sync');
      return;
    }

    try {
      final uid = firebaseUser.uid;
      debugPrint('🔄 Syncing Firebase user to Supabase: $uid');

      // Force token refresh so the accessToken callback has a valid user
      await firebaseUser.getIdToken(true);
      debugPrint('🔑 Token refreshed');
      
      // Small delay to ensure Supabase client picks up the new token
      await Future.delayed(const Duration(milliseconds: 500));

      final supabase = Supabase.instance.client;

      // Check if user already exists
      final existingUser = await supabase
          .from('profiles_public')
          .select()
          .eq('id', uid)
          .maybeSingle();

      if (existingUser != null) {
        debugPrint('✅ User already exists in Supabase');
        return;
      }

      // Insert new user into all 3 tables
      await supabase.from('profiles_public').insert({
        'id': uid,
        'full_name': firebaseUser.displayName ?? 'User',
        'profile_photo_url': firebaseUser.photoURL,
        'business_type': 'solo',
      });

      await supabase.from('profiles_contact').insert({
        'profile_id': uid,
        'email': firebaseUser.email,
        'phone_number': firebaseUser.phoneNumber,
      });

      await supabase.from('profiles_private').insert({
        'profile_id': uid,
        'ai_credits_available': 50,
        'wallet_balance': 0.0,
        'payment_provider': 'razorpay',
      });

      debugPrint('✅ User synced to Supabase (3 tables): $uid');
    } catch (e) {
      debugPrint('❌ Failed to sync user to Supabase: $e');
      // Don't throw - allow login to succeed even if Supabase sync fails
    }
  }

  // Sign in with email and password
  Future<AppAuthUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = AppAuthUser(
        id: credential.user!.uid,
        email: email.trim(),
        profileName: credential.user!.displayName,
        avatarUrl: credential.user!.photoURL,
        phone: credential.user!.phoneNumber,
      );

      _currentUser.value = user;
      
      // Sync user to Supabase with timeout
      try {
        await syncUserToSupabase().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️  Supabase sync timed out - continuing anyway');
          },
        );
      } catch (e) {
        debugPrint('⚠️  Supabase sync failed: $e - continuing anyway');
      }

      // Record device session (fire-and-forget, non-blocking)
      unawaited(DeviceInfoService.instance.recordLoginSession(user.id));
      
      return user;
    } catch (e) {
      final msg = _extractFirebaseError(e);
      throw msg ?? 'Sign in failed: $e';
    }
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      final msg = _extractFirebaseError(e);
      if (msg != null) throw msg;
      rethrow;
    }
  }

  // Sign out
  Future<void> logout() async {
    await _firebaseAuth.signOut();
    _currentUser.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKeyUser);
  }

  // Legacy phone auth methods (kept for backward compatibility)
  Future<void> startPhoneVerification({
    required String phoneNumber,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    void Function()? onAutoVerified,
  }) async {
    try {
      final phone = phoneNumber.trim();
      if (phone.isEmpty) {
        onError('Invalid phone number');
        return;
      }

      // Demo mode: bypass OTP and authenticate immediately with email
      // In production, implement proper phone auth
      final user = AppAuthUser(
        id: _idFromPhone(phone),
        email: '$phone@temp.com', // Temporary email
        phone: phone,
      );

      _currentUser.value = user;
      onAutoVerified?.call();
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<bool> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) async {
    // Legacy method - kept for backward compatibility
    return true;
  }

  String _idFromPhone(String phone) {
    return phone.trim();
  }

  String _encodeUser(AppAuthUser u) {
    final profileName = u.profileName ?? '';
    final avatar = u.avatarUrl ?? '';
    final phone = u.phone ?? '';
    return '${u.id}|${u.email}|$profileName|$avatar|$phone';
  }

  String? _extractFirebaseError(Object e) {
    // Try string parsing first (works on both mobile and web)
    final str = e.toString();
    if (str.contains('weak-password')) return 'Password is too weak';
    if (str.contains('email-already-in-use')) return 'Email is already registered';
    if (str.contains('invalid-email')) return 'Invalid email address';
    if (str.contains('user-not-found')) return 'No user found with this email';
    if (str.contains('wrong-password')) return 'Wrong password';
    if (str.contains('user-disabled')) return 'This account has been disabled';
    if (str.contains('too-many-requests')) return 'Too many attempts. Try again later';
    
    // Fallback to typed exception (mobile only)
    try {
      if (e is firebase_auth.FirebaseAuthException) {
        return _getErrorMessage(e);
      }
    } catch (_) {
      // Type check failed on web - ignore
    }
    
    return null;
  }

  String _getErrorMessage(firebase_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak';
      case 'email-already-in-use':
        return 'Email is already registered';
      case 'invalid-email':
        return 'Invalid email address';
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Wrong password';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  /// TEST FUNCTION: Check what JWT claims Supabase receives
  /// Call this after login to see what's in the JWT
  Future<void> testJWTClaims() async {
    try {
      debugPrint('🔍 Testing JWT claims...');
      
      // Get Firebase token first
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser == null) {
        debugPrint('❌ No Firebase user logged in');
        return;
      }
      
      final firebaseToken = await firebaseUser.getIdToken(true);
      debugPrint('🔑 Firebase UID: ${firebaseUser.uid}');
      debugPrint('🔑 Firebase Token (first 50 chars): ${firebaseToken?.substring(0, 50)}...');
      
      // Call Supabase function to get JWT claims
      final supabase = Supabase.instance.client;
      final response = await supabase.rpc('get_jwt_claims');
      
      debugPrint('📦 JWT Claims received by Supabase:');
      debugPrint(response.toString());
      
      // Check if 'sub' exists
      if (response != null && response is Map) {
        if (response.containsKey('sub')) {
          debugPrint('✅ Found "sub" claim: ${response['sub']}');
        } else if (response.containsKey('user_id')) {
          debugPrint('⚠️ Found "user_id" instead of "sub": ${response['user_id']}');
        } else {
          debugPrint('❌ No user identifier found in JWT!');
          debugPrint('Available keys: ${response.keys.toList()}');
        }
      } else {
        debugPrint('❌ JWT claims is null or not a Map');
      }
    } catch (e) {
      debugPrint('❌ Error testing JWT claims: $e');
    }
  }
}
