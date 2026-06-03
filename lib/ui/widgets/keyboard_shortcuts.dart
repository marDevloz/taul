import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Captures global keyboard shortcuts for the app.
///
/// Lives inside a [ShellRoute] so GoRouter navigation is available.
/// Handles these shortcuts:
/// - **Ctrl+N**: new entry (fires event, HomeView listens)
/// - **Ctrl+F**: focus search bar (fires event, HomeView listens)
/// - **Ctrl+,**: navigate to settings
/// - **Ctrl+Shift+T**: navigate to trash
/// - **Escape**: pop current route or close modal
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

        // ── Ctrl+N → nueva entrada (dispara evento, HomeView escucha) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyN) {
          ref.read(createEntryEventProvider.notifier).state++;
          return KeyEventResult.handled;
        }

        // ── Ctrl+F → enfocar búsqueda (dispara evento, HomeView escucha) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyF) {
          ref.read(focusSearchProvider.notifier).state = true;
          return KeyEventResult.handled;
        }

        // ── Ctrl+, → settings ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.comma) {
          context.push('/settings');
          return KeyEventResult.handled;
        }

        // ── Ctrl+Shift+T → papelera ──
        if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyT) {
          context.push('/trash');
          return KeyEventResult.handled;
        }

        // ── Escape → cerrar modal/sheet o volver ──
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (context.canPop()) {
            context.pop();
            return KeyEventResult.handled;
          }
        }

        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
