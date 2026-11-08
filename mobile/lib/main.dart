import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/theme.dart';
import 'features/analytics/analytics_screen.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/dashboard_screen.dart';
import 'features/expenses/domain/expense.dart';
import 'features/expenses/presentation/add_expense_screen.dart';
import 'features/expenses/presentation/expense_list_screen.dart';
import 'features/expenses/presentation/scan_receipt_screen.dart';
import 'features/goals/goals_screen.dart';
import 'shared/widgets/scaffold_with_navbar.dart';

void main() {
  runApp(const ProviderScope(child: CashScopeApp()));
}

final routerProvider = Provider<GoRouter>((ref) {
  final authStatus = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authStatus == AuthStatus.authenticated;
      final atLock = state.uri.path == '/login';

      if (authStatus == AuthStatus.unknown) {
        return atLock ? null : '/login';
      }

      if (!isLoggedIn && !atLock) return '/login';
      if (isLoggedIn && atLock) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/expenses',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ExpenseListScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/add',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AddExpenseScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/analytics',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AnalyticsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/goals',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: GoalsScreen()),
            ),
          ]),
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
