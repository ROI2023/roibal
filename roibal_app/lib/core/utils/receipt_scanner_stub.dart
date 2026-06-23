import 'package:flutter/material.dart';

import 'receipt_scanner.dart';

Future<ReceiptScanResult?> scanReceipt(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Escaneo de tickets'),
      content: const Text(
        'El escaneo de tickets todavía no está disponible en la versión web. '
        'Vas a poder usarlo compilando la app para Android o iOS.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido')),
      ],
    ),
  );
  return null;
}
