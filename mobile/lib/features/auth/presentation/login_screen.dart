import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/api_client.dart';
import '../application/auth_controller.dart';
import '../../../services/google_auth_service.dart';

// Simple provider for auth logic (to be moved to domain later)


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final apiClient = ref.read(apiClientProvider);

      final response = await apiClient.post(
        '/auth/login',
        {
          'email': _emailController.text,
          'password': _passwordController.text,
        },
      );

      final access = response.data['access_token'];
      final refresh = response.data['refresh_token'];

      await apiClient.storage.write(key: 'auth_token', value: access);
      await apiClient.storage.write(key: 'refresh_token', value: refresh);
      
      if (mounted) {
        ref.read(authControllerProvider.notifier).loginSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleService = GoogleAuthService();
      final response = await googleService.signIn();

      if (response == null) {
        throw Exception("Google login failed");
      }

      final access = response['access_token'];
      final refresh = response['refresh_token'];

      final apiClient = ref.read(apiClientProvider);

      await apiClient.storage.write(key: 'auth_token', value: access);
      await apiClient.storage.write(key: 'refresh_token', value: refresh);

      ref.read(authControllerProvider.notifier).loginSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google Login Failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('CashScope', style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 48),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
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
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading 
                    ? const CircularProgressIndicator() 
                    : const Text('Login'),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  child: const Text('Sign in with Google'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.push('/register'),
                child: const Text('Don\'t have an account? Sign Up'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
