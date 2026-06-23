import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/category_suggestions.dart';
import '../../data/models/category.dart';

class AddCategoryScreen extends ConsumerStatefulWidget {
  final Category? category;

  const AddCategoryScreen({super.key, this.category});

  @override
  ConsumerState<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends ConsumerState<AddCategoryScreen> {
  late final _nameController = TextEditingController(text: widget.category?.name ?? '');
  late final _budgetController = TextEditingController(
    text: widget.category?.budgetAmount == null ? '' : widget.category!.budgetAmount.toString(),
  );
  String? _selectedIcon;
  late CategoryType _selectedType;
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.category?.iconName;
    _selectedType = widget.category?.type ?? CategoryType.expense;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _applySuggestion(CategorySuggestion suggestion) {
    setState(() {
      _nameController.text = suggestion.name;
      _selectedIcon = suggestion.iconName;
      _selectedType = suggestion.type;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresá un nombre');
      return;
    }
    if (_selectedIcon == null) {
      _showError('Elegí un ícono');
      return;
    }

    final budgetText = _budgetController.text.trim();
    double? budgetAmount;
    if (budgetText.isNotEmpty) {
      budgetAmount = double.tryParse(budgetText.replaceAll(',', '.'));
      if (budgetAmount == null || budgetAmount < 0) {
        _showError('El presupuesto debe ser un número válido');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'name': name,
        'icon_name': _selectedIcon,
        'type': _selectedType == CategoryType.expense ? 'expense' : 'income',
        'budget_amount': budgetAmount,
      };
      if (_isEditing) {
        await supabase.from('categories').update(payload).eq('id', widget.category!.id);
      } else {
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('categories').insert({'user_id': userId, ...payload});
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${widget.category!.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await supabase.from('categories').delete().eq('id', widget.category!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo eliminar: $e');
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _deleting;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar categoría' : 'Nueva categoría'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Eliminar',
              onPressed: busy ? null : _delete,
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            if (!_isEditing) ...[
              Text('Sugerencias', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: categorySuggestions.map((suggestion) {
                  return ActionChip(
                    avatar: Icon(categoryIconFor(suggestion.iconName), size: 18),
                    label: Text(suggestion.name),
                    onPressed: () => _applySuggestion(suggestion),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 24),
            Text('Tipo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                ChoiceChip(
                  label: const Text('Gasto'),
                  selected: _selectedType == CategoryType.expense,
                  onSelected: (_) => setState(() => _selectedType = CategoryType.expense),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Ingreso'),
                  selected: _selectedType == CategoryType.income,
                  onSelected: (_) => setState(() => _selectedType = CategoryType.income),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _budgetController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Presupuesto mensual (opcional)',
                helperText: 'Para comparar el gasto del mes con lo presupuestado',
              ),
            ),
            const SizedBox(height: 24),
            Text('Ícono', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: categoryIconOptions.entries.map((entry) {
                final selected = _selectedIcon == entry.key;
                return InkWell(
                  borderRadius: BorderRadius.circular(28),
                  onTap: () => setState(() => _selectedIcon = entry.key),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: Icon(
                      entry.value,
                      color: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: busy ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
