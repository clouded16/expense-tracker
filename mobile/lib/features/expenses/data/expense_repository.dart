import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock_service.dart';
import '../../../core/db/database.dart';
import '../domain/expense.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ExpenseRepository(db);
});

class ExpenseRepository {
  final AppDatabase _db;

  ExpenseRepository(this._db);

  Future<List<Expense>> getExpenses() async {
    final query = _db.select(_db.expenses)
      ..orderBy([
        (t) => OrderingTerm(expression: t.transactionDate, mode: OrderingMode.desc),
        (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc),
      ]);
    final rows = await query.get();
    return rows.map(_toDomain).toList();
  }

  Future<Expense> createExpense(Expense expense) async {
    final companion = ExpensesCompanion.insert(
      amount: expense.amount,
      categoryName: Value(expense.categoryName),
      merchantName: Value(expense.merchantName),
      sourceName: Value(expense.sourceName ?? 'manual'),
      transactionDate: expense.transactionDate,
      createdAt: Value(expense.createdAt),
      updatedAt: Value(DateTime.now()),
    );
    final id = await _db.into(_db.expenses).insert(companion);
    final merchant = expense.merchantName?.trim();
    if (merchant != null && merchant.isNotEmpty) {
      await _bumpMerchant(merchant, expense.categoryName);
    }
    return expense.copyWith(id: id);
  }

  Future<Expense> updateExpense(Expense expense) async {
    final id = expense.id;
    if (id == null) {
      throw ArgumentError('Cannot update expense without an id');
    }
    await (_db.update(_db.expenses)..where((t) => t.id.equals(id))).write(
      ExpensesCompanion(
        amount: Value(expense.amount),
        categoryName: Value(expense.categoryName),
        merchantName: Value(expense.merchantName),
        sourceName: Value(expense.sourceName ?? 'manual'),
        transactionDate: Value(expense.transactionDate),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return expense;
  }

  Future<void> deleteExpense(int id) async {
    if (id == 0) {
      throw ArgumentError('Invalid expense ID');
    }
    await (_db.delete(_db.expenses)..where((t) => t.id.equals(id))).go();
  }

  Future<void> _bumpMerchant(String name, String? category) async {
    final existing = await (_db.select(_db.merchants)
          ..where((m) => m.name.equals(name)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.merchants).insert(
            MerchantsCompanion.insert(
              name: name,
              defaultCategory: Value(category),
              usageCount: const Value(1),
            ),
            mode: InsertMode.insertOrIgnore,
          );
    } else {
      await (_db.update(_db.merchants)..where((m) => m.id.equals(existing.id)))
          .write(MerchantsCompanion(
        usageCount: Value(existing.usageCount + 1),
        defaultCategory: Value(category ?? existing.defaultCategory),
      ));
    }
  }

  Expense _toDomain(ExpenseRow row) => Expense(
        id: row.id,
        amount: row.amount,
        categoryName: row.categoryName,
        merchantName: row.merchantName,
        sourceName: row.sourceName,
        transactionDate: row.transactionDate,
        createdAt: row.createdAt,
      );
}
