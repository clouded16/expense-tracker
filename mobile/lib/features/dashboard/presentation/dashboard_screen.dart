import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../analytics/domain/insight.dart';
import '../../auth/application/auth_controller.dart';
import '../../../core/api_client.dart';
import '../../ingestion/presentation/ingestion_review_screen.dart';
import '../../expenses/data/expense_repository.dart';

final budgetProvider = FutureProvider<double>((ref) async {
  final authStatus = ref.watch(authControllerProvider);

  if (authStatus != AuthStatus.authenticated) {
    return 0.0;
  }

  final api = ref.watch(apiClientProvider);
  final response = await api.get('/budget');
  return (response.data['monthly_amount'] as num).toDouble();
});

final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final authStatus = ref.watch(authControllerProvider);

  if (authStatus != AuthStatus.authenticated) {
    return {
      'totalSpent': 0.0,
      'budget': 0.0,
      'recent': <Expense>[],
      'insights': <Insight>[],
    };
  }

  final List<Expense> expenses = await ref.watch(expensesProvider.future);
  final budget = await ref.watch(budgetProvider.future);

  final now = DateTime.now();
  final monthlyExpenses = expenses.where((e) {
    return e.transactionDate.year == now.year &&
        e.transactionDate.month == now.month;
  }).toList();

  final double total =
      monthlyExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

  // Sort ALL expenses by createAt descending 
  final sortedExpenses = [...expenses];
  sortedExpenses.sort(
    (a, b) => b.createdAt.compareTo(a.createdAt)
  );
  return {
    'totalSpent': total,
    'budget': budget,
    'recent': sortedExpenses.take(5).toList(),
    'insights': <Insight>[],
  };
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: statsAsync.when(
        data: (stats) {
          final total = stats['totalSpent'] as double;
          final budget = stats['budget'] as double;
          final recent = stats['recent'] as List<Expense>;
          final insights = stats['insights'] as List<Insight>;

          final progress =
              budget == 0 ? 0.0 : (total / budget).clamp(0.0, 1.0);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardStatsProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [

                /// Summary Card
                Card(
                  elevation: 2,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Spent this Month'),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () =>
                                  _showBudgetDialog(context, ref),
                            ),
                          ],
                        ),
                        Text(
                          '₹${total.toStringAsFixed(0)}',
                          style:
                              Theme.of(context).textTheme.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.white24,
                          color: total > budget ? Colors.red : null,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          budget == 0
                              ? 'No budget set'
                              : '${((total / budget) * 100).toStringAsFixed(1)}% of ₹${budget.toStringAsFixed(0)} budget',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// Recent Transactions
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),

                ...recent.map(
                  (exp) => ListTile(
                    leading: const Icon(Icons.receipt_long),
                    title:
                        Text(exp.categoryName ?? 'Uncategorized'),
                    subtitle: Text(exp.merchantName ?? ''),
                    trailing: Text(
                      '- ₹${exp.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                /// Review Transactions Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.reviews),
                    label: const Text('Review Transactions'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const IngestionReviewScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Monthly Budget'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Budget Amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value =
                    double.tryParse(controller.text);
                if (value == null || value <= 0) return;

                final api = ref.read(apiClientProvider);
                await api.post('/budget', {
                  'amount': value,
                });

                ref.invalidate(budgetProvider);
                ref.invalidate(dashboardStatsProvider);

                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}