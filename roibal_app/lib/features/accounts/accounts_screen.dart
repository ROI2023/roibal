import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/account_style.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/account.dart';
import '../../data/providers/finance_providers.dart';
import 'add_account_screen.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Account? account}) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => AddAccountScreen(account: account)));
    if (changed == true) ref.invalidate(accountsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: accounts.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('Todavía no creaste cuentas'));
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final account in data)
                _AccountTile(
                  account: account,
                  onTap: () => _openEditor(context, ref, account: account),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

const _typeLabels = {
  AccountType.cash: 'Efectivo',
  AccountType.creditCard: 'Tarjeta de crédito',
  AccountType.investment: 'Inversión',
  AccountType.savingsWallet: 'Cuentas y Billeteras',
};

class _AccountTile extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const _AccountTile({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = accountStyleFor(account.type);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: style.color.withValues(alpha: 0.15),
        child: Icon(style.icon, color: style.color),
      ),
      title: Text(account.name),
      subtitle: Text(_typeLabels[account.type]!),
      trailing: Text(
        formatCurrency(account.currentBalance, account.currency),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      onTap: onTap,
    );
  }
}
