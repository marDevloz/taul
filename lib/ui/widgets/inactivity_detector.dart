import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/auto_lock_provider.dart';
import 'package:taul/ui/providers/entry_providers.dart';

/// Wraps the unlocked app tree and starts an inactivity countdown.
///
/// The countdown resets on every pointer event (click, touch, keyboard).
/// When the countdown expires, the master password is cleared and the
/// app is locked. The timer also pauses when the app goes to background
/// and resumes when it comes back to foreground.
class InactivityDetector extends ConsumerStatefulWidget {
  const InactivityDetector({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<InactivityDetector> createState() =>
      _InactivityDetectorState();
}

class _InactivityDetectorState extends ConsumerState<InactivityDetector>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWithLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncWithLockState() {
    final notifier = ref.read(autoLockProvider.notifier);
    final lockStatus = ref.read(appLockProvider);
    final hasKey = ref.read(masterPasswordProvider) != null;

    if (lockStatus == AppLockStatus.unlocked && hasKey) {
      notifier.activate();
    } else {
      notifier.deactivate();
    }
  }

  void _onLockStatusChange(AppLockStatus? _, AppLockStatus next) {
    final notifier = ref.read(autoLockProvider.notifier);
    if (next == AppLockStatus.unlocked &&
        ref.read(masterPasswordProvider) != null) {
      notifier.activate();
    } else {
      notifier.deactivate();
    }
  }

  void _onMasterPasswordChange(Uint8List? prev, Uint8List? next) {
    final notifier = ref.read(autoLockProvider.notifier);
    if (next != null && ref.read(appLockProvider) == AppLockStatus.unlocked) {
      notifier.activate();
    } else if (next == null) {
      notifier.deactivate();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final notifier = ref.read(autoLockProvider.notifier);
    if (state == AppLifecycleState.paused) {
      notifier.pause();
    } else if (state == AppLifecycleState.resumed) {
      notifier.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Track lock and password changes reactively.
    ref.listen(appLockProvider, _onLockStatusChange);
    ref.listen<Uint8List?>(masterPasswordProvider, _onMasterPasswordChange);

    // Reset the countdown on ANY user input.
    return Listener(
      onPointerDown: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
      onPointerMove: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
      onPointerUp: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
      onPointerSignal: (_) => ref.read(autoLockProvider.notifier).resetTimer(),
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}
