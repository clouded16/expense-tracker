import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../application/auth_controller.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  

  Future<void> _register() async {
    setState(() => _isLoading = true);

    try {
      final api = ref.read(apiClientProvider);

      final response = await api.post(
        '/auth/register',
        {
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'full_name': _nameController.text.trim(),
        },
      );

      // Save tokens
      await api.storage.write(
        key: 'auth_token',
        value: response.data['access_token'],
      );

      await api.storage.write(
        key: 'refresh_token',
        value: response.data['refresh_token'],
      );

      // Update auth state
      ref.read(authControllerProvider.notifier).loginSuccess();

    } catch (e) {
      debugPrint("Register error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('CashScope', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),
              Text('Start tracking your wealth', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 48),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text('Sign Up'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Already have an account? Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
