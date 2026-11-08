import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/auth/app_lock_service.dart';
import '../../core/db/database.dart';
import '../dashboard/data/budget_repository.dart';
import 'analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(budgetRepositoryProvider),
  );
});

class AnalyticsRepository {
  final AppDatabase _db;
  final BudgetRepository _budgets;

  AnalyticsRepository(this._db, this._budgets);

  Future<FinancialSummary> getFinancialSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final expenses = await (_db.select(_db.expenses)
          ..where((e) =>
              e.transactionDate.isBiggerOrEqualValue(monthStart) &
              e.transactionDate.isSmallerThanValue(monthEnd)))
        .get();

    final totalSpent = expenses.fold<double>(0, (a, e) => a + e.amount);
    final budget = await _budgets.getMonthlyBudget();
    final remaining = (budget - totalSpent).clamp(double.negativeInfinity, double.infinity);
    final saved = remaining > 0 ? remaining : 0.0;

    return FinancialSummary(
      monthName: DateFormat('MMMM yyyy').format(now),
      totalSpent: totalSpent,
      totalSaved: saved.toDouble(),
      budgetRemaining: remaining,
      monthlyBudget: budget,
    );
  }

  Future<List<MonthlyExpensePoint>> getMonthlyExpenses({int months = 6}) async {
    final now = DateTime.now();
    final cutoff = DateTime(now.year, now.month - (months - 1), 1);

    final expenses = await (_db.select(_db.expenses)
          ..where((e) => e.transactionDate.isBiggerOrEqualValue(cutoff)))
        .get();

    final buckets = <String, double>{};
    for (var i = 0; i < months; i++) {
      final m = DateTime(now.year, now.month - (months - 1 - i), 1);
      buckets[DateFormat('MMM yy').format(m)] = 0;
    }
    for (final e in expenses) {
      final key = DateFormat('MMM yy').format(e.transactionDate);
      buckets.update(key, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    return buckets.entries
        .map((e) => MonthlyExpensePoint(month: e.key, total: e.value))
        .toList();
  }

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final expenses = await (_db.select(_db.expenses)
          ..where((e) =>
              e.transactionDate.isBiggerOrEqualValue(monthStart) &
              e.transactionDate.isSmallerThanValue(monthEnd)))
        .get();

    final totals = <String, double>{};
    for (final e in expenses) {
      final key = (e.categoryName?.trim().isNotEmpty == true)
          ? e.categoryName!
          : 'Uncategorized';
      totals.update(key, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .map((e) => CategoryBreakdownItem(category: e.key, amount: e.value))
        .toList();
  }

  Future<List<SavingsTrendItem>> getSavingsTrend({int months = 6}) async {
    final now = DateTime.now();
    final out = <SavingsTrendItem>[];
    for (var i = months - 1; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final next = DateTime(m.year, m.month + 1, 1);

      final monthExpenses = await (_db.select(_db.expenses)
            ..where((e) =>
                e.transactionDate.isBiggerOrEqualValue(m) &
                e.transactionDate.isSmallerThanValue(next)))
          .get();
      final spent = monthExpenses.fold<double>(0, (a, e) => a + e.amount);
      final budget = await _budgets.getMonthlyBudget(forMonth: m);

      out.add(SavingsTrendItem(
        month: DateFormat('MMM yy').format(m),
        budget: budget,
        expense: spent,
        savings: (budget - spent).clamp(0, double.infinity).toDouble(),
      ));
    }
    return out;
  }

  Future<List<TopMerchantItem>> getTopMerchants({int limit = 5}) async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final expenses = await (_db.select(_db.expenses)
          ..where((e) =>
              e.transactionDate.isBiggerOrEqualValue(monthStart) &
              e.transactionDate.isSmallerThanValue(monthEnd) &
              e.merchantName.isNotNull()))
        .get();

    final totals = <String, double>{};
    for (final e in expenses) {
      final m = e.merchantName?.trim();
      if (m == null || m.isEmpty) continue;
      totals.update(m, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => TopMerchantItem(merchant: e.key, amount: e.value))
        .toList();
  }

  Future<AnalyticsAiInsights> getAiInsights() async {
    final summary = await getFinancialSummary();
    final breakdown = await getCategoryBreakdown();
    final trend = await getSavingsTrend(months: 3);

    final score = _healthScore(summary, trend);
    final insights = <String>[];

    if (summary.monthlyBudget == 0) {
      insights.add('Set a monthly budget on the dashboard to unlock spending guardrails.');
    } else if (summary.totalSpent > summary.monthlyBudget) {
      final over = summary.totalSpent - summary.monthlyBudget;
      insights.add('You are Rs ${over.toStringAsFixed(0)} over budget this month.');
    } else if (summary.budgetRemaining < summary.monthlyBudget * 0.2) {
      insights.add('Less than 20% of your budget remains. Slow down on discretionary spending.');
    } else {
      insights.add('You are pacing well — Rs ${summary.budgetRemaining.toStringAsFixed(0)} of your budget is unused.');
    }

    if (breakdown.isNotEmpty) {
      final top = breakdown.first;
      final share = summary.totalSpent == 0 ? 0 : (top.amount / summary.totalSpent) * 100;
      insights.add('${top.category} is your biggest category (${share.toStringAsFixed(0)}% of spend).');
    }

    if (trend.length >= 2) {
      final last = trend.last.expense;
      final prev = trend[trend.length - 2].expense;
      if (prev > 0) {
        final delta = ((last - prev) / prev) * 100;
        if (delta.abs() >= 10) {
          insights.add(delta > 0
              ? 'Spending up ${delta.toStringAsFixed(0)}% vs last month.'
              : 'Spending down ${delta.abs().toStringAsFixed(0)}% vs last month — nice.');
        }
      }
    }

    return AnalyticsAiInsights(financialHealthScore: score, insights: insights);
  }

  int _healthScore(FinancialSummary s, List<SavingsTrendItem> trend) {
    if (s.monthlyBudget <= 0) return 50;
    final usage = (s.totalSpent / s.monthlyBudget).clamp(0.0, 2.0);
    final budgetScore = ((1 - usage) * 60).clamp(-60, 60);

    final consistent = trend.where((t) => t.savings > 0).length;
    final consistencyScore = trend.isEmpty ? 0 : (consistent / trend.length) * 40;

    return (50 + budgetScore + consistencyScore).clamp(0, 100).round();
  }
}
