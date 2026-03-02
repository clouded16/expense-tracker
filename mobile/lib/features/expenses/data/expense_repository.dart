import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';
import '../domain/expense.dart';
import '../../auth/application/auth_controller.dart';

/// Repository Provider
final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(apiClientProvider));
});

/// 🔥 Expenses Future Provider 
final expensesProvider = FutureProvider<List<Expense>>((ref) async {
  final authStatus = ref.watch(authControllerProvider);
  if (authStatus != AuthStatus.authenticated) {
    return [];
  }
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.getExpenses();
});

class ExpenseRepository {
  final ApiClient _client;

  ExpenseRepository(this._client);

  Future<List<Expense>> getExpenses() async {
    final response = await _client.get('/expenses');
    return (response.data as List)
        .map((e) => Expense.fromJson(e))
        .toList();
  }

  Future<Expense> createExpense(Expense expense) async {
    final response = await _client.post('/expenses', expense.toJson());
    return Expense.fromJson(response.data);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final response =
        await _client.put('/expenses/${expense.id}', expense.toJson());
    return Expense.fromJson(response.data);
  }

  Future<void> deleteExpense(int id) async {
    if (id == 0) {
      throw Exception("Invalid expense ID");
    }

    await _client.delete('/expenses/$id');
  }
}