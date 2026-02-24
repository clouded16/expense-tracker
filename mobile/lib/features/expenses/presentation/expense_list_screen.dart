import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import '../../dashboard/presentation/dashboard_screen.dart';


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
        title: const Text('My Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-expense'),
          ),
        ],
      ),
      body: expensesAsync.when(
        data: (expenses) => expenses.isEmpty 
          ? RefreshIndicator(
              onRefresh: () async => ref.refresh(expensesProvider),
              child: ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(child: Text("No expenses yet. Add one!")),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => ref.refresh(expensesProvider),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                thickness: 8.0,
                radius: const Radius.circular(8),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  itemCount: expenses.length,
                  itemBuilder: (context, index) {
                    final expense = expenses[index];

                    final category = expense.categoryName ?? 'Uncategorized';
                    final merchant = expense.merchantName ?? '';

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (expense.categoryName?.isNotEmpty ?? false)
                              ? expense.categoryName![0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(expense.categoryName ?? 'Uncategorized'),
                      subtitle: Text(expense.merchantName ?? ''),
                      trailing: SizedBox(
                        width: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                '₹${expense.amount.toStringAsFixed(2)}',
                                textAlign: TextAlign.end,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                context.push(
                                  '/add-expense',
                                  extra: expense,
                                );
                              },
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Expense'),
                                    content: const Text(
                                        'Are you sure you want to delete this expense?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true && expense.id != null) {
                                  await ref
                                      .read(expenseRepositoryProvider)
                                      .deleteExpense(expense.id!);

                                  ref.invalidate(expensesProvider);
                                  ref.invalidate(dashboardStatsProvider);

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Expense deleted')),
                                    );
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
