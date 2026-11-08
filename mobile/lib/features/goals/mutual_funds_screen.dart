import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class MutualFundsScreen extends StatelessWidget {
  const MutualFundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Mutual Funds',
      categoryKey: 'mutual_funds',
      assetType: 'mutual_funds',
    );
  }
}
