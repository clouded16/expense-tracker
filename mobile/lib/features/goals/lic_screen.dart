import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class LICScreen extends StatelessWidget {
  const LICScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'LIC Policies',
      categoryKey: 'lic',
      assetType: 'lic',
    );
  }
}
