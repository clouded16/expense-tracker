import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class IndexFundsScreen extends StatelessWidget {
  const IndexFundsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Index Funds',
      categoryKey: 'index_funds',
      assetType: 'index_funds',
    );
  }
}
