import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/forgot_password_screen.dart';
import 'features/auth/presentation/verify_otp_screen.dart';
import 'features/auth/presentation/reset_password_screen.dart';
import 'shared/widgets/scaffold_with_navbar.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/expenses/presentation/expense_list_screen.dart';
import 'features/expenses/presentation/add_expense_screen.dart';
import 'features/expenses/presentation/scan_receipt_screen.dart';
import 'features/goals/goals_screen.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/expenses/domain/expense.dart';
import 'features/auth/application/auth_controller.dart';
import 'core/network/health_service.dart';
import 'core/theme/theme.dart';

void main() {
  runApp(const ProviderScope(child: CashScopeApp()));
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: HealthScreen(),
    );
  }
}

class HealthScreen extends StatefulWidget {
  const HealthScreen({super.key});

  @override
  State<HealthScreen> createState() => _HealthScreenState();
}

class _HealthScreenState extends State<HealthScreen> {
  String result = "Checking...";

  @override
  void initState() {
    super.initState();
    check();
  }

  Future<void> check() async {
    final response = await HealthService.checkHealth();

    setState(() {
      result = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Backend Health Check")),
      body: Center(
        child: Text(result),
      ),
    );
  }
}
final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    

    redirect: (context, state) {
      final isLoggedIn = authStatus == AuthStatus.authenticated;
      final isLoggingIn = state.uri.path == '/login' ||
          state.uri.path == '/register' ||
          state.uri.path == '/forgot-password' ||
          state.uri.path == '/verify-otp' ||
          state.uri.path == '/reset-password';

      // If not logged in → force login
      if (!isLoggedIn && !isLoggingIn) {
        return '/login';
      }

      // If logged in → prevent going back to login/register
      if (isLoggedIn && isLoggingIn) {
        return '/dashboard';
      }

      return null;
    },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/verify-otp',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return VerifyOtpScreen(email: email);
      },
    ),
    GoRoute(
      path: '/reset-password',
      builder: (context, state) {
        final email = state.uri.queryParameters['email'] ?? '';
        return ResetPasswordScreen(email: email);
      },
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) => const NoTransitionPage(child: DashboardScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/expenses',
              pageBuilder: (context, state) => const NoTransitionPage(child: ExpenseListScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/add',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AddExpenseScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/analytics',
              pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/goals',
              pageBuilder: (context, state) => const NoTransitionPage(child: GoalsScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/add-expense',
      builder: (context, state) {
        final expense = state.extra as Expense?;
        return AddExpenseScreen(existingExpense: expense);
      },
    ),
    GoRoute(
      path: '/scan-receipt',
      builder: (context, state) => const ScanReceiptScreen(),
    ),
  ],
);
});

class CashScopeApp extends ConsumerWidget {
  const CashScopeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CashScope',
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }
} 

