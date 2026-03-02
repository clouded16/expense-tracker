import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_service.dart';
import 'receipt_review_screen.dart';

class ReceiptUploadScreen extends StatefulWidget {
  const ReceiptUploadScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptUploadScreen> createState() => _ReceiptUploadScreenState();
}

class _ReceiptUploadScreenState extends State<ReceiptUploadScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _loading = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    setState(() { _error = null; });
    try {
      final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
      if (picked == null) return;

      final file = File(picked.path);
      await _upload(file);
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  Future<void> _upload(File file) async {
    setState(() { _loading = true; _error = null; });
    try {
      final json = await apiService.uploadReceipt(file);

      final status = (json['status'] ?? '').toString();
      final id = json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ;

      if (status == 'needs_review' && id != null) {
        if (!mounted) return;
        // navigate to review
        final refreshed = await Navigator.push<bool?>(context, MaterialPageRoute(
          builder: (_) => ReceiptReviewScreen(ingestion: json),
        ));

        // if review approved (caller returned true), pop with result to trigger refresh upstream
        if (refreshed == true) Navigator.pop(context, true);
      } else {
        // parsed successfully
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt parsed successfully')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Receipt')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Upload a photo of your receipt', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Scan Receipt'),
                            onPressed: _loading ? null : () => _pickImage(ImageSource.camera),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Gallery'),
                            onPressed: _loading ? null : () => _pickImage(ImageSource.gallery),
                          ),
                        ],
                      ),
                      if (_loading) ...[
                        const SizedBox(height: 12),
                        const CircularProgressIndicator(),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
