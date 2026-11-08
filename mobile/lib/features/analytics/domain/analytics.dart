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
    final categoryList = (json['by_category'] ?? json['category_totals'] ?? const []) as List;
    final monthlyList = (json['monthly_trends'] ?? json['monthly_trend'] ?? const []) as List;
    final computedTotal = categoryList.fold<double>(
      0,
      (sum, item) => sum + (((item as Map<String, dynamic>)['amount'] as num?)?.toDouble() ?? 0),
    );

    return SpendSummary(
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? computedTotal,
      byCategory: categoryList
          .map((c) => CategorySpend.fromJson(c))
          .toList(),
      monthlyTrends: monthlyList
          .map((m) => MonthlySpend.fromJson(m))
          .toList(),
    );
  }
}
