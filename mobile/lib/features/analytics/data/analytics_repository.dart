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
    final response = await _api.get('/analytics/summary');
    final payload = response.data as Map<String, dynamic>;
    final rawInsights = (payload['insights'] as List?) ?? const [];
    final now = DateTime.now().toIso8601String();

    return rawInsights
        .asMap()
        .entries
        .map((entry) => Insight.fromJson({
              'id': entry.key + 1,
              'type': 'trend',
              'title': 'Insight ${entry.key + 1}',
              'message': entry.value.toString(),
              'metadata': null,
              'generated_at': now,
            }))
        .toList();
  }
}
