import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'analytics_provider.dart';
import 'analytics_widgets.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(financialSummaryProvider);
    final monthlyAsync = ref.watch(monthlyExpensesProvider);
    final categoryAsync = ref.watch(categoryBreakdownProvider);
    final savingsAsync = ref.watch(savingsTrendProvider);
    final merchantsAsync = ref.watch(topMerchantsProvider);
    final insightsAsync = ref.watch(analyticsAiInsightsProvider);

    final hasError = summaryAsync.hasError ||
        monthlyAsync.hasError ||
        categoryAsync.hasError ||
        savingsAsync.hasError ||
        merchantsAsync.hasError ||
        insightsAsync.hasError;

    final isLoading = summaryAsync.isLoading ||
        monthlyAsync.isLoading ||
        categoryAsync.isLoading ||
        savingsAsync.isLoading ||
        merchantsAsync.isLoading ||
        insightsAsync.isLoading;

    Future<void> refreshAll() async {
      ref.invalidate(financialSummaryProvider);
      ref.invalidate(monthlyExpensesProvider);
      ref.invalidate(categoryBreakdownProvider);
      ref.invalidate(savingsTrendProvider);
      ref.invalidate(topMerchantsProvider);
      ref.invalidate(analyticsAiInsightsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 14),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFE0E7FF),
              child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF283593)),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: refreshAll,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (hasError)
              _ErrorBanner(
                message: 'Some analytics sections failed to load. Pull down to retry.',
                onRetry: refreshAll,
              ),
            if (isLoading && !summaryAsync.hasValue)
              const _LoadingBlock(height: 120)
            else
              summaryAsync.when(
                data: (data) => SummaryCard(summary: data),
                loading: () => const _LoadingBlock(height: 120),
                error: (_, __) => const _EmptyCard(message: 'Financial summary unavailable.'),
              ),
            const SizedBox(height: 12),
            monthlyAsync.when(
              data: (data) => MonthlyLineChartCard(points: data),
              loading: () => const _LoadingBlock(height: 280),
              error: (_, __) => const _EmptyCard(message: 'Monthly spending trend unavailable.'),
            ),
            const SizedBox(height: 12),
            categoryAsync.when(
              data: (data) => CategoryPieChartCard(items: data),
              loading: () => const _LoadingBlock(height: 260),
              error: (_, __) => const _EmptyCard(message: 'Category breakdown unavailable.'),
            ),
            const SizedBox(height: 12),
            savingsAsync.when(
              data: (data) => SavingsBarChartCard(items: data),
              loading: () => const _LoadingBlock(height: 270),
              error: (_, __) => const _EmptyCard(message: 'Savings trend unavailable.'),
            ),
            const SizedBox(height: 12),
            merchantsAsync.when(
              data: (data) => TopMerchantsCard(items: data),
              loading: () => const _LoadingBlock(height: 180),
              error: (_, __) => const _EmptyCard(message: 'Top merchants unavailable.'),
            ),
            const SizedBox(height: 12),
            insightsAsync.when(
              data: (data) => AiInsightsCard(data: data),
              loading: () => const _LoadingBlock(height: 180),
              error: (_, __) => const _EmptyCard(message: 'AI insights unavailable.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  final double height;

  const _LoadingBlock({required this.height});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, opacity, _) {
        return Opacity(
          opacity: opacity,
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
        );
      },
      onEnd: () {},
      child: const SizedBox.shrink(),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;

  const _EmptyCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.inbox_outlined, color: Color(0xFF9CA3AF)),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF5C88D)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFC26B00)),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
