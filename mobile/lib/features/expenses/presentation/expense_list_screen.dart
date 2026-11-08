import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';

final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses();
});

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends ConsumerState<ExpenseListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = ref.watch(expensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: () => context.push('/scan-receipt'),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => context.push('/add-expense'),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) {
          if (expenses.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(expensesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  _EmptyExpenseState(),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.refresh(expensesProvider),
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];
                  final category = (expense.categoryName ?? 'other').toLowerCase();
                  final visual = _categoryVisual(category);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Dismissible(
                      key: ValueKey('${expense.id ?? index}-${expense.createdAt.toIso8601String()}'),
                      background: _SwipeBg(
                        icon: Icons.edit_rounded,
                        label: 'Edit',
                        color: const Color(0xFF2563EB),
                        alignLeft: true,
                      ),
                      secondaryBackground: _SwipeBg(
                        icon: Icons.delete_outline_rounded,
                        label: 'Delete',
                        color: const Color(0xFFDC2626),
                        alignLeft: false,
                      ),
                      confirmDismiss: (direction) async {
                        if (direction == DismissDirection.startToEnd) {
                          context.push('/add-expense', extra: expense);
                          return false;
                        }
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Expense'),
                            content: const Text('Are you sure you want to delete this expense?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                            ],
                          ),
                        );
                        return confirm == true;
                      },
                      onDismissed: (_) async {
                        if (expense.id == null) return;
                        await ref.read(expenseRepositoryProvider).deleteExpense(expense.id!);
                        ref.invalidate(expensesProvider);
                        ref.invalidate(dashboardStatsProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Expense deleted')),
                          );
                        }
                      },
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          leading: CircleAvatar(
                            backgroundColor: visual.color.withOpacity(0.15),
                            child: Icon(visual.icon, color: visual.color),
                          ),
                          title: Text(
                            expense.merchantName?.isNotEmpty == true ? expense.merchantName! : (expense.categoryName ?? 'Expense'),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${expense.categoryName ?? 'Uncategorized'}  •  ${DateFormat('dd MMM yyyy').format(expense.transactionDate)}',
                          ),
                          trailing: Text(
                            'Rs ${expense.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
        loading: () => const _LoadingList(),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonExpense(),
        SizedBox(height: 10),
        _SkeletonExpense(),
        SizedBox(height: 10),
        _SkeletonExpense(),
      ],
    );
  }
}

class _SkeletonExpense extends StatelessWidget {
  const _SkeletonExpense();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _EmptyExpenseState extends StatelessWidget {
  const _EmptyExpenseState();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: const [
            Icon(Icons.receipt_long_outlined, size: 38, color: Color(0xFF9CA3AF)),
            SizedBox(height: 8),
            Text('No expenses yet', style: TextStyle(fontWeight: FontWeight.w700)),
            SizedBox(height: 4),
            Text('Tap + to add your first expense.', style: TextStyle(color: Color(0xFF6B7280))),
          ],
        ),
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool alignLeft;

  const _SwipeBg({
    required this.icon,
    required this.label,
    required this.color,
    required this.alignLeft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignLeft) ...[
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
          ],
          Icon(icon, color: Colors.white),
          if (alignLeft) ...[
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}

_CategoryVisual _categoryVisual(String category) {
  if (category.contains('food')) return const _CategoryVisual(Icons.restaurant_rounded, Color(0xFFF59E0B));
  if (category.contains('transport')) return const _CategoryVisual(Icons.directions_car_rounded, Color(0xFF3B82F6));
  if (category.contains('shopping')) return const _CategoryVisual(Icons.shopping_bag_rounded, Color(0xFF8B5CF6));
  if (category.contains('bill')) return const _CategoryVisual(Icons.receipt_rounded, Color(0xFFEF4444));
  return const _CategoryVisual(Icons.account_balance_wallet_rounded, Color(0xFF0F9D8A));
}

class _CategoryVisual {
  final IconData icon;
  final Color color;
  const _CategoryVisual(this.icon, this.color);
}
