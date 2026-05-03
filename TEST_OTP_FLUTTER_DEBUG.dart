
// ============================================
// FLUTTER OTP DEBUGGING TEST
// ============================================
// This file helps debug why OTP attempts are not incrementing
// Add this code to a test button in your app
// ============================================

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpDebugTest extends StatefulWidget {
  const OtpDebugTest({super.key});

  @override
  State<OtpDebugTest> createState() => _OtpDebugTestState();
}

class _OtpDebugTestState extends State<OtpDebugTest> {
  final _supabase = Supabase.instance.client;
  final _logs = <String>[];

  void _log(String message) {
    setState(() {
      _logs.add('${DateTime.now().toIso8601String()}: $message');
    });
    debugPrint('🧪 $message');
  }

  Future<void> _runTest() async {
    _logs.clear();
    _log('Starting OTP debug test...');

    try {
      // Step 1: Create a test booking
      _log('Step 1: Creating test booking...');
      final insertResponse = await _supabase
          .from('bookings')
          .insert({
            'profile_customer_id': 'flutter-test-user-${DateTime.now().millisecondsSinceEpoch}',
            'profile_provider_id': 'flutter-test-provider',
            'post_id': (await _supabase
                .from('posts')
                .select('id')
                .order('created_at', ascending: false)
                .limit(1)
                .single())['id'],
            'status': 'pending',
            'service_type': 'passenger',
            'total_price': 100.0,
            'price_snapshot': 100.0,
            'deposit_snapshot': 0.0,
            'currency_snapshot': 'INR',
            'persons_snapshot': 1,
            'booking_strategy_snapshot': 'instant',
            'post_mode': 'instant',
            'start_time': DateTime.now().toIso8601String(),
            'end_time': DateTime.now().add(Duration(hours: 1)).toIso8601String(),
            'otp_code': null, // Let trigger generate
          })
          .select('id, otp_code, otp_attempts, otp_locked, otp_verified, profile_customer_id')
          .single();

      final bookingId = insertResponse['id'] as int;
      final otpCode = insertResponse['otp_code'] as String?;
      final customerId = insertResponse['profile_customer_id'] as String;
      
      _log('✅ Booking created: ID=$bookingId, OTP=$otpCode');
      _log('   Customer ID: $customerId');
      _log('   Initial attempts: ${insertResponse['otp_attempts']}');

      // Step 2: Verify with WRONG OTP (attempt 1)
      _log('Step 2: Testing wrong OTP (attempt 1)...');
      final result1 = await _supabase.rpc(
        'verify_otp',
        params: {
          'p_booking_id': bookingId,
          'p_profile_customer_id': customerId,
          'p_entered_otp': '999999',
        },
      );
      _log('   Result: $result1');

      // Step 3: Check if attempts incremented
      _log('Step 3: Checking if attempts incremented...');
      final checkResponse1 = await _supabase
          .from('bookings')
          .select('id, otp_attempts, otp_locked, otp_verified')
          .eq('id', bookingId)
          .single();
      
      _log('   Attempts after wrong OTP: ${checkResponse1['otp_attempts']}');
      _log('   Locked: ${checkResponse1['otp_locked']}');
      _log('   Verified: ${checkResponse1['otp_verified']}');

      if (checkResponse1['otp_attempts'] == 1) {
        _log('✅ SUCCESS: Attempts incremented correctly!');
      } else {
        _log('❌ FAILURE: Attempts did NOT increment (still ${checkResponse1['otp_attempts']})');
        _log('   This means the UPDATE statement in verify_otp is not executing');
        _log('   Possible causes:');
        _log('   1. RLS policy blocking UPDATE');
        _log('   2. Function not using SECURITY DEFINER');
        _log('   3. Wrong column names in UPDATE statement');
      }

      // Step 4: Test multiple wrong attempts
      _log('Step 4: Testing 4 more wrong attempts...');
      for (int i = 2; i <= 5; i++) {
        final result = await _supabase.rpc(
          'verify_otp',
          params: {
            'p_booking_id': bookingId,
            'p_profile_customer_id': customerId,
            'p_entered_otp': '$i$i$i$i$i$i',
          },
        );
        _log('   Attempt $i result: $result');
      }

      // Step 5: Check if locked after 5 attempts
      _log('Step 5: Checking if locked after 5 attempts...');
      final checkResponse2 = await _supabase
          .from('bookings')
          .select('id, otp_attempts, otp_locked, otp_verified')
          .eq('id', bookingId)
          .single();
      
      _log('   Final attempts: ${checkResponse2['otp_attempts']}');
      _log('   Locked: ${checkResponse2['otp_locked']}');

      if (checkResponse2['otp_attempts'] == 5 && checkResponse2['otp_locked'] == true) {
        _log('✅ SUCCESS: Locking works correctly!');
      } else {
        _log('❌ FAILURE: Locking did NOT work');
        _log('   Expected: attempts=5, locked=true');
        _log('   Got: attempts=${checkResponse2['otp_attempts']}, locked=${checkResponse2['otp_locked']}');
      }

      // Step 6: Try correct OTP after locked
      _log('Step 6: Testing correct OTP after locked...');
      final result6 = await _supabase.rpc(
        'verify_otp',
        params: {
          'p_booking_id': bookingId,
          'p_profile_customer_id': customerId,
          'p_entered_otp': otpCode,
        },
      );
      _log('   Result: $result6');
      
      if (result6 == 'locked') {
        _log('✅ SUCCESS: Correctly blocked after 5 attempts');
      } else {
        _log('❌ FAILURE: Should return "locked" but got "$result6"');
      }

      // Cleanup
      _log('Cleaning up test booking...');
      await _supabase
          .from('bookings')
          .delete()
          .eq('id', bookingId);
      _log('✅ Test complete!');

    } catch (e, stackTrace) {
      _log('❌ ERROR: $e');
      _log('Stack trace: $stackTrace');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OTP Debug Test'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _runTest,
              child: const Text('Run OTP Test'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                Color color = Colors.black;
                if (log.contains('✅')) {
                  color = Colors.green;
                } else if (log.contains('❌')) {
                  color = Colors.red;
                } else if (log.contains('⚠️')) {
                  color = Colors.orange;
                }
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(
                    log,
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// HOW TO USE THIS TEST
// ============================================
// 1. Add this file to your project
// 2. Add a button in your app to navigate to this screen:
//    Navigator.push(context, MaterialPageRoute(builder: (_) => OtpDebugTest()));
// 3. Run the test and watch the logs
// 4. Share the logs with me to diagnose the issue
// ============================================
