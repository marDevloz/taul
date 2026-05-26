import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/screens/home_view.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/lock_screen.dart';
import 'package:taul/ui/screens/settings_screen.dart';
import 'package:taul/ui/screens/trash_screen.dart';
import 'package:taul/ui/widgets/inactivity_detector.dart';
import 'package:taul/ui/widgets/keyboard_shortcuts.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, __) => const HomeView(),
      ),
      GoRoute(
        path: '/entry/:id',
        name: 'entry',
        builder: (_, state) => EntryDetailView(entryId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/trash',
        name: 'trash',
        builder: (_, __) => const TrashScreen(),
      ),
    ],
  );
});

class TaulApp extends ConsumerWidget {
  const TaulApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lockStatus = ref.watch(appLockProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Taúl',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (lockStatus == AppLockStatus.checking) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (lockStatus == AppLockStatus.locked) {
          return const LockScreen();
        }
        return AppKeyboardShortcuts(
          child: InactivityDetector(child: child!),
        );
      },
    );
  }
}
