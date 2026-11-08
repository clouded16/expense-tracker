import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';

final goalsApiServiceProvider = Provider<GoalsApiService>((ref) {
  return GoalsApiService(ref.watch(apiClientProvider));
});

class GoalsApiService {
  final ApiClient _api;

  GoalsApiService(this._api);

  Future<List<Map<String, dynamic>>> fetchMutualFunds() async {
    final response = await _api.get('/api/goals/mutual-funds');
    return ((response.data['data'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchStocks() async {
    final response = await _api.get('/api/goals/stocks?limit=50');
    return ((response.data['data'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> fetchGoldPrice() async {
    final response = await _api.get('/api/goals/gold');
    return ((response.data['data'] as Map?) ?? const {}).cast<String, dynamic>();
  }

  Future<List<Map<String, dynamic>>> fetchFDRates() async {
    final response = await _api.get('/api/goals/fd-rates');
    return ((response.data['data'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchLICPolicies() async {
    final response = await _api.get('/api/goals/lic-policies');
    return ((response.data['data'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAssetType(String assetType) async {
    final response = await _api.get('/api/goals/assets/$assetType');
    return ((response.data['data'] as List?) ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
  }

  Future<Map<String, dynamic>> fetchBestChoice() async {
    final response = await _api.get('/api/goals/best-choice');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<void> addPortfolioItem(Map<String, dynamic> payload) async {
    await _api.post('/api/goals/portfolio/add', payload);
  }

  Future<Map<String, dynamic>> fetchPortfolio() async {
    final response = await _api.get('/api/goals/portfolio');
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<void> deletePortfolioItem(int itemId) async {
    await _api.delete('/api/goals/portfolio/$itemId');
  }
}
