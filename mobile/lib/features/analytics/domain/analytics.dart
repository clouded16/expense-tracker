class CategorySpend {
  final String category;
  final double amount;
  final double percentage;

  CategorySpend({
    required this.category,
    required this.amount,
    required this.percentage,
  });

  factory CategorySpend.fromJson(Map<String, dynamic> json) {
    return CategorySpend(
      category: json['category'],
      amount: (json['amount'] as num).toDouble(),
      percentage: (json['percentage'] as num).toDouble(),
    );
  }
}

class MonthlySpend {
  final String month;
  final double total;

  MonthlySpend({
    required this.month,
    required this.total,
  });

  factory MonthlySpend.fromJson(Map<String, dynamic> json) {
    return MonthlySpend(
      month: json['month'],
      total: (json['total'] as num).toDouble(),
    );
  }
}

class SpendSummary {
  final double totalSpend;
  final List<CategorySpend> byCategory;
  final List<MonthlySpend> monthlyTrends;

  SpendSummary({
    required this.totalSpend,
    required this.byCategory,
    required this.monthlyTrends,
  });

  factory SpendSummary.fromJson(Map<String, dynamic> json) {
    return SpendSummary(
      totalSpend: (json['total_spend'] as num).toDouble(),
      byCategory: (json['by_category'] as List)
          .map((c) => CategorySpend.fromJson(c))
          .toList(),
      monthlyTrends: (json['monthly_trends'] as List)
          .map((m) => MonthlySpend.fromJson(m))
          .toList(),
    );
  }
}
