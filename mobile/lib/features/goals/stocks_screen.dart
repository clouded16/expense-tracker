import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class StocksScreen extends StatelessWidget {
  const StocksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Stocks',
      categoryKey: 'stocks',
      assetType: 'stocks',
    );
  }
}
