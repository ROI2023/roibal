import 'package:flutter/material.dart';

import '../../data/models/account.dart';

class AccountStyle {
  final IconData icon;
  final Color color;

  const AccountStyle(this.icon, this.color);
}

const _accountStyles = <AccountType, AccountStyle>{
  AccountType.cash: AccountStyle(Icons.payments_outlined, Colors.green),
  AccountType.creditCard: AccountStyle(Icons.credit_card, Colors.deepPurple),
  AccountType.investment: AccountStyle(Icons.trending_up, Colors.blue),
  AccountType.savingsWallet: AccountStyle(Icons.account_balance_wallet_outlined, Colors.teal),
};

AccountStyle accountStyleFor(AccountType type) =>
    _accountStyles[type] ?? const AccountStyle(Icons.help_outline, Colors.grey);
