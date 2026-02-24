import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'shared/widgets/scaffold_with_navbar.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/expenses/presentation/expense_list_screen.dart';
import 'features/expenses/presentation/add_expense_screen.dart';
import 'features/goals/presentation/goals_screen.dart';
import 'features/analytics/presentation/analytics_screen.dart';
import 'features/expenses/domain/expense.dart';
import 'features/auth/application/auth_controller.dart';

void main() {
  runApp(const ProviderScope(child: CashScopeApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    

    redirect: (context, state) {
      final isLoggedIn = authStatus == AuthStatus.authenticated;
      final isLoggingIn = state.uri.path == '/login' ||
          state.uri.path == '/register';

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
      ),
      routerConfig: router,
    );
  }
}