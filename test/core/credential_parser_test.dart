import 'package:flutter_test/flutter_test.dart';
import 'package:taul/core/credential_parser.dart';

void main() {
  group('CredentialParser', () {
    test('parses new *-separated format', () {
      final result = CredentialParser.parse('Gmail*user*pass');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
    });

    test('parses with URL as 4th *-segment', () {
      final result = CredentialParser.parse('Gmail*user*pass*https://mail.google.com');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
      expect(result.url, 'https://mail.google.com');
    });

    test('parses URL separated by space after *-segments', () {
      final result = CredentialParser.parse('Gmail*user*pass https://mail.google.com');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
      expect(result.url, 'https://mail.google.com');
    });

    test('parses with tags', () {
      final result = CredentialParser.parse('Gmail*user*pass -#work -#dev');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
      expect(result.tags, ['work', 'dev']);
    });

    test('parses full example', () {
      final result = CredentialParser.parse('Gmail*user*pass*https://mail.google.com -#work');
      expect(result, isNotNull);
      expect(result!.url, 'https://mail.google.com');
      expect(result.tags, ['work']);
    });

    test('parses bare domain URL without protocol', () {
      final result = CredentialParser.parse('Gmail*user*pass*mail.google.com');
      expect(result, isNotNull);
      expect(result!.url, 'mail.google.com');
      expect(result.username, 'user');
      expect(result.password, 'pass');
    });

    test('parses bare domain URL with space separator', () {
      final result = CredentialParser.parse('Gmail*user*pass mail.google.com');
      expect(result, isNotNull);
      expect(result!.url, 'mail.google.com');
    });

    test('parses IP address as URL', () {
      final result = CredentialParser.parse('Gmail*user*pass*192.168.1.1');
      expect(result, isNotNull);
      expect(result!.url, '192.168.1.1');
    });

    test('single * segment — password only', () {
      final result = CredentialParser.parse('Gmail*pass123');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'Gmail');
      expect(result.password, 'pass123');
    });

    test('returns null when no * found', () {
      final result = CredentialParser.parse('Gmail user pass');
      expect(result, isNull);
    });

    test('legacy comma format still works', () {
      final result = CredentialParser.parse('Gmail,*user,*pass');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
    });

    test('legacy comma format with tags', () {
      final result = CredentialParser.parse('Gmail,*user,*pass,;#work');
      expect(result, isNotNull);
      expect(result!.tags, ['work']);
    });

    test('ignores extra spaces around *', () {
      final result = CredentialParser.parse('  Gmail  *  user  *  pass  ');
      expect(result, isNotNull);
      expect(result!.service, 'Gmail');
      expect(result.username, 'user');
      expect(result.password, 'pass');
    });
  });
}
