import 'package:flutter/material.dart';

import '../../../core/utils/currency_format.dart';
import '../../../data/providers/finance_providers.dart';

class CategoryBudgetBarChart extends StatelessWidget {
  final List<CategoryBudgetProgress> progress;

  const CategoryBudgetBarChart({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Asigná un presupuesto mensual a tus categorías para ver este gráfico'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Presupuesto vs. gasto del mes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Row(
              children: [
                _LegendDot(color: Colors.blueGrey.shade300, label: 'Presupuesto'),
                const SizedBox(width: 16),
                _LegendDot(color: Theme.of(context).colorScheme.primary, label: 'Gastado'),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < progress.length; i++) ...[
              if (i > 0) const SizedBox(height: 16),
              _CategoryBudgetRow(progress: progress[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  final CategoryBudgetProgress progress;

  const _CategoryBudgetRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final budget = progress.category.budgetAmount!;
    final spent = progress.spent;
    final overBudget = spent > budget;
    final fraction = budget <= 0 ? 0.0 : (spent / budget).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                progress.category.name,
                style: Theme.of(context).textTheme.bodyMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${formatCurrency(spent, 'ARS')} / ${formatCurrency(budget, 'ARS')}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: overBudget ? Colors.red.shade400 : null,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Container(height: 16, color: Colors.blueGrey.shade300),
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 16,
                  color: overBudget ? Colors.red.shade400 : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
