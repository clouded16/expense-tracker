import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'analytics_models.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>((ref) {
  return AnalyticsRepository(ref.watch(apiClientProvider));
});

class AnalyticsRepository {
  final ApiClient _api;

  AnalyticsRepository(this._api);

  Future<FinancialSummary> getFinancialSummary() async {
    final response = await _api.get('/api/analytics/summary');
    final payload = (response.data as Map).cast<String, dynamic>();
    return FinancialSummary.fromJson(
      ((payload['financial_summary'] as Map?) ?? const {}).cast<String, dynamic>(),
    );
  }

  Future<List<MonthlyExpensePoint>> getMonthlyExpenses() async {
    final response = await _api.get('/api/analytics/monthly-expenses');
    return ((response.data as List?) ?? const [])
        .map((e) => MonthlyExpensePoint.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<CategoryBreakdownItem>> getCategoryBreakdown() async {
    final response = await _api.get('/api/analytics/category-breakdown');
    return ((response.data as List?) ?? const [])
        .map((e) => CategoryBreakdownItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<SavingsTrendItem>> getSavingsTrend() async {
    final response = await _api.get('/api/analytics/savings-trend');
    return ((response.data as List?) ?? const [])
        .map((e) => SavingsTrendItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<List<TopMerchantItem>> getTopMerchants() async {
    final response = await _api.get('/api/analytics/top-merchants');
    return ((response.data as List?) ?? const [])
        .map((e) => TopMerchantItem.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<AnalyticsAiInsights> getAiInsights() async {
    final response = await _api.get('/api/analytics/ai-insights');
    return AnalyticsAiInsights.fromJson((response.data as Map).cast<String, dynamic>());
  }
}
