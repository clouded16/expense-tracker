import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/api_client.dart';

import '../domain/receipt_ocr_result.dart';

final receiptOCRRepositoryProvider = Provider((ref) {
  return ReceiptOCRRepository(ref.watch(apiClientProvider));
});

class ReceiptOCRRepository {
  final ApiClient _client;

  ReceiptOCRRepository(this._client);

  Future<ReceiptOCRResult> scanReceipt(String imagePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imagePath),
    });

    final response = await _client.dio.post(
      '/ocr/scan-receipt',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    return ReceiptOCRResult.fromJson(response.data as Map<String, dynamic>);
  }
}
