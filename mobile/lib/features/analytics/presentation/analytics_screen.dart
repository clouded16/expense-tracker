import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../data/analytics_repository.dart';
import '../domain/analytics.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(spendSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Spending Analytics')),
      body: summaryAsync.when(
        data: (summary) => SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTotalSection(summary.totalSpend),
              const SizedBox(height: 32),
              const Text('Spending by Category',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildCategoryChart(summary.byCategory),
              const SizedBox(height: 32),
              const Text('Monthly Trends',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildTrendsChart(summary.monthlyTrends),
              const SizedBox(height: 32),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildTotalSection(double total) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Colors.blue, Colors.indigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text('Total Confirmed Spend',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text('₹${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart(List<CategorySpend> data) {
    if (data.isEmpty) return const Center(child: Text('No category data available'));

    return AspectRatio(
      aspectRatio: 1.3,
      child: PieChart(
        PieChartData(
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: data.map((item) {
            return PieChartSectionData(
              color: _getCategoryColor(item.category),
              value: item.amount,
              title: '${item.percentage.toInt()}%',
              radius: 60,
              titleStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              badgeWidget: _buildBadge(item.category),
              badgePositionPercentageOffset: 1.3,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendsChart(List<MonthlySpend> trends) {
    if (trends.isEmpty) return const Center(child: Text('No trend data available'));

    return AspectRatio(
      aspectRatio: 1.7,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: trends.map((e) => e.total).reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < trends.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(trends[index].month.split('-').last,
                          style: const TextStyle(fontSize: 10)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: trends.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.total,
                  color: Colors.blueAccent,
                  width: 16,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBadge(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(category,
          style: const TextStyle(color: Colors.white, fontSize: 10)),
    );
  }

  Color _getCategoryColor(String category) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];
    return colors[category.hashCode % colors.length];
  }
}
