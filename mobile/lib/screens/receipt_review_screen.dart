import 'package:flutter/material.dart';

import '../services/api_service.dart';

class ReceiptReviewScreen extends StatefulWidget {
  final Map<String, dynamic> ingestion;
  const ReceiptReviewScreen({Key? key, required this.ingestion}) : super(key: key);

  @override
  State<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends State<ReceiptReviewScreen> {
  late TextEditingController _merchantController;
  late TextEditingController _categoryController;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _merchantController = TextEditingController(text: widget.ingestion['parsed_merchant']?.toString() ?? widget.ingestion['merchant']?.toString() ?? '');
    _categoryController = TextEditingController(text: widget.ingestion['parsed_category']?.toString() ?? widget.ingestion['category']?.toString() ?? '');
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _approve() async {
    setState(() { _loading = true; _error = null; });
    try {
      final id = widget.ingestion['id'] is int ? widget.ingestion['id'] as int : int.parse(widget.ingestion['id'].toString());
      await apiService.approveIngestion(id, merchantName: _merchantController.text.trim(), categoryName: _categoryController.text.trim());

      // pop and signal success so callers can refresh
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _reject() async {
    setState(() { _loading = true; _error = null; });
    try {
      final id = widget.ingestion['id'] is int ? widget.ingestion['id'] as int : int.parse(widget.ingestion['id'].toString());
      await apiService.rejectIngestion(id);
      Navigator.pop(context, false);
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
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
                Text('Amount: ${ingestion['parsed_amount'] ?? ingestion['amount'] ?? ''}', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 12),
                TextField(
                  controller: _merchantController,
                  decoration: const InputDecoration(labelText: 'Merchant'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _categoryController,
                  decoration: const InputDecoration(labelText: 'Category'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Confidence: '),
                    Text((ingestion['confidence_score'] ?? ingestion['confidence'] ?? '').toString()),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
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
                      child: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2,)) : const Text('Approve'),
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
