import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/app_lock_service.dart';
import '../../../core/db/database.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BudgetRepository(db);
});

class BudgetRepository {
  final AppDatabase _db;

  BudgetRepository(this._db);

  Future<double> getMonthlyBudget({DateTime? forMonth}) async {
    final m = forMonth ?? DateTime.now();
    final row = await (_db.select(_db.budgets)
          ..where((b) =>
              b.year.equals(m.year) &
              b.month.equals(m.month) &
              b.categoryName.isNull()))
        .getSingleOrNull();
    if (row != null) return row.monthlyAmount;

    final fallback = await (_db.select(_db.budgets)
          ..where((b) => b.categoryName.isNull())
          ..orderBy([
            (b) => OrderingTerm(expression: b.updatedAt, mode: OrderingMode.desc),
          ])
          ..limit(1))
        .getSingleOrNull();
    return fallback?.monthlyAmount ?? 0.0;
  }

  Future<void> setMonthlyBudget(double amount, {DateTime? forMonth}) async {
    final m = forMonth ?? DateTime.now();
    final existing = await (_db.select(_db.budgets)
          ..where((b) =>
              b.year.equals(m.year) &
              b.month.equals(m.month) &
              b.categoryName.isNull()))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.budgets).insert(
            BudgetsCompanion.insert(
              monthlyAmount: amount,
              year: m.year,
              month: m.month,
              updatedAt: Value(DateTime.now()),
            ),
          );
    } else {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(
        monthlyAmount: Value(amount),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  Future<Map<String, double>> getCategoryBudgets({DateTime? forMonth}) async {
    final m = forMonth ?? DateTime.now();
    final rows = await (_db.select(_db.budgets)
          ..where((b) =>
              b.year.equals(m.year) &
              b.month.equals(m.month) &
              b.categoryName.isNotNull()))
        .get();
    return {
      for (final r in rows)
        if (r.categoryName != null) r.categoryName!: r.monthlyAmount,
    };
  }
}
