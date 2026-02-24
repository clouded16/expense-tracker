class Expense {
  final int? id;
  final double amount;
  final String? categoryName;
  final String? merchantName;
  final String? sourceName;
  final DateTime transactionDate;
  final DateTime createdAt;

  Expense({
    this.id,
    required this.amount,
    this.categoryName,
    this.merchantName,
    this.sourceName,
    required this.transactionDate,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      amount: (json['amount'] as num).toDouble(),
      categoryName: json['category_name'],
      merchantName: json['merchant_name'],
      sourceName: json['source_name'],
      transactionDate: DateTime.parse(json['transaction_date']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'transaction_date':
          transactionDate.toIso8601String().split('T').first,
      'category_name': categoryName,
      'merchant_name': merchantName,
      'source_name': sourceName ?? 'manual',
    };
  }

  Expense copyWith({
    int? id,
    double? amount,
    String? categoryName,
    String? merchantName,
    String? sourceName,
    DateTime? transactionDate,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      categoryName: categoryName ?? this.categoryName,
      merchantName: merchantName ?? this.merchantName,
      sourceName: sourceName ?? this.sourceName,
      transactionDate: transactionDate ?? this.transactionDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}