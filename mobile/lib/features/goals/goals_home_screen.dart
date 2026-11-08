import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'best_choice_screen.dart';
import 'portfolio_screen.dart';
import 'your_choice_screen.dart';
import 'goals_provider.dart';

class GoalsHomeScreen extends ConsumerWidget {
  const GoalsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PortfolioScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(bestChoiceProvider);
          ref.invalidate(mutualFundsProvider);
          ref.invalidate(stocksProvider);
          ref.invalidate(goldProvider);
          ref.invalidate(fdRatesProvider);
          ref.invalidate(licPoliciesProvider);
          ref.invalidate(assetTypeProvider('government_bonds'));
          ref.invalidate(assetTypeProvider('index_funds'));
          ref.invalidate(assetTypeProvider('etfs'));
          ref.invalidate(goalsPortfolioProvider);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
          const Text(
            'Smart Investment',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 22),
          ),
          const SizedBox(height: 6),
          const Text(
            'Build your portfolio with guided recommendations.',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 14),
          _EntryCard(
            title: 'Best Choice',
            subtitle: 'AI-recommended investments based on your financial behavior',
            icon: Icons.auto_awesome,
            colors: const [Color(0xFF2C7A7B), Color(0xFF38B2AC)],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BestChoiceScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _EntryCard(
            title: 'Your Choice',
            subtitle: 'Explore investment categories and build your portfolio',
            icon: Icons.tune,
            colors: const [Color(0xFF1E3A8A), Color(0xFF2563EB)],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const YourChoiceScreen()),
              );
            },
          ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _EntryCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.white.withOpacity(0.12),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 10, offset: Offset(0, 5)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
