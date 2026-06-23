import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../core/config/supabase_config.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/expense_transaction.dart';
import '../models/projected_movement.dart';
import 'auth_providers.dart';

final accountsProvider = FutureProvider.autoDispose<List<Account>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final rows = await supabase
      .from('accounts')
      .select()
      .eq('user_id', user.id)
      .order('created_at');
  return rows.map(Account.fromJson).toList();
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final rows = await supabase.from('categories').select().order('name');
  return rows.map(Category.fromJson).toList();
});

final expenseCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  return categories.where((c) => c.type == CategoryType.expense).toList();
});

final incomeCategoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) async {
  final categories = await ref.watch(categoriesProvider.future);
  return categories.where((c) => c.type == CategoryType.income).toList();
});

/// How many recent transactions to show — starts at 5, grows by 20 each time
/// the user taps "Mostrar más" in the dashboard's movements list.
final recentTransactionsLimitProvider = StateProvider.autoDispose<int>((ref) => 5);

final recentTransactionsProvider =
    FutureProvider.autoDispose<List<ExpenseTransaction>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final limit = ref.watch(recentTransactionsLimitProvider);
  final rows = await supabase
      .from('transactions')
      .select('*, categories(*)')
      .eq('user_id', user.id)
      .order('transaction_date', ascending: false)
      .limit(limit);
  return rows.map(ExpenseTransaction.fromJson).toList();
});

final projectedOutflowsProvider =
    FutureProvider.autoDispose<List<ProjectedMovement>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final rows = await supabase
      .from('transaction_movements')
      .select('*, transactions(description, categories(*)), accounts(name)')
      .eq('user_id', user.id)
      .eq('status', 'pending')
      .order('due_date');
  return rows.map(ProjectedMovement.fromJson).toList();
});

/// Pending (unpaid) movements for a single account — used to let the user
/// pick which credit card installments a "Pagar tarjeta" payment settles.
final pendingMovementsForAccountProvider = FutureProvider.autoDispose
    .family<List<ProjectedMovement>, String>((ref, accountId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final rows = await supabase
      .from('transaction_movements')
      .select('*, transactions(description, categories(*)), accounts(name)')
      .eq('user_id', user.id)
      .eq('account_id', accountId)
      .eq('status', 'pending')
      .order('due_date');
  return rows.map(ProjectedMovement.fromJson).toList();
});

/// A single paid movement that contributed to a category's monthly total —
/// shown in the donut chart's drill-down list when a slice is tapped.
class CategoryOutflowMovement {
  final String description;
  final double amount;
  final DateTime paidDate;

  const CategoryOutflowMovement({
    required this.description,
    required this.amount,
    required this.paidDate,
  });
}

class CategorySpending {
  final Category category;
  final double amount;
  final List<CategoryOutflowMovement> movements;

  const CategorySpending(this.category, this.amount, this.movements);
}

/// Aggregates this month's real ARS cash outflows by category — "Salidas del
/// mes" — for the dashboard donut chart. This is cash-basis, not accrual: a
/// cash/debit purchase counts the day it happens, but a credit card
/// installment only counts once its card payment is actually registered
/// (transaction_movements.paid_date), under the *original purchase's*
/// category. Finance charges from "Pagar tarjeta" land under whatever
/// category the user assigned them to (e.g. "Gastos Financieros"). Transfers
/// between the user's own accounts (paying the card itself) are excluded so
/// the same money isn't counted twice.
final monthlySpendingByCategoryProvider =
    FutureProvider.autoDispose<List<CategorySpending>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  final rows = await supabase
      .from('transaction_movements')
      .select('amount, paid_date, transactions(description, is_transfer, categories(*))')
      .eq('user_id', user.id)
      .eq('status', 'paid')
      .eq('currency', 'ARS')
      .lt('amount', 0)
      .gte('paid_date', monthStart.toIso8601String())
      .lt('paid_date', monthEnd.toIso8601String());

  final movementsByCategory = <String, List<CategoryOutflowMovement>>{};
  final categories = <String, Category>{};
  for (final row in rows) {
    final tx = row['transactions'] as Map<String, dynamic>?;
    if (tx == null || tx['is_transfer'] == true) continue;
    final categoryJson = tx['categories'] as Map<String, dynamic>?;
    if (categoryJson == null) continue;
    final category = Category.fromJson(categoryJson);
    if (category.type != CategoryType.expense) continue;

    movementsByCategory.putIfAbsent(category.id, () => []).add(
          CategoryOutflowMovement(
            description: tx['description'] as String,
            amount: -(row['amount'] as num).toDouble(),
            paidDate: DateTime.parse(row['paid_date'] as String),
          ),
        );
    categories[category.id] = category;
  }

  final result = movementsByCategory.entries.map((e) {
    final movements = e.value..sort((a, b) => b.paidDate.compareTo(a.paidDate));
    final total = movements.fold<double>(0, (sum, m) => sum + m.amount);
    return CategorySpending(categories[e.key]!, total, movements);
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return result;
});

class CategoryBudgetProgress {
  final Category category;
  final double spent;

  const CategoryBudgetProgress({required this.category, required this.spent});
}

/// Expense categories that have a monthly budget set, paired with how much
/// was spent in that category so far this month — feeds the budget bar chart.
final categoryBudgetProgressProvider =
    FutureProvider.autoDispose<List<CategoryBudgetProgress>>((ref) async {
  final categories = await ref.watch(expenseCategoriesProvider.future);
  final spending = await ref.watch(monthlySpendingByCategoryProvider.future);
  final spentByCategory = {for (final s in spending) s.category.id: s.amount};

  return categories
      .where((c) => c.budgetAmount != null && c.budgetAmount! > 0)
      .map((c) => CategoryBudgetProgress(category: c, spent: spentByCategory[c.id] ?? 0))
      .toList();
});
