import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ingestion/data/ingestion_repository.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  final IngestionLog ingestion;

  const ReceiptReviewScreen({
    super.key,
    required this.ingestion,
  });

  @override
  ConsumerState<ReceiptReviewScreen> createState() =>
      _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState
    extends ConsumerState<ReceiptReviewScreen> {
  late TextEditingController _merchantController;
  late TextEditingController _categoryController;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _merchantController =
        TextEditingController(text: widget.ingestion.parsedMerchant ?? '');

    _categoryController =
        TextEditingController(text: widget.ingestion.parsedCategory ?? '');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ingestionRepositoryProvider);

      await repo.approve(
        id: widget.ingestion.id,
        merchantName: _merchantController.text.trim(),
        categoryName: _categoryController.text.trim(),
      );

      ref.invalidate(ingestionReviewProvider);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _reject() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final repo = ref.read(ingestionRepositoryProvider);

      await repo.reject(widget.ingestion.id);

      ref.invalidate(ingestionReviewProvider);

      if (mounted) Navigator.pop(context, false);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ingestion = widget.ingestion;

    return Scaffold(
      appBar: AppBar(title: const Text('Review Receipt')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount: ₹${ingestion.parsedAmount?.toStringAsFixed(2) ?? '-'}',
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _merchantController,
                  decoration:
                      const InputDecoration(labelText: 'Merchant'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration:
                      const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Confidence: '),
                    Text(
                        ingestion.confidenceScore.toStringAsFixed(2)),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _loading ? null : _reject,
                      child: const Text('Reject'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _loading ? null : _approve,
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}