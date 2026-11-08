import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../analytics/analytics_provider.dart';
import '../../analytics/domain/insight.dart';
import '../../auth/application/auth_controller.dart';
import '../../expenses/domain/expense.dart';
import '../../expenses/presentation/expense_list_screen.dart';
import '../data/budget_repository.dart';

final budgetProvider = FutureProvider<double>((ref) async {
  return ref.watch(budgetRepositoryProvider).getMonthlyBudget();
});

final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final List<Expense> expenses = await ref.watch(expensesProvider.future);
  final budget = await ref.watch(budgetProvider.future);

  final now = DateTime.now();
  final monthlyExpenses = expenses.where((e) {
    return e.transactionDate.year == now.year && e.transactionDate.month == now.month;
  }).toList();

  final double total = monthlyExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

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
            icon: const Icon(Icons.lock_outline_rounded),
            tooltip: 'Lock app',
            onPressed: () async {
              await ref.logout();
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
          final progress = budget <= 0 ? 0.0 : (total / budget).clamp(0.0, 1.0);
          final savings = budget - total;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(financialSummaryProvider);
              ref.invalidate(monthlyExpensesProvider);
              ref.invalidate(categoryBreakdownProvider);
              ref.invalidate(savingsTrendProvider);
              ref.invalidate(topMerchantsProvider);
              ref.invalidate(analyticsAiInsightsProvider);
              ref.invalidate(dashboardStatsProvider);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _GradientSummaryCard(
                  total: total,
                  budget: budget,
                  savings: savings,
                  onEditBudget: () => _showBudgetDialog(context, ref),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Expense Overview', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: progress,
                          minHeight: 10,
                          borderRadius: BorderRadius.circular(10),
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: progress > 0.9 ? Colors.red.shade400 : const Color(0xFF0F9D8A),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          budget == 0
                              ? 'Set a monthly budget to track progress.'
                              : '${(progress * 100).toStringAsFixed(1)}% of Rs ${budget.toStringAsFixed(0)} used',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Quick Actions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Add Expense',
                        onTap: () => context.go('/add'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.insights_outlined,
                        label: 'Analytics',
                        onTap: () => context.go('/analytics'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.flag_outlined,
                        label: 'Goals',
                        onTap: () => context.go('/goals'),
                      ),
                    ),
                  ],
                ),
                if (insights.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Insights', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...insights.map(
                    (insight) => Card(
                      child: ListTile(
                        leading: Icon(_getInsightIcon(insight.type), color: const Color(0xFFF59E0B)),
                        title: Text(insight.title),
                        subtitle: Text(insight.message, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                const Text('Recent Transactions', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 10),
                if (recent.isEmpty)
                  const _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    message: 'No expenses yet',
                    subtitle: 'Your recent transactions will appear here.',
                  )
                else
                  ...recent.map(
                    (exp) => Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.receipt_long, size: 18)),
                        title: Text(exp.categoryName ?? 'Uncategorized'),
                        subtitle: Text(exp.merchantName ?? ''),
                        trailing: Text(
                          'Rs ${exp.amount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  IconData _getInsightIcon(String type) {
    switch (type) {
      case 'trend':
        return Icons.trending_up_rounded;
      case 'anomaly':
        return Icons.warning_amber_rounded;
      case 'duplicate':
        return Icons.copy_rounded;
      default:
        return Icons.lightbulb_outline_rounded;
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
            decoration: const InputDecoration(labelText: 'Budget Amount'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final value = double.tryParse(controller.text);
                if (value == null || value <= 0) return;

                await ref.read(budgetRepositoryProvider).setMonthlyBudget(value);
                ref.invalidate(budgetProvider);
                ref.invalidate(dashboardStatsProvider);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _GradientSummaryCard extends StatelessWidget {
  final double total;
  final double budget;
  final double savings;
  final VoidCallback onEditBudget;

  const _GradientSummaryCard({
    required this.total,
    required this.budget,
    required this.savings,
    required this.onEditBudget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF5B4EE6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x26000000), blurRadius: 14, offset: Offset(0, 8)),
        ],
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Financial Summary',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: onEditBudget,
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Monthly Budget: Rs ${budget.toStringAsFixed(0)}'),
            Text('Total Expenses: Rs ${total.toStringAsFixed(0)}'),
            Text('Savings Remaining: Rs ${savings.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFF283593)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 34, color: const Color(0xFF9CA3AF)),
            const SizedBox(height: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}
