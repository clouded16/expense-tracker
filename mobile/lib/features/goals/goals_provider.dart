import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/goals_api_service.dart';
import 'goals_models.dart';

final bestChoiceProvider = FutureProvider<BestChoiceResponse>((ref) async {
  final payload = await ref.watch(goalsApiServiceProvider).fetchBestChoice();
  return BestChoiceResponse.fromJson(payload);
});

final mutualFundsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(goalsApiServiceProvider).fetchMutualFunds();
});

final stocksProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(goalsApiServiceProvider).fetchStocks();
});

final goldProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return ref.watch(goalsApiServiceProvider).fetchGoldPrice();
});

final fdRatesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(goalsApiServiceProvider).fetchFDRates();
});

final licPoliciesProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return ref.watch(goalsApiServiceProvider).fetchLICPolicies();
});

final assetTypeProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, assetType) async {
  return ref.watch(goalsApiServiceProvider).fetchAssetType(assetType);
});

final goalsPortfolioProvider = FutureProvider<GoalsPortfolioSummary>((ref) async {
  final payload = await ref.watch(goalsApiServiceProvider).fetchPortfolio();
  return GoalsPortfolioSummary.fromJson(payload);
});

final investmentDetailsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, category) async {
  final api = ref.watch(goalsApiServiceProvider);
  switch (category) {
    case 'mutual_funds':
      return api.fetchMutualFunds();
    case 'stocks':
      return api.fetchStocks();
    case 'gold':
      final gold = await api.fetchGoldPrice();
      return [gold];
    case 'fd':
      return api.fetchFDRates();
    case 'lic':
      return api.fetchLICPolicies();
    default:
      return api.fetchAssetType(category);
  }
});
