import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/features/dashboard/presentation/dashboard_screen.dart';
import 'package:mobile/features/expenses/data/expense_repository.dart';
import 'package:mobile/features/expenses/data/receipt_ocr_repository.dart';
import 'package:mobile/features/expenses/presentation/expense_list_screen.dart';

import '../domain/expense.dart';

class ScanReceiptScreen extends ConsumerStatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  ConsumerState<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends ConsumerState<ScanReceiptScreen> {
  final _merchantController = TextEditingController();
  final _amountController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isOcrLoading = false;
  bool _isSaving = false;
  String? _imagePath;
  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Other';

  static const List<String> _categories = [
    'Food',
    'Groceries',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Medical',
    'Fuel',
    'Travel',
    'Other',
  ];

  @override
  void dispose() {
    _merchantController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    setState(() {
      _imagePath = picked.path;
    });

    await _processOCR(picked.path);
  }

  Future<void> _processOCR(String path) async {
    setState(() => _isOcrLoading = true);
    try {
      final result = await ref.read(receiptOCRRepositoryProvider).scanReceipt(path);
      if (!mounted) return;

      setState(() {
        _merchantController.text = result.merchant ?? '';
        _amountController.text = result.amount?.toStringAsFixed(2) ?? '';
        _selectedDate = result.date ?? DateTime.now();
        if (result.category != null && _categories.contains(result.category)) {
          _selectedCategory = result.category!;
        } else {
          _selectedCategory = 'Other';
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? 'OCR request failed')
          : (e.message ?? 'OCR request failed');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isOcrLoading = false);
    }
    
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final expense = Expense(
        amount: amount,
        categoryName: _selectedCategory,
        merchantName: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        sourceName: 'manual',
        transactionDate: _selectedDate,
        createdAt: DateTime.now(),
      );

      await ref.read(expenseRepositoryProvider).createExpense(expense);
      ref.invalidate(expensesProvider);
      ref.invalidate(dashboardStatsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense saved')),
      );
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      final detail = e.response?.data is Map<String, dynamic>
          ? (e.response?.data['detail']?.toString() ?? 'Failed to save expense')
          : (e.message ?? 'Failed to save expense');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save expense: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = _isOcrLoading || _isSaving;

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_imagePath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_imagePath!),
                  height: 220,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('No image selected'),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isOcrLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              TextField(
                controller: _merchantController,
                decoration: const InputDecoration(
                  labelText: 'Merchant Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Total Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: isBusy ? null : _pickDate,
                child: Text('Date: ${_selectedDate.toIso8601String().split('T').first}'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                items: _categories
                    .map(
                      (category) => DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: isBusy
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: isBusy ? null : _saveExpense,
                  child: _isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Save Expense'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
