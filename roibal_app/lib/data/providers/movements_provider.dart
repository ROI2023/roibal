import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/supabase_config.dart';
import '../models/movement_item.dart';
import 'auth_providers.dart';

final movementsProvider = FutureProvider.autoDispose
    .family<List<MovementItem>, (DateTime, DateTime)>((ref, range) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final (start, end) = range;

  final startStr = '${start.year.toString().padLeft(4, '0')}-'
      '${start.month.toString().padLeft(2, '0')}-01';
  final endStr = '${end.year.toString().padLeft(4, '0')}-'
      '${end.month.toString().padLeft(2, '0')}-'
      '${end.day.toString().padLeft(2, '0')}';

  final rows = await supabase
      .from('transactions')
      .select(
          '*, categories(*), transaction_movements(account_id, amount, accounts(name))')
      .eq('user_id', user.id)
      .gte('transaction_date', startStr)
      .lte('transaction_date', endStr)
      .order('transaction_date', ascending: false);

  return rows.map(MovementItem.fromJson).toList();
});
