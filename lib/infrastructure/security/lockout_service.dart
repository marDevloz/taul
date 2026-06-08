import 'dart:async';

/// In-memory lockout service for brute-force protection.
///
/// Tracks failed attempts per category and enforces time-based lockouts.
/// Resets on app restart (acceptable for offline desktop app).
class LockoutService {
  LockoutService._();
  static final instance = LockoutService._();

  // ── Configuration ──
  static const maxMasterPasswordAttempts = 5;
  static const masterPasswordLockoutSeconds = 30;
  static const maxBackupCodeAttempts = 3;
  static const backupCodeLockoutSeconds = 60;

  // ── State ──
  final _attempts = <String, int>{};
  final _lockoutUntil = <String, DateTime>{};
  final _timers = <String, Timer>{};

  /// Records a failed attempt for [category].
  /// Returns true if the user is now locked out.
  bool recordFailedAttempt(String category) {
    final count = (_attempts[category] ?? 0) + 1;
    _attempts[category] = count;

    final maxAttempts = _maxAttemptsFor(category);
    final lockoutDuration = _lockoutDurationFor(category);

    if (count >= maxAttempts) {
      _startLockout(category, lockoutDuration);
      return true;
    }
    return false;
  }

  /// Returns true if [category] is currently locked out.
  bool isLockedOut(String category) {
    final until = _lockoutUntil[category];
    if (until == null) return false;
    if (DateTime.now().isBefore(until)) return true;
    // Lockout expired — clean up
    _clearLockout(category);
    return false;
  }

  /// Returns remaining lockout duration, or null if not locked out.
  Duration? lockoutRemaining(String category) {
    final until = _lockoutUntil[category];
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) {
      _clearLockout(category);
      return null;
    }
    return remaining;
  }

  /// Resets failed attempts for [category] (call on successful verification).
  void resetAttempts(String category) {
    _attempts.remove(category);
    _clearLockout(category);
  }

  /// Number of failed attempts for [category] (before lockout).
  int failedAttempts(String category) => _attempts[category] ?? 0;

  // ── Internal ──

  int _maxAttemptsFor(String category) {
    if (category == 'backup_code') return maxBackupCodeAttempts;
    return maxMasterPasswordAttempts; // default: master password
  }

  Duration _lockoutDurationFor(String category) {
    if (category == 'backup_code') {
      return const Duration(seconds: backupCodeLockoutSeconds);
    }
    return const Duration(seconds: masterPasswordLockoutSeconds);
  }

  void _startLockout(String category, Duration duration) {
    _lockoutUntil[category] = DateTime.now().add(duration);
    _timers[category]?.cancel();
    _timers[category] = Timer(duration, () {
      _clearLockout(category);
    });
  }

  void _clearLockout(String category) {
    _lockoutUntil.remove(category);
    _attempts.remove(category);
    _timers[category]?.cancel();
    _timers.remove(category);
  }
}
