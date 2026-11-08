import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../domain/receipt_ocr_result.dart';

final receiptOCRRepositoryProvider = Provider((ref) {
  return ReceiptOCRRepository();
});

class ReceiptOCRRepository {
  Future<ReceiptOCRResult> scanReceipt(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(imagePath);
      final recognized = await recognizer.processImage(input);
      return _parse(recognized.text);
    } finally {
      await recognizer.close();
    }
  }

  ReceiptOCRResult _parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final amount = _extractAmount(lines);
    final date = _extractDate(rawText);
    final merchant = _extractMerchant(lines);
    final category = _guessCategory(rawText.toLowerCase(), merchant);

    return ReceiptOCRResult(
      merchant: merchant,
      amount: amount,
      date: date,
      category: category,
      rawText: rawText,
    );
  }

  double? _extractAmount(List<String> lines) {
    final totalRegex = RegExp(
      r'(?:total|grand\s*total|amount\s*due|amt|balance)\s*[:\-]?\s*(?:rs\.?|inr|₹)?\s*([0-9]+(?:[.,][0-9]{1,2})?)',
      caseSensitive: false,
    );
    for (final line in lines.reversed) {
      final m = totalRegex.firstMatch(line);
      if (m != null) {
        return double.tryParse(m.group(1)!.replaceAll(',', ''));
      }
    }
    final numberRegex = RegExp(r'(?:rs\.?|inr|₹)\s*([0-9]+(?:[.,][0-9]{1,2})?)',
        caseSensitive: false);
    final allMatches = <double>[];
    for (final line in lines) {
      for (final m in numberRegex.allMatches(line)) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', ''));
        if (v != null) allMatches.add(v);
      }
    }
    if (allMatches.isEmpty) return null;
    return allMatches.reduce((a, b) => a > b ? a : b);
  }

  DateTime? _extractDate(String text) {
    final candidates = <RegExp>[
      RegExp(r'\b(\d{2})[\/\-](\d{2})[\/\-](\d{4})\b'),
      RegExp(r'\b(\d{4})[\/\-](\d{2})[\/\-](\d{2})\b'),
      RegExp(r'\b(\d{2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{4})\b',
          caseSensitive: false),
    ];
    for (final r in candidates) {
      final m = r.firstMatch(text);
      if (m != null) {
        try {
          if (r.pattern.startsWith(r'\b(\d{2})\s+')) {
            const months = {
              'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
              'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
            };
            final day = int.parse(m.group(1)!);
            final mon = months[m.group(2)!.substring(0, 3).toLowerCase()]!;
            final year = int.parse(m.group(3)!);
            return DateTime(year, mon, day);
          }
          if (r.pattern.startsWith(r'\b(\d{4})')) {
            return DateTime(
              int.parse(m.group(1)!),
              int.parse(m.group(2)!),
              int.parse(m.group(3)!),
            );
          }
          return DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(2)!),
            int.parse(m.group(1)!),
          );
        } catch (_) {
          continue;
        }
      }
    }
    return null;
  }

  String? _extractMerchant(List<String> lines) {
    for (final line in lines.take(4)) {
      if (RegExp(r'^[A-Za-z][A-Za-z &\-\.]{2,40}$').hasMatch(line) &&
          !RegExp(r'(invoice|receipt|bill|tax|gstin)', caseSensitive: false)
              .hasMatch(line)) {
        return line;
      }
    }
    return lines.isNotEmpty ? lines.first : null;
  }

  String? _guessCategory(String text, String? merchant) {
    final m = (merchant ?? '').toLowerCase();
    bool hits(List<String> kws) =>
        kws.any((k) => text.contains(k) || m.contains(k));

    if (hits(['restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'swiggy', 'zomato'])) {
      return 'Food';
    }
    if (hits(['uber', 'ola', 'fuel', 'petrol', 'metro', 'transport', 'rapido'])) {
      return 'Transport';
    }
    if (hits(['mart', 'kirana', 'grocer', 'bigbasket', 'blinkit', 'dmart'])) {
      return 'Groceries';
    }
    if (hits(['hospital', 'clinic', 'pharma', 'medical', 'apollo', 'medplus'])) {
      return 'Medical';
    }
    if (hits(['amazon', 'flipkart', 'myntra', 'mall', 'store'])) {
      return 'Shopping';
    }
    if (hits(['electricity', 'gas', 'water', 'broadband', 'recharge', 'bill'])) {
      return 'Bills';
    }
    return null;
  }
}
