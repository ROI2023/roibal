import 'package:flutter/material.dart';

import 'receipt_scanner_stub.dart' if (dart.library.io) 'receipt_scanner_mobile.dart' as impl;

class ReceiptScanResult {
  final double? amount;
  final String? description;

  const ReceiptScanResult({this.amount, this.description});
}

/// Lets the user photograph/pick a receipt and returns a suggested amount
/// and description. Returns null if the user cancels (or, on web, where
/// OCR isn't available yet).
Future<ReceiptScanResult?> scanReceipt(BuildContext context) => impl.scanReceipt(context);
