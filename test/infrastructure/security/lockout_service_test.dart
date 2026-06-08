import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/security/lockout_service.dart';

void main() {
  // Each test gets a fresh instance by resetting state
  late LockoutService lockout;

  setUp(() {
    lockout = LockoutService.instance;
    // Reset state between tests by accessing internals via reset
    lockout.resetAttempts('master_password');
    lockout.resetAttempts('backup_code');
  });

  group('Master password lockout', () {
    test('should not be locked out initially', () {
      expect(lockout.isLockedOut('master_password'), false);
      expect(lockout.lockoutRemaining('master_password'), null);
    });

    test('should track failed attempts', () {
      lockout.recordFailedAttempt('master_password');
      expect(lockout.failedAttempts('master_password'), 1);

      lockout.recordFailedAttempt('master_password');
      expect(lockout.failedAttempts('master_password'), 2);
    });

    test('should lock out after 5 failed attempts', () {
      for (var i = 0; i < 4; i++) {
        final locked = lockout.recordFailedAttempt('master_password');
        expect(locked, false);
      }
      final locked = lockout.recordFailedAttempt('master_password');
      expect(locked, true);
      expect(lockout.isLockedOut('master_password'), true);
      expect(lockout.lockoutRemaining('master_password'), isNotNull);
    });

    test('should reset attempts on success', () {
      for (var i = 0; i < 3; i++) {
        lockout.recordFailedAttempt('master_password');
      }
      lockout.resetAttempts('master_password');
      expect(lockout.failedAttempts('master_password'), 0);
      expect(lockout.isLockedOut('master_password'), false);
    });

    test('should lock out for 30 seconds', () {
      for (var i = 0; i < 5; i++) {
        lockout.recordFailedAttempt('master_password');
      }
      final remaining = lockout.lockoutRemaining('master_password');
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThanOrEqualTo(29));
      expect(remaining.inSeconds, lessThanOrEqualTo(30));
    });
  });

  group('Backup code lockout', () {
    test('should not be locked out initially', () {
      expect(lockout.isLockedOut('backup_code'), false);
    });

    test('should lock out after 3 failed attempts', () {
      for (var i = 0; i < 2; i++) {
        final locked = lockout.recordFailedAttempt('backup_code');
        expect(locked, false);
      }
      final locked = lockout.recordFailedAttempt('backup_code');
      expect(locked, true);
      expect(lockout.isLockedOut('backup_code'), true);
    });

    test('should lock out for 60 seconds', () {
      for (var i = 0; i < 3; i++) {
        lockout.recordFailedAttempt('backup_code');
      }
      final remaining = lockout.lockoutRemaining('backup_code');
      expect(remaining, isNotNull);
      expect(remaining!.inSeconds, greaterThanOrEqualTo(59));
      expect(remaining.inSeconds, lessThanOrEqualTo(60));
    });

    test('should reset independently from master password', () {
      lockout.recordFailedAttempt('master_password');
      lockout.recordFailedAttempt('master_password');
      lockout.resetAttempts('backup_code');
      expect(lockout.failedAttempts('master_password'), 2);
      expect(lockout.failedAttempts('backup_code'), 0);
    });
  });

  group('Categories are independent', () {
    test('master password and backup_code track separately', () {
      lockout.recordFailedAttempt('master_password');
      lockout.recordFailedAttempt('master_password');
      lockout.recordFailedAttempt('backup_code');

      expect(lockout.failedAttempts('master_password'), 2);
      expect(lockout.failedAttempts('backup_code'), 1);
    });

    test('lockout in one category does not affect the other', () {
      for (var i = 0; i < 5; i++) {
        lockout.recordFailedAttempt('master_password');
      }
      expect(lockout.isLockedOut('master_password'), true);
      expect(lockout.isLockedOut('backup_code'), false);
    });
  });
}
