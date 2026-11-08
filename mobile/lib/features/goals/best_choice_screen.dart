import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'goals_provider.dart';

class BestChoiceScreen extends ConsumerWidget {
  const BestChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(bestChoiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Best Choice')),
      body: asyncData.when(
        loading: () => const _LoadingState(),
        error: (error, _) => Center(child: Text('Failed to load recommendations: $error')),
        data: (data) {
          final totalAllocation = data.suggestedAllocation.values.fold<num>(0, (a, b) => a + b);
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bestChoiceProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
              _GradientCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Financial Summary', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Monthly Income: Rs ${data.monthlyIncome.toStringAsFixed(0)}'),
                    Text('Monthly Expense: Rs ${data.monthlyExpense.toStringAsFixed(0)}'),
                    Text('Monthly Savings: Rs ${data.monthlySavings.toStringAsFixed(0)}'),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (data.suggestedAllocation.isNotEmpty)
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Suggested Allocation', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 42,
                              sections: data.suggestedAllocation.entries.toList().asMap().entries.map((entry) {
                                final index = entry.key;
                                final row = entry.value;
                                final value = row.value.toDouble();
                                final pct = totalAllocation == 0 ? 0.0 : (value / totalAllocation) * 100;
                                return PieChartSectionData(
                                  value: value,
                                  color: _colors[index % _colors.length],
                                  radius: 56,
                                  title: '${pct.toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        ...data.suggestedAllocation.entries.toList().asMap().entries.map((entry) {
                          final index = entry.key;
                          final row = entry.value;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _colors[index % _colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(child: Text(row.key.replaceAll('_', ' '))),
                                Text('${row.value}%'),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              const Text('Investment Recommendations', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              if (data.recommendations.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('No recommendations available for current financial data.'),
                  ),
                )
              else
                ...data.recommendations.map(
                  (r) => Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.assetName, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          Text('Risk: ${r.riskLevel}'),
                          if (r.expectedReturn != null)
                            Text('Expected Return: ${r.expectedReturn!.toStringAsFixed(2)}%'),
                          if (r.price != null) Text('Live Price: Rs ${r.price!.toStringAsFixed(2)}'),
                          Text('Recommended Monthly: Rs ${r.recommendedMonthlyAmount.toStringAsFixed(0)}'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _GradientCard extends StatelessWidget {
  final Widget child;
  const _GradientCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF103D6B), Color(0xFF1F6FB2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: child,
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonBox(height: 140),
        SizedBox(height: 14),
        _SkeletonBox(height: 260),
        SizedBox(height: 14),
        _SkeletonBox(height: 120),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  const _SkeletonBox({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

const _colors = [
  Color(0xFF2E86AB),
  Color(0xFF00A676),
  Color(0xFFF39C12),
  Color(0xFFE74C3C),
  Color(0xFF8E44AD),
];
