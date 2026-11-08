import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../services/goals_api_service.dart';
import 'goals_provider.dart';

class InvestmentDetailScreen extends ConsumerWidget {
  final String title;
  final String categoryKey;
  final String assetType;

  const InvestmentDetailScreen({
    super.key,
    required this.title,
    required this.categoryKey,
    required this.assetType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(investmentDetailsProvider(categoryKey));
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: asyncData.when(
        loading: () => const _LoadingList(),
        error: (error, _) => Center(child: Text('Unable to load details: $error')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No live data available right now.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(investmentDetailsProvider(categoryKey));
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final row = rows[index];
                final name = (row['asset_name'] ??
                        row['name'] ??
                        row['scheme_name'] ??
                        row['policy_name'] ??
                        row['bank_name'] ??
                        row['symbol'] ??
                        'Unknown')
                    .toString();
                return Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        const SizedBox(height: 8),
                        _line('Risk Level', row['risk_level']),
                        _line('Expected Return', _asPercent(row['expected_return'] ?? row['one_year_return'])),
                        _line('Benefits', row['benefits']),
                        _line('Who Should Invest', row['who_should_invest']),
                        _line('Minimum Investment', _asCurrency(row['minimum_investment'] ?? row['minimum_deposit'])),
                        _line('Lock-in Period', row['lock_in_period']),
                        _line('Data Source', row['data_source'] ?? row['source']),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => _openAddDialog(context, ref, row, name),
                            child: const Text('Add to Portfolio'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _line(String label, dynamic value) {
    final v = (value == null || value.toString().trim().isEmpty) ? 'N/A' : value.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text('$label: $v'),
    );
  }

  String _asPercent(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    return n == null ? 'N/A' : '${n.toStringAsFixed(2)}%';
  }

  String _asCurrency(dynamic value) {
    final n = value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');
    return n == null ? 'N/A' : 'Rs ${n.toStringAsFixed(0)}';
  }

  Future<void> _openAddDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
    String name,
  ) async {
    final amountController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add to Portfolio'),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Invested Amount'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      }
      return;
    }

    final exp = row['expected_return'] ?? row['one_year_return'];
    final expectedReturn = exp is num ? exp.toDouble() : double.tryParse(exp?.toString() ?? '');

    try {
      await ref.read(goalsApiServiceProvider).addPortfolioItem({
        'asset_type': assetType,
        'asset_name': name,
        'invested_amount': amount,
        'expected_return': expectedReturn,
        'risk_level': row['risk_level']?.toString(),
        'start_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });

      ref.invalidate(goalsPortfolioProvider);
      ref.invalidate(investmentDetailsProvider(categoryKey));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to portfolio')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add to portfolio: $e')),
        );
      }
    }
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _SkeletonCard(),
        SizedBox(height: 10),
        _SkeletonCard(),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}
