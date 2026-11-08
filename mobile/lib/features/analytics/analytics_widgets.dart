import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'analytics_models.dart';

class SummaryCard extends StatelessWidget {
  final FinancialSummary summary;

  const SummaryCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F4C81), Color(0xFF2E86DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Financial Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (summary.monthName.isNotEmpty)
              Text('Month: ${summary.monthName}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (summary.monthName.isNotEmpty) const SizedBox(height: 6),
            Text('Total Spent: Rs ${summary.totalSpent.toStringAsFixed(0)}'),
            Text('Total Saved: Rs ${summary.totalSaved.toStringAsFixed(0)}'),
            Text('Budget Remaining: Rs ${summary.budgetRemaining.toStringAsFixed(0)}'),
          ],
        ),
      ),
    );
  }
}

class MonthlyLineChartCard extends StatelessWidget {
  final List<MonthlyExpensePoint> points;

  const MonthlyLineChartCard({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyCard(message: 'No monthly expense data.');
    }
    final clipped = points.length > 12 ? points.sublist(points.length - 12) : points;
    final xLabelInterval = clipped.length > 8 ? 2 : 1;
    final maxY = points.fold<double>(0, (max, row) => math.max(max, row.total));
    final yInterval = _autoInterval(maxY == 0 ? 100 : maxY * 1.2);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Monthly Spending Trend', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxY == 0 ? 100 : maxY * 1.2,
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots
                          .map(
                            (spot) => LineTooltipItem(
                              'Rs ${spot.y.toStringAsFixed(0)}',
                              const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: yInterval,
                        reservedSize: 42,
                        getTitlesWidget: (value, _) =>
                            Text(_compactAmount(value), style: const TextStyle(fontSize: 11)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= clipped.length) return const SizedBox.shrink();
                          if (idx % xLabelInterval != 0 && idx != clipped.length - 1) {
                            return const SizedBox.shrink();
                          }
                          final label = clipped[idx].month.split(' ').first;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(label, style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: clipped.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.total)).toList(),
                      isCurved: true,
                      barWidth: 3,
                      color: const Color(0xFF2E86DE),
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2E86DE).withOpacity(0.25),
                            const Color(0xFF2E86DE).withOpacity(0.02),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryPieChartCard extends StatelessWidget {
  final List<CategoryBreakdownItem> items;

  const CategoryPieChartCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(message: 'No category data.');
    }
    final clipped = items.take(8).toList();
    final total = clipped.fold<double>(0, (a, b) => a + b.amount);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Category Breakdown', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: clipped.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    final pct = total == 0 ? 0.0 : (row.amount / total) * 100;
                    return PieChartSectionData(
                      value: row.amount,
                      radius: 60,
                      color: _palette[idx % _palette.length],
                      title: '${pct.toStringAsFixed(0)}%',
                      titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...clipped.asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              final pct = total == 0 ? 0.0 : (row.amount / total) * 100;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _palette[idx % _palette.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.category,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${pct.toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class SavingsBarChartCard extends StatelessWidget {
  final List<SavingsTrendItem> items;

  const SavingsBarChartCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(message: 'No savings trend data.');
    }
    final maxSavings = items.fold<double>(0, (m, row) => math.max(m, row.savings));
    final minSavings = items.fold<double>(0, (m, row) => math.min(m, row.savings));
    final computedMax = maxSavings <= 0 ? 100.0 : maxSavings * 1.15;
    final computedMin = minSavings >= 0 ? 0.0 : minSavings * 1.15;
    final yInterval = _autoInterval((computedMax - computedMin).abs());
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Savings Trend', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SizedBox(
              height: 230,
              child: BarChart(
                BarChartData(
                  minY: computedMin,
                  maxY: computedMax,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: yInterval,
                  ),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                        'Rs ${rod.toY.toStringAsFixed(0)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, _) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= items.length) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(items[idx].month.split(' ').first, style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        interval: yInterval,
                        getTitlesWidget: (value, _) => Text(
                          _compactAmount(value),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ),
                  barGroups: items.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final row = entry.value;
                    return BarChartGroupData(
                      x: idx,
                      barRods: [
                        BarChartRodData(
                          toY: row.savings,
                          width: 12,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          gradient: LinearGradient(
                            colors: row.savings >= 0
                                ? [const Color(0xFF00A676), const Color(0xFF0ECB81)]
                                : [const Color(0xFFE74C3C), const Color(0xFFF1948A)],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopMerchantsCard extends StatelessWidget {
  final List<TopMerchantItem> items;

  const TopMerchantsCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _EmptyCard(message: 'No top merchants data.');
    }
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Top Merchants', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ...items.take(5).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final row = entry.value;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(radius: 12, child: Text('${idx + 1}', style: const TextStyle(fontSize: 10))),
                title: Text(row.merchant, overflow: TextOverflow.ellipsis),
                trailing: Text('Rs ${row.amount.toStringAsFixed(0)}'),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class AiInsightsCard extends StatelessWidget {
  final AnalyticsAiInsights data;

  const AiInsightsCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFFF39C12)),
                const SizedBox(width: 8),
                Text(
                  'AI Insights - Score ${data.financialHealthScore}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...data.insights.map(
              (insight) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 18, color: Color(0xFFF39C12)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(insight)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      ),
    );
  }
}

String _compactAmount(double value) {
  final abs = value.abs();
  if (abs >= 10000000) return '${(value / 10000000).toStringAsFixed(1)}Cr';
  if (abs >= 100000) return '${(value / 100000).toStringAsFixed(1)}L';
  if (abs >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
  return value.toStringAsFixed(0);
}

double _autoInterval(double range) {
  if (range <= 0) return 25;
  if (range <= 200) return 25;
  if (range <= 1000) return 100;
  if (range <= 5000) return 500;
  if (range <= 20000) return 2000;
  if (range <= 50000) return 5000;
  if (range <= 200000) return 20000;
  return 50000;
}

const _palette = [
  Color(0xFF2E86AB),
  Color(0xFF00A676),
  Color(0xFFF39C12),
  Color(0xFFE74C3C),
  Color(0xFF8E44AD),
  Color(0xFF34495E),
];
