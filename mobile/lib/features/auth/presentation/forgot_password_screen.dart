import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api_client.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _loading = false;

  Future<void> _sendOtp() async {
  setState(() => _loading = true);

  try {
    final api = ApiClient();

    final response = await api.post(
      '/auth/send-reset-otp',
      {
        "email": _emailController.text.trim(),
      },
    );

    print("OTP Response: ${response.data}");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('If this email is registered, an OTP has been sent.'),
      ),
    );

    context.push(
      '/verify-otp?email=${Uri.encodeComponent(_emailController.text.trim())}',
    );
  } catch (e) {
    print("OTP ERROR: $e");

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to send OTP: $e')),
    );
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton(
                onPressed: _loading ? null : _sendOtp,
                child: _loading ? const CircularProgressIndicator() : const Text('Send OTP'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
