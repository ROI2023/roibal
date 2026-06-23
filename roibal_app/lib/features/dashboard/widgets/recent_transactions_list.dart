import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_format.dart';
import '../../../data/models/category.dart';
import '../../../data/models/expense_transaction.dart';
import '../../../data/providers/finance_providers.dart';

double _signedAmount(ExpenseTransaction t) =>
    t.category?.type == CategoryType.income ? t.totalAmount : -t.totalAmount;

class RecentTransactionsList extends ConsumerStatefulWidget {
  final List<ExpenseTransaction> transactions;

  const RecentTransactionsList({super.key, required this.transactions});

  @override
  ConsumerState<RecentTransactionsList> createState() => _RecentTransactionsListState();
}

class _RecentTransactionsListState extends ConsumerState<RecentTransactionsList> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final transactions = widget.transactions;
    if (transactions.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Sin movimientos registrados todavía')),
        ),
      );
    }

    final sumByCurrency = <String, double>{};
    for (final t in transactions) {
      sumByCurrency.update(t.currency, (v) => v + _signedAmount(t), ifAbsent: () => _signedAmount(t));
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Text('Últimos movimientos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Text(
                    '${transactions.length}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  for (final e in sumByCurrency.entries)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Text(
                        formatCurrency(e.value, e.key),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: e.value >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                        ),
                      ),
                    ),
                  Icon(_expanded ? Icons.expand_less : Icons.chevron_right),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            for (final t in transactions) _TransactionTile(transaction: t),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () =>
                      ref.read(recentTransactionsLimitProvider.notifier).state += 20,
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Mostrar más movimientos'),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final ExpenseTransaction transaction;

  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.category?.type == CategoryType.income;
    final sign = isIncome ? '+' : '-';
    final color = isIncome ? Colors.green.shade700 : Colors.red.shade700;
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(categoryIconFor(transaction.category?.iconName), color: color),
      ),
      title: Text(transaction.description),
      subtitle: Text(transaction.category?.name ?? 'Transferencia'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign${formatCurrency(transaction.totalAmount, transaction.currency)}',
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            DateFormat('dd/MM/yyyy HH:mm').format(transaction.transactionDate),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
