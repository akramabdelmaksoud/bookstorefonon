import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/env.dart';
import '../core/theme.dart';
import 'admin/admin_home_screen.dart';
import 'auth/login_screen.dart';
import 'cashier/cashier_screen.dart';
import 'providers.dart';

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Bookstore POS',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: Env.isConfigured ? const _AuthGate() : const _MissingConfig(),
      );
}

class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final session = auth.value?.session ?? ref.watch(supabaseProvider).auth.currentSession;
    if (session == null) return const LoginScreen();

    return ref.watch(isAdminProvider).when(
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Could not load your profile\n$e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                  onPressed: () => ref.invalidate(isAdminProvider),
                  child: const Text('Retry'),
                ),
              ]),
            ),
          ),
          data: (isAdmin) => isAdmin ? const AdminHomeScreen() : const CashierScreen(),
        );
  }
}

class _MissingConfig extends StatelessWidget {
  const _MissingConfig();

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: SelectableText(
              'Supabase is not configured.\n\nRun with:\n'
              'flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
}
