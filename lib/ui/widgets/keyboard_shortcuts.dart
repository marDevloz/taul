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
      onKeyEvent: (node, event) {
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
        final location = GoRouterState.of(context).uri.toString();

        // ── Ctrl+N → nueva entrada (solo en home) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyN) {
          if (location == '/') {
            ref.read(createEntryEventProvider.notifier).state++;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        // ── Ctrl+F → enfocar búsqueda (solo en home) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyF) {
          if (location == '/') {
            ref.read(focusSearchProvider.notifier).state = true;
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        }

        // ── Ctrl+, → settings (global) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.comma) {
          if (location != '/settings') {
            context.go('/settings');
          }
          return KeyEventResult.handled;
        }

        // ── Ctrl+Shift+T → papelera (global) ──
        if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyT) {
          if (location != '/trash') {
            context.go('/trash');
          }
          return KeyEventResult.handled;
        }

        // ── Escape → navegar a home ──
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (location != '/') {
            context.go('/');
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
