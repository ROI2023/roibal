import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/group_member.dart';
import '../../data/providers/group_providers.dart';

const _kCurrencies = ['ARS', 'USD', 'EUR', 'BRL', 'UYU', 'CLP'];

class AddPartialPaymentScreen extends ConsumerStatefulWidget {
  final String eventId;
  const AddPartialPaymentScreen({super.key, required this.eventId});

  @override
  ConsumerState<AddPartialPaymentScreen> createState() => _AddPartialPaymentScreenState();
}

class _AddPartialPaymentScreenState extends ConsumerState<AddPartialPaymentScreen> {
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _currency = 'ARS';
  GroupMember? _toMember;
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
    if (_toMember == null) {
      _showError('Elegí a quién le pagás');
      return;
    }
    if (_toMember!.id == myMember.id) {
      _showError('No podés pagarte a vos mismo');
      return;
    }

    setState(() => _saving = true);
    try {
      await supabase.from('group_partial_payments').insert({
        'event_id': widget.eventId,
        'from_member_id': myMember.id,
        'to_member_id': _toMember!.id,
        'currency': _currency,
        'amount': amount,
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'payment_date': DateTime.now().toIso8601String(),
      });

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      _showError('No se pudo registrar: $e');
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
    final membersAsync = ref.watch(groupMembersProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar pago parcial')),
      body: myMemberAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (myMember) {
          if (myMember == null) {
            return const Center(child: Text('No sos miembro de este evento'));
          }
          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (members) {
              final others = members
                  .where((m) =>
                      m.id != myMember.id && m.status == GroupMemberStatus.accepted)
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Estás registrando que le pagaste a alguien del grupo.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cada parte deberá confirmar su lado para que impacte en las cuentas personales.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: Theme.of(context).textTheme.displaySmall,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(hintText: '0'),
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
                  Text('Le pagué a:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (others.isEmpty)
                    const Text('No hay otros miembros en el evento.')
                  else
                    RadioGroup<GroupMember>(
                      groupValue: _toMember,
                      onChanged: (v) => setState(() => _toMember = v),
                      child: Column(
                        children: others
                            .map((m) => RadioListTile<GroupMember>(
                                  value: m,
                                  title: Text(m.label),
                                  contentPadding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _saving ? null : () => _save(myMember),
                    child: _saving
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Registrar pago'),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
