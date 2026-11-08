import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class BondScreen extends StatelessWidget {
  const BondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Government Bonds',
      categoryKey: 'government_bonds',
      assetType: 'government_bonds',
    );
  }
}
