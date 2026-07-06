import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../models/group_event.dart';
import '../models/group_expense.dart';
import '../models/group_member.dart';
import '../models/group_member_share.dart';
import '../models/group_partial_payment.dart';
import '../models/group_settlement.dart';
import 'auth_providers.dart';

// ---------------------------------------------------------------------------
// Eventos donde el usuario es miembro accepted
// ---------------------------------------------------------------------------

final myGroupEventsProvider = FutureProvider.autoDispose<List<GroupEvent>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final memberRows = await supabase
      .from('group_members')
      .select('event_id')
      .eq('user_id', user.id)
      .eq('status', 'accepted');

  final eventIds = memberRows.map((r) => r['event_id'] as String).toList();
  if (eventIds.isEmpty) return [];

  final rows = await supabase
      .from('group_events')
      .select()
      .inFilter('id', eventIds)
      .order('created_at', ascending: false);

  return rows.map(GroupEvent.fromJson).toList();
});

// ---------------------------------------------------------------------------
// Miembros de un evento
// ---------------------------------------------------------------------------

final groupMembersProvider =
    FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, eventId) async {
  final rows = await supabase
      .from('group_members')
      .select()
      .eq('event_id', eventId)
      .order('created_at');
  return rows.map(GroupMember.fromJson).toList();
});

/// Miembro del evento correspondiente al usuario actual (null si no es miembro).
final myMemberProvider =
    FutureProvider.autoDispose.family<GroupMember?, String>((ref, eventId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final members = await ref.watch(groupMembersProvider(eventId).future);
  try {
    return members.firstWhere(
      (m) => m.userId == user.id && m.status == GroupMemberStatus.accepted,
    );
  } catch (_) {
    return null;
  }
});

// ---------------------------------------------------------------------------
// Shares de porcentaje por evento
// ---------------------------------------------------------------------------

final groupMemberSharesProvider =
    FutureProvider.autoDispose.family<List<GroupMemberShare>, String>((ref, eventId) async {
  final members = await ref.watch(groupMembersProvider(eventId).future);
  final memberIds = members.map((m) => m.id).toList();
  if (memberIds.isEmpty) return [];
  final rows = await supabase
      .from('group_member_shares')
      .select()
      .inFilter('group_member_id', memberIds);
  return rows.map(GroupMemberShare.fromJson).toList();
});

// ---------------------------------------------------------------------------
// Gastos del evento
// ---------------------------------------------------------------------------

final groupExpensesProvider =
    FutureProvider.autoDispose.family<List<GroupExpense>, String>((ref, eventId) async {
  final rows = await supabase
      .from('group_expenses')
      .select('*, group_members(*)')
      .eq('event_id', eventId)
      .order('expense_date', ascending: false);
  return rows.map(GroupExpense.fromJson).toList();
});

// ---------------------------------------------------------------------------
// Pagos parciales del evento
// ---------------------------------------------------------------------------

final groupPartialPaymentsProvider =
    FutureProvider.autoDispose.family<List<GroupPartialPayment>, String>((ref, eventId) async {
  final rows = await supabase
      .from('group_partial_payments')
      .select(
          '*, from_member:group_members!from_member_id(*), to_member:group_members!to_member_id(*)')
      .eq('event_id', eventId)
      .order('payment_date', ascending: false);
  return rows.map(GroupPartialPayment.fromJson).toList();
});

// ---------------------------------------------------------------------------
// Settlements del evento
// ---------------------------------------------------------------------------

final groupSettlementsProvider =
    FutureProvider.autoDispose.family<List<GroupSettlement>, String>((ref, eventId) async {
  final rows = await supabase
      .from('group_settlements')
      .select(
          '*, from_member:group_members!from_member_id(*), to_member:group_members!to_member_id(*)')
      .eq('event_id', eventId)
      .order('created_at');
  return rows.map(GroupSettlement.fromJson).toList();
});

// ---------------------------------------------------------------------------
// Un solo evento (para la pantalla de detalle)
// ---------------------------------------------------------------------------

final groupEventProvider =
    FutureProvider.autoDispose.family<GroupEvent?, String>((ref, eventId) async {
  final rows =
      await supabase.from('group_events').select().eq('id', eventId).maybeSingle();
  if (rows == null) return null;
  return GroupEvent.fromJson(rows);
});
