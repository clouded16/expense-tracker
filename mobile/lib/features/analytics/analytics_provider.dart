import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_models.dart';
import 'analytics_repository.dart';

final financialSummaryProvider = FutureProvider<FinancialSummary>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getFinancialSummary();
});

final monthlyExpensesProvider = FutureProvider<List<MonthlyExpensePoint>>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getMonthlyExpenses();
});

final categoryBreakdownProvider = FutureProvider<List<CategoryBreakdownItem>>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getCategoryBreakdown();
});

final savingsTrendProvider = FutureProvider<List<SavingsTrendItem>>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getSavingsTrend();
});

final topMerchantsProvider = FutureProvider<List<TopMerchantItem>>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getTopMerchants();
});

final analyticsAiInsightsProvider = FutureProvider<AnalyticsAiInsights>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getAiInsights();
});
