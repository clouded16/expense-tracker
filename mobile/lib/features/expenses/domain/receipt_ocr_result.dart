class ReceiptOCRResult {
  final String? merchant;
  final double? amount;
  final DateTime? date;
  final String? category;
  final String rawText;

  ReceiptOCRResult({
    required this.merchant,
    required this.amount,
    required this.date,
    required this.category,
    required this.rawText,
  });

  factory ReceiptOCRResult.fromJson(Map<String, dynamic> json) {
    return ReceiptOCRResult(
      merchant: json['merchant'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      date: json['date'] != null ? DateTime.tryParse(json['date'] as String) : null,
      category: json['category'] as String?,
      rawText: (json['raw_text'] as String?) ?? '',
    );
  }
}