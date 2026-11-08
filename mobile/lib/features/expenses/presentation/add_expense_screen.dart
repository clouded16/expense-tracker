import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/expenses/presentation/expense_list_screen.dart';

import '../data/expense_repository.dart';
import '../domain/expense.dart';

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
  final _categoryController = TextEditingController();
  final _descController = TextEditingController();
  bool _isLoading = false;

  static const _quickCategories = <Map<String, dynamic>>[
    {'name': 'Food', 'icon': Icons.restaurant_outlined},
    {'name': 'Transport', 'icon': Icons.directions_car_outlined},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_outlined},
    {'name': 'Bills', 'icon': Icons.receipt_long_outlined},
    {'name': 'Medical', 'icon': Icons.local_hospital_outlined},
    {'name': 'Other', 'icon': Icons.category_outlined},
  ];

  Future<void> _submit() async {
    if (_amountController.text.isEmpty || _categoryController.text.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isEdit = widget.existingExpense != null;

      final expense = Expense(
        id: widget.existingExpense?.id,
        amount: double.parse(_amountController.text),
        categoryName: _categoryController.text,
        merchantName: _descController.text.isNotEmpty ? _descController.text : null,
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final selectedCategory = _categoryController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingExpense != null ? 'Edit Expense' : 'Add Expense'),
        actions: [
          IconButton(
            tooltip: 'Scan receipt',
            onPressed: _isLoading ? null : () => context.push('/scan-receipt'),
            icon: const Icon(Icons.document_scanner_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _submit,
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_isLoading ? 'Saving...' : 'Save Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Expense Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _amountController,
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixText: 'Rs ',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _categoryController,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Merchant / Description (Optional)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Quick Category', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _quickCategories.map((item) {
                final name = item['name'] as String;
                final icon = item['icon'] as IconData;
                final selected = selectedCategory.toLowerCase() == name.toLowerCase();
                return ChoiceChip(
                  selected: selected,
                  showCheckmark: false,
                  avatar: Icon(icon, size: 18, color: selected ? Colors.white : const Color(0xFF4B5563)),
                  label: Text(name),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF111827),
                    fontWeight: FontWeight.w600,
                  ),
                  selectedColor: const Color(0xFF283593),
                  backgroundColor: Colors.white,
                  onSelected: (_) => setState(() => _categoryController.text = name),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
