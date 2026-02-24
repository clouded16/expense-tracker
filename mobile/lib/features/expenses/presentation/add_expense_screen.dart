import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/expense_repository.dart';
import '../domain/expense.dart';
import 'package:mobile/features/expenses/presentation/expense_list_screen.dart'; 
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? existingExpense;

  const AddExpenseScreen({
    super.key,
    this.existingExpense,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController(); // Simple text input for now
  final _descController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit() async {
      if (_amountController.text.isEmpty ||
          _categoryController.text.isEmpty) return;

      setState(() => _isLoading = true);

      try {
        final isEdit = widget.existingExpense != null;

        final expense = Expense(
          id: widget.existingExpense?.id, // preserve original id
          amount: double.parse(_amountController.text),
          categoryName: _categoryController.text,
          merchantName: _descController.text.isNotEmpty
              ? _descController.text
              : null,
          sourceName: 'manual',
          transactionDate: DateTime.now(),
          createdAt: widget.existingExpense?.createdAt ?? DateTime.now(),
        );

        final repo = ref.read(expenseRepositoryProvider);

        if (isEdit) {
          await repo.updateExpense(expense);
        } else {
          await repo.createExpense(expense);
        }

        ref.invalidate(expensesProvider);
        ref.invalidate(dashboardStatsProvider);

        if (mounted) {
          _amountController.clear();
          _categoryController.clear();
          _descController.clear();
          context.go('/dashboard');
        }
      } 
        catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

  @override
  void initState() {
    super.initState();

    final expense = widget.existingExpense;

    if (expense != null) {
      _amountController.text = expense.amount.toString();
      _categoryController.text = expense.categoryName ?? '';
      _descController.text = expense.merchantName ?? '';
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existingExpense != null
              ? 'Edit Expense'
              : 'Add Expense',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Amount (₹)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(labelText: 'Category (e.g. Food)'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description (Optional)'),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading ? const CircularProgressIndicator() : const Text('Save Expense'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
