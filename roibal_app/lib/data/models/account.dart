enum AccountType { cash, creditCard, investment, savingsWallet }

AccountType accountTypeFromString(String value) {
  switch (value) {
    case 'cash':
      return AccountType.cash;
    case 'credit_card':
      return AccountType.creditCard;
    case 'investment':
      return AccountType.investment;
    case 'savings_wallet':
      return AccountType.savingsWallet;
    default:
      throw ArgumentError('Unknown account type: $value');
  }
}

class Account {
  final String id;
  final String userId;
  final String name;
  final AccountType type;
  final String currency;
  final double currentBalance;
  final double initialBalance;
  final DateTime lastUpdate;
  final int? closingDay;
  final int? dueDay;

  const Account({
    required this.id,
    required this.userId,
    required this.name,
    required this.type,
    required this.currency,
    required this.currentBalance,
    required this.initialBalance,
    required this.lastUpdate,
    this.closingDay,
    this.dueDay,
  });

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      type: accountTypeFromString(json['type'] as String),
      currency: json['currency'] as String,
      currentBalance: (json['current_balance'] as num).toDouble(),
      initialBalance: (json['initial_balance'] as num).toDouble(),
      lastUpdate: DateTime.parse(json['last_update'] as String),
      closingDay: json['closing_day'] as int?,
      dueDay: json['due_day'] as int?,
    );
  }
}
