import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:taul/core/auto_updater.dart';
import 'package:taul/ui/providers/entry_providers.dart';
import 'package:taul/ui/providers/theme_provider.dart';
import 'package:taul/ui/screens/home_view.dart';
import 'package:taul/ui/screens/entry_detail_view.dart';
import 'package:taul/ui/screens/lock_screen.dart';
import 'package:taul/ui/screens/settings_screen.dart';
import 'package:taul/ui/screens/tag_management_screen.dart';
import 'package:taul/ui/screens/user_manual_screen.dart';
import 'package:taul/ui/screens/about_screen.dart';
import 'package:taul/ui/screens/sync_view.dart';
import 'package:taul/ui/screens/conflict_view.dart';
import 'package:taul/ui/screens/trash_screen.dart';
import 'package:taul/ui/widgets/inactivity_detector.dart';
import 'package:taul/ui/widgets/keyboard_shortcuts.dart';
import 'package:taul/ui/widgets/update_dialog.dart';

/// Tracks whether the startup update check has been dispatched.
final _updateCheckDoneProvider = StateProvider<bool>((ref) => false);

/// Prevents duplicate addPostFrameCallback registration in builder.
bool _updateCheckScheduled = false;

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
              GoRoute(
                path: 'about',
                name: 'about',
                builder: (_, __) => const AboutScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/trash',
            name: 'trash',
            builder: (_, __) => const TrashScreen(),
          ),
          GoRoute(
            path: '/sync',
            name: 'sync',
            builder: (_, __) => const SyncView(),
            routes: [
              GoRoute(
                path: 'conflicts',
                name: 'sync-conflicts',
                builder: (_, __) => const ConflictView(),
              ),
            ],
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
      builder: (appContext, child) {
        if (lockStatus == AppLockStatus.checking) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (lockStatus == AppLockStatus.locked) {
          return const _LockScreenWrapper();
        }
        // Dispatch one-time update check using MaterialApp's context
        // (which has Navigator and ScaffoldMessenger as ancestors)
        final updateCheckDone = ref.watch(_updateCheckDoneProvider);
        if (!updateCheckDone && !_updateCheckScheduled) {
          _updateCheckScheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(_updateCheckDoneProvider.notifier).state = true;
            _handleAutoUpdate(appContext, ref);
          });
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

/// Chequea si hay actualización disponible y maneja la respuesta del usuario.
Future<void> _handleAutoUpdate(BuildContext context, WidgetRef ref) async {
  try {
    final service = ref.read(updateServiceProvider);
    final manifest = await service.checkForUpdate();
    if (manifest == null || !context.mounted) return;

    final action = await showUpdateDialog(context, manifest);
    if (!context.mounted || action == null) return;

    switch (action) {
      case UpdateDialogAction.download:
        await _downloadAndInstall(context, service, manifest);
      case UpdateDialogAction.skip:
        await service.skipVersion(manifest.version);
      case UpdateDialogAction.later:
        break;
    }
  } catch (_) {
    // Fail silencioso — el update check no debe crashear la app
  }
}

/// Descarga la actualización y la instala.
/// Funciona en Windows (installer) y Android (APK).
Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateManifest manifest,
) async {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Descargando actualización...'),
        ],
      ),
      duration: Duration(minutes: 2),
    ),
  );

  try {
    final path = await service.downloadUpdate(manifest.downloadUrl);

    // Validate hash before installation (Android only — Windows installer
    // hash is a separate future scope; emitting APK hash in manifest only).
    if (Platform.isAndroid) {
      try {
        await service.validateHash(path, manifest.sha256);
      } on HashMismatchException {
        // Delete corrupted file best-effort
        try {
          final file = File(path);
          if (await file.exists()) await file.delete();
        } catch (cleanupError) {
          Logger().w('Failed to delete corrupted APK', error: cleanupError);
        }
        rethrow;
      }
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    // installUpdate: Windows lanza installer, Android abre APK
    await service.installUpdate(path);

    // Cleanup after installation — never blocks user
    try {
      await service.cleanup(path);
    } catch (e) {
      Logger().w('APK cleanup failed', error: e);
    }

    // Success notification
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Actualización a v${manifest.version} instalada'),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updateErrorMessage(e))),
      );
    }
  }
}
