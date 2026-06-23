import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/category_icons.dart';
import '../../data/models/category.dart';
import '../../data/providers/finance_providers.dart';
import 'add_category_screen.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _openEditor(BuildContext context, WidgetRef ref, {Category? category}) async {
    final changed = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (context) => AddCategoryScreen(category: category)));
    if (changed == true) ref.invalidate(categoriesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorías')),
      body: categories.when(
        data: (data) {
          if (data.isEmpty) {
            return const Center(child: Text('Todavía no creaste categorías'));
          }
          final expense = data.where((c) => c.type == CategoryType.expense).toList();
          final income = data.where((c) => c.type == CategoryType.income).toList();
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              if (expense.isNotEmpty) _SectionHeader(title: 'Gastos'),
              ...expense.map(
                (c) => _CategoryTile(
                  category: c,
                  onTap: () => _openEditor(context, ref, category: c),
                ),
              ),
              if (income.isNotEmpty) _SectionHeader(title: 'Ingresos'),
              ...income.map(
                (c) => _CategoryTile(
                  category: c,
                  onTap: () => _openEditor(context, ref, category: c),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onTap;

  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final budget = category.budgetAmount;
    return ListTile(
      leading: CircleAvatar(child: Icon(categoryIconFor(category.iconName))),
      title: Text(category.name),
      subtitle: budget == null ? null : Text('Presupuesto: \$${budget.toStringAsFixed(2)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
