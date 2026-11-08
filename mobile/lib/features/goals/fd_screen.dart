import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class FDScreen extends StatelessWidget {
  const FDScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'Fixed Deposits',
      categoryKey: 'fd',
      assetType: 'fixed_deposit',
    );
  }
}
