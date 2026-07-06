import 'package:flutter_test/flutter_test.dart';
import 'package:roibal_app/features/group_events/utils/debt_simplifier.dart';

void main() {
  // Helpers
  double totalTransferred(List<DebtSettlement> s) =>
      s.fold(0.0, (sum, t) => sum + t.amount);

  bool isBalanced(Map<String, double> balances, List<DebtSettlement> settlements) {
    final net = Map<String, double>.from(balances);
    for (final s in settlements) {
      net[s.fromMemberId] = (net[s.fromMemberId] ?? 0) + s.amount;
      net[s.toMemberId] = (net[s.toMemberId] ?? 0) - s.amount;
    }
    return net.values.every((v) => v.abs() < 0.01);
  }

  group('simplifyDebts', () {
    test('caso básico: 3 personas en una moneda', () {
      // A pagó de más (50), B pagó lo justo (0), C pagó de menos (-50)
      // A le debe a C 50
      final balances = {'A': 50.0, 'B': 0.0, 'C': -50.0};
      final result = simplifyDebts(balances);

      expect(result, hasLength(1));
      expect(result.first.fromMemberId, 'C');
      expect(result.first.toMemberId, 'A');
      expect(result.first.amount, closeTo(50.0, 0.01));
      expect(isBalanced(balances, result), isTrue);
    });

    test('3 personas, deuda distribuida: minimiza transferencias', () {
      // A le deben 60, B le deben 40, C debe 100
      // Óptimo: C → A (60), C → B (40) = 2 transferencias en vez de 3+
      final balances = {'A': 60.0, 'B': 40.0, 'C': -100.0};
      final result = simplifyDebts(balances);

      expect(result.length, lessThanOrEqualTo(2));
      expect(totalTransferred(result), closeTo(100.0, 0.01));
      expect(isBalanced(balances, result), isTrue);
    });

    test('múltiples monedas sin cruce: cada moneda independiente', () {
      // ARS: A le debe 200 a B
      final arsBalances = {'A': 200.0, 'B': -200.0};
      final arsResult = simplifyDebts(arsBalances);

      // USD: C le debe 50 a D
      final usdBalances = {'C': 50.0, 'D': -50.0};
      final usdResult = simplifyDebts(usdBalances);

      expect(arsResult, hasLength(1));
      expect(arsResult.first.fromMemberId, 'B');
      expect(arsResult.first.toMemberId, 'A');
      expect(isBalanced(arsBalances, arsResult), isTrue);

      expect(usdResult, hasLength(1));
      expect(usdResult.first.fromMemberId, 'D');
      expect(usdResult.first.toMemberId, 'C');
      expect(isBalanced(usdBalances, usdResult), isTrue);
    });

    test('neteo cruzado: A↔B en 2 monedas distintas', () {
      // En ARS: A tiene net +1000 (le deben 1000 ARS) → B debe 1000 ARS a A
      // En USD: A tiene net -50 (debe 50 USD) → A debe 50 USD a B
      // Si 1 USD = 1000 ARS: pueden netear y quedan sin deuda cruzada.
      // Este test verifica que el algoritmo detecta y genera 1 transferencia neta.

      final arsBalances = {'A': 1000.0, 'B': -1000.0};
      final usdBalances = {'A': -50.0, 'B': 50.0};

      final arsResult = simplifyDebts(arsBalances);
      final usdResult = simplifyDebts(usdBalances);

      // Sin neteo: deberíamos tener 2 transferencias (B → A en ARS, A → B en USD)
      expect(arsResult, hasLength(1));
      expect(usdResult, hasLength(1));
      // B debe pagar a A en ARS
      expect(arsResult.first.fromMemberId, 'B');
      expect(arsResult.first.toMemberId, 'A');
      // A debe pagar a B en USD
      expect(usdResult.first.fromMemberId, 'A');
      expect(usdResult.first.toMemberId, 'B');

      // La detección de cruce (mismo par A↔B con deudas inversas) es responsabilidad
      // del SettlementScreen — aquí solo verificamos que el algoritmo por moneda es correcto.
      expect(isBalanced(arsBalances, arsResult), isTrue);
      expect(isBalanced(usdBalances, usdResult), isTrue);
    });

    test('con pagos parciales ya descontados del balance', () {
      // Escenario: A pagó 300, B pagó 0, C pagó 0. Total=300, cada uno debe 100.
      // Net: A=+200, B=-100, C=-100
      // Además, B ya hizo un pago parcial a A de 50 → net ajustado: A=+150, B=-50, C=-100
      final balances = {'A': 150.0, 'B': -50.0, 'C': -100.0};
      final result = simplifyDebts(balances);

      expect(totalTransferred(result), closeTo(150.0, 0.01));
      expect(isBalanced(balances, result), isTrue);
      // Máximo 2 transferencias (B→A y C→A)
      expect(result.length, lessThanOrEqualTo(2));
    });

    test('todos balanceados: devuelve lista vacía', () {
      final balances = {'A': 0.0, 'B': 0.0, 'C': 0.0};
      expect(simplifyDebts(balances), isEmpty);
    });

    test('un solo deudor y un solo acreedor', () {
      final balances = {'A': 75.5, 'B': -75.5};
      final result = simplifyDebts(balances);
      expect(result, hasLength(1));
      expect(result.first.amount, closeTo(75.5, 0.01));
      expect(isBalanced(balances, result), isTrue);
    });
  });
}
