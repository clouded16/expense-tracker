import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/app_lock_service.dart';
import '../../../core/db/database.dart';
import '../domain/analytics.dart';
import '../domain/insight.dart';

final analyticsLegacyRepositoryProvider =
    Provider<AnalyticsLegacyRepository>((ref) {
  return AnalyticsLegacyRepository(ref.watch(appDatabaseProvider));
});

final spendSummaryProvider = FutureProvider.autoDispose<SpendSummary>((ref) {
  return ref.watch(analyticsLegacyRepositoryProvider).getSpendSummary();
});

final insightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) {
  return ref.watch(analyticsLegacyRepositoryProvider).getInsights();
});

class AnalyticsLegacyRepository {
  final AppDatabase _db;

  AnalyticsLegacyRepository(this._db);

  Future<SpendSummary> getSpendSummary() async {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 1);

    final monthExpenses = await (_db.select(_db.expenses)
          ..where((e) =>
              e.transactionDate.isBiggerOrEqualValue(monthStart) &
              e.transactionDate.isSmallerThanValue(monthEnd)))
        .get();

    final totalSpend = monthExpenses.fold<double>(0, (a, e) => a + e.amount);

    final byCat = <String, double>{};
    for (final e in monthExpenses) {
      final key = (e.categoryName?.trim().isNotEmpty == true)
          ? e.categoryName!
          : 'Uncategorized';
      byCat.update(key, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    final categoryEntries = byCat.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final byCategory = categoryEntries
        .map((entry) => CategorySpend(
              category: entry.key,
              amount: entry.value,
              percentage: totalSpend == 0 ? 0 : (entry.value / totalSpend) * 100,
            ))
        .toList();

    final monthlyTrends = <MonthlySpend>[];
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      final mEnd = DateTime(m.year, m.month + 1, 1);
      final rows = await (_db.select(_db.expenses)
            ..where((e) =>
                e.transactionDate.isBiggerOrEqualValue(m) &
                e.transactionDate.isSmallerThanValue(mEnd)))
          .get();
      monthlyTrends.add(MonthlySpend(
        month: DateFormat('MMM yy').format(m),
        total: rows.fold<double>(0, (a, e) => a + e.amount),
      ));
    }

    return SpendSummary(
      totalSpend: totalSpend,
      byCategory: byCategory,
      monthlyTrends: monthlyTrends,
    );
  }

  Future<List<Insight>> getInsights() async {
    final summary = await getSpendSummary();
    final messages = <String>[];

    if (summary.byCategory.isNotEmpty) {
      final top = summary.byCategory.first;
      messages.add(
        '${top.category} accounts for ${top.percentage.toStringAsFixed(0)}% of spending this month.',
      );
    }
    if (summary.monthlyTrends.length >= 2) {
      final last = summary.monthlyTrends.last.total;
      final prev = summary.monthlyTrends[summary.monthlyTrends.length - 2].total;
      if (prev > 0) {
        final delta = ((last - prev) / prev) * 100;
        if (delta.abs() >= 10) {
          messages.add(delta > 0
              ? 'Spend rose ${delta.toStringAsFixed(0)}% vs last month.'
              : 'Spend dropped ${delta.abs().toStringAsFixed(0)}% vs last month.');
        }
      }
    }

    final now = DateTime.now().toIso8601String();
    return messages
        .asMap()
        .entries
        .map((e) => Insight.fromJson({
              'id': e.key + 1,
              'type': 'trend',
              'title': 'Insight ${e.key + 1}',
              'message': e.value,
              'metadata': null,
              'generated_at': now,
            }))
        .toList();
  }
}
