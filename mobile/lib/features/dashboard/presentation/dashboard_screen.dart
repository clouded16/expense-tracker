import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/domain/expense.dart';
import '../../analytics/data/analytics_repository.dart';
import '../../analytics/domain/insight.dart';
import '../../auth/application/auth_controller.dart';
import '../../expenses/presentation/expense_list_screen.dart';
import '../../../core/api_client.dart';

final budgetProvider = FutureProvider<double>((ref) async {
  final api = ref.watch(apiClientProvider);
  final response = await api.get('/budget');
  return (response.data['monthly_amount'] as num).toDouble();
});


// We'll keep dashboardStatsProvider but make it use the analytics data
final dashboardStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {

  // 🔥 Make dashboard depend on expensesProvider
  final List<Expense> expenses = await ref.watch(expensesProvider.future);
  final budget = await ref.watch(budgetProvider.future);

  final now = DateTime.now();
  final monthlyExpenses = expenses.where((e) {
     return e.transactionDate.year == now.year &&
            e.transactionDate.month == now.month;
            }).toList();

  final double total = monthlyExpenses.fold<double>(
    0.0,
    (sum, e) => sum + e.amount,
  );

  return {
    'totalSpent': total,
    'budget': budget,
    'recent': monthlyExpenses.take(5).toList(),
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

          final progress = budget == 0 ? 0.0 : (total / budget).clamp(0.0, 1.0);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(spendSummaryProvider);
              ref.invalidate(insightsProvider);
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
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total Spent this Month'),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () => _showBudgetDialog(context, ref),
                              ),
                            ],
                          ),
                          Text(
                            '₹${total.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.displaySmall,
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

                /// Insights
                if (insights.isNotEmpty) ...[
                  Text(
                    'Insights for You',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: insights.length,
                      itemBuilder: (context, index) {
                        final insight = insights[index];
                        return Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 12),
                          child: Card(
                            child: ListTile(
                              leading: Icon(
                                _getInsightIcon(insight.type),
                                color: Colors.amber,
                              ),
                              title: Text(
                                insight.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: Text(
                                insight.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                /// Recent Transactions
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...recent.map((exp) => ListTile(
                  leading: const Icon(Icons.receipt_long),
                  title: Text(exp.categoryName ?? 'Uncategorized'),
                  subtitle: Text(
                    exp.merchantName ?? '',
                  ),
                  trailing: Text(
                    '- ₹${exp.amount.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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

  IconData _getInsightIcon(String type) {
    switch (type) {
      case 'trend':
        return Icons.trending_up;
      case 'anomaly':
        return Icons.warning_amber_rounded;
      case 'duplicate':
        return Icons.copy;
      default:
        return Icons.lightbulb_outline;
    }
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
            decoration: const InputDecoration(
              labelText: 'Budget Amount',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);

                if (value == null || value <= 0) {
                  return;
                }

                final api = ref.read(apiClientProvider);

                await api.post('/budget', {
                  'amount': value,
                });

                // 🔥 Refresh budget + dashboard
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
