import 'package:flutter_riverpod/flutter_riverpod.dart';

final goalsApiServiceProvider = Provider<GoalsApiService>((ref) {
  return GoalsApiService();
});

class GoalsApiService {
  GoalsApiService();

  Future<List<Map<String, dynamic>>> fetchMutualFunds() async => const [];
  Future<List<Map<String, dynamic>>> fetchStocks() async => const [];
  Future<Map<String, dynamic>> fetchGoldPrice() async => const {};
  Future<List<Map<String, dynamic>>> fetchFDRates() async => const [];
  Future<List<Map<String, dynamic>>> fetchLICPolicies() async => const [];
  Future<List<Map<String, dynamic>>> fetchAssetType(String assetType) async =>
      const [];
  Future<Map<String, dynamic>> fetchBestChoice() async => const {};
  Future<void> addPortfolioItem(Map<String, dynamic> payload) async {}
  Future<Map<String, dynamic>> fetchPortfolio() async => const {};
  Future<void> deletePortfolioItem(int itemId) async {}
}
