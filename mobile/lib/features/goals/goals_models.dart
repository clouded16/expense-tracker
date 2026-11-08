class BestChoiceRecommendation {
  final int id;
  final String assetType;
  final String assetName;
  final String riskLevel;
  final double? expectedReturn;
  final double? price;
  final double recommendedMonthlyAmount;
  final double allocationPercent;

  const BestChoiceRecommendation({
    required this.id,
    required this.assetType,
    required this.assetName,
    required this.riskLevel,
    required this.expectedReturn,
    required this.price,
    required this.recommendedMonthlyAmount,
    required this.allocationPercent,
  });

  factory BestChoiceRecommendation.fromJson(Map<String, dynamic> json) {
    return BestChoiceRecommendation(
      id: (json['id'] as num?)?.toInt() ?? 0,
      assetType: (json['asset_type'] ?? '').toString(),
      assetName: (json['asset_name'] ?? '').toString(),
      riskLevel: (json['risk_level'] ?? '').toString(),
      expectedReturn: (json['expected_return'] as num?)?.toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      recommendedMonthlyAmount:
          (json['recommended_monthly_amount'] as num?)?.toDouble() ?? 0,
      allocationPercent: (json['allocation_percent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class BestChoiceResponse {
  final double monthlyIncome;
  final double monthlyExpense;
  final double monthlySavings;
  final Map<String, num> suggestedAllocation;
  final List<BestChoiceRecommendation> recommendations;

  const BestChoiceResponse({
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.monthlySavings,
    required this.suggestedAllocation,
    required this.recommendations,
  });

  factory BestChoiceResponse.fromJson(Map<String, dynamic> json) {
    return BestChoiceResponse(
      monthlyIncome: (json['monthly_income'] as num?)?.toDouble() ?? 0,
      monthlyExpense: (json['monthly_expense'] as num?)?.toDouble() ?? 0,
      monthlySavings: (json['monthly_savings'] as num?)?.toDouble() ?? 0,
      suggestedAllocation: ((json['suggested_allocation'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), value as num)),
      recommendations: ((json['investment_options'] as List?) ?? const [])
          .map((e) => BestChoiceRecommendation.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
    );
  }
}

class GoalsPortfolioItem {
  final int id;
  final String assetType;
  final String assetName;
  final double investedAmount;
  final double? expectedReturn;
  final String? riskLevel;
  final DateTime startDate;

  const GoalsPortfolioItem({
    required this.id,
    required this.assetType,
    required this.assetName,
    required this.investedAmount,
    required this.expectedReturn,
    required this.riskLevel,
    required this.startDate,
  });

  factory GoalsPortfolioItem.fromJson(Map<String, dynamic> json) {
    return GoalsPortfolioItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      assetType: (json['asset_type'] ?? '').toString(),
      assetName: (json['asset_name'] ?? '').toString(),
      investedAmount: (json['invested_amount'] as num?)?.toDouble() ?? 0,
      expectedReturn: (json['expected_return'] as num?)?.toDouble(),
      riskLevel: json['risk_level']?.toString(),
      startDate: DateTime.tryParse((json['start_date'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

class GoalsPortfolioSummary {
  final double totalInvestedAmount;
  final double expectedYearlyReturn;
  final List<GoalsPortfolioItem> items;
  final List<Map<String, dynamic>> allocationByType;

  const GoalsPortfolioSummary({
    required this.totalInvestedAmount,
    required this.expectedYearlyReturn,
    required this.items,
    required this.allocationByType,
  });

  factory GoalsPortfolioSummary.fromJson(Map<String, dynamic> json) {
    return GoalsPortfolioSummary(
      totalInvestedAmount: (json['total_invested_amount'] as num?)?.toDouble() ?? 0,
      expectedYearlyReturn: (json['expected_yearly_return'] as num?)?.toDouble() ?? 0,
      items: ((json['items'] as List?) ?? const [])
          .map((e) => GoalsPortfolioItem.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      allocationByType: ((json['allocation_by_type'] as List?) ?? const [])
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList(),
    );
  }
}
