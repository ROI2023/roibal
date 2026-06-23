import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/category.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/payments/pay_credit_card_screen.dart';
import '../../features/projected/projected_outflows_screen.dart';
import '../../features/recurring/add_recurring_expense_screen.dart';
import '../../features/transactions/add_transaction_screen.dart';
import '../config/supabase_config.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isLoggingIn = state.matchedLocation == '/login';

      if (!isLoggedIn) return isLoggingIn ? null : '/login';
      if (isLoggedIn && isLoggingIn) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => const AddTransactionScreen(type: CategoryType.expense),
      ),
      GoRoute(
        path: '/add-income',
        builder: (context, state) => const AddTransactionScreen(type: CategoryType.income),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/accounts',
        builder: (context, state) => const AccountsScreen(),
      ),
      GoRoute(
        path: '/add-recurring-expense',
        builder: (context, state) => const AddRecurringExpenseScreen(),
      ),
      GoRoute(
        path: '/projected-outflows',
        builder: (context, state) => const ProjectedOutflowsScreen(),
      ),
      GoRoute(
        path: '/pay-credit-card',
        builder: (context, state) => const PayCreditCardScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod's authStateProvider stream to GoRouter's Listenable-based refresh API.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
  }
}
