import '../../../data/models/group_event.dart';
import '../../../data/models/group_expense.dart';
import '../../../data/models/group_member.dart';
import '../../../data/models/group_member_share.dart';
import '../../../data/models/group_partial_payment.dart';

/// Balance neto de un miembro en una moneda concreta.
/// Positivo = le deben dinero. Negativo = debe dinero.
class MemberCurrencyBalance {
  final GroupMember member;
  final String currency;
  final double paid;       // lo que pagó en gastos grupales
  final double shouldPay;  // lo que le corresponde según su %
  final double partialsPaid;   // pagos parciales que hizo (deuda ya saldada)
  final double partialsReceived; // pagos parciales que recibió
  final double net;        // paid - shouldPay + partialsPaid - partialsReceived

  const MemberCurrencyBalance({
    required this.member,
    required this.currency,
    required this.paid,
    required this.shouldPay,
    required this.partialsPaid,
    required this.partialsReceived,
    required this.net,
  });
}

class GroupBalanceResult {
  /// { currency → { memberId → MemberCurrencyBalance } }
  final Map<String, Map<String, MemberCurrencyBalance>> byCurrency;

  const GroupBalanceResult(this.byCurrency);

  /// Monedas con al menos un gasto.
  List<String> get currencies => byCurrency.keys.toList();

  /// Balance neto de un miembro en una moneda (para el algoritmo de deudas).
  /// { memberId → net }
  Map<String, double> netBalancesFor(String currency) {
    final byMember = byCurrency[currency];
    if (byMember == null) return {};
    return {for (final e in byMember.entries) e.key: e.value.net};
  }
}

/// Calcula el balance grupal en función de gastos, shares y pagos parciales.
///
/// Para [splitMode] == [SplitMode.perCurrency]: los % de responsabilidad son
/// por moneda. Para [SplitMode.baseCurrency]: los % son únicos (guardados con
/// currency == baseCurrency) y se aplican al total de cada moneda del evento.
GroupBalanceResult calculateGroupBalance({
  required List<GroupMember> members,
  required List<GroupExpense> expenses,
  required List<GroupMemberShare> shares,
  required List<GroupPartialPayment> partialPayments,
  required SplitMode splitMode,
  required String baseCurrency,
}) {
  final acceptedMembers = members.where((m) => m.status == GroupMemberStatus.accepted).toList();

  // Agrupar shares: { memberId → { currency → % } }
  final shareMap = <String, Map<String, double>>{};
  for (final s in shares) {
    shareMap.putIfAbsent(s.groupMemberId, () => <String, double>{})[s.currency] = s.percentage;
  }

  // Calcular porcentaje efectivo para un miembro en una moneda dada
  double shareFor(String memberId, String currency) {
    if (splitMode == SplitMode.baseCurrency) {
      return shareMap[memberId]?[baseCurrency] ?? 0.0;
    }
    return shareMap[memberId]?[currency] ?? 0.0;
  }

  // Obtener monedas usadas en gastos
  final currencies = expenses.map((e) => e.currency).toSet().toList();

  final result = <String, Map<String, MemberCurrencyBalance>>{};

  for (final currency in currencies) {
    final expensesInCurrency = expenses.where((e) => e.currency == currency).toList();
    final totalInCurrency = expensesInCurrency.fold<double>(0, (s, e) => s + e.amount);

    final byMember = <String, MemberCurrencyBalance>{};

    for (final member in acceptedMembers) {
      final paid = expensesInCurrency
          .where((e) => e.paidByMemberId == member.id)
          .fold<double>(0, (s, e) => s + e.amount);

      final pct = shareFor(member.id, currency);
      final shouldPay = totalInCurrency * pct / 100.0;

      // Pagos parciales (todos, confirmados o no, como dice el prompt)
      final partialsPaid = partialPayments
          .where((p) => p.currency == currency && p.fromMemberId == member.id)
          .fold<double>(0, (s, p) => s + p.amount);

      final partialsReceived = partialPayments
          .where((p) => p.currency == currency && p.toMemberId == member.id)
          .fold<double>(0, (s, p) => s + p.amount);

      // net positivo = le deben; negativo = debe
      final net = paid - shouldPay + partialsPaid - partialsReceived;

      byMember[member.id] = MemberCurrencyBalance(
        member: member,
        currency: currency,
        paid: paid,
        shouldPay: shouldPay,
        partialsPaid: partialsPaid,
        partialsReceived: partialsReceived,
        net: net,
      );
    }

    result[currency] = byMember;
  }

  return GroupBalanceResult(result);
}
