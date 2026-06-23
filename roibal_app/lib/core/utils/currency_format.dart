import 'package:intl/intl.dart';

/// Formats amounts Argentina-style (dot thousands separator, comma decimal):
/// ARS as 999.999 (no decimals), USD as 999.999,99 (2 decimals).
String formatCurrency(double amount, String currency) {
  final formatter = NumberFormat.currency(
    locale: 'es_AR',
    symbol: currency == 'USD' ? 'US\$' : '\$',
    decimalDigits: currency == 'USD' ? 2 : 0,
  );
  return formatter.format(amount);
}
