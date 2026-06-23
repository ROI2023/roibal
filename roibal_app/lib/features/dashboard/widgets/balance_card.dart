import 'package:flutter/material.dart';

import '../../../core/utils/currency_format.dart';
import '../../../data/models/account.dart';

class BalanceCard extends StatelessWidget {
  final List<Account> accounts;

  const BalanceCard({super.key, required this.accounts});

  @override
  Widget build(BuildContext context) {
    final balancesByCurrency = <String, double>{};
    for (final a in accounts) {
      balancesByCurrency.update(
        a.currency,
        (v) => v + a.currentBalance,
        ifAbsent: () => a.currentBalance,
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balance total', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (balancesByCurrency.isEmpty)
              const Text('Sin cuentas todavía')
            else
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: balancesByCurrency.entries
                    .map((e) => _CurrencyAmount(currency: e.key, amount: e.value))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyAmount extends StatelessWidget {
  final String currency;
  final double amount;

  const _CurrencyAmount({required this.currency, required this.amount});

  @override
  Widget build(BuildContext context) {
    return Text(
      formatCurrency(amount, currency),
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }
}
