import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class GoldScreen extends StatelessWidget {
  const GoldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Gold',
      categoryKey: 'gold',
      assetType: 'gold',
    );
  }
}
