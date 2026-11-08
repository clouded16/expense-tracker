import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bond_screen.dart';
import 'etfs_screen.dart';
import 'fd_screen.dart';
import 'gold_screen.dart';
import 'index_funds_screen.dart';
import 'lic_screen.dart';
import 'mutual_funds_screen.dart';
import 'stocks_screen.dart';
import 'goals_provider.dart';

class YourChoiceScreen extends ConsumerWidget {
  const YourChoiceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = <_ChoiceItem>[
      _ChoiceItem('Mutual Funds', 'Diversified professionally managed funds', Icons.account_balance, const MutualFundsScreen()),
      _ChoiceItem('LIC Policies', 'Insurance-linked long-term plans', Icons.shield_outlined, const LICScreen()),
      _ChoiceItem('Stocks', 'Direct equity investments with market upside', Icons.show_chart, const StocksScreen()),
      _ChoiceItem('Gold', 'Defensive diversification and inflation hedge', Icons.workspace_premium_outlined, const GoldScreen()),
      _ChoiceItem('Fixed Deposits', 'Stable interest rates with fixed tenure', Icons.savings_outlined, const FDScreen()),
      _ChoiceItem('Government Bonds', 'Sovereign fixed-income instruments', Icons.gavel_outlined, const BondScreen()),
      _ChoiceItem('Index Funds', 'Passive market-tracking funds', Icons.stacked_line_chart, const IndexFundsScreen()),
      _ChoiceItem('ETFs', 'Exchange-traded diversified instruments', Icons.candlestick_chart, const EtfsScreen()),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Your Choice')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(mutualFundsProvider);
          ref.invalidate(stocksProvider);
          ref.invalidate(goldProvider);
          ref.invalidate(fdRatesProvider);
          ref.invalidate(licPoliciesProvider);
          ref.invalidate(assetTypeProvider('government_bonds'));
          ref.invalidate(assetTypeProvider('index_funds'));
          ref.invalidate(assetTypeProvider('etfs'));
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE8EEF9),
                  child: Icon(item.icon, color: const Color(0xFF1E3A8A)),
                ),
                title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(item.description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.screen));
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChoiceItem {
  final String title;
  final String description;
  final IconData icon;
  final Widget screen;

  const _ChoiceItem(this.title, this.description, this.icon, this.screen);
}
