class DebtSettlement {
  final String fromMemberId;
  final String toMemberId;
  final double amount;

  const DebtSettlement({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}

/// Algoritmo greedy de minimización de transferencias (Splitwise-style).
///
/// [netBalances]: mapa { memberId → balance neto }.
///   Positivo = acreedor (le deben dinero).
///   Negativo = deudor (debe dinero).
///
/// Devuelve la lista mínima de [DebtSettlement] que salda todas las deudas.
List<DebtSettlement> simplifyDebts(Map<String, double> netBalances) {
  const epsilon = 0.005; // tolerancia para errores de punto flotante

  final settlements = <DebtSettlement>[];

  // Separar en deudores y acreedores con montos positivos
  final debtors = <String>[];
  final creditors = <String>[];
  final debtorAmounts = <double>[];
  final creditorAmounts = <double>[];

  for (final entry in netBalances.entries) {
    if (entry.value < -epsilon) {
      debtors.add(entry.key);
      debtorAmounts.add(-entry.value);
    } else if (entry.value > epsilon) {
      creditors.add(entry.key);
      creditorAmounts.add(entry.value);
    }
  }

  // Ordenar descendente para emparejar los montos más grandes primero
  final debtorOrder = List.generate(debtors.length, (i) => i)
    ..sort((a, b) => debtorAmounts[b].compareTo(debtorAmounts[a]));
  final creditorOrder = List.generate(creditors.length, (i) => i)
    ..sort((a, b) => creditorAmounts[b].compareTo(creditorAmounts[a]));

  final sortedDebtors = debtorOrder.map((i) => debtors[i]).toList();
  final sortedCreditors = creditorOrder.map((i) => creditors[i]).toList();
  final sortedDebtAmounts = debtorOrder.map((i) => debtorAmounts[i]).toList();
  final sortedCreditAmounts = creditorOrder.map((i) => creditorAmounts[i]).toList();

  int di = 0, ci = 0;
  while (di < sortedDebtors.length && ci < sortedCreditors.length) {
    final debt = sortedDebtAmounts[di];
    final credit = sortedCreditAmounts[ci];
    final transfer = debt < credit ? debt : credit;

    if (transfer > epsilon) {
      settlements.add(DebtSettlement(
        fromMemberId: sortedDebtors[di],
        toMemberId: sortedCreditors[ci],
        amount: double.parse(transfer.toStringAsFixed(2)),
      ));
    }

    sortedDebtAmounts[di] -= transfer;
    sortedCreditAmounts[ci] -= transfer;

    if (sortedDebtAmounts[di] < epsilon) di++;
    if (sortedCreditAmounts[ci] < epsilon) ci++;
  }

  return settlements;
}
