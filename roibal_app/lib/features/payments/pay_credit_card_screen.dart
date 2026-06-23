import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/category_icons.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/projected_movement.dart';
import '../../data/providers/finance_providers.dart';

class PayCreditCardScreen extends ConsumerStatefulWidget {
  const PayCreditCardScreen({super.key});

  @override
  ConsumerState<PayCreditCardScreen> createState() => _PayCreditCardScreenState();
}

class _PayCreditCardScreenState extends ConsumerState<PayCreditCardScreen> {
  Account? _selectedCard;
  String? _autoSelectedForAccountId;
  final Set<String> _selectedMovementIds = {};
  final _totalPaidController = TextEditingController();
  Category? _financeCategory;
  final List<Account?> _sourceAccounts = [null];
  final List<TextEditingController> _sourceAmountControllers = [TextEditingController()];
  bool _saving = false;

  @override
  void dispose() {
    _totalPaidController.dispose();
    for (final c in _sourceAmountControllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _parse(String text) => double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;

  void _addSourceRow() {
    setState(() {
      _sourceAccounts.add(null);
      _sourceAmountControllers.add(TextEditingController());
    });
  }

  void _removeSourceRow(int index) {
    setState(() {
      _sourceAccounts.removeAt(index);
      _sourceAmountControllers.removeAt(index).dispose();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save(double subtotal, double totalPaid, double diff) async {
    if (_selectedCard == null) {
      _showError('Elegí una tarjeta');
      return;
    }
    if (totalPaid <= 0) {
      _showError('Ingresá el importe total a pagar');
      return;
    }
    if (diff < -0.005) {
      _showError('El importe es menor a los ítems seleccionados: deseleccioná alguno o ajustá el importe');
      return;
    }
    if (diff > 0.005 && _financeCategory == null) {
      _showError('Elegí una categoría para los intereses/gastos de la diferencia');
      return;
    }

    final sources = <(Account, double)>[];
    for (var i = 0; i < _sourceAccounts.length; i++) {
      final account = _sourceAccounts[i];
      final amount = _parse(_sourceAmountControllers[i].text);
      if (account == null && amount == 0) continue;
      if (account == null) {
        _showError('Elegí la cuenta de origen en todas las filas');
        return;
      }
      if (amount <= 0) {
        _showError('Ingresá un importe válido para ${account.name}');
        return;
      }
      if (account.currency != _selectedCard!.currency) {
        _showError('${account.name} debe estar en ${_selectedCard!.currency}, igual que la tarjeta');
        return;
      }
      sources.add((account, amount));
    }
    if (sources.isEmpty) {
      _showError('Agregá al menos una cuenta de origen');
      return;
    }
    final sourceTotal = sources.fold<double>(0, (sum, s) => sum + s.$2);
    if ((sourceTotal - totalPaid).abs() > 0.01) {
      _showError(
        'La suma de las cuentas de origen (${formatCurrency(sourceTotal, _selectedCard!.currency)}) '
        'debe ser igual al importe total a pagar (${formatCurrency(totalPaid, _selectedCard!.currency)})',
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      for (final id in _selectedMovementIds) {
        await supabase
            .from('transaction_movements')
            .update({'status': 'paid', 'paid_date': now.toIso8601String()})
            .eq('id', id);
      }

      if (diff > 0.005) {
        final financeTransaction = await supabase
            .from('transactions')
            .insert({
              'user_id': userId,
              'description': 'Intereses y gastos de tarjeta',
              'category_id': _financeCategory!.id,
              'is_transfer': false,
              'currency': _selectedCard!.currency,
              'total_amount': diff,
              'transaction_date': now.toIso8601String(),
            })
            .select()
            .single();
        await supabase.from('transaction_movements').insert({
          'user_id': userId,
          'transaction_id': financeTransaction['id'],
          'account_id': _selectedCard!.id,
          'currency': _selectedCard!.currency,
          'amount': -diff,
          'installment_number': 1,
          'total_installments': 1,
          'due_date': today,
          'status': 'paid',
          'paid_date': now.toIso8601String(),
        });
      }

      final transferTransaction = await supabase
          .from('transactions')
          .insert({
            'user_id': userId,
            'description': 'Pago tarjeta ${_selectedCard!.name}',
            'category_id': null,
            'is_transfer': true,
            'currency': _selectedCard!.currency,
            'total_amount': totalPaid,
            'transaction_date': now.toIso8601String(),
          })
          .select()
          .single();

      final movements = <Map<String, dynamic>>[
        for (final (account, amount) in sources)
          {
            'user_id': userId,
            'transaction_id': transferTransaction['id'],
            'account_id': account.id,
            'currency': account.currency,
            'amount': -amount,
            'installment_number': 1,
            'total_installments': 1,
            'due_date': today,
            'status': 'paid',
            'paid_date': now.toIso8601String(),
          },
        {
          'user_id': userId,
          'transaction_id': transferTransaction['id'],
          'account_id': _selectedCard!.id,
          'currency': _selectedCard!.currency,
          'amount': totalPaid,
          'installment_number': 1,
          'total_installments': 1,
          'due_date': today,
          'status': 'paid',
          'paid_date': now.toIso8601String(),
        },
      ];
      await supabase.from('transaction_movements').insert(movements);

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo registrar el pago: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final pendingMovements = _selectedCard == null
        ? const AsyncValue<List<ProjectedMovement>>.data([])
        : ref.watch(pendingMovementsForAccountProvider(_selectedCard!.id));
    final expenseCategories = ref.watch(expenseCategoriesProvider);

    final subtotal = pendingMovements.maybeWhen(
      data: (movements) => movements
          .where((m) => _selectedMovementIds.contains(m.id))
          .fold<double>(0, (sum, m) => sum + m.amount.abs()),
      orElse: () => 0.0,
    );
    final totalPaid = _parse(_totalPaidController.text);
    final diff = totalPaid - subtotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar tarjeta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text('Tarjeta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            accounts.when(
              data: (data) {
                final cards = data.where((a) => a.type == AccountType.creditCard).toList();
                if (cards.isEmpty) {
                  return const Text('No tenés tarjetas de crédito cargadas');
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cards.map((a) {
                    return ChoiceChip(
                      label: Text(a.name),
                      selected: _selectedCard?.id == a.id,
                      onSelected: (_) => setState(() {
                        _selectedCard = a;
                        _selectedMovementIds.clear();
                      }),
                    );
                  }).toList(),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            if (_selectedCard != null) ...[
              const SizedBox(height: 24),
              Text('Ítems pendientes a saldar', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              pendingMovements.when(
                data: (movements) {
                  if (_autoSelectedForAccountId != _selectedCard!.id) {
                    _autoSelectedForAccountId = _selectedCard!.id;
                    _selectedMovementIds
                      ..clear()
                      ..addAll(movements.map((m) => m.id));
                    final autoSelectedSubtotal =
                        movements.fold<double>(0, (sum, m) => sum + m.amount.abs());
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        setState(() {
                          _totalPaidController.text = autoSelectedSubtotal.toStringAsFixed(2);
                        });
                      }
                    });
                  }
                  if (movements.isEmpty) {
                    return const Text('Esta tarjeta no tiene ítems pendientes');
                  }
                  return Column(
                    children: movements.map((m) {
                      final installmentSuffix = m.totalInstallments > 1
                          ? ' (${m.installmentNumber}/${m.totalInstallments})'
                          : '';
                      return CheckboxListTile(
                        value: _selectedMovementIds.contains(m.id),
                        onChanged: (checked) => setState(() {
                          if (checked == true) {
                            _selectedMovementIds.add(m.id);
                          } else {
                            _selectedMovementIds.remove(m.id);
                          }
                        }),
                        secondary: Icon(categoryIconFor(m.category?.iconName)),
                        title: Text('${m.description}$installmentSuffix'),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(m.dueDate)),
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                      );
                    }).toList(),
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Subtotal ítems: ${formatCurrency(subtotal, _selectedCard!.currency)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _totalPaidController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Importe total a pagar',
                  helperText: 'Puede ser mayor al subtotal si incluye intereses, gastos o impuestos',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (diff > 0.005) ...[
                const SizedBox(height: 16),
                Text(
                  'Diferencia (intereses/gastos): ${formatCurrency(diff, _selectedCard!.currency)}',
                  style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('Categoría para la diferencia', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                expenseCategories.when(
                  data: (data) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: data.map((c) {
                      return ChoiceChip(
                        label: Text(c.name),
                        selected: _financeCategory?.id == c.id,
                        onSelected: (_) => setState(() => _financeCategory = c),
                      );
                    }).toList(),
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                ),
              ] else if (diff < -0.005) ...[
                const SizedBox(height: 16),
                Text(
                  'El importe es menor al subtotal seleccionado por '
                  '${formatCurrency(-diff, _selectedCard!.currency)}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              Text('Cuentas de origen', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              accounts.when(
                data: (data) {
                  final sourceOptions =
                      data.where((a) => a.type != AccountType.creditCard).toList();
                  return Column(
                    children: [
                      for (var i = 0; i < _sourceAccounts.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<Account>(
                                  initialValue: _sourceAccounts[i],
                                  decoration: const InputDecoration(labelText: 'Cuenta'),
                                  items: sourceOptions
                                      .map((a) => DropdownMenuItem(
                                            value: a,
                                            child: Text('${a.name} (${a.currency})'),
                                          ))
                                      .toList(),
                                  onChanged: (a) => setState(() => _sourceAccounts[i] = a),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _sourceAmountControllers[i],
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(labelText: 'Importe'),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              if (_sourceAccounts.length > 1)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _removeSourceRow(i),
                                ),
                            ],
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addSourceRow,
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar otra cuenta'),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : () => _save(subtotal, totalPaid, diff),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Registrar pago'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
