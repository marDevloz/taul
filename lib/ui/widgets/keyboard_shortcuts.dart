import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Captures global keyboard shortcuts for the app.
///
/// Wraps the unlocked app tree and handles these shortcuts:
/// - **Ctrl+N**: new entry (home only — fires event, HomeView listens)
/// - **Ctrl+F**: focus search bar (home only — fires event, HomeView listens)
/// - **Ctrl+,**: navigate to settings
/// - **Ctrl+Shift+T**: navigate to trash
/// - **Escape**: navigate to home from any screen
///
/// NOTE: This widget lives in MaterialApp.router's builder, OUTSIDE the
/// GoRouter tree, so GoRouterState.of(context) is NOT available here.
/// Shortcuts that need to check the current route instead fire events
/// that only the relevant screen listens to.
class AppKeyboardShortcuts extends ConsumerWidget {
  final Widget child;
  const AppKeyboardShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) =>
          debugPrint('[KB] AppKeyboardShortcuts focus: $f'),
      onKeyEvent: (node, event) {
        // DEBUG: log every key event
        debugPrint(
          '[KB] keyEvent: ${event.runtimeType} logicalKey=${event.logicalKey}',
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

        // ── Ctrl+N → nueva entrada (dispara evento, HomeView escucha) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyN) {
          debugPrint('[KB] Ctrl+N fired');
          ref.read(createEntryEventProvider.notifier).state++;
          return KeyEventResult.handled;
        }

        // ── Ctrl+F → enfocar búsqueda (dispara evento, HomeView escucha) ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.keyF) {
          debugPrint('[KB] Ctrl+F fired');
          ref.read(focusSearchProvider.notifier).state = true;
          return KeyEventResult.handled;
        }

        // ── Ctrl+, → settings ──
        if (ctrl && !shift && event.logicalKey == LogicalKeyboardKey.comma) {
          debugPrint('[KB] Ctrl+, → settings');
          try {
            context.push('/settings');
            return KeyEventResult.handled;
          } catch (_) {
            return KeyEventResult.ignored;
          }
        }

        // ── Ctrl+Shift+T → papelera ──
        if (ctrl && shift && event.logicalKey == LogicalKeyboardKey.keyT) {
          debugPrint('[KB] Ctrl+Shift+T → trash');
          try {
            context.push('/trash');
            return KeyEventResult.handled;
          } catch (_) {
            return KeyEventResult.ignored;
          }
        }

        // ── Escape → cerrar modal/sheet o volver ──
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          debugPrint('[KB] Escape → pop');
          try {
            if (context.canPop()) {
              context.pop();
              return KeyEventResult.handled;
            }
          } catch (_) {
            // ignore
          }
        }

        debugPrint('[KB] unhandled: ctrl=$ctrl shift=$shift key=${event.logicalKey}');
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }
}
