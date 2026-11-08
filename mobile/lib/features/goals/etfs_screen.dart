import 'package:flutter/material.dart';

import 'investment_detail_screen.dart';

class EtfsScreen extends StatelessWidget {
  const EtfsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InvestmentDetailScreen(
      title: 'ETFs',
      categoryKey: 'etfs',
      assetType: 'etfs',
    );
  }
}
