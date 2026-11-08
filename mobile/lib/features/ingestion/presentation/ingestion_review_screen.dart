import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ingestion/data/ingestion_repository.dart';

class IngestionReviewScreen extends ConsumerWidget {
  const IngestionReviewScreen({super.key});

  Color _colorForConfidence(double score) {
    if (score >= 0.8) return Colors.green;
    if (score >= 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(ingestionReviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ingestion Review')),
      body: async.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No items need review'));
          }

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              final merchant = item.parsedMerchant ?? 'Unknown Merchant';
              final category = item.parsedCategory ?? 'Uncategorized';
              final amount = item.parsedAmount ?? 0.0;
              final confidence = item.confidenceScore;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  merchant,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$category - ₹${amount.toStringAsFixed(2)}',
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Created: ${item.createdAt.toLocal()}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: _colorForConfidence(confidence),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              confidence.toStringAsFixed(2),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () async {
                              final repo =
                                  ref.read(ingestionRepositoryProvider);
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                await repo.reject(item.id);
                                ref.invalidate(ingestionReviewProvider);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Rejected')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final repo =
                                  ref.read(ingestionRepositoryProvider);
                              final messenger =
                                  ScaffoldMessenger.of(context);
                              try {
                                await repo.approve(
                                  id: item.id,
                                  merchantName: item.parsedMerchant ?? 'Unknown Merchant',
                                  categoryName: item.parsedCategory ?? 'Uncategorized',
                                );
                                ref.invalidate(ingestionReviewProvider);
                                messenger.showSnackBar(
                                  const SnackBar(
                                      content: Text('Approved')),
                                );
                              } catch (e) {
                                messenger.showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            },
                            child: const Text('Approve'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $err'),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () =>
                    ref.refresh(ingestionReviewProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}