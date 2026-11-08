import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/goals_api_service.dart';
import 'goals_provider.dart';

class PortfolioScreen extends ConsumerWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(goalsPortfolioProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Portfolio')),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Failed to load portfolio: $error')),
        data: (summary) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(goalsPortfolioProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF143E75), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.pie_chart_outline_rounded, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Investment Portfolio',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total invested: Rs ${summary.totalInvestedAmount.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text('Expected yearly return: Rs ${summary.expectedYearlyReturn.toStringAsFixed(0)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (summary.allocationByType.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        height: 220,
                        child: PieChart(
                          PieChartData(
                            sections: summary.allocationByType.asMap().entries.map((entry) {
                              final amount = (entry.value['amount'] as num?)?.toDouble() ?? 0;
                              return PieChartSectionData(
                                value: amount,
                                title: amount.toStringAsFixed(0),
                                color: _colors[entry.key % _colors.length],
                                radius: 56,
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                if (summary.items.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(Icons.account_balance_wallet_outlined, size: 36, color: Color(0xFF9CA3AF)),
                          SizedBox(height: 10),
                          Text('No investments in portfolio yet'),
                        ],
                      ),
                    ),
                  )
                else
                  ...summary.items.map(
                    (item) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.assetName,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                  ),
                                ),
                                _RiskBadge(level: item.riskLevel ?? 'Unknown'),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                  onPressed: () => _deleteItem(context, ref, item.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('Invested amount: Rs ${item.investedAmount.toStringAsFixed(0)}'),
                            Text('Expected return: ${item.expectedReturn?.toStringAsFixed(2) ?? '-'}%'),
                            Text('Start date: ${DateFormat('dd MMM yyyy').format(item.startDate)}'),
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

  Future<void> _deleteItem(BuildContext context, WidgetRef ref, int itemId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Investment'),
        content: const Text('Remove this investment from portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(goalsApiServiceProvider).deletePortfolioItem(itemId);
      ref.invalidate(goalsPortfolioProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deleted from portfolio')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }
}

class _RiskBadge extends StatelessWidget {
  final String level;
  const _RiskBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final normalized = level.toLowerCase();
    Color color;
    if (normalized.contains('low')) {
      color = const Color(0xFF16A34A);
    } else if (normalized.contains('medium')) {
      color = const Color(0xFFF59E0B);
    } else {
      color = const Color(0xFFDC2626);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        level,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

const _colors = [
  Color(0xFF2E86AB),
  Color(0xFFF6A623),
  Color(0xFF45B97C),
  Color(0xFFE94F37),
  Color(0xFF4F6D7A),
];
