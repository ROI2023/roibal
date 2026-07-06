import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/account.dart';
import '../../data/models/category.dart';
import '../../data/models/group_member.dart';
import '../../data/providers/finance_providers.dart';
import '../../data/providers/group_providers.dart';

const _kCurrencies = ['ARS', 'USD', 'EUR', 'BRL', 'UYU', 'CLP'];

class AddGroupExpenseScreen extends ConsumerStatefulWidget {
  final String eventId;
  const AddGroupExpenseScreen({super.key, required this.eventId});

  @override
  ConsumerState<AddGroupExpenseScreen> createState() => _AddGroupExpenseScreenState();
}

class _AddGroupExpenseScreenState extends ConsumerState<AddGroupExpenseScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _currency = 'ARS';
  Category? _selectedCategory;
  Account? _selectedAccount;
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save(GroupMember myMember) async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      _showError('Ingresá un monto válido');
      return;
    }
    if (_selectedAccount == null) {
      _showError('Elegí una cuenta personal');
      return;
    }

    setState(() => _saving = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final description = _descriptionController.text.trim().isEmpty
          ? (_selectedCategory?.name ?? 'Gasto grupal')
          : _descriptionController.text.trim();

      // 1. Crear transaction personal
      final txRow = await supabase
          .from('transactions')
          .insert({
            'user_id': userId,
            'description': description,
            'category_id': _selectedCategory?.id,
            'currency': _currency,
            'total_amount': amount,
            'transaction_date': now.toIso8601String(),
            'is_transfer': false,
          })
          .select()
          .single();

      // 2. Crear transaction_movement (débito en cuenta elegida)
      await supabase.from('transaction_movements').insert({
        'user_id': userId,
        'transaction_id': txRow['id'],
        'account_id': _selectedAccount!.id,
        'currency': _currency,
        'amount': -amount,
        'installment_number': 1,
        'total_installments': 1,
        'due_date': now.toIso8601String().split('T').first,
        'status': 'paid',
        'paid_date': now.toIso8601String(),
      });

      // 3. Crear group_expense vinculado
      await supabase.from('group_expenses').insert({
        'event_id': widget.eventId,
        'paid_by_member_id': myMember.id,
        'description': description,
        'category_id': _selectedCategory?.id,
        'currency': _currency,
        'amount': amount,
        'expense_date': now.toIso8601String(),
        'personal_transaction_id': txRow['id'],
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final myMemberAsync = ref.watch(myMemberProvider(widget.eventId));
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo gasto grupal')),
      body: myMemberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (myMember) {
          if (myMember == null) {
            return const Center(child: Text('No sos miembro de este evento'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(hintText: '0'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 24),
              Text('Moneda', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _kCurrencies
                    .map((c) => ChoiceChip(
                          label: Text(c),
                          selected: _currency == c,
                          onSelected: (_) => setState(() => _currency = c),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),
              Text('Categoría (opcional)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (cats) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cats
                      .map((c) => ChoiceChip(
                            label: Text(c.name),
                            selected: _selectedCategory?.id == c.id,
                            onSelected: (_) => setState(
                              () => _selectedCategory =
                                  _selectedCategory?.id == c.id ? null : c,
                            ),
                          ))
                      .toList(),
                ),
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
              const SizedBox(height: 24),
              Text('Cuenta personal (de dónde sale el dinero)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              accountsAsync.when(
                data: (accounts) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts
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
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : () => _save(myMember),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Registrar gasto'),
              ),
            ],
          );
        },
      ),
    );
  }
}
