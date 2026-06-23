import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/providers/finance_providers.dart';

enum _CycleType { monthlyDay, everyNDays }

const _cycleLabels = {
  _CycleType.monthlyDay: 'Cada mes (día fijo)',
  _CycleType.everyNDays: 'Cada N días',
};

const _cycleValues = {
  _CycleType.monthlyDay: 'monthly_day',
  _CycleType.everyNDays: 'every_n_days',
};

class AddRecurringExpenseScreen extends ConsumerStatefulWidget {
  const AddRecurringExpenseScreen({super.key});

  @override
  ConsumerState<AddRecurringExpenseScreen> createState() => _AddRecurringExpenseScreenState();
}

class _AddRecurringExpenseScreenState extends ConsumerState<AddRecurringExpenseScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _cycleDayController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _monthsToGenerateController = TextEditingController(text: '12');

  Category? _selectedCategory;
  Account? _selectedAccount;
  _CycleType _cycleType = _CycleType.monthlyDay;
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _cycleDayController.dispose();
    _intervalDaysController.dispose();
    _monthsToGenerateController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  List<DateTime> _generateOccurrences({
    required _CycleType cycleType,
    required DateTime startDate,
    int? cycleDay,
    int? intervalDays,
    required int monthsToGenerate,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final horizon = DateTime(start.year, start.month + monthsToGenerate, start.day);
    final occurrences = <DateTime>[];

    if (cycleType == _CycleType.monthlyDay) {
      var year = start.year;
      var month = start.month;
      if (start.day > cycleDay!) {
        month += 1;
      }
      for (var i = 0; i < monthsToGenerate; i++) {
        final totalMonths = (year * 12 + (month - 1)) + i;
        final occYear = totalMonths ~/ 12;
        final occMonth = totalMonths % 12 + 1;
        final lastDay = DateTime(occYear, occMonth + 1, 0).day;
        final day = cycleDay > lastDay ? lastDay : cycleDay;
        occurrences.add(DateTime(occYear, occMonth, day));
      }
    } else {
      var occ = start;
      while (!occ.isAfter(horizon)) {
        occurrences.add(occ);
        occ = occ.add(Duration(days: intervalDays!));
      }
    }
    return occurrences;
  }

  Future<void> _save() async {
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      _showError('Ingresá una descripción');
      return;
    }
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showError('Ingresá un monto válido');
      return;
    }
    if (_selectedCategory == null) {
      _showError('Elegí una categoría');
      return;
    }
    if (_selectedAccount == null) {
      _showError('Elegí una cuenta');
      return;
    }

    int? cycleDay;
    int? intervalDays;
    if (_cycleType == _CycleType.monthlyDay) {
      cycleDay = int.tryParse(_cycleDayController.text.trim());
      if (cycleDay == null || cycleDay < 1 || cycleDay > 31) {
        _showError('Ingresá un día del mes válido (1-31)');
        return;
      }
    } else {
      intervalDays = int.tryParse(_intervalDaysController.text.trim());
      if (intervalDays == null || intervalDays < 1) {
        _showError('Ingresá un intervalo de días válido');
        return;
      }
    }

    final monthsToGenerate = int.tryParse(_monthsToGenerateController.text.trim());
    if (monthsToGenerate == null || monthsToGenerate < 1) {
      _showError('Ingresá una cantidad de meses válida');
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final recurringExpense = await supabase
          .from('recurring_expenses')
          .insert({
            'user_id': userId,
            'description': description,
            'category_id': _selectedCategory!.id,
            'account_id': _selectedAccount!.id,
            'currency': _selectedAccount!.currency,
            'amount': amount,
            'cycle_type': _cycleValues[_cycleType],
            'cycle_day': cycleDay,
            'interval_days': intervalDays,
            'start_date': DateTime(_startDate.year, _startDate.month, _startDate.day)
                .toIso8601String(),
            'months_to_generate': monthsToGenerate,
          })
          .select()
          .single();

      final occurrences = _generateOccurrences(
        cycleType: _cycleType,
        startDate: _startDate,
        cycleDay: cycleDay,
        intervalDays: intervalDays,
        monthsToGenerate: monthsToGenerate,
      );

      for (final occurrence in occurrences) {
        final transaction = await supabase
            .from('transactions')
            .insert({
              'user_id': userId,
              'description': description,
              'category_id': _selectedCategory!.id,
              'recurring_expense_id': recurringExpense['id'],
              'currency': _selectedAccount!.currency,
              'total_amount': amount,
              'transaction_date': occurrence.toIso8601String(),
            })
            .select()
            .single();

        await supabase.from('transaction_movements').insert({
          'user_id': userId,
          'transaction_id': transaction['id'],
          'account_id': _selectedAccount!.id,
          'currency': _selectedAccount!.currency,
          'amount': -amount,
          'installment_number': 1,
          'total_installments': 1,
          'due_date': occurrence.toIso8601String(),
          'status': 'pending',
        });
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(expenseCategoriesProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto recurrente')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Monto'),
            ),
            const SizedBox(height: 24),
            Text('Categoría', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            categories.when(
              data: (data) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data
                    .map((c) => ChoiceChip(
                          label: Text(c.name),
                          selected: _selectedCategory?.id == c.id,
                          onSelected: (_) => setState(() => _selectedCategory = c),
                        ))
                    .toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            Text('Cuenta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            accounts.when(
              data: (data) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data
                    .map((a) => ChoiceChip(
                          label: Text('${a.name} (${a.currency})'),
                          selected: _selectedAccount?.id == a.id,
                          onSelected: (_) => setState(() => _selectedAccount = a),
                        ))
                    .toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            Text('Ciclo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _CycleType.values.map((c) {
                return ChoiceChip(
                  label: Text(_cycleLabels[c]!),
                  selected: _cycleType == c,
                  onSelected: (_) => setState(() => _cycleType = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_cycleType == _CycleType.monthlyDay)
              TextField(
                controller: _cycleDayController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Día del mes',
                  hintText: '1-31',
                ),
              )
            else
              TextField(
                controller: _intervalDaysController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cada cuántos días',
                  hintText: 'ej: 30',
                ),
              ),
            const SizedBox(height: 24),
            Text('Fecha de inicio', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
              child: Text(
                '${_startDate.day.toString().padLeft(2, '0')}/${_startDate.month.toString().padLeft(2, '0')}/${_startDate.year}',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _monthsToGenerateController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Meses a generar'),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
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
