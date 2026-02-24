import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_client.dart';
import '../domain/analytics.dart';
import '../domain/insight.dart';

final analyticsRepositoryProvider = Provider((ref) => AnalyticsRepository(ref.watch(apiClientProvider)));

final spendSummaryProvider = FutureProvider.autoDispose<SpendSummary>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getSpendSummary();
});

final insightsProvider = FutureProvider.autoDispose<List<Insight>>((ref) async {
  return ref.watch(analyticsRepositoryProvider).getInsights();
});

class AnalyticsRepository {
  final ApiClient _api;

  AnalyticsRepository(this._api);

  Future<SpendSummary> getSpendSummary() async {
    final response = await _api.get('/analytics/summary');
    return SpendSummary.fromJson(response.data);
  }

  Future<List<Insight>> getInsights() async {
    final response = await _api.get('/analytics/insights');
    return (response.data as List).map((i) => Insight.fromJson(i)).toList();
  }
}
