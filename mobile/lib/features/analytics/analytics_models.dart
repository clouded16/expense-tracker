class MonthlyExpensePoint {
  final String month;
  final double total;

  const MonthlyExpensePoint({required this.month, required this.total});

  factory MonthlyExpensePoint.fromJson(Map<String, dynamic> json) {
    return MonthlyExpensePoint(
      month: (json['month'] ?? '').toString(),
      total: (json['total'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CategoryBreakdownItem {
  final String category;
  final double amount;

  const CategoryBreakdownItem({required this.category, required this.amount});

  factory CategoryBreakdownItem.fromJson(Map<String, dynamic> json) {
    return CategoryBreakdownItem(
      category: (json['category'] ?? 'Uncategorized').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SavingsTrendItem {
  final String month;
  final double budget;
  final double expense;
  final double savings;

  const SavingsTrendItem({
    required this.month,
    required this.budget,
    required this.expense,
    required this.savings,
  });

  factory SavingsTrendItem.fromJson(Map<String, dynamic> json) {
    return SavingsTrendItem(
      month: (json['month'] ?? '').toString(),
      budget: (json['budget'] as num?)?.toDouble() ?? 0,
      expense: (json['expense'] as num?)?.toDouble() ?? 0,
      savings: (json['savings'] as num?)?.toDouble() ?? 0,
    );
  }
}

class TopMerchantItem {
  final String merchant;
  final double amount;

  const TopMerchantItem({required this.merchant, required this.amount});

  factory TopMerchantItem.fromJson(Map<String, dynamic> json) {
    return TopMerchantItem(
      merchant: (json['merchant'] ?? 'Unknown merchant').toString(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AnalyticsAiInsights {
  final int financialHealthScore;
  final List<String> insights;

  const AnalyticsAiInsights({
    required this.financialHealthScore,
    required this.insights,
  });

  factory AnalyticsAiInsights.fromJson(Map<String, dynamic> json) {
    return AnalyticsAiInsights(
      financialHealthScore: (json['financial_health_score'] as num?)?.toInt() ?? 0,
      insights: ((json['insights'] as List?) ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

class FinancialSummary {
  final String monthName;
  final double totalSpent;
  final double totalSaved;
  final double budgetRemaining;
  final double monthlyBudget;

  const FinancialSummary({
    required this.monthName,
    required this.totalSpent,
    required this.totalSaved,
    required this.budgetRemaining,
    required this.monthlyBudget,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      monthName: (json['month_name'] ?? '').toString(),
      totalSpent: (json['total_spent'] as num?)?.toDouble() ?? 0,
      totalSaved: (json['total_saved'] as num?)?.toDouble() ?? 0,
      budgetRemaining: (json['budget_remaining'] as num?)?.toDouble() ?? 0,
      monthlyBudget: (json['monthly_budget'] as num?)?.toDouble() ?? 0,
    );
  }
}
