import 'package:flutter/material.dart';
import '../../services/auth_repository.dart';
import '../../services/profile_name_registry.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isCheckingName = false;
  bool? _isNameAvailable;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }
  
  Future<void> _checkNameAvailability(String name) async {
    if (name.trim().isEmpty) {
      setState(() {
        _isNameAvailable = null;
        _isCheckingName = false;
      });
      return;
    }
    
    setState(() => _isCheckingName = true);
    
    try {
      final available = await ProfileNameRegistry.instance.checkNameAvailability(name.trim());
      setState(() {
        _isNameAvailable = available;
        _isCheckingName = false;
      });
    } catch (e) {
      setState(() {
        _isNameAvailable = null;
        _isCheckingName = false;
      });
    }
  }

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();
    
    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      await AuthRepository.instance.signUpWithEmail(
        email: email,
        password: password,
        profileName: name,
      );
      
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.app_registration, size: 80, color: Colors.green),
              const SizedBox(height: 24),
              const Text(
                'Create Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Join VaultWheels',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: const OutlineInputBorder(),
                  errorText: _isNameAvailable == false 
                      ? 'Name already taken' 
                      : null,
                  suffixIcon: _nameController.text.trim().isEmpty
                      ? null
                      : _isCheckingName
                          ? const Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : Icon(
                              _isNameAvailable == true 
                                  ? Icons.check_circle 
                                  : Icons.error,
                              color: _isNameAvailable == true 
                                  ? Colors.green 
                                  : Colors.red,
                            ),
                ),
                onChanged: (value) {
                  // Debounce the check
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (_nameController.text == value) {
                      _checkNameAvailability(value);
                    }
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign Up',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(context, 
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
                },
                child: const Text('Already have an account? Sign In'),
              ),
              const SizedBox(height: 16),
              // Guest mode button
              OutlinedButton.icon(
                onPressed: _isLoading ? null : () {
                  // Navigate to main screen without logging in
                  Navigator.pushReplacementNamed(context, '/main');
                },
                icon: const Icon(Icons.person_outline),
                label: const Text('Continue as Guest'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Browse posts without signing in',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

