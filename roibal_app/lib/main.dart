import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/config/supabase_config.dart';
import 'core/router/app_router.dart';
import 'core/router/pending_invite_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  await SupabaseConfig.initialize();
  final prefs = await SharedPreferences.getInstance();
  final pendingToken = prefs.getString('pending_invite_token');
  runApp(ProviderScope(
    overrides: pendingToken != null
        ? [pendingInviteTokenProvider.overrideWith((ref) => pendingToken)]
        : const [],
    child: const RoibalApp(),
  ));
}

class RoibalApp extends ConsumerWidget {
  const RoibalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'ROIBAL',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
