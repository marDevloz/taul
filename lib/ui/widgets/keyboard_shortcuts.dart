import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Captures global keyboard shortcuts for the app.
///
/// Wraps the unlocked app tree and handles these shortcuts:
/// - **Ctrl+N**: new entry (home only)
/// - **Ctrl+F**: focus search bar (home only)
/// - **Ctrl+,**: navigate to settings
/// - **Ctrl+Shift+T**: navigate to trash
/// - **Escape**: navigate to home from any screen
class AppKeyboardShortcuts extends ConsumerWidget {
  final Widget child;
  const AppKeyboardShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => debugPrint(
        '[KB] AppKeyboardShortcuts focus: $f, route: ${GoRouterState.of(context).uri.toString()}',
      ),
      onKeyEvent: (node, event) {
        // DEBUG: log every key event
        debugPrint(
          '[KB] keyEvent: ${event.runtimeType} logicalKey=${event.logicalKey} '
          'physicalKey=${event.physicalKey}',
        );

        // Ignore repeats to avoid spawning multiple dialogs.
        if (event is KeyRepeatEvent) return KeyEventResult.ignored;
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final ctrl =
            HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.controlLeft) ||
                HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.controlRight);
        final shift =
            HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.shiftLeft) ||
                HardwareKeyboard.instance
                    .isLogicalKeyPressed(LogicalKeyboardKey.shiftRight);

        // ── Ctrl+N → nueva entrada (solo en home) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyN) {
          try {
            if (GoRouterState.of(context).uri.toString() == '/') {
              ref.read(createEntryEventProvider.notifier).state++;
              return KeyEventResult.handled;
            }
          } catch (_) {
            // Router may not be available during transitions.
          }
          return KeyEventResult.ignored;
        }

        // ── Ctrl+F → enfocar búsqueda (solo en home) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyF) {
          try {
            if (GoRouterState.of(context).uri.toString() == '/') {
              ref.read(focusSearchProvider.notifier).state = true;
              return KeyEventResult.handled;
            }
          } catch (_) {}
          return KeyEventResult.ignored;
        }

        // ── Ctrl+, → settings (global) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.comma) {
          try {
            if (GoRouterState.of(context).uri.toString() != '/settings') {
              context.go('/settings');
            }
            return KeyEventResult.handled;
          } catch (_) {
            return KeyEventResult.ignored;
          }
        }

        // ── Ctrl+Shift+T → papelera (global) ──
        if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyT) {
          try {
            if (GoRouterState.of(context).uri.toString() != '/trash') {
              context.push('/trash');
            }
            return KeyEventResult.handled;
          } catch (_) {
            return KeyEventResult.ignored;
          }
        }

        // ── Escape → navegar a home ──
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          try {
            if (GoRouterState.of(context).uri.toString() != '/') {
              debugPrint('[KB] Escape → go home');
              context.go('/');
              return KeyEventResult.handled;
            }
          } catch (_) {}
          return KeyEventResult.ignored;
        }

        debugPrint(
          '[KB] unhandled: ctrl=$ctrl shift=$shift key=${event.logicalKey} '
          'route=${GoRouterState.of(context).uri.toString()}',
        );
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
