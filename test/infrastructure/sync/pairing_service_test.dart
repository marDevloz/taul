import 'package:flutter_test/flutter_test.dart';
import 'package:taul/infrastructure/sync/pairing_service.dart';

void main() {
  late PairingService service;

  setUp(() {
    service = PairingService();
  });

  group('generateCode', () {
    test('should return 6-digit code', () {
      final code = service.generateCode();
      expect(code.length, 6);
      expect(int.parse(code), inInclusiveRange(100000, 999999));
    });

    test('should produce different codes on successive calls', () {
      final code1 = service.generateCode();
      final code2 = service.generateCode();
      // Extremely unlikely to be equal with secure random
      expect(code1, isNot(equals(code2)));
    });
  });

  group('validateCode', () {
    test('should accept correct code', () {
      final code = service.generateCode();
      expect(service.validateCode(code), true);
    });

    test('should reject incorrect code', () {
      service.generateCode();
      expect(service.validateCode('000000'), false);
    });

    test('should reset failed attempts on success', () {
      final code = service.generateCode();
      service.validateCode('111111');
      service.validateCode('222222');
      expect(service.failedAttempts, 2);
      service.validateCode(code);
      expect(service.failedAttempts, 0);
    });
  });

  group('lockout', () {
    test('should lock out after 3 failures', () {
      service.generateCode();
      service.validateCode('111111');
      service.validateCode('222222');
      final locked = service.validateCode('333333');
      expect(locked, false);
      expect(service.isLockedOut, true);
    });

    test('should reject all codes when locked out', () {
      final code = service.generateCode();
      service.validateCode('111111');
      service.validateCode('222222');
      service.validateCode('333333');
      expect(service.validateCode(code), false);
    });

    test('should reset after new code generated', () {
      service.generateCode();
      service.validateCode('111111');
      service.validateCode('222222');
      service.validateCode('333333');
      expect(service.isLockedOut, true);
      service.generateCode();
      expect(service.isLockedOut, false);
      expect(service.failedAttempts, 0);
    });
  });

  group('generateQrData', () {
    test('should return valid https URL', () {
      final data = service.generateQrData('192.168.1.100', 54321);
      expect(data, 'https://192.168.1.100:54321');
    });
  });
}
