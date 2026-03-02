import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/expense_repository.dart';
import '../domain/expense.dart';
import '../../dashboard/presentation/dashboard_screen.dart';

class ExpenseListScreen extends ConsumerStatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  ConsumerState<ExpenseListScreen> createState() =>
      _ExpenseListScreenState();
}

class _ExpenseListScreenState
    extends ConsumerState<ExpenseListScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // when app resumes, refresh expenses
      ref.invalidate(expensesProvider);
    }
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
        data: (expenses) {
          if (expenses.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(expensesProvider);
              },
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child:
                        Text("No expenses yet. Add one!"),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(expensesProvider);
            },
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: ListView.builder(
                controller: _scrollController,
                physics:
                    const AlwaysScrollableScrollPhysics(),
                itemCount: expenses.length,
                itemBuilder: (context, index) {
                  final expense = expenses[index];

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (expense.categoryName
                                    ?.isNotEmpty ??
                                false)
                            ? expense.categoryName![0]
                                .toUpperCase()
                            : '?',
                      ),
                    ),
                    title: Text(
                        expense.categoryName ??
                            'Uncategorized'),
                    subtitle:
                        Text(expense.merchantName ?? ''),
                    trailing: SizedBox(
                      width: 150,
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              '₹${expense.amount.toStringAsFixed(2)}',
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                                Icons.edit,
                                size: 18),
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(),
                            onPressed: () {
                              context.push(
                                '/add-expense',
                                extra: expense,
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                                Icons.delete,
                                size: 18),
                            padding:
                                EdgeInsets.zero,
                            constraints:
                                const BoxConstraints(),
                            onPressed: () async {
                              final confirm =
                                  await showDialog<
                                      bool>(
                                context: context,
                                builder: (context) =>
                                    AlertDialog(
                                  title: const Text(
                                      'Delete Expense'),
                                  content:
                                      const Text(
                                          'Are you sure you want to delete this expense?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                              context,
                                              false),
                                      child: const Text(
                                          'Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () =>
                                          Navigator.pop(
                                              context,
                                              true),
                                      child: const Text(
                                          'Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true &&
                                  expense.id != null) {
                                await ref
                                    .read(
                                        expenseRepositoryProvider)
                                    .deleteExpense(
                                        expense.id!);

                                ref.invalidate(
                                    expensesProvider);
                                ref.invalidate(
                                    dashboardStatsProvider);

                                if (mounted) {
                                  ScaffoldMessenger.of(
                                          context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Expense deleted'),
                                    ),
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
          );
        },
        loading: () =>
            const Center(
                child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Error: $err')),
      ),
    );
  }
}