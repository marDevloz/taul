import 'package:flutter_test/flutter_test.dart';
import 'package:taul/domain/entities/sync_state.dart';

void main() {
  group('SyncState.connecting', () {
    test('should be between idle and pairing', () {
      expect(SyncState.values.indexOf(SyncState.connecting),
          lessThan(SyncState.values.indexOf(SyncState.pairing)));
      expect(SyncState.values.indexOf(SyncState.connecting),
          greaterThan(SyncState.values.indexOf(SyncState.idle)));
    });

    test('should be considered active', () {
      expect(SyncState.connecting.isActive, isTrue);
    });

    test('should not allow start', () {
      expect(SyncState.connecting.canStart, isFalse);
    });

    test('should show progress', () {
      expect(SyncState.connecting.showProgress, isTrue);
    });
  });

  group('SyncState.isActive', () {
    test('should return true for connecting, pairing, syncing', () {
      expect(SyncState.connecting.isActive, isTrue);
      expect(SyncState.pairing.isActive, isTrue);
      expect(SyncState.syncing.isActive, isTrue);
    });

    test('should return false for idle, complete, error', () {
      expect(SyncState.idle.isActive, isFalse);
      expect(SyncState.complete.isActive, isFalse);
      expect(SyncState.error.isActive, isFalse);
    });
  });

  group('SyncState.canStart', () {
    test('should return true for idle, complete, error', () {
      expect(SyncState.idle.canStart, isTrue);
      expect(SyncState.complete.canStart, isTrue);
      expect(SyncState.error.canStart, isTrue);
    });

    test('should return false for connecting, pairing, syncing', () {
      expect(SyncState.connecting.canStart, isFalse);
      expect(SyncState.pairing.canStart, isFalse);
      expect(SyncState.syncing.canStart, isFalse);
    });
  });

  group('SyncState.showProgress', () {
    test('should return true for connecting, pairing, syncing, complete', () {
      expect(SyncState.connecting.showProgress, isTrue);
      expect(SyncState.pairing.showProgress, isTrue);
      expect(SyncState.syncing.showProgress, isTrue);
      expect(SyncState.complete.showProgress, isTrue);
    });

    test('should return false for idle, error', () {
      expect(SyncState.idle.showProgress, isFalse);
      expect(SyncState.error.showProgress, isFalse);
    });
  });
}