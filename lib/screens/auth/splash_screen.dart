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
    AuthRepository.instance.currentUserListenable.addListener(_onAuthStateChanged);
    
    // Also set a max timeout - navigate after 5 seconds regardless
    Future.delayed(const Duration(seconds: 5), () {
      if (!mounted || _hasNavigated) return;
      _navigate();
    });
  }

  @override
  void dispose() {
    AuthRepository.instance.currentUserListenable.removeListener(_onAuthStateChanged);
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
    AuthRepository.instance.currentUserListenable.removeListener(_onAuthStateChanged);
    
    // Guest-first: Always go to main screen (no forced login)
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.directions_car, size: 80, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'VaultWheels',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your Transport Partner',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}



