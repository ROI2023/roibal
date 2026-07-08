import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/group_event.dart';
import '../../data/models/group_expense.dart';
import '../../data/models/group_member.dart';
import '../../data/models/group_member_share.dart';
import '../../data/models/group_partial_payment.dart';
import '../../data/models/group_settlement.dart';
import '../../data/providers/group_providers.dart';
import 'utils/debt_simplifier.dart';
import 'utils/group_balance_calculator.dart';

class SettlementScreen extends ConsumerStatefulWidget {
  final String eventId;
  const SettlementScreen({super.key, required this.eventId});

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen> {
  bool _closing = false;

  void _invalidate() {
    ref.invalidate(groupEventProvider(widget.eventId));
    ref.invalidate(groupSettlementsProvider(widget.eventId));
    ref.invalidate(groupMembersProvider(widget.eventId));
    ref.invalidate(groupExpensesProvider(widget.eventId));
    ref.invalidate(groupPartialPaymentsProvider(widget.eventId));
    ref.invalidate(groupMemberSharesProvider(widget.eventId));
  }

  // -------------------------------------------------------------------------
  // Cerrar el evento: calcular balances y generar settlements
  // -------------------------------------------------------------------------
  Future<void> _closeAndSettle(
    GroupEvent event,
    List<GroupMember> members,
    List<GroupExpense> expenses,
    List<GroupMemberShare> shares,
    List<GroupPartialPayment> payments,
  ) async {
    // Validar que los shares sumen 100 por cada moneda
    final currencies = expenses.map((e) => e.currency).toSet();
    final accepted = members.where((m) => m.status == GroupMemberStatus.accepted).toList();

    for (final currency in currencies) {
      final currencyKey =
          event.splitMode == SplitMode.baseCurrency ? event.baseCurrency : currency;
      double total = 0;
      for (final m in accepted) {
        final share = shares
            .where((s) => s.groupMemberId == m.id && s.currency == currencyKey)
            .firstOrNull;
        total += share?.percentage ?? 0;
      }
      if ((total - 100).abs() > 0.05) {
        _showError(
            'Los porcentajes de $currency no suman 100 (suman ${total.toStringAsFixed(1)}). '
            'Ajustá los % en la pestaña "Miembros & %" antes de cerrar.');
        return;
      }
    }

    setState(() => _closing = true);
    try {
      final result = calculateGroupBalance(
        members: members,
        expenses: expenses,
        shares: shares,
        partialPayments: payments,
        splitMode: event.splitMode,
        baseCurrency: event.baseCurrency,
      );

      final settlementRows = <Map<String, dynamic>>[];
      for (final currency in result.currencies) {
        final nets = result.netBalancesFor(currency);
        final debtSettlements = simplifyDebts(nets);
        for (final ds in debtSettlements) {
          settlementRows.add({
            'event_id': widget.eventId,
            'from_member_id': ds.fromMemberId,
            'to_member_id': ds.toMemberId,
            'currency': currency,
            'amount': ds.amount,
            'status': 'suggested',
          });
        }
      }

      if (settlementRows.isNotEmpty) {
        await supabase.from('group_settlements').insert(settlementRows);
      }

      await supabase
          .from('group_events')
          .update({'status': 'pending'})
          .eq('id', widget.eventId);

      _invalidate();
    } catch (e) {
      _showError('Error al cerrar el evento: $e');
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  // -------------------------------------------------------------------------
  // Confirmar lado propio de un settlement
  // -------------------------------------------------------------------------
  Future<void> _confirmSettlement(
      BuildContext context, GroupSettlement s, bool isFrom) async {
    final accounts = await supabase
        .from('accounts')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .order('created_at');

    if (!context.mounted) return;

    String? selectedAccountId;
    String? selectedAccountCurrency;
    final rateController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final crossCurrency = selectedAccountCurrency != null &&
              selectedAccountCurrency != s.currency;
          final rateOk = !crossCurrency ||
              (double.tryParse(rateController.text.replaceAll(',', '.')) ?? 0) > 0;

          return AlertDialog(
            title: Text(isFrom ? 'Confirmar: yo pagué' : 'Confirmar: yo recibí'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isFrom
                      ? 'Confirmás que pagaste ${s.currency} ${s.amount.toStringAsFixed(2)} '
                          'a ${s.toMember?.label ?? '?'}.'
                      : 'Confirmás que recibiste ${s.currency} ${s.amount.toStringAsFixed(2)} '
                          'de ${s.fromMember?.label ?? '?'}.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Cuenta personal'),
                  items: (accounts as List)
                      .map((a) => DropdownMenuItem<String>(
                            value: a['id'] as String,
                            child: Text('${a['name']} (${a['currency']})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    final acct = (accounts as List)
                        .firstWhere((a) => a['id'] == v);
                    setS(() {
                      selectedAccountId = v;
                      selectedAccountCurrency = acct['currency'] as String;
                      rateController.clear();
                    });
                  },
                ),
                if (crossCurrency) ...[
                  const SizedBox(height: 12),
                  Text(
                    'La cuenta es en $selectedAccountCurrency pero la deuda '
                    'es en ${s.currency}. Ingresá el tipo de cambio:',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: rateController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          '1 ${s.currency} = ? $selectedAccountCurrency',
                      hintText: 'ej: 1200',
                    ),
                    onChanged: (_) => setS(() {}),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: selectedAccountId == null || !rateOk
                    ? null
                    : () => Navigator.pop(ctx, true),
                child: const Text('Confirmar'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true || selectedAccountId == null || !context.mounted) return;

    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final label = isFrom
          ? 'Liquidación grupal a ${s.toMember?.label ?? ''}'
          : 'Liquidación grupal de ${s.fromMember?.label ?? ''}';
      final txAmount = isFrom ? -s.amount : s.amount;

      // Cross-currency: si la cuenta es distinta moneda, convertir el monto
      final accountCurrency = selectedAccountCurrency ?? s.currency;
      final rate = accountCurrency != s.currency
          ? (double.tryParse(rateController.text.replaceAll(',', '.')) ?? 1.0)
          : 1.0;
      final movementAmount = txAmount * rate;
      final movementCurrency = accountCurrency;

      final txRow = await supabase
          .from('transactions')
          .insert({
            'user_id': userId,
            'description': label,
            'currency': s.currency,
            'total_amount': s.amount,
            'transaction_date': now.toIso8601String(),
            'is_transfer': true,
          })
          .select()
          .single();

      await supabase.from('transaction_movements').insert({
        'user_id': userId,
        'transaction_id': txRow['id'],
        'account_id': selectedAccountId,
        'currency': movementCurrency,
        'amount': movementAmount,
        'installment_number': 1,
        'total_installments': 1,
        'due_date': now.toIso8601String().split('T').first,
        'status': 'paid',
        'paid_date': now.toIso8601String(),
      });

      // Preparar update del settlement
      final otherConfirmed = isFrom ? s.toConfirmedAt : s.fromConfirmedAt;
      final bothConfirmed = otherConfirmed != null;

      await supabase.from('group_settlements').update({
        if (isFrom) 'from_confirmed_at': now.toIso8601String(),
        if (isFrom) 'from_personal_transaction_id': txRow['id'],
        if (!isFrom) 'to_confirmed_at': now.toIso8601String(),
        if (!isFrom) 'to_personal_transaction_id': txRow['id'],
        if (bothConfirmed) 'confirmed_at': now.toIso8601String(),
        if (bothConfirmed) 'status': 'confirmed',
      }).eq('id', s.id);

      // Verificar si todos los settlements quedaron confirmados
      if (bothConfirmed) await _checkBalanced();

      _invalidate();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _checkBalanced() async {
    final remaining = await supabase
        .from('group_settlements')
        .select('id')
        .eq('event_id', widget.eventId)
        .eq('status', 'suggested');
    if ((remaining as List).isEmpty) {
      await supabase
          .from('group_events')
          .update({'status': 'balanced'})
          .eq('id', widget.eventId);
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  // -------------------------------------------------------------------------
  // Exportar PDF
  // -------------------------------------------------------------------------
  Future<void> _exportPdf(
    GroupEvent event,
    List<GroupMember> members,
    List<GroupExpense> expenses,
    List<GroupSettlement> settlements,
  ) async {
    final doc = pw.Document();
    final dateFmt = DateFormat('dd/MM/yyyy');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(event.name,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          ),
          pw.Text(
              'Desde ${dateFmt.format(event.startDate)}'
              '${event.endDate != null ? ' hasta ${dateFmt.format(event.endDate!)}' : ''}'),
          pw.Text('Moneda base: ${event.baseCurrency}'),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Gastos'),
          pw.TableHelper.fromTextArray(
            headers: ['Fecha', 'Descripción', 'Quién pagó', 'Moneda', 'Monto'],
            data: expenses
                .map((e) => [
                      dateFmt.format(e.expenseDate),
                      e.description,
                      e.paidByMember?.label ?? '?',
                      e.currency,
                      e.amount.toStringAsFixed(2),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Liquidaciones'),
          pw.TableHelper.fromTextArray(
            headers: ['De', 'A', 'Moneda', 'Monto', 'Estado'],
            data: settlements
                .map((s) => [
                      s.fromMember?.label ?? '?',
                      s.toMember?.label ?? '?',
                      s.currency,
                      s.amount.toStringAsFixed(2),
                      s.status == GroupSettlementStatus.confirmed ? 'Confirmado' : 'Sugerido',
                    ])
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name: '${event.name} - Liquidación.pdf',
    );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(groupEventProvider(widget.eventId));
    final membersAsync = ref.watch(groupMembersProvider(widget.eventId));
    final expensesAsync = ref.watch(groupExpensesProvider(widget.eventId));
    final sharesAsync = ref.watch(groupMemberSharesProvider(widget.eventId));
    final paymentsAsync = ref.watch(groupPartialPaymentsProvider(widget.eventId));
    final settlementsAsync = ref.watch(groupSettlementsProvider(widget.eventId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquidación'),
        actions: [
          settlementsAsync.maybeWhen(
            data: (settlements) => IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Exportar PDF',
              onPressed: eventAsync.value == null || membersAsync.value == null
                  ? null
                  : () => _exportPdf(
                        eventAsync.value!,
                        membersAsync.value!,
                        expensesAsync.value ?? [],
                        settlements,
                      ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: eventAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (event) {
          if (event == null) return const Center(child: Text('Evento no encontrado'));

          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (members) => expensesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (expenses) => sharesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (shares) => paymentsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (payments) => settlementsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (settlements) => _SettlementBody(
                      event: event,
                      members: members,
                      expenses: expenses,
                      shares: shares,
                      payments: payments,
                      settlements: settlements,
                      closing: _closing,
                      onClose: () => _closeAndSettle(event, members, expenses, shares, payments),
                      onConfirm: (s, isFrom) => _confirmSettlement(context, s, isFrom),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body separado para mantener build legible
// ---------------------------------------------------------------------------
class _SettlementBody extends StatelessWidget {
  final GroupEvent event;
  final List<GroupMember> members;
  final List<GroupExpense> expenses;
  final List<GroupMemberShare> shares;
  final List<GroupPartialPayment> payments;
  final List<GroupSettlement> settlements;
  final bool closing;
  final VoidCallback onClose;
  final Future<void> Function(GroupSettlement, bool isFrom) onConfirm;

  const _SettlementBody({
    required this.event,
    required this.members,
    required this.expenses,
    required this.shares,
    required this.payments,
    required this.settlements,
    required this.closing,
    required this.onClose,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final myUserId = supabase.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: () async {},
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado del evento
          _StatusBanner(event.status),
          const SizedBox(height: 16),

          // Botón de cerrar (solo si está abierto)
          if (event.status == GroupEventStatus.open) ...[
            FilledButton.icon(
              onPressed: closing ? null : onClose,
              icon: closing
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_outline),
              label: const Text('Cerrar y generar liquidación'),
            ),
            const SizedBox(height: 24),
          ],

          // Lista de settlements
          if (settlements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('No hay liquidaciones generadas todavía.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else ...[
            Text('Liquidaciones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...settlements.map((s) {
              final isFrom = s.fromMember?.userId == myUserId;
              final isTo = s.toMember?.userId == myUserId;
              final myFromConfirmed = s.fromConfirmedAt != null;
              final myToConfirmed = s.toConfirmedAt != null;
              final canConfirmFrom = isFrom && !myFromConfirmed;
              final canConfirmTo = isTo && !myToConfirmed;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${s.fromMember?.label ?? '?'}  →  ${s.toMember?.label ?? '?'}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${s.currency} ${s.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _ConfirmChip(
                              label: s.fromMember?.label ?? '?',
                              confirmed: myFromConfirmed),
                          const SizedBox(width: 8),
                          _ConfirmChip(
                              label: s.toMember?.label ?? '?',
                              confirmed: myToConfirmed),
                        ],
                      ),
                      if (canConfirmFrom || canConfirmTo) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (canConfirmFrom)
                              FilledButton.tonal(
                                onPressed: () => onConfirm(s, true),
                                child: const Text('Confirmar: yo pagué'),
                              ),
                            if (canConfirmTo) ...[
                              if (canConfirmFrom) const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: () => onConfirm(s, false),
                                child: const Text('Confirmar: yo recibí'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final GroupEventStatus status;
  const _StatusBanner(this.status);

  @override
  Widget build(BuildContext context) {
    final (msg, color, icon) = switch (status) {
      GroupEventStatus.open => (
          'El evento está abierto. Podés cerrar y generar la liquidación.',
          Colors.blue,
          Icons.lock_open,
        ),
      GroupEventStatus.pending => (
          'Evento cerrado. Cada miembro debe confirmar su parte.',
          Colors.orange,
          Icons.pending_outlined,
        ),
      GroupEventStatus.balanced => (
          'Todas las liquidaciones están confirmadas. ¡Saldado!',
          Colors.green,
          Icons.check_circle_outline,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }
}

class _ConfirmChip extends StatelessWidget {
  final String label;
  final bool confirmed;
  const _ConfirmChip({required this.label, required this.confirmed});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
        size: 14,
        color: confirmed ? Colors.green : Colors.grey,
      ),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: confirmed
          ? Colors.green.withValues(alpha: 0.1)
          : Colors.grey.withValues(alpha: 0.1),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}
