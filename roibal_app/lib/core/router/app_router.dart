import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/category.dart';
import '../../data/providers/auth_providers.dart';
import '../../features/accounts/accounts_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/categories/categories_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/group_events/add_group_expense_screen.dart';
import '../../features/group_events/add_partial_payment_screen.dart';
import '../../features/group_events/create_group_event_screen.dart';
import '../../features/group_events/group_event_detail_screen.dart';
import '../../features/group_events/group_events_list_screen.dart';
import '../../features/group_events/join_event_screen.dart';
import '../../features/group_events/settlement_screen.dart';
import '../../features/payments/pay_credit_card_screen.dart';
import '../../features/projected/projected_outflows_screen.dart';
import '../../features/recurring/add_recurring_expense_screen.dart';
import '../../features/transactions/add_transaction_screen.dart';
import '../config/supabase_config.dart';
import 'pending_invite_provider.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(ref),
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isJoining = state.matchedLocation.startsWith('/join/');

      if (!isLoggedIn) {
        // /join/:token es pública — la pantalla maneja el estado de no-autenticado
        if (isLoggingIn || isJoining) return null;
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        // Si el usuario acaba de loguearse y tenía una invitación pendiente, retomar
        final pendingToken = ref.read(pendingInviteTokenProvider);
        if (pendingToken != null) {
          ref.read(pendingInviteTokenProvider.notifier).state = null;
          return '/join/$pendingToken';
        }
        return '/';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),

      // Transacciones y gastos
      GoRoute(
        path: '/add-expense',
        builder: (context, state) => const AddTransactionScreen(type: CategoryType.expense),
      ),
      GoRoute(
        path: '/add-income',
        builder: (context, state) => const AddTransactionScreen(type: CategoryType.income),
      ),

      // Config
      GoRoute(path: '/categories', builder: (context, state) => const CategoriesScreen()),
      GoRoute(path: '/accounts', builder: (context, state) => const AccountsScreen()),
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

      // -----------------------------------------------------------------------
      // Gastos grupales
      // -----------------------------------------------------------------------
      GoRoute(path: '/groups', builder: (context, state) => const GroupEventsListScreen()),
      GoRoute(path: '/groups/new', builder: (context, state) => const CreateGroupEventScreen()),
      GoRoute(
        path: '/groups/:eventId',
        builder: (context, state) =>
            GroupEventDetailScreen(eventId: state.pathParameters['eventId']!),
        routes: [
          GoRoute(
            path: 'expenses/new',
            builder: (context, state) =>
                AddGroupExpenseScreen(eventId: state.pathParameters['eventId']!),
          ),
          GoRoute(
            path: 'partial-payment',
            builder: (context, state) =>
                AddPartialPaymentScreen(eventId: state.pathParameters['eventId']!),
          ),
          GoRoute(
            path: 'settle',
            builder: (context, state) =>
                SettlementScreen(eventId: state.pathParameters['eventId']!),
          ),
        ],
      ),

      // Invitación pública (sin guard de auth)
      GoRoute(
        path: '/join/:token',
        builder: (context, state) =>
            JoinEventScreen(token: state.pathParameters['token']!),
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
