import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api_client.dart';

final ingestionRepositoryProvider = Provider((ref) {
  return IngestionRepository(ref.watch(apiClientProvider));
});

final ingestionReviewProvider =
    FutureProvider.autoDispose<List<IngestionLog>>((ref) async {
  final repo = ref.watch(ingestionRepositoryProvider);
  return repo.getNeedsReview();
});

class IngestionRepository {
  final ApiClient _client;

  IngestionRepository(this._client);

  Future<List<IngestionLog>> getNeedsReview() async {
    final response = await _client.get('/ingestion?status=needs_review');

    return (response.data as List)
        .map((e) => IngestionLog.fromJson(e))
        .toList();
  }

  Future<void> approve(int id) async {
    await _client.dio.patch('/ingestion/$id/approve');
  }

  Future<void> reject(int id) async {
    await _client.dio.patch('/ingestion/$id/reject');
  }
}

class IngestionLog {
  final int id;
  final double parsedAmount;
  final String parsedCategory;
  final String parsedMerchant;
  final double confidenceScore;
  final DateTime createdAt;

  IngestionLog({
    required this.id,
    required this.parsedAmount,
    required this.parsedCategory,
    required this.parsedMerchant,
    required this.confidenceScore,
    required this.createdAt,
  });

  factory IngestionLog.fromJson(Map<String, dynamic> json) {
    return IngestionLog(
      id: json['id'] as int,
      parsedAmount: (json['parsed_amount'] is num)
          ? (json['parsed_amount'] as num).toDouble()
          : double.tryParse(json['parsed_amount'].toString()) ?? 0.0,
      parsedCategory: json['parsed_category']?.toString() ?? '',
      parsedMerchant: json['parsed_merchant']?.toString() ?? '',
      confidenceScore: (json['confidence_score'] is num)
          ? (json['confidence_score'] as num).toDouble()
          : double.tryParse(json['confidence_score']?.toString() ?? '0') ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
