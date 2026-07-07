import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/build_info.dart';
import '../../core/config/supabase_config.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/widgets/app_logo_title.dart';
import '../../data/providers/finance_providers.dart';
import 'widgets/balance_card.dart';
import 'widgets/category_budget_bar_chart.dart';
import 'widgets/category_donut_chart.dart';
import 'widgets/onboarding_banner.dart';
import 'widgets/recent_transactions_list.dart';

PopupMenuItem<String> _sectionHeader(BuildContext context, String label) {
  return PopupMenuItem<String>(
    enabled: false,
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    ),
  );
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    _checkPendingInvite();
  }

  Future<void> _checkPendingInvite() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('pending_invite_token');
    if (token == null || !mounted) return;
    await prefs.remove('pending_invite_token');
    // ignore: use_build_context_synchronously
    context.go('/join/$token');
  }

  Future<void> _refresh() async {
    ref.invalidate(accountsProvider);
    ref.invalidate(recentTransactionsLimitProvider);
    ref.invalidate(recentTransactionsProvider);
    ref.invalidate(monthlySpendingByCategoryProvider);
    ref.invalidate(categoryBudgetProgressProvider);
    ref.invalidate(projectedOutflowsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsProvider);
    final categories = ref.watch(categoriesProvider);
    final recentTransactions = ref.watch(recentTransactionsProvider);
    final monthlySpending = ref.watch(monthlySpendingByCategoryProvider);
    final budgetProgress = ref.watch(categoryBudgetProgressProvider);

    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppLogoTitle(logoSize: 28),
        actions: [
          PopupMenuButton<ThemeMode>(
            tooltip: 'Tema',
            icon: Icon(switch (themeMode) {
              ThemeMode.light => Icons.light_mode_outlined,
              ThemeMode.dark => Icons.dark_mode_outlined,
              ThemeMode.system => Icons.brightness_auto_outlined,
            }),
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode),
            itemBuilder: (context) => const [
              PopupMenuItem(value: ThemeMode.light, child: Text('Claro')),
              PopupMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
              PopupMenuItem(value: ThemeMode.system, child: Text('Sistema')),
            ],
          ),
          PopupMenuButton<String>(
            tooltip: 'Más',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) async {
              if (value == 'logout') {
                await supabase.auth.signOut();
                return;
              }
              if (value == '/projected-outflows' ||
                  value == '/categories' ||
                  value == '/accounts' ||
                  value == '/groups') {
                await context.push(value);
                if (value == '/categories') ref.invalidate(categoriesProvider);
                if (value == '/accounts') ref.invalidate(accountsProvider);
                return;
              }
              final added = await context.push<bool>(value);
              if (added == true) await _refresh();
            },
            itemBuilder: (context) => [
              _sectionHeader(context, 'Gastos grupales'),
              const PopupMenuItem(
                value: '/groups',
                child: ListTile(
                  leading: Icon(Icons.group_outlined),
                  title: Text('Eventos y viajes'),
                ),
              ),
              const PopupMenuDivider(),
              _sectionHeader(context, 'Configuración'),
              const PopupMenuItem(
                value: '/categories',
                child: ListTile(
                  leading: Icon(Icons.category_outlined),
                  title: Text('Categorías'),
                ),
              ),
              const PopupMenuItem(
                value: '/accounts',
                child: ListTile(
                  leading: Icon(Icons.account_balance_wallet_outlined),
                  title: Text('Cuentas'),
                ),
              ),
              const PopupMenuDivider(),
              _sectionHeader(context, 'Acciones'),
              const PopupMenuItem(
                value: '/add-income',
                child: ListTile(leading: Icon(Icons.attach_money), title: Text('Nuevo ingreso')),
              ),
              const PopupMenuItem(
                value: '/add-recurring-expense',
                child: ListTile(leading: Icon(Icons.repeat), title: Text('Nuevo gasto recurrente')),
              ),
              const PopupMenuItem(
                value: '/pay-credit-card',
                child: ListTile(
                  leading: Icon(Icons.credit_card),
                  title: Text('Pagar tarjeta'),
                ),
              ),
              const PopupMenuDivider(),
              _sectionHeader(context, 'Informes'),
              const PopupMenuItem(
                value: '/projected-outflows',
                child: ListTile(
                  leading: Icon(Icons.event_note_outlined),
                  title: Text('Salidas proyectadas'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(leading: Icon(Icons.logout), title: Text('Cerrar sesión')),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  'v$kAppVersion · $kBuildTime',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            categories.maybeWhen(
              data: (data) => data.isEmpty
                  ? OnboardingBanner(
                      message: 'Todavía no tenés categorías cargadas. Agregá categorías '
                          'para tus Ingresos y tus Egresos desde el menú ⋮ > Configuración > Categorías.',
                      actionLabel: 'Ir a Categorías',
                      onAction: () async {
                        await context.push('/categories');
                        ref.invalidate(categoriesProvider);
                      },
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            accounts.maybeWhen(
              data: (data) => data.isEmpty
                  ? OnboardingBanner(
                      message: 'Todavía no tenés cuentas cargadas. Agregá tus cuentas '
                          '(efectivo, banco, tarjetas) desde el menú ⋮ > Configuración > Cuentas.',
                      actionLabel: 'Ir a Cuentas',
                      onAction: () async {
                        await context.push('/accounts');
                        ref.invalidate(accountsProvider);
                      },
                    )
                  : const SizedBox.shrink(),
              orElse: () => const SizedBox.shrink(),
            ),
            accounts.when(
              data: (data) => BalanceCard(accounts: data),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: 16),
            monthlySpending.when(
              data: (data) => CategoryDonutChart(spending: data),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: 16),
            budgetProgress.when(
              data: (data) => CategoryBudgetBarChart(progress: data),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: 16),
            recentTransactions.when(
              data: (data) => RecentTransactionsList(transactions: data),
              loading: () => const _LoadingCard(),
              error: (e, _) => _ErrorCard(message: '$e'),
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.large(
        onPressed: () async {
          final added = await context.push<bool>('/add-expense');
          if (added == true) {
            await _refresh();
          }
        },
        child: const Icon(Icons.add, size: 36),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Error: $message', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}
