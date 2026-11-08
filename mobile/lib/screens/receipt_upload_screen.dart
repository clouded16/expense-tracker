import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api_client.dart';
import '../features/ingestion/data/ingestion_repository.dart';
import 'receipt_review_screen.dart';

class ReceiptUploadScreen extends ConsumerStatefulWidget {
  const ReceiptUploadScreen({super.key});

  @override
  ConsumerState<ReceiptUploadScreen> createState() =>
      _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends ConsumerState<ReceiptUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _error = null);
    try {
      final XFile? picked =
          await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;
      await _upload(File(picked.path));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _upload(File file) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.uploadFile('/ingest/ocr', file);
      final json = response.data as Map<String, dynamic>;

      final status = (json['status'] ?? '').toString();
      final id = json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id']?.toString() ?? '');

      if (!mounted) return;

      if (status == 'needs_review' && id != null) {
        final approved = await Navigator.push<bool?>(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ReceiptReviewScreen(ingestion: IngestionLog.fromJson(json)),
          ),
        );
        if (approved == true && mounted) Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt parsed successfully')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Upload a photo of your receipt',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        onPressed: _loading
                            ? null
                            : () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        onPressed: _loading
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                      ),
                    ],
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const CircularProgressIndicator(),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
