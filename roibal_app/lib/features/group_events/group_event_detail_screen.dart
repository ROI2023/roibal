import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/supabase_config.dart';
import '../../data/models/group_event.dart';
import '../../data/models/group_expense.dart';
import '../../data/models/group_member.dart';
import '../../data/models/group_member_share.dart';
import '../../data/models/group_partial_payment.dart';
import '../../data/providers/group_providers.dart';
import 'utils/group_balance_calculator.dart';

// ---------------------------------------------------------------------------
// Pantalla principal con tabs
// ---------------------------------------------------------------------------

class GroupEventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;
  const GroupEventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<GroupEventDetailScreen> createState() => _GroupEventDetailScreenState();
}

class _GroupEventDetailScreenState extends ConsumerState<GroupEventDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _invalidateAll() {
    ref.invalidate(groupEventProvider(widget.eventId));
    ref.invalidate(groupExpensesProvider(widget.eventId));
    ref.invalidate(groupMembersProvider(widget.eventId));
    ref.invalidate(groupMemberSharesProvider(widget.eventId));
    ref.invalidate(groupPartialPaymentsProvider(widget.eventId));
    ref.invalidate(groupSettlementsProvider(widget.eventId));
  }

  Future<void> _reopenEvent() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir evento'),
        content: const Text(
          'Se borrarán las liquidaciones sugeridas (no confirmadas) y el evento vuelve a "Abierto".\n'
          'Los pagos ya confirmados se mantienen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reabrir')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      // Borrar settlements sugeridos (no confirmados)
      await supabase
          .from('group_settlements')
          .delete()
          .eq('event_id', widget.eventId)
          .eq('status', 'suggested');
      // Volver a 'open'
      await supabase
          .from('group_events')
          .update({'status': 'open'})
          .eq('id', widget.eventId);
      _invalidateAll();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(groupEventProvider(widget.eventId));

    return eventAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (event) {
        if (event == null) {
          return const Scaffold(body: Center(child: Text('Evento no encontrado')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(event.name),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Gastos'),
                Tab(text: 'Miembros & %'),
                Tab(text: 'Balance'),
              ],
            ),
            actions: [
              if (event.status == GroupEventStatus.pending)
                TextButton.icon(
                  onPressed: _reopenEvent,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Reabrir'),
                ),
              if (event.status == GroupEventStatus.pending ||
                  event.status == GroupEventStatus.balanced)
                IconButton(
                  icon: const Icon(Icons.receipt_long_outlined),
                  tooltip: 'Ver liquidación',
                  onPressed: () async {
                    await context.push('/groups/${widget.eventId}/settle');
                    _invalidateAll();
                  },
                ),
            ],
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _GastosTab(eventId: widget.eventId, event: event, onRefresh: _invalidateAll),
              _MembersTab(eventId: widget.eventId, event: event, onRefresh: _invalidateAll),
              _BalanceTab(eventId: widget.eventId, event: event),
            ],
          ),
          floatingActionButton: ListenableBuilder(
            listenable: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0 && event.status == GroupEventStatus.open) {
                return FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/groups/${widget.eventId}/expenses/new');
                    _invalidateAll();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Gasto'),
                );
              }
              if (_tabController.index == 2 && event.status == GroupEventStatus.open) {
                return FloatingActionButton.extended(
                  onPressed: () async {
                    await context.push('/groups/${widget.eventId}/settle');
                    _invalidateAll();
                  },
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Cerrar y liquidar'),
                  backgroundColor: Theme.of(context).colorScheme.tertiary,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Gastos
// ---------------------------------------------------------------------------

class _GastosTab extends ConsumerWidget {
  final String eventId;
  final GroupEvent event;
  final VoidCallback onRefresh;
  const _GastosTab({required this.eventId, required this.event, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(groupExpensesProvider(eventId));
    final paymentsAsync = ref.watch(groupPartialPaymentsProvider(eventId));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (expenses) => paymentsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (payments) {
            if (expenses.isEmpty && payments.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('No hay gastos todavía', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            // Mezclar gastos y pagos parciales ordenados por fecha
            final items = [
              ...expenses.map((e) => _FeedItem(date: e.expenseDate, expense: e)),
              ...payments.map((p) => _FeedItem(date: p.paymentDate, payment: p)),
            ]..sort((a, b) => b.date.compareTo(a.date));

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final item = items[i];
                if (item.expense != null) return _ExpenseTile(item.expense!);
                return _PartialPaymentTile(item.payment!, eventId: eventId, onRefresh: onRefresh);
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeedItem {
  final DateTime date;
  final GroupExpense? expense;
  final GroupPartialPayment? payment;
  _FeedItem({required this.date, this.expense, this.payment});
}

class _ExpenseTile extends StatelessWidget {
  final GroupExpense expense;
  const _ExpenseTile(this.expense);

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM');
    return ListTile(
      leading: CircleAvatar(child: Text(expense.paidByMember?.label[0].toUpperCase() ?? '?')),
      title: Text(expense.description),
      subtitle: Text('${expense.paidByMember?.label ?? '?'} · ${fmt.format(expense.expenseDate)}'),
      trailing: Text(
        '${expense.currency} ${expense.amount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PartialPaymentTile extends ConsumerWidget {
  final GroupPartialPayment payment;
  final String eventId;
  final VoidCallback onRefresh;
  const _PartialPaymentTile(this.payment, {required this.eventId, required this.onRefresh});

  Future<void> _confirm(BuildContext context, WidgetRef ref, bool isFrom) async {
    final accounts = await supabase
        .from('accounts')
        .select()
        .eq('user_id', supabase.auth.currentUser!.id)
        .order('created_at');

    if (!context.mounted) return;

    String? selectedAccountId;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isFrom ? 'Confirmar pago enviado' : 'Confirmar pago recibido'),
        content: StatefulBuilder(
          builder: (ctx, setS) => DropdownButtonFormField<String>(
            decoration: const InputDecoration(labelText: 'Cuenta personal'),
            items: (accounts as List)
                .map((a) => DropdownMenuItem<String>(
                      value: a['id'] as String,
                      child: Text('${a['name']} (${a['currency']})'),
                    ))
                .toList(),
            onChanged: (v) => setS(() => selectedAccountId = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: selectedAccountId == null ? null : () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (selectedAccountId == null || !context.mounted) return;

    try {
      final userId = supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final label = isFrom
          ? 'Pago grupal a ${payment.toMember?.label ?? ''}'
          : 'Cobro grupal de ${payment.fromMember?.label ?? ''}';
      final txAmount = isFrom ? -payment.amount : payment.amount;

      final txRow = await supabase
          .from('transactions')
          .insert({
            'user_id': userId,
            'description': label,
            'currency': payment.currency,
            'total_amount': payment.amount,
            'transaction_date': now.toIso8601String(),
            'is_transfer': true,
          })
          .select()
          .single();

      await supabase.from('transaction_movements').insert({
        'user_id': userId,
        'transaction_id': txRow['id'],
        'account_id': selectedAccountId,
        'currency': payment.currency,
        'amount': txAmount,
        'installment_number': 1,
        'total_installments': 1,
        'due_date': now.toIso8601String().split('T').first,
        'status': 'paid',
        'paid_date': now.toIso8601String(),
      });

      await supabase.from('group_partial_payments').update(
        isFrom
            ? {
                'from_confirmed_at': now.toIso8601String(),
                'from_personal_transaction_id': txRow['id'],
              }
            : {
                'to_confirmed_at': now.toIso8601String(),
                'to_personal_transaction_id': txRow['id'],
              },
      ).eq('id', payment.id);

      onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId = supabase.auth.currentUser?.id;
    final isFrom = payment.fromMember?.userId == myId;
    final isTo = payment.toMember?.userId == myId;
    final fmt = DateFormat('dd/MM');

    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.blueGrey,
        child: Icon(Icons.swap_horiz, color: Colors.white, size: 18),
      ),
      title: Text(
        '${payment.fromMember?.label ?? '?'} → ${payment.toMember?.label ?? '?'}',
      ),
      subtitle: Text(
        '${fmt.format(payment.paymentDate)}  '
        '${payment.isFullyConfirmed ? '✓ Confirmado' : '⏳ Pendiente de confirmación'}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('${payment.currency} ${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          if (!payment.isFullyConfirmed && (isFrom || isTo))
            TextButton(
              onPressed: () => _confirm(context, ref, isFrom),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                isFrom && payment.fromConfirmedAt == null
                    ? 'Confirmar envío'
                    : 'Confirmar recibo',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Miembros & Shares
// ---------------------------------------------------------------------------

class _MembersTab extends ConsumerStatefulWidget {
  final String eventId;
  final GroupEvent event;
  final VoidCallback onRefresh;
  const _MembersTab({required this.eventId, required this.event, required this.onRefresh});

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  // { memberId → { currency → TextEditingController } }
  final Map<String, Map<String, TextEditingController>> _controllers = {};
  bool _savingShares = false;

  @override
  void dispose() {
    for (final byMember in _controllers.values) {
      for (final ctrl in byMember.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  void _initControllers(List<GroupMember> members, List<GroupMemberShare> shares,
      List<String> currencies) {
    for (final member in members) {
      _controllers.putIfAbsent(member.id, () => {});
      for (final currency in currencies) {
        if (!_controllers[member.id]!.containsKey(currency)) {
          final existing = shares
              .where((s) => s.groupMemberId == member.id && s.currency == currency)
              .firstOrNull;
          _controllers[member.id]![currency] = TextEditingController(
            text: existing != null ? existing.percentage.toStringAsFixed(1) : '',
          );
        }
      }
    }
  }

  Future<void> _saveShares(
      List<GroupMember> members, List<String> currencies) async {
    // Validar que cada moneda sume 100
    for (final currency in currencies) {
      double total = 0;
      for (final member in members) {
        final val = double.tryParse(
                _controllers[member.id]?[currency]?.text.replaceAll(',', '.') ?? '') ??
            0;
        total += val;
      }
      if ((total - 100).abs() > 0.05) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Los % de $currency deben sumar 100 (actualmente ${total.toStringAsFixed(1)})'),
        ));
        return;
      }
    }

    setState(() => _savingShares = true);
    try {
      for (final member in members) {
        for (final currency in currencies) {
          final pct = double.tryParse(
                  _controllers[member.id]?[currency]?.text.replaceAll(',', '.') ?? '') ??
              0;
          await supabase.from('group_member_shares').upsert(
            {
              'group_member_id': member.id,
              'currency': currency,
              'percentage': pct,
              'updated_at': DateTime.now().toIso8601String(),
            },
            onConflict: 'group_member_id,currency',
          );
        }
      }
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Porcentajes guardados')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _savingShares = false);
    }
  }

  Future<void> _generateInviteLink() async {
    try {
      final token = _randomToken();
      await supabase.from('group_invite_links').insert({
        'event_id': widget.eventId,
        'token': token,
        'created_by': supabase.auth.currentUser!.id,
      });
      final base = Uri.base;
      final link = '${base.scheme}://${base.host}/join/$token';
      final result = await Share.share(
        'Te invito al evento "${widget.event.name}" en Roibal. Usá este link para unirte: $link',
        subject: 'Invitación a ${widget.event.name}',
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(link)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  String _randomToken() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    return List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.eventId));
    final sharesAsync = ref.watch(groupMemberSharesProvider(widget.eventId));
    final expensesAsync = ref.watch(groupExpensesProvider(widget.eventId));

    return membersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (members) => sharesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shares) => expensesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (expenses) {
            final accepted =
                members.where((m) => m.status == GroupMemberStatus.accepted).toList();

            // Monedas usadas + moneda base
            final currencies = {
              ...expenses.map((e) => e.currency),
              if (widget.event.splitMode == SplitMode.baseCurrency)
                widget.event.baseCurrency,
            }.toList();

            _initControllers(accepted, shares, currencies);

            return RefreshIndicator(
              onRefresh: () async => widget.onRefresh(),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Miembros
                  Row(
                    children: [
                      Text('Miembros', style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _generateInviteLink,
                        icon: const Icon(Icons.link, size: 16),
                        label: const Text('Invitar'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...members.map((m) => ListTile(
                        leading: CircleAvatar(child: Text(m.label[0].toUpperCase())),
                        title: Text(m.label),
                        trailing: _MemberStatusChip(m.status),
                        contentPadding: EdgeInsets.zero,
                      )),
                  if (widget.event.status == GroupEventStatus.open && accepted.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Porcentajes de responsabilidad',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Cada moneda debe sumar 100%.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (currencies.isEmpty)
                      const Text('Cargá al menos un gasto para ver las monedas.')
                    else
                      ...currencies.map((currency) =>
                          _SharesTable(
                            currency: currency,
                            members: accepted,
                            controllers: _controllers,
                          )),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _savingShares
                          ? null
                          : () => _saveShares(accepted, currencies),
                      child: _savingShares
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Guardar porcentajes'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SharesTable extends StatefulWidget {
  final String currency;
  final List<GroupMember> members;
  final Map<String, Map<String, TextEditingController>> controllers;
  const _SharesTable({
    required this.currency,
    required this.members,
    required this.controllers,
  });

  @override
  State<_SharesTable> createState() => _SharesTableState();
}

class _SharesTableState extends State<_SharesTable> {
  double get _total => widget.members.fold(0.0, (sum, m) {
        final val = double.tryParse(
                widget.controllers[m.id]?[widget.currency]?.text.replaceAll(',', '.') ??
                    '') ??
            0;
        return sum + val;
      });

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final isValid = (total - 100).abs() < 0.05;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.currency,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Text(
              'Suma: ${total.toStringAsFixed(1)}%',
              style: TextStyle(
                color: isValid ? Colors.green : Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...widget.members.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(child: Text(m.label)),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: widget.controllers[m.id]?[widget.currency],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        suffixText: '%',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _MemberStatusChip extends StatelessWidget {
  final GroupMemberStatus status;
  const _MemberStatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      GroupMemberStatus.accepted => ('Aceptado', Colors.green),
      GroupMemberStatus.invited => ('Invitado', Colors.orange),
      GroupMemberStatus.declined => ('Declinado', Colors.red),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Balance
// ---------------------------------------------------------------------------

class _BalanceTab extends ConsumerStatefulWidget {
  final String eventId;
  final GroupEvent event;
  const _BalanceTab({required this.eventId, required this.event});

  @override
  ConsumerState<_BalanceTab> createState() => _BalanceTabState();
}

class _BalanceTabState extends ConsumerState<_BalanceTab> {
  bool _showConverted = false;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(groupMembersProvider(widget.eventId));
    final expensesAsync = ref.watch(groupExpensesProvider(widget.eventId));
    final sharesAsync = ref.watch(groupMemberSharesProvider(widget.eventId));
    final paymentsAsync = ref.watch(groupPartialPaymentsProvider(widget.eventId));

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
            data: (payments) {
              if (expenses.isEmpty) {
                return const Center(
                  child: Text('No hay gastos cargados todavía.',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              final result = calculateGroupBalance(
                members: members,
                expenses: expenses,
                shares: shares,
                partialPayments: payments,
                splitMode: widget.event.splitMode,
                baseCurrency: widget.event.baseCurrency,
              );

              final myUserId = supabase.auth.currentUser?.id;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Toggle de conversión
                  if (result.currencies.length > 1) ...[
                    SwitchListTile(
                      value: _showConverted,
                      onChanged: (v) => setState(() => _showConverted = v),
                      title: Text('Mostrar en ${widget.event.baseCurrency}'),
                      subtitle: const Text('Tasa sugerida — ajustable al liquidar'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    if (_showConverted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                        ),
                        child: const Text(
                          'Tasas sugeridas al momento. Pueden ajustarse antes de confirmar.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    const Divider(),
                  ],
                  ...result.currencies.map((currency) {
                    final byMember = result.byCurrency[currency]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            currency,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...byMember.values.map((b) {
                          final isMe = b.member.userId == myUserId;
                          final net = b.net;
                          final netColor = net > 0
                              ? Colors.green
                              : net < 0
                                  ? Theme.of(context).colorScheme.error
                                  : Colors.grey;
                          final netLabel = net > 0
                              ? 'Te deben'
                              : net < 0
                                  ? 'Debés'
                                  : 'Saldado';
                          return Card(
                            color: isMe
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withValues(alpha: 0.3)
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(b.member.label[0].toUpperCase()),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(b.member.label,
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                        Text(
                                          'Pagó: $currency ${b.paid.toStringAsFixed(2)} · '
                                          'Le corresponde: $currency ${b.shouldPay.toStringAsFixed(2)}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        netLabel,
                                        style: TextStyle(fontSize: 11, color: netColor),
                                      ),
                                      Text(
                                        '$currency ${net.abs().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: netColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
