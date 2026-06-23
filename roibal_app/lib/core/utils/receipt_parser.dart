import 'receipt_scanner.dart';

final _amountPattern = RegExp(r'\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{2})|\d+(?:[.,]\d{2})');

/// Heuristic receipt parsing for the first OCR version: the largest amount
/// found on the ticket is usually the total, and the first non-empty line
/// is usually the merchant name.
ReceiptScanResult parseReceiptText(String text) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

  double? bestAmount;
  for (final line in lines) {
    for (final match in _amountPattern.allMatches(line)) {
      final value = _parseAmount(match.group(0)!);
      if (value != null && (bestAmount == null || value > bestAmount)) {
        bestAmount = value;
      }
    }
  }

  return ReceiptScanResult(amount: bestAmount, description: lines.isEmpty ? null : lines.first);
}

double? _parseAmount(String raw) {
  var s = raw;
  if (s.contains(',') && s.contains('.')) {
    if (s.lastIndexOf(',') > s.lastIndexOf('.')) {
      s = s.replaceAll('.', '').replaceAll(',', '.');
    } else {
      s = s.replaceAll(',', '');
    }
  } else if (s.contains(',')) {
    final decimals = s.split(',').last;
    s = decimals.length == 2 ? s.replaceAll(',', '.') : s.replaceAll(',', '');
  }
  return double.tryParse(s);
}
