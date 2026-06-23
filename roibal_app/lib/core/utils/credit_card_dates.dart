({int year, int month}) _addMonths(int year, int month, int months) {
  final total = year * 12 + (month - 1) + months;
  return (year: total ~/ 12, month: total % 12 + 1);
}

/// Computes the payment due date for a given installment of a credit card
/// purchase, based on the card's statement closing day and payment due day.
///
/// Purchases made after the closing day roll into the next statement; each
/// subsequent installment bills on the following month's statement.
DateTime creditCardInstallmentDueDate({
  required DateTime purchaseDate,
  required int closingDay,
  required int dueDay,
  required int installmentNumber,
}) {
  var closeYear = purchaseDate.year;
  var closeMonth = purchaseDate.month;
  if (purchaseDate.day > closingDay) {
    final next = _addMonths(closeYear, closeMonth, 1);
    closeYear = next.year;
    closeMonth = next.month;
  }

  var dueYear = closeYear;
  var dueMonth = closeMonth;
  if (dueDay <= closingDay) {
    final next = _addMonths(dueYear, dueMonth, 1);
    dueYear = next.year;
    dueMonth = next.month;
  }

  if (installmentNumber > 1) {
    final next = _addMonths(dueYear, dueMonth, installmentNumber - 1);
    dueYear = next.year;
    dueMonth = next.month;
  }

  return DateTime(dueYear, dueMonth, dueDay);
}
