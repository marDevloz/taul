import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/theme_provider.dart';
import 'package:taul/ui/screens/home_view.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/lock_screen.dart';
import 'package:taul/ui/screens/settings_screen.dart';
import 'package:taul/ui/screens/tag_management_screen.dart';
import 'package:taul/ui/screens/user_manual_screen.dart';
import 'package:taul/ui/screens/trash_screen.dart';
import 'package:taul/ui/widgets/inactivity_detector.dart';
import 'package:taul/ui/widgets/keyboard_shortcuts.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      // ShellRoute wraps ALL routes so AppKeyboardShortcuts lives inside
      // the GoRouter tree and GoRouterState.of(context) works.
      ShellRoute(
        builder: (context, state, child) => AppKeyboardShortcuts(child: child),
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
            routes: [
              GoRoute(
                path: 'tags',
                name: 'tags',
                builder: (_, __) => const TagManagementScreen(),
              ),
              GoRoute(
                path: 'manual',
                name: 'manual',
                builder: (_, __) => const UserManualScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/trash',
            name: 'trash',
            builder: (_, __) => const TrashScreen(),
          ),
        ],
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
      themeMode: ref.watch(themeModeProvider),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      builder: (context, child) {
        if (lockStatus == AppLockStatus.checking) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (lockStatus == AppLockStatus.locked) {
          return const _LockScreenWrapper();
        }
        return InactivityDetector(child: child!);
      },
    );
  }
}

/// Wraps [LockScreen] in an [Overlay] so EditableText (TextField) can
/// render its selection toolbar without crashing.
///
/// The [LockScreen] is rendered outside the router's Navigator (to preserve
/// navigation state while locked), but still needs an Overlay ancestor
/// for text selection handles.
class _LockScreenWrapper extends StatelessWidget {
  const _LockScreenWrapper();

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(builder: (_) => const LockScreen()),
      ],
    );
  }
}
