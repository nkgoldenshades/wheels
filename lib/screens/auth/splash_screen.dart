import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';

class Splashscreen extends StatefulWidget {
  const Splashscreen({super.key});

  @override
  State<Splashscreen> createState() => _SplashscreenState();
}

class _SplashscreenState extends State<Splashscreen> {
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();

    // Listen for auth state changes - navigate as soon as ready
    AuthRepository.instance.currentUserListenable.addListener(
      _onAuthStateChanged,
    );

    // Also set a max timeout - navigate after 5 seconds regardless
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _hasNavigated) return;
      _navigate();
    });
  }

  @override
  void dispose() {
    AuthRepository.instance.currentUserListenable.removeListener(
      _onAuthStateChanged,
    );
    super.dispose();
  }

  void _onAuthStateChanged() {
    if (!mounted || _hasNavigated) return;
    // Wait a bit to ensure initialization is complete
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted || _hasNavigated) return;
      _navigate();
    });
  }

  void _navigate() {
    if (_hasNavigated) return;
    _hasNavigated = true;

    // Remove listener to prevent multiple calls
    AuthRepository.instance.currentUserListenable.removeListener(
      _onAuthStateChanged,
    );

    // Guest-first: Always go to main screen (no forced login)
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue.shade50, Colors.blue.shade100],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Car Icon with Shadow (VaultWheels style)
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.directions_car,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'VaultWheels',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your Transport Partner',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
