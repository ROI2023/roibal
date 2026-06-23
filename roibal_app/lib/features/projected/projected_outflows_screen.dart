import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/projected_movement.dart';
import '../../data/providers/finance_providers.dart';

class ProjectedOutflowsScreen extends ConsumerWidget {
  const ProjectedOutflowsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projected = ref.watch(projectedOutflowsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Salidas proyectadas')),
      body: projected.when(
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(child: Text('No hay salidas proyectadas'));
          }

          final byMonth = <String, List<ProjectedMovement>>{};
          for (final m in movements) {
            final key = DateFormat('yyyy-MM').format(m.dueDate);
            byMonth.putIfAbsent(key, () => []).add(m);
          }
          final monthKeys = byMonth.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final key in monthKeys) ...[
                _MonthHeader(monthKey: key, movements: byMonth[key]!),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: byMonth[key]!.map((m) => _ProjectedTile(movement: m)).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

const _spanishMonths = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];

class _MonthHeader extends StatelessWidget {
  final String monthKey;
  final List<ProjectedMovement> movements;

  const _MonthHeader({required this.monthKey, required this.movements});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('yyyy-MM').parse(monthKey);
    final label = '${_spanishMonths[date.month - 1]} ${date.year}';
    final totalsByCurrency = <String, double>{};
    for (final m in movements) {
      totalsByCurrency.update(m.currency, (v) => v + m.amount, ifAbsent: () => m.amount);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        Text(
          totalsByCurrency.entries
              .map((e) => formatCurrency(e.value, e.key))
              .join(' / '),
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ProjectedTile extends StatelessWidget {
  final ProjectedMovement movement;

  const _ProjectedTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isIncome = movement.amount > 0;
    final color = isIncome ? Colors.green.shade700 : Colors.red.shade700;
    final installmentSuffix =
        movement.totalInstallments > 1 ? ' (${movement.installmentNumber}/${movement.totalInstallments})' : '';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.15),
        child: Icon(categoryIconFor(movement.category?.iconName), color: color),
      ),
      title: Text('${movement.description}$installmentSuffix'),
      subtitle: Text('${movement.accountName} · ${DateFormat('dd/MM/yyyy').format(movement.dueDate)}'),
      trailing: Text(
        formatCurrency(movement.amount, movement.currency),
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
