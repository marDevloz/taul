import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:taul/ui/screens/trash_screen.dart';
import 'package:taul/ui/widgets/inactivity_detector.dart';
import 'package:taul/ui/widgets/keyboard_shortcuts.dart';
import 'package:taul/ui/widgets/update_dialog.dart';

/// Tracks whether the startup update check has been dispatched.
final _updateCheckDoneProvider = StateProvider<bool>((ref) => false);

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
}

/// Descarga el installer, muestra feedback y lo ejecuta.
Future<void> _downloadAndInstall(
  BuildContext context,
  UpdateService service,
  UpdateManifest manifest,
) async {
  if (!context.mounted) return;
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
      duration: Duration(seconds: 30),
    ),
  );

  try {
    final path = await service.downloadInstaller(manifest.url);
    if (!context.mounted) return;
    await service.installUpdate(path);
    // Si llegamos acá el installer falló (no cerró la app)
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al instalar la actualización')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al descargar: $e')),
      );
    }
  }
}
