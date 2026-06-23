import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/category_icons.dart';
import '../../../core/utils/currency_format.dart';
import '../../../data/providers/finance_providers.dart';

final _palette = <Color>[
  Colors.teal,
  Colors.orange,
  Colors.indigo,
  Colors.pink,
  Colors.amber,
  Colors.blueGrey,
];

class CategoryDonutChart extends StatefulWidget {
  final List<CategorySpending> spending;

  const CategoryDonutChart({super.key, required this.spending});

  @override
  State<CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<CategoryDonutChart> {
  int? _touchedIndex;

  void _showCategoryDetail(CategorySpending spending, Color color) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(categoryIconFor(spending.category.iconName), color: color),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        spending.category.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      formatCurrency(spending.amount, 'ARS'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: spending.movements.length,
                    itemBuilder: (context, i) {
                      final m = spending.movements[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(m.description),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(m.paidDate)),
                        trailing: Text(formatCurrency(m.amount, 'ARS')),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final spending = widget.spending;
    if (spending.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: Text('Todavía no hubo salidas de dinero este mes')),
        ),
      );
    }

    final total = spending.fold<double>(0, (sum, s) => sum + s.amount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Salidas del Mes (ARS)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Tocá una porción para ver el detalle',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            if (event is! FlTapUpEvent) return;
                            final index = response?.touchedSection?.touchedSectionIndex;
                            if (index == null || index < 0 || index >= spending.length) return;
                            _showCategoryDetail(
                              spending[index],
                              _palette[index % _palette.length],
                            );
                          },
                        ),
                        sections: [
                          for (var i = 0; i < spending.length; i++)
                            PieChartSectionData(
                              value: spending[i].amount,
                              color: _palette[i % _palette.length],
                              title:
                                  '${(spending[i].amount / total * 100).round()}%\n${formatCurrency(spending[i].amount, 'ARS')}',
                              radius: i == _touchedIndex ? 56 : 50,
                              titleStyle: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: spending.length,
                      itemBuilder: (context, i) => InkWell(
                        onTap: () => _showCategoryDetail(spending[i], _palette[i % _palette.length]),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: _palette[i % _palette.length],
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  spending[i].category.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                formatCurrency(spending[i].amount, 'ARS'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
