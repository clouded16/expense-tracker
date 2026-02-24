import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../application/auth_controller.dart';
import 'login_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(authControllerProvider);

    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case AuthStatus.authenticated:
        return const DashboardScreen();

      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}