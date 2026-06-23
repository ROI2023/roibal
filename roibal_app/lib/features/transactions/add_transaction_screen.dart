import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/account_style.dart';
import '../../core/utils/credit_card_dates.dart';
import '../../core/utils/receipt_scanner.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/providers/finance_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final CategoryType type;

  const AddTransactionScreen({super.key, required this.type});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _installmentsController = TextEditingController(text: '1');
  Category? _selectedCategory;
  Account? _selectedAccount;
  bool _saving = false;

  bool get _isIncome => widget.type == CategoryType.income;

  bool get _isCreditCardPurchase =>
      !_isIncome && _selectedAccount?.type == AccountType.creditCard;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _installmentsController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
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

    var installments = 1;
    if (_isCreditCardPurchase) {
      installments = int.tryParse(_installmentsController.text.trim()) ?? 0;
      if (installments < 1) {
        _showError('Ingresá una cantidad de cuotas válida');
        return;
      }
      if (_selectedAccount!.closingDay == null || _selectedAccount!.dueDay == null) {
        _showError('Esa tarjeta no tiene día de cierre/vencimiento configurado');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final transaction = await supabase
          .from('transactions')
          .insert({
            'user_id': userId,
            'description': _descriptionController.text.trim().isEmpty
                ? _selectedCategory!.name
                : _descriptionController.text.trim(),
            'category_id': _selectedCategory!.id,
            'currency': _selectedAccount!.currency,
            'total_amount': amount,
            'transaction_date': now.toIso8601String(),
          })
          .select()
          .single();

      if (_isCreditCardPurchase) {
        final movements = <Map<String, dynamic>>[];
        final baseCents = (amount * 100 / installments).floor();
        final remainderCents = (amount * 100).round() - baseCents * installments;
        for (var i = 1; i <= installments; i++) {
          final cents = baseCents + (i == installments ? remainderCents : 0);
          final dueDate = creditCardInstallmentDueDate(
            purchaseDate: now,
            closingDay: _selectedAccount!.closingDay!,
            dueDay: _selectedAccount!.dueDay!,
            installmentNumber: i,
          );
          movements.add({
            'user_id': userId,
            'transaction_id': transaction['id'],
            'account_id': _selectedAccount!.id,
            'currency': _selectedAccount!.currency,
            'amount': -(cents / 100),
            'installment_number': i,
            'total_installments': installments,
            'due_date': DateTime(dueDate.year, dueDate.month, dueDate.day).toIso8601String(),
            'status': 'pending',
          });
        }
        await supabase.from('transaction_movements').insert(movements);
      } else {
        await supabase.from('transaction_movements').insert({
          'user_id': userId,
          'transaction_id': transaction['id'],
          'account_id': _selectedAccount!.id,
          'currency': _selectedAccount!.currency,
          'amount': _isIncome ? amount : -amount,
          'installment_number': 1,
          'total_installments': 1,
          'due_date': DateTime(now.year, now.month, now.day).toIso8601String(),
          'status': 'paid',
          'paid_date': now.toIso8601String(),
        });
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _scanReceipt() async {
    final result = await scanReceipt(context);
    if (result == null || !mounted) return;
    setState(() {
      if (result.amount != null) {
        _amountController.text = result.amount!.toStringAsFixed(2);
      }
      if (result.description != null && _descriptionController.text.trim().isEmpty) {
        _descriptionController.text = result.description!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final categories =
        ref.watch(_isIncome ? incomeCategoriesProvider : expenseCategoriesProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isIncome ? 'Registrar ingreso' : 'Registrar gasto')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.displaySmall,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(hintText: '0'),
            ),
            if (!_isIncome) ...[
              const SizedBox(height: 8),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _scanReceipt,
                  icon: const Icon(Icons.document_scanner_outlined),
                  label: const Text('Escanear ticket'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
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
                children: data.map((a) {
                  final style = accountStyleFor(a.type);
                  final selected = _selectedAccount?.id == a.id;
                  return ChoiceChip(
                    avatar: Icon(
                      style.icon,
                      color: selected ? null : style.color,
                      size: 18,
                    ),
                    label: Text('${a.name} (${a.currency})'),
                    selected: selected,
                    selectedColor: style.color.withValues(alpha: 0.25),
                    onSelected: (_) => setState(() => _selectedAccount = a),
                  );
                }).toList(),
              ),
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            if (_isCreditCardPurchase) ...[
              const SizedBox(height: 24),
              TextField(
                controller: _installmentsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Cantidad de cuotas'),
              ),
            ],
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
