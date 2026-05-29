import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taul/ui/providers/entry_providers.dart';

// ── State ──

class AutoLockState {
  const AutoLockState({
    this.duration = const Duration(minutes: 5),
    this.isActive = false,
    this.isPaused = false,
  });

  /// How long of inactivity before the app locks.
  final Duration duration;

  /// Whether the auto-lock timer is currently counting down.
  final bool isActive;

  /// Whether the timer is paused (e.g. app went to background).
  final bool isPaused;

  AutoLockState copyWith({
    Duration? duration,
    bool? isActive,
    bool? isPaused,
  }) {
    return AutoLockState(
      duration: duration ?? this.duration,
      isActive: isActive ?? this.isActive,
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

// ── Notifier ──

class AutoLockNotifier extends StateNotifier<AutoLockState> {
  AutoLockNotifier(this._ref) : super(const AutoLockState());

  final Ref _ref;
  Timer? _timer;

  /// Start (or restart) the inactivity countdown.
  void activate() {
    _startTimer();
  }

  /// Stop the timer and mark as inactive.
  void deactivate() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isActive: false, isPaused: false);
  }

  /// Reset the countdown — call on any user interaction.
  void resetTimer() {
    if (state.isActive && !state.isPaused) {
      _timer?.cancel();
      _startTimer();
    }
  }

  /// Pause the countdown (e.g. app goes to background).
  void pause() {
    if (state.isActive) {
      _timer?.cancel();
      _timer = null;
      state = state.copyWith(isPaused: true);
    }
  }

  /// Resume the countdown (e.g. app returns to foreground).
  void resume() {
    if (state.isActive && state.isPaused) {
      _startTimer();
    }
  }

  /// Change the configured duration. Resets the timer if active.
  void setDuration(Duration duration) {
    state = state.copyWith(duration: duration);
    if (state.isActive && !state.isPaused) {
      _timer?.cancel();
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(state.duration, _onTimeout);
    state = state.copyWith(isActive: true, isPaused: false);
  }

  void _onTimeout() {
    _timer = null;
    _ref.read(masterPasswordProvider.notifier).clearMasterPassword();
    _ref.read(appLockProvider.notifier).lock();
    state = state.copyWith(isActive: false, isPaused: false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

// ── Provider ──

final autoLockProvider =
    StateNotifierProvider<AutoLockNotifier, AutoLockState>((ref) {
  return AutoLockNotifier(ref);
});
