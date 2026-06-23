import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../core/utils/account_style.dart';
import '../../core/utils/currency_format.dart';
import '../../data/models/account.dart';

const _typeLabels = {
  AccountType.cash: 'Efectivo',
  AccountType.creditCard: 'Tarjeta de crédito',
  AccountType.investment: 'Inversión',
  AccountType.savingsWallet: 'Cuentas y Billeteras',
};

const _typeValues = {
  AccountType.cash: 'cash',
  AccountType.creditCard: 'credit_card',
  AccountType.investment: 'investment',
  AccountType.savingsWallet: 'savings_wallet',
};

class AddAccountScreen extends ConsumerStatefulWidget {
  final Account? account;

  const AddAccountScreen({super.key, this.account});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  late final _nameController = TextEditingController(text: widget.account?.name ?? '');
  late final _balanceController = TextEditingController(
    text: widget.account == null ? '' : widget.account!.initialBalance.toString(),
  );
  late final _closingDayController = TextEditingController(
    text: widget.account?.closingDay?.toString() ?? '',
  );
  late final _dueDayController = TextEditingController(
    text: widget.account?.dueDay?.toString() ?? '',
  );
  late AccountType _selectedType = widget.account?.type ?? AccountType.cash;
  late String _selectedCurrency = widget.account?.currency ?? 'ARS';
  bool _saving = false;
  bool _deleting = false;

  bool get _isEditing => widget.account != null;
  bool get _isCreditCard => _selectedType == AccountType.creditCard;

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _closingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Ingresá un nombre');
      return;
    }

    double? balance;
    if (!_isEditing) {
      final balanceText = _balanceController.text.trim().replaceAll(',', '.');
      balance = balanceText.isEmpty ? 0.0 : double.tryParse(balanceText);
      if (balance == null) {
        _showError('Ingresá un saldo inicial válido');
        return;
      }
    }

    int? closingDay;
    int? dueDay;
    if (_isCreditCard) {
      closingDay = int.tryParse(_closingDayController.text.trim());
      dueDay = int.tryParse(_dueDayController.text.trim());
      if (closingDay == null || closingDay < 1 || closingDay > 31) {
        _showError('Ingresá un día de cierre válido (1-31)');
        return;
      }
      if (dueDay == null || dueDay < 1 || dueDay > 31) {
        _showError('Ingresá un día de vencimiento válido (1-31)');
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final payload = {
        'name': name,
        'type': _typeValues[_selectedType],
        'currency': _selectedCurrency,
        'closing_day': closingDay,
        'due_day': dueDay,
      };
      if (_isEditing) {
        await supabase.from('accounts').update(payload).eq('id', widget.account!.id);
      } else {
        final userId = supabase.auth.currentUser!.id;
        await supabase.from('accounts').insert({
          'user_id': userId,
          ...payload,
          'current_balance': balance,
          'initial_balance': balance,
        });
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
        title: const Text('Eliminar cuenta'),
        content: Text('¿Eliminar "${widget.account!.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await supabase.from('accounts').delete().eq('id', widget.account!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo eliminar (¿tiene movimientos asociados?): $e');
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
        title: Text(_isEditing ? 'Editar cuenta' : 'Nueva cuenta'),
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: 24),
            Text('Tipo', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccountType.values.map((t) {
                final style = accountStyleFor(t);
                final selected = _selectedType == t;
                return ChoiceChip(
                  avatar: Icon(style.icon, color: selected ? null : style.color, size: 18),
                  label: Text(_typeLabels[t]!),
                  selected: selected,
                  selectedColor: style.color.withValues(alpha: 0.25),
                  onSelected: (_) => setState(() => _selectedType = t),
                );
              }).toList(),
            ),
            if (_isCreditCard) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _closingDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Día de cierre',
                        hintText: '1-31',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _dueDayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Día de vencimiento',
                        hintText: '1-31',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Text('Moneda', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['ARS', 'USD'].map((c) {
                return ChoiceChip(
                  label: Text(c),
                  selected: _selectedCurrency == c,
                  onSelected: (_) => setState(() => _selectedCurrency = c),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            if (_isEditing)
              Text(
                'Saldo actual: ${formatCurrency(widget.account!.currentBalance, widget.account!.currency)}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              TextField(
                controller: _balanceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Saldo inicial (opcional)',
                  hintText: '0',
                ),
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
